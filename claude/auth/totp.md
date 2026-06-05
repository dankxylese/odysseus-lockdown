# TOTP 2FA

**File:** `core/auth.py`
**Library:** `pyotp`

## Setup Flow

```
1. User requests TOTP setup
   POST /api/auth/totp/generate
   → totp_generate_secret(username)
   → Returns: {secret, otpauth_uri, qr_code_png_base64}
   (secret stored temporarily, totp_enabled=False until confirmed)

2. User scans QR code in authenticator app

3. User submits first code to confirm
   POST /api/auth/totp/confirm
   → totp_confirm_enable(username, code)
   → pyotp.TOTP(secret).verify(code)
   → If valid: set totp_enabled=True, generate 8 backup codes
   → Returns: {backup_codes: ["XXXX-XXXX", ...]}
   (user must save backup codes — shown once)
```

## Verification

```python
# core/auth.py — totp_verify(username, code)
def totp_verify(username: str, code: str) -> bool:
    user = self.users[username]
    if not user.get("totp_enabled"):
        return True   # no 2FA = always pass
    
    secret = user["totp_secret"]
    totp = pyotp.TOTP(secret)
    
    # Check main TOTP code (±1 window = 90s tolerance)
    if totp.verify(code, valid_window=1):
        return True
    
    # Check backup codes (consume on use)
    if code in user["totp_backup_codes"]:
        user["totp_backup_codes"].remove(code)
        self._save()
        return True
    
    return False
```

## Login Flow with TOTP

```
POST /api/auth/login
  1. verify_password(username, password) → if fail: 401
  2. if totp_enabled:
       if no totp_code in request: return {"requires_totp": true}
       totp_verify(username, totp_code) → if fail: 401
  3. create_session(username) → set cookie
```

## Disable 2FA

```python
# core/auth.py — totp_disable(username, password)
# Requires password confirmation
def totp_disable(username: str, password: str) -> bool:
    if not verify_password(username, password):
        return False
    user = self.users[username]
    user["totp_secret"] = None
    user["totp_enabled"] = False
    user["totp_backup_codes"] = []
    self._save()
    return True
```

## Backup Codes

- 8 codes generated at TOTP confirm time
- Format: `"XXXX-XXXX"` (8 alphanumeric chars with dash)
- Each code single-use (removed from list when used)
- Shown to user once at setup — not recoverable
- Routes at `routes/auth_routes.py`
