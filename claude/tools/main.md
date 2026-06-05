# Tool System

Three-tier system: **native tools** + **MCP tools** + **RAG-selected delivery**.

## Three Tiers

```
LLM output (tool blocks)
  │
  ▼
parse_tool_blocks()              src/tool_parsing.py
  │  5 formats: fenced blocks, [TOOL_CALL], XML <invoke>, <tool_code>, DSML
  │
  ▼
execute_tool_block(type, content)  src/tool_execution.py
  │
  ├─ mcp__*     → mcp_manager.call_tool()      src/mcp_manager.py
  └─ everything else → do_*(content, ...)      src/tool_implementations.py
```

## Tool Discovery Per Request

Not all 60+ tools are in the system prompt. Each agent round retrieves a ~20-tool subset:

```python
# src/tool_index.py — get_tools_for_round()
always   = ALWAYS_AVAILABLE           # always present (bash, python, web_search, etc.)
relevant = idx.get_tools_for_query(message, k=16)  # cosine similarity to user message
mcp      = [all connected MCP tool names]
blocked  = blocked_tools_for_owner(owner)          # security gate
final    = (always | relevant | mcp) - blocked
```

## Security Gate

```python
# src/tool_security.py:54-66 — is_public_blocked_tool()
# Returns True (blocked) for non-admin users for:
# bash, python, file I/O, grep/glob/ls, manage_*, email, calendar, tasks,
# webhooks, tokens, endpoints, MCP, api_call, vault, model download/serve
# MCP tools (mcp__*) always blocked for non-admin
# Single-user or AUTH_ENABLED=false → all tools allowed
```

## Detailed Files

| Topic | File |
|---|---|
| RAG tool selection, ALWAYS_AVAILABLE | [tool-index.md](tool-index.md) |
| 5 parsing formats, DSML, TOOL_NAME_MAP | [tool-parsing.md](tool-parsing.md) |
| execute_tool_block routing, file I/O | [tool-execution.md](tool-execution.md) |
| All 60+ native tools grouped by category | [native-tools.md](native-tools.md) |
| Security gate, privilege checking | [tool-security.md](tool-security.md) |
| MCP manager lifecycle, transports | [mcp-manager.md](mcp-manager.md) |
| Built-in MCP servers (Browser, Google, etc.) | [mcp-builtin.md](mcp-builtin.md) |

## Adding a New Native Tool

1. Add the tool name string to `TOOL_TAGS` in `src/agent_tools.py`
2. Add a `do_<toolname>()` async function in `src/tool_implementations.py`
3. Add routing in `execute_tool_block()` in `src/tool_execution.py`
4. Add a rich description in `BUILTIN_TOOL_DESCRIPTIONS` in `src/tool_index.py`
5. If admin-only: add to `NON_ADMIN_BLOCKED_TOOLS` in `src/tool_security.py`
6. If always available: add to `ALWAYS_AVAILABLE` in `src/tool_index.py`

## Tool Block Format

The canonical format (Pattern 1) the LLM writes:
```
```bash
ls -la /app/data
```
```

Result format injected back into context:
```
Tool result (bash):
Exit code: 0
Output:
total 48
drwxr-xr-x 8 ...
```
