# Context Injection

**File:** `src/chat_processor.py`
**Class:** `ChatProcessor`

How memory and personal document results are retrieved and injected into the LLM message array.

## Retrieval Pipeline

```python
# src/chat_processor.py — ChatProcessor.retrieve_context(message, owner)

def retrieve_context(message: str, owner: str) -> Optional[str]:
    all_memories = memory_manager.list(owner=owner)
    
    # Stage 1: BM25 keyword match
    bm25_hits = _bm25_search(message, all_memories)
    
    # Stage 2: Semantic vector match (if ChromaDB available)
    vector_hits = []
    if memory_vector and memory_vector.healthy:
        vector_hits = memory_vector.recall(message, owner=owner, top_k=5)
    
    # Merge: union by ID, deduplicate, rank by combined score
    hits = _merge_results(bm25_hits, vector_hits)
    
    if not hits:
        return None
    
    # Format for LLM context
    lines = [f"- {h['text']}" for h in hits[:8]]
    return "Relevant memories:\n" + "\n".join(lines)
```

## BM25 Search

```python
# Simple TF-IDF-like scoring without external dependencies
def _bm25_search(query: str, memories: list) -> list:
    query_words = set(query.lower().split())
    scored = []
    for m in memories:
        words = set(m["text"].lower().split())
        overlap = len(query_words & words)
        if overlap > 0:
            scored.append((overlap / len(query_words), m))
    return [m for _, m in sorted(scored, reverse=True)[:10]]
```

## Injection into LLM Messages

Both memory and doc results are wrapped as `untrusted_context_message()` before injection:

```python
# src/chat_handler.py — ChatHandler.build_context()

# 1. Memory context
memory_context = chat_processor.retrieve_context(message, owner=user)
if memory_context:
    messages.append(untrusted_context_message("memories", memory_context))
    # Injected as role:"user" with <<<UNTRUSTED_SOURCE_DATA>>> markers

# 2. Personal document context
doc_hits = personal_docs_mgr.search(message, owner=user, k=5)
if doc_hits:
    messages.append(untrusted_context_message("personal_documents", doc_hits))

# 3. Chat history
messages.extend(session_messages)

# 4. Current user message
messages.append({"role": "user", "content": ...})
```

Injection point: BEFORE chat history, AFTER system prompt.

## Why Untrusted Wrapping

Memory content could be:
- Injected by a previous tool result that contained malicious text
- From external sources (emails, web pages stored as memories)

The `<<<UNTRUSTED_SOURCE_DATA>>>` markers tell the LLM to treat this as data, not instructions. See [../security/prompt-injection.md](../security/prompt-injection.md).

## Relevance Threshold

Context is only injected if there are actual hits — no empty context blocks are added. This prevents padding the context window with irrelevant `[No memories found]` noise.

## Personal Assistant Context

For scheduled personal assistant runs (`src/builtin_actions.py`), the assistant has access to `ASSISTANT_ALWAYS_AVAILABLE` tools which include `manage_memory` directly — it can read/write memories as part of its proactive check-ins.
