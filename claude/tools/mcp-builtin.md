# Built-in MCP Servers

**File:** `src/builtin_mcp.py`
**Entry:** `register_builtin_servers(mcp_manager)` — called at startup

These servers are pre-registered and connect automatically if their dependencies are available. Users can also add custom MCP servers via Settings → MCP.

## Browser (Playwright)

```python
# src/builtin_mcp.py
# Transport: stdio
# Command: npx -y @playwright/mcp@latest
# Requires: Node.js + npx on PATH (or pre-cached)
```

Tools exposed:
- `screenshot` — capture current browser page
- `navigate` — go to URL
- `click` — click element
- `type` — type text into field
- `extract_text` — get page text content

Error if `npx` unavailable: "run `npx -y @playwright/mcp@latest --version` to cache it"

## Fetch

```python
# Transport: stdio
# Command: node <bundled_fetch_server_path>
# No external dependencies
```

Tools: `fetch` — HTTP GET/POST, returns parsed content.

## Google Calendar

```python
# Transport: http (OAuth flow)
# Requires: Google OAuth credentials in api_key_manager
# OAuth flow: src/mcp_oauth.py
```

Tools mirror Google Calendar API: list events, create event, update event, delete event.

## Gmail

```python
# Transport: http (OAuth flow)
# Same OAuth setup as Google Calendar
```

Tools: list messages, get message, send message, create draft.

## Google Drive

```python
# Transport: http (OAuth flow)
```

Tools: list files, get file, create file, update file.

## Filesystem

```python
# Transport: stdio
# Command: python -m mcp_servers.rag_server (or similar internal server)
```

Exposes read/write/search of specific allowed directories.

## Internal MCP Servers (mcp_servers/)

These are Odysseus-native MCP servers that run as separate processes:

| Server | File | Purpose |
|---|---|---|
| Email MCP | `mcp_servers/email_server.py` | Email tools via stdio for external agents |
| Image Gen MCP | `mcp_servers/image_gen_server.py` | Image generation tools |
| Memory MCP | `mcp_servers/memory_server.py` | Memory access for external agents |
| RAG MCP | `mcp_servers/rag_server.py` | Personal doc search for external agents |

These are NOT auto-connected — they're available for users to add as custom MCP servers pointing to `localhost`.

## Adding a Custom MCP Server

Via UI: Settings → MCP → Add Server

Via API:
```http
POST /api/mcp/servers
{
  "name": "My Server",
  "transport": "stdio",
  "command": "node",
  "args": ["/path/to/server.js"]
}
```

Or for HTTP/SSE:
```http
POST /api/mcp/servers
{
  "name": "Remote Server",
  "transport": "sse",
  "url": "http://localhost:8080/sse"
}
```

## Security Note

MCP tool schemas are untrusted (third-party servers). All schema content is sanitized before injection into the system prompt — see [mcp-manager.md](mcp-manager.md) for sanitization details.

MCP tools are always blocked for non-admin users regardless of what tools the server exposes.
