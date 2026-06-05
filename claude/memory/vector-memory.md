# Vector Memory

**File:** `src/memory_vector.py`
**Class:** `MemoryVectorStore`

ChromaDB-backed semantic memory search. Stores embeddings of memory text and retrieves by cosine similarity.

## ChromaDB Collection

```python
COLLECTION_NAME = "odysseus_memory"
# One global collection for all users (owner stored in metadata for filtering)
```

## Core Operations

```python
# src/memory_vector.py — MemoryVectorStore

def store(id: str, text: str, owner: str, metadata: dict = None):
    """Embed memory text and upsert into ChromaDB."""
    embedding = embed_model.encode([text])   # fastembed ONNX
    collection.upsert(
        ids=[id],
        embeddings=embedding.tolist(),
        documents=[text],
        metadatas=[{"owner": owner, **(metadata or {})}],
    )

def recall(query: str, owner: str = None, top_k: int = 5) -> list[dict]:
    """Find most semantically similar memories."""
    embedding = embed_model.encode([query])
    where = {"owner": owner} if owner else None
    results = collection.query(
        query_embeddings=embedding.tolist(),
        n_results=top_k,
        where=where,
        include=["documents", "metadatas", "distances"],
    )
    # Returns: [{"text": str, "id": str, "distance": float, "owner": str}]

def rebuild(memories: list[dict]):
    """Re-embed all memories — used after bulk import."""
    collection.delete(where={"owner": owner})
    for m in memories:
        self.store(m["id"], m["text"], m["owner"])
```

## Embedding Model

```python
# src/embeddings.py — get_embedding_client() singleton
# Model: all-MiniLM-L6-v2 (fastembed ONNX)
# ~80MB download on first use, cached in data/
# Same model used for tool index + personal docs
```

## Health Check

```python
# src/memory_vector.py — __init__
try:
    self.client = get_chroma_client()   # HTTP client to ChromaDB
    self.client.heartbeat()
    self.healthy = True
except Exception:
    self.healthy = False
    logger.warning("ChromaDB unreachable — vector memory disabled")
```

Routes check `memory_vector.healthy` before calling vector methods and fall back to native search.

## Sync with Native Memory

When a memory is added via `manage_memory` tool or `/api/memory`:
1. `memory_manager.add(...)` → saves to `data/memory.json`
2. If `memory_vector.healthy`: `memory_vector.store(id, text, owner)` → ChromaDB

When deleted:
1. `memory_manager.delete(id)` → removes from JSON
2. `memory_vector.delete(id)` → removes from ChromaDB collection

If ChromaDB was down when a memory was added, `rebuild()` is called on reconnect to sync.
