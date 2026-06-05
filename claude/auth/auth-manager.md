# AuthManager

**File:** `core/auth.py`
**Class:** `AuthManager`

Handles all user lifecycle operations: creation, password verification, session tokens, TOTP 2FA.

## Persistence

```
data/auth.json   — all user data (atomic writes via core/atomic_io.py)
```

Format:
```json
{
  "users": {
    "alice": {
      "password_hash": "$2b$12$...",
      "created": "ISO8601",
      "is_admin": true,
      "privileges": {"can_use_agent": true, ...},
      "totp_secret": null,
      "totp_enabled": false,
      "totp_backup_codes": []
    }
  },
  "sessions": {
    "<token_hex>": {"username": "alice", "expiry": "ISO8601"}
  }
}
```

## Key Methods

### User Creation
```python
# core/auth.py
def create_user(username: str, password: str, is_admin: bool = False) -> bool:
    hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt(rounds=12)).decode()
    self.users[username] = {
        "password_hash": hash,
        "created": datetime.utcnow().isoformat(),
        "is_admin": is_admin,
        "privileges": {},
        "totp_secret": None, "totp_enabled": False, "totp_backup_codes": [],
    }
    self._save()
    return True
```

### Password Verification
```python
def verify_password(username: str, password: str) -> bool:
    user = self.users.get(username)
    if not user:
        return False
    return bcrypt.checkpw(password.encode(), user["password_hash"].encode())
```

### Session Creation
```python
def create_session(username: str) -> str:
    token = secrets.token_hex(32)    # 64-char hex string
    expiry = (datetime.utcnow() + timedelta(days=7)).isoformat()
    self.sessions[token] = {"username": username, "expiry": expiry}
    self._save()
    return token
```

### Token Validation
```python
def validate_token(token: Optional[str]) -> bool:
    if not token:
        return False
    session = self.sessions.get(token)
    if not session:
        return False
    # Check expiry
    expiry = datetime.fromisoformat(session["expiry"])
    if datetime.utcnow() > expiry:
        del self.sessions[token]
        self._save()
        return False
    # Check user still exists
    return session["username"] in self.users
```

### Delete User (Security: Revoke All Access)
```python
def delete_user(username: str) -> bool:
    # Remove user record
    del self.users[username]
    # Revoke ALL active sessions for this user
    to_remove = [t for t, s in self.sessions.items() if s["username"] == username]
    for t in to_remove:
        del self.sessions[t]
    # API tokens are revoked via DB cascade in routes/api_token_routes.py
    self._save()
    return True
```

## is_configured Property

```python
@property
def is_configured(self) -> bool:
    return len(self.users) > 0
```

Used by AuthMiddleware to redirect to `/login` for initial setup.

## Atomic Writes

```python
# core/auth.py — _save()
from core.atomic_io import atomic_write_json
atomic_write_json("data/auth.json", {"users": self.users, "sessions": self.sessions})
# Write to temp file, fsync, rename — crash-safe
```

## TOTP 2FA

See [totp.md](totp.md) for full 2FA details.

Quick reference: `totp_secret` field in user dict. When `totp_enabled=True`, login flow requires TOTP code after password.
