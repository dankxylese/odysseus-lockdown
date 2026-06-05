# Authentication

Two-layer auth: **session cookies** for browser users, **Bearer tokens** for API access. Both handled in `AuthMiddleware` in `app.py`.

## Files

| File | Role |
|---|---|
| `core/auth.py` | AuthManager — bcrypt, TOTP, user CRUD, privilege system |
| `app.py:252-359` | AuthMiddleware — request-level auth enforcement |
| `core/middleware.py` | INTERNAL_TOOL_HEADER, INTERNAL_TOOL_TOKEN constants |
| `src/auth_helpers.py` | `get_current_user()`, `require_admin()`, `owner_filter()` |
| `routes/auth_routes.py` | Login, signup, logout, TOTP, status endpoints |
| `routes/api_token_routes.py` | API token CRUD |

## Quick Reference

| Scenario | How auth works |
|---|---|
| Browser user | Session cookie (`odysseus_session`) → `AuthManager.validate_token()` |
| API client | `Authorization: Bearer ody_<token>` → bcrypt check via prefix cache |
| Agent loopback | `X-Odysseus-Internal-Token` header + direct loopback → `internal-tool` user |
| No auth | `AUTH_ENABLED=false` → all requests pass through |
| Localhost bypass | `LOCALHOST_BYPASS=true` + direct loopback (no proxy headers) → pass through |

## Detailed Files

- [middleware.md](middleware.md) — AuthMiddleware dispatch logic
- [auth-manager.md](auth-manager.md) — AuthManager: bcrypt, users, sessions
- [totp.md](totp.md) — 2FA setup flow and verification
- [privileges.md](privileges.md) — Per-user privilege booleans
- [api-tokens.md](api-tokens.md) — API token format, scopes, prefix cache

## Key Constants

```python
# app.py:161-186
AUTH_EXEMPT_EXACT = {
    "/api/auth/setup", "/api/auth/signup", "/api/auth/login", "/api/auth/logout",
    "/api/auth/status", "/api/auth/features", "/api/auth/settings",
    "/api/auth/integrations/presets",
    "/api/health", "/api/version", "/login",
}
AUTH_EXEMPT_PREFIXES = ["/static"]
# Dynamic: /api/tasks/<id>/webhook/<token>  (webhook token auth)

SESSION_COOKIE = "odysseus_session"  # routes/auth_routes.py
```

## Persistence

```
data/auth.json    — users dict with password hashes + privileges
data/sessions.json — (legacy; sessions now in DB)
data/app.db        — ApiToken table for Bearer tokens
```

`data/auth.json` structure:
```json
{
  "users": {
    "alice": {
      "password_hash": "$2b$12$...",
      "created": "2025-01-01T00:00:00",
      "is_admin": true,
      "privileges": {...},
      "totp_secret": null,
      "totp_backup_codes": []
    }
  }
}
```

## Reserved Usernames

`internal-tool`, `api`, `demo`, `system` — cannot be created via signup. These are internal sentinels used by the auth system.
