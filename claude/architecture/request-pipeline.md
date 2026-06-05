# Request Pipeline

Every HTTP request passes through this chain before reaching a route handler.

## Middleware Chain (outer → inner)

```
Client
  │
  ▼
[1] CORSMiddleware                   app.py:88
    Allowed origins: ALLOWED_ORIGINS env (default: localhost)
    Custom headers: X-Odysseus-Internal-Token, X-Odysseus-Owner, X-TZ-Offset
  │
  ▼
[2] SecurityHeadersMiddleware        core/middleware.py
    Adds: X-Frame-Options: DENY, X-Content-Type-Options: nosniff
    Generates CSP nonce → request.state.csp_nonce
    HTML responses get: Content-Security-Policy with nonce
  │
  ▼
[3] _RequestTimeoutMiddleware        app.py:134
    Hard limit: REQUEST_HARD_TIMEOUT (default 45s)
    asyncio.wait_for(call_next(request), timeout=45)
    Returns 504 on timeout
    EXEMPT prefixes: /api/chat, /api/shell/stream, /api/research,
                     /api/model/download, /api/model/probe,
                     /api/model-endpoints, /api/cookbook/setup,
                     /api/upload, /api/image
  │
  ▼
[4] AuthMiddleware                   app.py:252   (only if AUTH_ENABLED=true)
    │
    ├─ Exempt exact paths: /api/auth/*, /api/health, /api/version, /login
    ├─ Exempt prefix: /static
    ├─ Exempt pattern: /api/tasks/<id>/webhook/<token>  (path-embedded credential)
    │
    ├─ Internal loopback bypass:
    │    Header: X-Odysseus-Internal-Token = INTERNAL_TOOL_TOKEN (secrets.token_hex(32))
    │    Must be DIRECT loopback (127.0.0.1/::1, NO proxy forward headers)
    │    Sets: request.state.current_user = X-Odysseus-Owner value (or "internal-tool")
    │
    ├─ LOCALHOST_BYPASS (direct loopback only, no proxy headers):
    │    Sets: request.state.current_user = None (treated as anonymous admin)
    │
    ├─ Bearer token path (Authorization: Bearer ody_<token>):
    │    Prefix cache: token[:8] → [(id, hash, owner, scopes)]
    │    Cache invalidated on token create/revoke (app.state.invalidate_token_cache)
    │    bcrypt.checkpw(raw_token, stored_hash)
    │    Sets: request.state.current_user = "api"
    │          request.state.api_token = True
    │          request.state.api_token_owner = <owner username>
    │          request.state.api_token_scopes = ["chat", ...]
    │    Fire-and-forget: update ApiToken.last_used_at
    │
    └─ Cookie path (SESSION_COOKIE):
         auth_manager.validate_token(token) → check expiry + user exists
         Sets: request.state.current_user = <username>
               request.state.api_token = False
  │
  ▼
Route handler
```

## Proxy Safety: _is_trusted_loopback()

The internal loopback and LOCALHOST_BYPASS checks use this function:

```python
# app.py:236-250
_PROXY_FWD_HEADERS = (
    "cf-connecting-ip", "cf-ray", "cf-visitor",
    "x-forwarded-for", "x-forwarded-host", "x-real-ip", "forwarded",
)

def _is_trusted_loopback(request: Request) -> bool:
    host = request.client.host if request.client else None
    if host not in ("127.0.0.1", "::1"):
        return False
    # Reject if ANY proxy forwarding header present — Cloudflare tunnel
    # connects from 127.0.0.1, so this prevents tunnel bypass.
    for _h in _PROXY_FWD_HEADERS:
        if request.headers.get(_h):
            return False
    return True
```

## Exception Handlers

Registered globally — any unhandled domain exception returns structured JSON:

| Exception | Status | JSON |
|---|---|---|
| `SessionNotFoundError` | 404 | `{"error": "SESSION_NOT_FOUND"}` |
| `InvalidFileUploadError` | 400 | `{"error": "INVALID_FILE_UPLOAD"}` |
| `LLMServiceError` | 502 | `{"error": "LLM_SERVICE_ERROR"}` |
| `WebSearchError` | 502 | `{"error": "WEB_SEARCH_ERROR"}` |

Defined in `core/exceptions.py`, handlers at `app.py:490-504`.

## Static Assets

```python
# app.py:368-383 — _RevalidatingStatic
# .js/.css/.html → Cache-Control: no-cache (revalidate, never serve stale)
# Generated images → Cache-Control: public, max-age=31536000, immutable
# (filenames are content hashes so they never change)
```

## CSP Nonce Injection

HTML pages served via `_serve_html_with_nonce()` (`app.py:731`):
- `SecurityHeadersMiddleware` generates `request.state.csp_nonce` per request
- `app.py:736`: replaces `{{CSP_NONCE}}` placeholder in HTML with the nonce
- Inline `<script>` tags in `index.html` carry `nonce="{{CSP_NONCE}}"` which matches the CSP header
