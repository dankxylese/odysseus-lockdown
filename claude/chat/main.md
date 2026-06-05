# Chat & Agent Pipeline

The chat system has two modes: **plain chat** (single LLM call) and **agent mode** (multi-round tool loop). The routing decision happens before any LLM call.

## Decision Tree: Chat vs Agent

```
POST /api/chat
  │
  ├─ classify_tool_intent(message)          src/action_intents.py
  │    Regex patterns for: calendar, notes, email, shell, research, UI actions
  │    Returns: ToolIntent(needs_tools: bool, category: str)
  │
  ├─ needs_tools = True → agent_loop.stream_agent_loop()
  │
  └─ needs_tools = False → single LLM call (stream or non-stream)
```

## Files in This Pipeline

| File | Role |
|---|---|
| `routes/chat_routes.py` | HTTP entry point — validates request, calls handler |
| `src/chat_handler.py` | Builds LLM context (system prompt + memory + docs + history) |
| `src/chat_processor.py` | BM25 + RAG memory retrieval, personal-doc injection |
| `src/action_intents.py` | Pattern-based chat-to-agent routing |
| `src/agent_loop.py` | Multi-round agent: tool retrieval → LLM stream → parse → execute → loop |
| `src/tool_parsing.py` | Extract tool blocks from LLM output |
| `src/tool_execution.py` | Route tool blocks to native/MCP, format results |
| `src/context_compactor.py` | Auto-summarize when approaching context limit |
| `src/llm_core.py` | HTTP client for OpenAI-compatible endpoints |
| `src/endpoint_resolver.py` | Resolve which LLM endpoint/model to use |
| `src/model_context.py` | Token estimation + context window math |

## Detailed Docs

- [request-to-llm.md](request-to-llm.md) — Full request flow from HTTP to first LLM call
- [agent-loop.md](agent-loop.md) — Multi-round agent execution with tool blocks
- [streaming.md](streaming.md) — SSE streaming mechanics
- [context-build.md](context-build.md) — How system prompt, memory, and docs are assembled
- [compaction.md](compaction.md) — Context window management and auto-summarization

## Key Data Shapes

**Tool block format** (what the LLM writes to invoke a tool):
```
```bash
ls -la /app/data
```
```

**Agent round result** injected back into messages:
```json
{"role": "user", "content": "Tool result (bash):\nExit code: 0\nOutput:\ntotal 48\n..."}
```

**context_compactor trigger** ([src/context_compactor.py:38](../../src/context_compactor.py)):
```python
COMPACT_THRESHOLD = 0.85  # at 85% of context window, summarize oldest messages
```
