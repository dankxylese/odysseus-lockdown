# Streaming

## Endpoints

```
POST /api/chat         — non-streaming, returns full JSON response
POST /api/chat_stream  — SSE or chunked, yields tokens as they arrive
```

Both routes ultimately call the same pipeline. The streaming variant wraps it in a `StreamingResponse`.

## Stream Mechanics

```python
# routes/chat_routes.py — simplified
from fastapi.responses import StreamingResponse

async def generate():
    async for token in stream_agent_loop(messages, ...):  # or stream_llm() for plain chat
        yield token.encode("utf-8")

return StreamingResponse(generate(), media_type="text/plain")
```

**Token type:** raw UTF-8 text chunks (not SSE `data:` framing). The frontend reads them with a `ReadableStream` / `TextDecoder` loop.

## Tool Block Buffering During Stream

The LLM output is simultaneously:
1. **Yielded** to the client token-by-token (user sees it in real-time)
2. **Accumulated** in a buffer to detect tool blocks after the response ends

```python
# src/agent_loop.py — simplified streaming round
accumulated = ""
async for token in stream_llm(messages, ...):
    yield token           # → client sees it immediately
    accumulated += token

# After stream ends:
blocks = parse_tool_blocks(accumulated)
if blocks:
    # Execute tools, inject result, start next round
    # Client stream stays open across rounds
```

This means the client stream stays **open for the entire agent run**, even across multiple tool executions. Each round's tokens are appended to the same stream.

## Round Boundary Markers

Between tool execution and the next LLM response, tool result is visible to the user:
```
[LLM text...]
[Tool result (bash): ...]   ← injected as context, shown to user
[LLM continuation...]       ← next round begins
```

The frontend renders this progressively — each chunk appended to the chat bubble.

## Shell SSE Stream: /api/shell/stream

Separate endpoint for interactive shell execution:
- Returns `text/event-stream` (true SSE)
- Route: `routes/shell_routes.py`
- Format: `data: {"output": "...", "exit_code": null|N}\n\n`
- Admin-gated (requires `is_admin`)

## Streaming vs Non-Streaming LLM Calls

```python
# src/llm_core.py
async def stream_llm(messages, endpoint, model, ...) -> AsyncGenerator[str, None]:
    # Streams via httpx async streaming
    async with client.stream("POST", url, json=payload) as resp:
        async for chunk in resp.aiter_text():
            # Parse SSE data: lines, extract content delta
            yield delta

async def llm_call_async(messages, endpoint, model, ...) -> str:
    # Single POST, waits for full response
    resp = await client.post(url, json=payload)
    return resp.json()["choices"][0]["message"]["content"]
```

## Request Timeout Exemption

Streaming endpoints are exempt from the 45s `_RequestTimeoutMiddleware`:
```python
# app.py:121-131
_TIMEOUT_EXEMPT_PREFIXES = (
    "/api/chat",         # streaming agent can run for minutes
    "/api/shell/stream", # SSE
    "/api/research",     # multi-minute deep research
    ...
)
```
