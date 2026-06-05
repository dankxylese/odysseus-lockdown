# Privilege System

**File:** `core/auth.py` — `get_privileges(username)` and `update_privileges(username, ...)`

Each user has a `privileges` dict in `data/auth.json`. Admins always get all privileges.

## Privilege Fields

```python
# Merged from stored + defaults when missing:
DEFAULT_PRIVILEGES = {
    "can_use_agent":     True,   # agent mode (tool loop)
    "can_use_bash":      False,  # bash/python tools (admin only by default)
    "can_use_browser":   True,   # web search + web fetch
    "can_use_documents": True,   # document editor
    "can_use_research":  True,   # deep research
    "can_generate_images": True, # image generation
    "can_manage_memory": True,   # memory add/edit/delete
    "max_messages_per_day": 0,   # 0 = unlimited
    "allowed_models": [],        # [] = all models allowed
}
```

## Admin Override

```python
# core/auth.py — get_privileges(username)
def get_privileges(username: str) -> dict:
    if self.is_admin(username):
        # Admins get everything regardless of stored values
        return {k: True for k in DEFAULT_PRIVILEGES} | {"max_messages_per_day": 0, "allowed_models": []}
    stored = self.users[username].get("privileges", {})
    return DEFAULT_PRIVILEGES | stored   # stored overrides defaults
```

## Tool Security vs Privileges

These are two separate systems:

| System | File | Controls |
|---|---|---|
| Tool security gate | `src/tool_security.py` | Which tools non-admins can execute (bash, python, etc.) |
| User privileges | `core/auth.py` | Feature access at the HTTP route level (can_use_research, etc.) |

Tool security is the primary enforcement mechanism. Privileges are higher-level feature toggles that routes check before reaching the agent.

## Checking Privileges in Routes

```python
# Example from a route handler
privileges = auth_manager.get_privileges(current_user)
if not privileges.get("can_use_research"):
    raise HTTPException(403, "Research not enabled for this account")
```

## Admin Status

```python
# core/auth.py
def is_admin(username: str) -> bool:
    return self.users.get(username, {}).get("is_admin", False)

# First user created is always admin (routes/auth_routes.py signup logic)
```

## Rate Limiting via Privileges

```python
# max_messages_per_day: int
# 0 = unlimited
# Tracked via message count in DB (core/database.py ChatMessage table)
# Reset at midnight UTC
```
