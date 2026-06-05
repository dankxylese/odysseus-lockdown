# Auth Middleware

**File:** `app.py:252-359` — `AuthMiddleware` class

Full middleware dispatch logic — see also [../architecture/request-pipeline.md](../architecture/request-pipeline.md) for the full stack context.

## Dispatch Order

```python
async def dispatch(self, request: Request, call_next):
    path = request.url.path

    # 1. Exempt paths → pass through immediately
    if _is_auth_exempt(path):
        return await call_next(request)

    # 2. Internal tool loopback (X-Odysseus-Internal-Token)
    #    Only from direct loopback (no proxy headers)
    hdr = request.headers.get(INTERNAL_TOOL_HEADER)
    if hdr and secrets.compare_digest(hdr, INTERNAL_TOOL_TOKEN) and _is_trusted_loopback(request):
        # Optional impersonation via X-Odysseus-Owner
        impersonate = request.headers.get("X-Odysseus-Owner")
        request.state.current_user = impersonate if valid else "internal-tool"
        request.state.api_token = False
        return await call_next(request)

    # 3. LOCALHOST_BYPASS for direct loopback (no proxy headers)
    if LOCALHOST_BYPASS and _is_trusted_loopback(request):
        return await call_next(request)

    # 4. Auth not configured yet → redirect or 401
    if not auth_manager.is_configured:
        ...

    # 5. Bearer token (API)
    auth_header = request.headers.get("authorization", "")
    if auth_header.startswith("Bearer ody_"):
        ...validate via prefix cache + bcrypt...
        request.state.current_user = "api"
        request.state.api_token = True
        request.state.api_token_owner = matched_owner
        request.state.api_token_scopes = matched_scopes
        return await call_next(request)

    # 6. Session cookie
    token = request.cookies.get(SESSION_COOKIE)
    if not auth_manager.validate_token(token):
        return 401 or redirect to /login

    request.state.current_user = auth_manager.get_username_for_token(token)
    request.state.api_token = False
    return await call_next(request)
```

## request.state Fields Set by Middleware

| Field | Type | Meaning |
|---|---|---|
| `current_user` | str | Username of authenticated user (`"api"` for Bearer, `"internal-tool"` for loopback) |
| `api_token` | bool | True if Bearer token auth |
| `api_token_id` | str | Bearer token DB row ID (for last_used update) |
| `api_token_owner` | str | Actual owner username when `current_user="api"` |
| `api_token_scopes` | list[str] | Authorized scopes (e.g. `["chat", "email:read"]`) |

## Bearer Token Validation

```python
# app.py:294-341
raw_token = auth_header[7:]      # strip "Bearer "
prefix = raw_token[:8]           # first 8 chars as cache key

# Cache check (avoids DB query on every request)
if app.state._token_cache_dirty:
    async with _token_cache_lock:
        await asyncio.to_thread(_refresh_token_cache)

candidates = _token_cache.get(prefix, [])
for tid, thash, owner, scopes in candidates:
    if bcrypt.checkpw(raw_token.encode(), thash.encode()):
        matched_id, matched_owner, matched_scopes = tid, owner, scopes
        break

# Fire-and-forget last_used_at update (off hot path)
asyncio.create_task(_touch_last_used(matched_id))
```

Cache is invalidated (`app.state._token_cache_dirty = True`) when any token is created or revoked — routes call `app.state.invalidate_token_cache()`.

## _is_trusted_loopback()

```python
# app.py:236-250
def _is_trusted_loopback(request: Request) -> bool:
    # Must be direct loopback (127.0.0.1 or ::1)
    # AND have no proxy forwarding headers (CF-Connecting-IP, X-Forwarded-For, etc.)
    # Cloudflare tunnel connects FROM 127.0.0.1, so this blocks tunnel bypass
```

## Internal Tool Token

```python
# core/middleware.py
INTERNAL_TOOL_HEADER = "X-Odysseus-Internal-Token"
INTERNAL_TOOL_TOKEN  = secrets.token_hex(32)   # generated fresh per process start
```

The agent uses this token when making HTTP loopback calls to admin-gated routes (e.g., calendar, notes). The token is only valid within the same process lifetime and only from direct loopback.

## get_current_user() Helper

```python
# src/auth_helpers.py
def get_current_user(request: Request) -> Optional[str]:
    user = getattr(request.state, "current_user", None)
    # For Bearer tokens, return api_token_owner (the real user), not "api"
    if user == "api":
        return getattr(request.state, "api_token_owner", None)
    return user
```

Route handlers call `get_current_user(request)` to get the effective username, transparent to whether cookie or Bearer.
