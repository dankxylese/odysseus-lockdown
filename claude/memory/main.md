# Memory & RAG Systems

Three overlapping memory systems that inject context into the LLM.

## Systems Overview

| System | File | Persistence | Search |
|---|---|---|---|
| Native Memory | `src/memory.py` | `data/memory.json` | Fuzzy text + BM25 |
| Vector Memory | `src/memory_vector.py` | ChromaDB `odysseus_memory` | Semantic (cosine) |
| Personal Docs | `src/personal_docs.py` + `src/rag_vector.py` | ChromaDB `odysseus_rag_<owner>` | Semantic (cosine) |

All three are injected into the LLM context via `src/chat_processor.py` before each message.

## Detailed Files

- [native-memory.md](native-memory.md) — MemoryManager: JSON persistence, CRUD, fuzzy search
- [vector-memory.md](vector-memory.md) — MemoryVectorStore: ChromaDB, fastembed, recall/store
- [personal-docs.md](personal-docs.md) — PersonalDocsManager: VectorRAG, per-user collections
- [context-injection.md](context-injection.md) — How memory/docs are injected into chat context

## Quick Flow

```
User message arrives
  │
  ▼
ChatProcessor.retrieve_context(message, owner)
  ├─ BM25 keyword search over all memories
  ├─ memory_vector.recall(message, top_k=5)  — semantic similarity
  └─ Merge + deduplicate → format as "Memory: ..."
  │
  ▼
personal_docs_mgr.search(message, owner, k=5)
  └─ VectorRAG.search() → relevant document chunks
  │
  ▼
Both results wrapped in untrusted_context_message()
Added to LLM messages BEFORE chat history
```

## ChromaDB Dependency

Both vector systems require ChromaDB running at `CHROMA_HOST:CHROMA_PORT` (docker-compose: `chromadb` service).

If unavailable:
- `get_rag_manager()` returns `None`
- Memory falls back to native (JSON) search only
- Personal docs unavailable (routes return 503)

## Routes

```
/api/memory/*           — routes/memory_routes.py
/api/personal/*         — routes/personal_routes.py
/api/embedding/*        — routes/embedding_routes.py (model management)
```
