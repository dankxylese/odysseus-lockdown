# Context Building

How the LLM message array is assembled before each call.

## Assembly Order

```python
messages = []

# 1. System prompt
messages.append({
    "role": "system",
    "content": preset.system_prompt or DEFAULT_SYSTEM_PROMPT
})

# 2. Untrusted memory context (if relevant memories found)
#    src/chat_processor.py — ChatProcessor.retrieve_context()
memory_hits = chat_processor.retrieve_context(user_message, owner=user)
if memory_hits:
    messages.append(untrusted_context_message("memories", memory_hits))
    # → role: "user", wrapped in <<<UNTRUSTED_SOURCE_DATA>>> markers

# 3. Personal document context (if RAG finds relevant chunks)
doc_hits = personal_docs_mgr.search(user_message, owner=user, k=5)
if doc_hits:
    messages.append(untrusted_context_message("personal_documents", doc_hits))

# 4. Chat history (N most recent messages)
for msg in session.get_recent_messages(limit=N):
    messages.append({"role": msg.role, "content": msg.content})

# 5. Current user message
messages.append({"role": "user", "content": content_blocks})
#   content_blocks = str for text-only, list for multimodal (images + text)
```

## Memory Retrieval: ChatProcessor (src/chat_processor.py)

Two-stage retrieval combining keyword (BM25) and semantic (vector) search:

```python
# src/chat_processor.py — ChatProcessor.retrieve_context()
# Stage 1: BM25 keyword match over all memories
bm25_hits = bm25_search(user_message, memories)

# Stage 2: Vector similarity via MemoryVectorStore
vector_hits = memory_vector.recall(user_message, top_k=5)

# Merge + deduplicate + rank
hits = merge_and_rank(bm25_hits, vector_hits)

# Return top hits as formatted text
return format_memory_hits(hits)
```

Full memory detail → [../memory/context-injection.md](../memory/context-injection.md)

## Multimodal Content (Images)

When the user attaches an image:
```python
content_blocks = [
    {"type": "text", "text": user_message},
    {"type": "image_url", "image_url": {"url": "data:image/png;base64,..."}}
]
messages.append({"role": "user", "content": content_blocks})
```

Images are base64-encoded from `data/uploads/`. Vision model must be set on the endpoint.

Handled in `src/document_processor.py` — `process_multimodal_content()`.

## Agent-Mode System Prompt Addition

When entering agent mode, `_AGENT_PREAMBLE` + `_AGENT_RULES` are prepended to (or replace) the system message, and tool descriptions are appended:

```python
# src/agent_loop.py
system_content = _AGENT_PREAMBLE + "\n\n" + _AGENT_RULES + "\n\n"
system_content += format_tool_list(available_tools)
messages[0] = {"role": "system", "content": system_content}
```

The original preset system prompt is retained as a suffix to the agent preamble.

## Prompt Security Wrapping

External/untrusted content is always wrapped:
```python
# src/prompt_security.py:26
def untrusted_context_message(label: str, content: Any) -> Dict:
    return {
        "role": "user",
        "content": (
            f"{UNTRUSTED_CONTEXT_HEADER}\n"
            f"Source: {label}\n\n"
            "<<<UNTRUSTED_SOURCE_DATA>>>\n"
            f"{content}\n"
            "<<<END_UNTRUSTED_SOURCE_DATA>>>"
        ),
        "metadata": {"trusted": False, "source": label},
    }
```

Sources wrapped: memories, personal documents, web results, emails, tool output, skills text.

## Context Length Enforcement

Before each LLM call:
```python
# src/model_context.py
window = get_context_length(model)        # lookup table by model name
used   = estimate_tokens(messages)        # rough 4-chars-per-token heuristic
ratio  = used / window

if ratio > COMPACT_THRESHOLD (0.85):
    messages = await compact_context(messages, endpoint, model)
```

Compaction detail → [compaction.md](compaction.md)
