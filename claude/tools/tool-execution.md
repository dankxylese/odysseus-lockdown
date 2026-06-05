# Tool Execution

**File:** `src/tool_execution.py`
**Entry:** `async def execute_tool_block(tool_type, content, owner, session_id, workspace, ...) -> Dict`

Routes a parsed tool block to either an MCP server or a native implementation.

## Dispatch Logic

```python
# src/tool_execution.py — execute_tool_block()

# 1. Security gate (before anything else)
if is_public_blocked_tool(tool_type) and not owner_is_admin_or_single_user(owner):
    return {"error": f"Tool '{tool_type}' is not available for this user", "exit_code": 1}

# 2. MCP tools: mcp__<server_id>__<tool_name>
if tool_type.startswith("mcp__"):
    server_id, tool_name = parse_mcp_tool_name(tool_type)
    return await mcp_manager.call_tool(server_id, tool_name, parse_json_args(content))

# 3. Native tool dispatch
match tool_type:
    case "bash":          return await _do_bash(content, workspace)
    case "python":        return await _do_python(content, workspace)
    case "web_search":    return await do_web_search(content)
    case "web_fetch":     return await do_web_fetch(content)
    case "read_file":     return await _do_read_file(content, workspace)
    case "write_file":    return await _do_write_file(content, workspace)
    case "edit_file":     return await _do_edit_file(content, workspace)
    case "grep":          return await _do_grep(content, workspace)
    case "glob":          return await _do_glob(content, workspace)
    case "ls":            return await _do_ls(content, workspace)
    # ... all other tools delegate to src/tool_implementations.py do_*() functions
    case _:
        return await _delegate_to_implementations(tool_type, content, ...)
```

## Agent Working Directory

```python
# src/tool_execution.py:27
_AGENT_WORKDIR = str(pathlib.Path(__file__).parent.parent / "data")
# → /app/data in Docker
# Bash and Python executions use this as cwd to keep state in the bind-mounted volume
```

## Output Limits

```python
# src/tool_execution.py:29-31
MAX_OUTPUT_CHARS = 10_000   # bash/python stdout truncated to this
MAX_READ_CHARS   = 20_000   # file read content truncated
MAX_DIFF_LINES   = 400      # edit_file unified diff truncated
```

## File I/O Tools

### edit_file (exact string replacement)

```python
# src/tool_execution.py:70-120 — _do_edit_file()
# Input JSON: {"path": str, "old_string": str, "new_string": str, "replace_all"?: bool}
# 
# Fails if old_string is missing or non-unique (unless replace_all=true)
# → prevents silent edits to wrong location
# Returns: unified diff {"text": str, "added": N, "removed": M, "new_file": bool}
```

### write_file

Content too large to inline — see `src/tool_execution.py` for `_do_write_file()`.
Constrained to workspace when set, else to an allowlist of paths + sensitive-file blocklist.

### Path Resolution

```python
# src/tool_execution.py — _resolve_tool_path(raw_path)
# 1. Expand ~ to HOME
# 2. Resolve relative paths against _AGENT_WORKDIR
# 3. Block: /etc/passwd, /etc/shadow, .env files, credentials.json, etc.
# 4. When workspace= set: confine to workspace dir (_resolve_tool_path_in_workspace)
```

## Unified Diff

```python
# src/tool_execution.py:34-67 — _unified_diff()
import difflib
diff_lines = list(difflib.unified_diff(old_lines, new_lines, fromfile=f"a/{path}", ...))
# Truncated at MAX_DIFF_LINES
return {"text": diff, "added": N, "removed": M, "new_file": bool, "file": basename}
```

The diff is returned to the frontend for visual display.

## format_tool_result()

```python
# src/agent_tools.py — format_tool_result()
# Normalizes the raw tool result dict into the string injected into agent context:
# "Tool result (bash):\nExit code: 0\nOutput:\n<stdout>"
# "Tool result (bash):\nError: command timed out after 60s"
```

## Bash Execution

```python
# src/tool_execution.py — _do_bash()
# Runs via asyncio.create_subprocess_exec(["bash", "-c", command])
# cwd = _AGENT_WORKDIR
# timeout = 60 seconds (asyncio.wait_for)
# stdout/stderr captured, merged, truncated to MAX_OUTPUT_CHARS
# Returns: {"output": str, "exit_code": int}
```

## Python Execution

```python
# src/tool_execution.py — _do_python()
# Runs in a subprocess: python -c "..." or python <tmpfile>
# Same timeout + output limits as bash
# stdout captured, exec'ed in isolation (no shared state between calls)
```
