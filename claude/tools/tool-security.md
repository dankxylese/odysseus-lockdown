# Tool Security

**File:** `src/tool_security.py`

## NON_ADMIN_BLOCKED_TOOLS

```python
# src/tool_security.py:14-51
NON_ADMIN_BLOCKED_TOOLS = {
    # Server filesystem access
    "bash", "python",
    "read_file", "write_file", "edit_file",
    "grep", "glob", "ls",

    # Cross-user data exposure
    "search_chats",

    # Persistent state mutations
    "manage_memory", "manage_skills", "manage_tasks",
    "manage_endpoints", "manage_mcp", "manage_webhooks",
    "manage_tokens", "manage_documents", "manage_settings",

    # Generic loopback surfaces
    "api_call", "app_api",

    # External messaging
    "send_email", "reply_to_email",
    "list_emails", "read_email",
    "resolve_contact", "manage_contact",
    "manage_calendar",

    # Credential access
    "vault_search", "vault_get", "vault_unlock",

    # Heavy resource operations
    "download_model", "serve_model", "serve_preset",
    "stop_served_model", "cancel_download", "adopt_served_model",
}
```

## Gate Function

```python
# src/tool_security.py:54-66
def is_public_blocked_tool(tool_name: Optional[str]) -> bool:
    """Fails CLOSED: malformed/None tool_name treated as blocked."""
    if tool_name is None or tool_name == "":
        return False  # nothing to gate
    if not isinstance(tool_name, str):
        return True   # non-string = blocked (injection attempt)
    # mcp__ tools always blocked for non-admins
    return tool_name in NON_ADMIN_BLOCKED_TOOLS or tool_name.startswith("mcp__")
```

## Admin Check

```python
# src/tool_security.py:69-80
def owner_is_admin_or_single_user(owner: Optional[str]) -> bool:
    auth = AuthManager()
    if not auth.is_configured:
        return True   # No users yet → allow all (initial setup)
    return bool(owner and auth.is_admin(owner))
```

## Privilege Bypass Conditions

All tools are available when ANY of these are true:
1. `AUTH_ENABLED=false` — auth disabled entirely
2. `auth.is_configured = False` — no users created yet
3. User has `is_admin=True` in `data/auth.json`
4. Single user exists (implied admin)

## blocked_tools_for_owner()

```python
# src/tool_security.py:83-87
def blocked_tools_for_owner(owner: Optional[str]) -> Set[str]:
    """Returns full blocked set for non-admins, empty set for admins."""
    if owner_is_admin_or_single_user(owner):
        return set()
    return set(NON_ADMIN_BLOCKED_TOOLS)
```

Used in agent loop to filter tool list before injection into system prompt — non-admin users never even _see_ blocked tools in the prompt.

## Where the Gate is Enforced

1. **System prompt** — `blocked_tools_for_owner(owner)` removes blocked tools from retrieval (`src/agent_loop.py`)
2. **Execution** — `is_public_blocked_tool()` checked at start of `execute_tool_block()` (`src/tool_execution.py`)
3. **MCP** — all `mcp__*` tools blocked for non-admins regardless of server

Double-enforcement (prompt + execution) means:
- Prompt filter: user never sees the tool option
- Execution filter: defense-in-depth if model somehow tries to use it anyway
