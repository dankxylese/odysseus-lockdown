# MCP Manager

**File:** `src/mcp_manager.py`
**Class:** `McpManager`

Manages connections to MCP (Model Context Protocol) servers. Each server exposes tools that become available in the agent loop as `mcp__<server_id>__<tool_name>`.

## State

```python
class McpManager:
    _connections: Dict[str, dict]     # server_id → {status, name, error, ...}
    _tools: Dict[str, list]           # server_id → [tool schemas]
    _sessions: Dict[str, Any]         # server_id → MCP ClientSession
    _stacks: Dict[str, Any]           # server_id → context manager stack
    _connect_tasks: Dict[str, Task]   # server_id → in-flight connect task
    _generation: int                  # bumps on tool list change → invalidates prompt cache
```

## Connection Lifecycle

```python
# src/mcp_manager.py — connect_server()
async def connect_server(server_id, name, transport, command, args, env, url):
    # transport: "stdio" | "sse" | "http"
    
    # stdio: spawn subprocess
    if transport == "stdio":
        params = StdioServerParameters(command=command, args=args, env=env)
        read, write = await stdio_client(params).__aenter__()
    
    # SSE: HTTP streaming
    elif transport == "sse":
        read, write = await sse_client(url).__aenter__()
    
    # HTTP: OAuth flow (handled via mcp_oauth.py)
    
    session = await ClientSession(read, write).__aenter__()
    await session.initialize()
    tools = await session.list_tools()
    
    self._sessions[server_id] = session
    self._tools[server_id] = tools.tools
    self._generation += 1   # invalidate prompt cache
    self._connections[server_id] = {"status": "connected", ...}
```

## Tool Calling

```python
# src/mcp_manager.py — call_tool()
async def call_tool(server_id: str, tool_name: str, args: dict) -> Any:
    session = self._sessions[server_id]
    result = await session.call_tool(tool_name, args)
    return result.content  # list of TextContent | ImageContent | ...
```

## Tool Name Format

MCP tools are exposed as: `mcp__<server_id>__<tool_name>`

Examples:
- `mcp__browser__screenshot`
- `mcp__gmail__send_email`
- `mcp__my-custom-server__query_db`

The double underscore separates server ID from tool name in `tool_execution.py` dispatch.

## Schema Sanitization (Prompt Safety)

MCP servers are third-party — their tool schemas are untrusted input. Before injecting into the system prompt:

```python
# src/mcp_manager.py:42-80 — _sanitize_schema_token() + _format_mcp_params()
_MCP_PARAM_MAX = 12    # max params rendered per tool
_MCP_TOKEN_MAX = 40    # max chars per name/type token
_MCP_HINT_MAX  = 300   # total hint length cap

def _sanitize_schema_token(value, limit=40):
    text = re.sub(r"[\x00-\x1f\x7f]+", " ", str(value))   # strip control chars
    text = re.sub(r"\s+", " ", text).strip()
    if len(text) > limit:
        text = text[:limit].rstrip() + "…"
    return text
```

Prevents hostile schema from injecting newlines or blowing up the prompt.

## Generation Counter

```python
self._generation: int  # incremented every time tool list changes
```

This is used to invalidate prompt caches when MCP tools change (new server connected, server disconnected, server reconnected with different tools). The agent loop re-fetches the tool list each round, so it automatically picks up the new generation.

## Startup Connection

```python
# app.py:884-897 — _startup_mcp_connections()
# 1. register_builtin_servers(mcp_manager)   → src/builtin_mcp.py
# 2. mcp_manager.connect_all_enabled()       → all DB-persisted servers with enabled=True
# Runs as background task (20s timeout), non-blocking
```

## Error Handling

```python
# src/mcp_manager.py:16-31 — _format_mcp_connection_error()
# Provides user-actionable messages for common failures:
# - Playwright MCP: "run npx -y @playwright/mcp@latest --version to cache it"
# - Generic: raw error string
```

## DB Model

MCP server config stored in `McpServer` SQLAlchemy model (`core/database.py`):
```
id, owner, name, transport, command, args, env, url, 
enabled (bool), disabled_tools (JSON array of disabled tool names)
```

`disabled_tools` allows per-server tool disabling from the UI.

## Routes

`routes/mcp_routes.py`:
- `GET /api/mcp/servers` — list all + tool schemas + connection status
- `POST /api/mcp/servers` — add new server
- `DELETE /api/mcp/servers/{id}` — remove + disconnect
- `POST /api/mcp/servers/{id}/reconnect` — reconnect
- `POST /api/mcp/servers/{id}/call` — invoke tool directly
