# API Tokens

**File:** `routes/api_token_routes.py`, `core/database.py:ApiToken`

Bearer tokens for external API access. Format: `ody_<43 chars base64>`.

## Token Format

```python
# routes/api_token_routes.py — create token
import secrets, base64
raw = "ody_" + base64.urlsafe_b64encode(secrets.token_bytes(32)).rstrip(b"=").decode()
# Example: ody_ABC123XYZ...  (4 + 43 = 47 chars total)
prefix = raw[:8]   # first 8 chars stored for cache lookup
hash   = bcrypt.hashpw(raw.encode(), bcrypt.gensalt()).decode()
```

DB row: `ApiToken(id, owner, name, token_prefix, token_hash, scopes, is_active, last_used_at, created_at)`

## Token Scopes

```python
# Comma-separated in ApiToken.scopes column
VALID_SCOPES = [
    "chat",           # POST /api/chat, /api/chat_stream
    "todos:read",     # GET notes/tasks
    "todos:write",    # POST/PUT/DELETE notes/tasks
    "email:read",     # GET emails
    "email:draft",    # Create email drafts
    "email:send",     # Send emails
]
```

Routes check scopes via:
```python
scopes = getattr(request.state, "api_token_scopes", [])
if "email:send" not in scopes:
    raise HTTPException(403, "Token scope insufficient")
```

## In-Memory Prefix Cache

```python
# app.py:200-225
# Map: token_prefix (first 8 chars) → [(id, hash, owner, scopes)]
# Rebuilt from DB on first request after invalidation
_token_cache: dict = {}
_token_cache_dirty = True

def _refresh_token_cache():
    rows = db.query(ApiToken).filter(ApiToken.is_active == True).all()
    for r in rows:
        new_map[r.token_prefix].append((r.id, r.token_hash, r.owner, scopes))
```

Cache invalidated (`app.state.invalidate_token_cache()`) when:
- Token created
- Token revoked (is_active → False)
- Token deleted

This prevents a DB query on every API request while keeping revocation immediate.

## Routes

```
GET    /api/tokens              — list my tokens (owner-filtered)
POST   /api/tokens              — create new token (returns raw token ONCE)
DELETE /api/tokens/{id}         — revoke token
GET    /api/tokens/{id}/last-used — get last_used_at
```

## Codex Integration

The Codex plugin uses API tokens with specific scopes. `routes/codex_routes.py` re-uses the same token scopes for the Codex/Claude plugin bridge, so external Codex sessions only touch data the user explicitly authorized.
