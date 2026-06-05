# Request to LLM — Full Flow

## Entry Point: routes/chat_routes.py

```python
# routes/chat_routes.py — setup_chat_routes()
# POST /api/chat
# POST /api/chat_stream (streaming variant)
```

Request body (Pydantic model at `src/request_models.py`):
```python
class ChatRequest:
    session_id: str
    message: str
    attach_ids: list[str]   # uploaded file IDs
    preset_id: Optional[str]
    research_enabled: bool
    model: Optional[str]    # override session model
    endpoint_id: Optional[str]
```

## Step 1 — Auth & Session Hydration

```python
user = get_current_user(request)             # from request.state.current_user
session = session_manager.get_session(session_id)  # loads metadata; messages lazy
```

`SessionManager.get_session()` is defined in `core/session_manager.py`. Messages are loaded from DB on demand.

## Step 2 — Intent Classification

```python
# src/action_intents.py:108
intent = classify_tool_intent(message)
# Returns ToolIntent(needs_tools=True/False, category="calendar|notes|email|...", reason="...")
```

Key: an explanatory question ("how do I add an event?") returns `needs_tools=False` via `_EXPLANATORY_PREFIX` check. Only action verbs trigger agent mode.

Full pattern list → [src/action_intents.py:48-100](../../src/action_intents.py)

## Step 3 — Context Building (src/chat_handler.py + src/chat_processor.py)

```python
# Simplified — actual call in chat_handler.py
messages = []

# System prompt from preset or default
messages.append({"role": "system", "content": system_prompt})

# Relevant memories (BM25 + vector retrieval)
# src/chat_processor.py — ChatProcessor.retrieve_context()
memory_context = chat_processor.retrieve_context(message, owner=user)
if memory_context:
    messages.append(untrusted_context_message("memories", memory_context))

# Relevant personal documents (VectorRAG)
doc_context = personal_docs_mgr.search(message, owner=user)
if doc_context:
    messages.append(untrusted_context_message("personal_documents", doc_context))

# Chat history (from session_manager)
for msg in session.messages[-N:]:
    messages.append({"role": msg.role, "content": msg.content})

# Current user message (with attachments as multimodal content if images)
messages.append({"role": "user", "content": [...]})
```

Untrusted context wrapping → [../security/prompt-injection.md](../security/prompt-injection.md)
Memory retrieval detail → [../memory/context-injection.md](../memory/context-injection.md)

## Step 4 — Endpoint Resolution (src/endpoint_resolver.py)

```python
# Resolves: session endpoint → user default endpoint → OPENAI_BASE_URL env
endpoint = resolve_endpoint(session, model_override=request.model)
# Returns: {"url": "http://localhost:11434/v1/chat/completions", "model": "llama3.2", ...}
```

## Step 5 — LLM Call or Agent Loop

### Plain chat (needs_tools=False):
```python
# src/llm_core.py — llm_call_async() or stream_llm()
response = await llm_call_async(messages, endpoint, model, temperature=...)
# OR for streaming:
async for chunk in stream_llm(messages, endpoint, model, ...):
    yield chunk
```

### Agent mode (needs_tools=True):
```python
# src/agent_loop.py — stream_agent_loop()
async for token in stream_agent_loop(messages, session, endpoint, model, owner=user, ...):
    yield token
```

Agent loop detail → [agent-loop.md](agent-loop.md)

## Step 6 — Save Response

After LLM/agent returns final text:
```python
session_manager.add_message(session_id, "assistant", response_text, metadata={...})
# Fires webhook events: chat.completed, chat.message
webhook_manager.fire_event("chat.completed", session_id, owner=user)
```

## LLM Core: src/llm_core.py

Key functions:
- `llm_call_async(messages, endpoint, model, ...)` → single call, returns full text
- `stream_llm(messages, endpoint, model, ...)` → async generator yielding tokens
- `stream_llm_with_fallback(...)` → tries primary, falls back to secondary endpoint

Dead-host cooldown: failed endpoints are cooled off for N seconds to avoid hammering.
Retry logic: transient errors retried up to 3 times with backoff.
