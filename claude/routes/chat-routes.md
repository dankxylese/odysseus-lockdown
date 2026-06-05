# Chat Routes

**File:** `routes/chat_routes.py`

## POST /api/chat

Non-streaming chat endpoint.

```python
# Request body (src/request_models.py: ChatRequest)
{
    "session_id": "uuid",
    "message": "user text",
    "attach_ids": ["upload-id-1"],   # uploaded file IDs
    "preset_id": "preset-uuid",       # optional preset
    "research_enabled": false,
    "model": "llama3.2",             # override session model
    "endpoint_id": "ep-uuid"         # override session endpoint
}

# Response
{
    "response": "assistant text",
    "session_id": "uuid",
    "metadata": {"model": ..., "tokens": ..., "agent_rounds": N}
}
```

## POST /api/chat_stream

Streaming variant — returns plain text chunks (not SSE `data:` frames).
Same request body as `/api/chat`. Client reads via `ReadableStream`.

## GET /api/search

Quick web search (not deep research):
```python
# Query params: q=<query>&count=<N>
# Returns: [{"title", "url", "snippet"}, ...]
# Backed by SearXNG
```

## Research Routes (routes/research_routes.py)

```
POST /api/research             — start deep research job
  Body: {"query": str, "session_id": str, "depth": "quick"|"deep"}
  Returns: {"job_id": uuid}

GET  /api/research/{job_id}    — poll status
  Returns: {"status": "pending"|"running"|"done"|"error", "progress": N}

GET  /api/research/{job_id}/report  — get completed report
  Returns: {"report": markdown_text, "sources": [...]}

GET  /api/research             — list all research jobs for user
DELETE /api/research/{job_id}  — delete research job
```

## History Routes (routes/history_routes.py)

```
GET /api/history/search?q=<query>   — full-text search across all chat messages
GET /api/history/recent             — recently active sessions
```

## Shell Routes (routes/shell_routes.py)

```
POST /api/shell/exec    — execute command (returns JSON, admin only)
GET  /api/shell/stream  — SSE shell execution stream (admin only)
  Event format: data: {"output": str, "exit_code": null|N}
```

## Session Routes (routes/session_routes.py)

```
GET    /api/sessions              — list all sessions (paginated)
POST   /api/sessions              — create new session
GET    /api/sessions/{id}         — get session metadata + messages
PUT    /api/sessions/{id}         — update (rename, change model/preset)
DELETE /api/sessions/{id}         — delete session + messages
POST   /api/sessions/{id}/fork    — clone session
POST   /api/sessions/{id}/archive — archive (hide from list)
GET    /api/sessions/{id}/messages — get messages (paginated)
DELETE /api/sessions/{id}/messages — clear messages
```

## Chat Handler Flow (for adding new chat behaviour)

If you need to add pre-processing or post-processing to the chat pipeline:

1. **Pre-processing** (before LLM call): modify `src/chat_handler.py:ChatHandler.build_context()`
2. **Intent routing** (chat vs agent): modify `src/action_intents.py:_ROUTING_PATTERNS`
3. **Agent system prompt**: modify `src/agent_loop.py:_AGENT_RULES`
4. **Post-processing** (after LLM response): modify `routes/chat_routes.py` response handling

## Copilot Routes (routes/copilot_routes.py)

```
POST /api/copilot/auth/start     — begin GitHub device flow
GET  /api/copilot/auth/poll      — poll for completion
POST /api/copilot/auth/complete  — exchange code for token
GET  /api/copilot/models         — list Copilot-available models
```
