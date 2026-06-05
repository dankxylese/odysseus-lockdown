# Personal Documents RAG

**Files:** `src/personal_docs.py`, `src/rag_vector.py`, `src/rag_manager.py`

Semantic search over user-uploaded documents (PDFs, markdown, text files). Per-user ChromaDB collections.

## Stack

```
PersonalDocsManager (src/personal_docs.py)
  └─ RAGManager (src/rag_manager.py)
       └─ VectorRAG (src/rag_vector.py)
            └─ ChromaDB collection: odysseus_rag_<owner>
```

## VectorRAG

```python
# src/rag_vector.py — VectorRAG

COLLECTION_PREFIX = "odysseus_rag_"

def index_file(path: str, owner: str):
    """Read file, chunk it, embed chunks, upsert into ChromaDB."""
    text = extract_text(path)      # PDF→text, markdown→text, etc.
    chunks = chunk_text(text, size=500, overlap=50)
    for i, chunk in enumerate(chunks):
        embedding = embed_model.encode([chunk])
        collection.upsert(
            ids=[f"{path}#{i}"],
            embeddings=embedding.tolist(),
            documents=[chunk],
            metadatas=[{"source": path, "chunk": i, "owner": owner}],
        )

def search(query: str, owner: str, k: int = 5) -> list[dict]:
    """Return top-k semantically relevant chunks."""
    embedding = embed_model.encode([query])
    collection = client.get_collection(COLLECTION_PREFIX + owner)
    results = collection.query(
        query_embeddings=embedding.tolist(),
        n_results=k,
        include=["documents", "metadatas"],
    )
    return [{"text": doc, "source": meta["source"]} 
            for doc, meta in zip(results["documents"][0], results["metadatas"][0])]
```

## PersonalDocsManager

```python
# src/personal_docs.py — PersonalDocsManager

def add_directory(path: str, owner: str) -> dict:
    """Scan directory for documents and index all of them."""
    supported = [".pdf", ".md", ".txt", ".rst", ".html", ".docx"]
    for file in Path(path).rglob("*"):
        if file.suffix in supported:
            rag.index_file(str(file), owner)
    return {"indexed": count, "path": path}

def search(query: str, owner: str, k: int = 5) -> Optional[str]:
    """Return formatted search results, or None if no relevant chunks."""
    hits = rag.search(query, owner, k)
    if not hits:
        return None
    return "\n\n".join(f"[{h['source']}]\n{h['text']}" for h in hits)

def remove_document(path: str, owner: str):
    """Remove all chunks for a specific document."""
    # Deletes from ChromaDB where source=path
```

## Routes

```
POST /api/personal/add_directory
  Body: {"path": "/path/to/docs", "owner": "alice"}

POST /api/personal/query
  Body: {"query": "what is the cancellation policy?"}

DELETE /api/personal/document
  Body: {"path": "/path/to/file.pdf"}
```

Source: `routes/personal_routes.py`

## Supported File Types

PDF, Markdown, plain text, RST, HTML, DOCX. PDF extraction uses `pypdf`. Other formats use standard file reading.

## Per-User Isolation

Each user gets their own ChromaDB collection (`odysseus_rag_<username>`). Users cannot search each other's documents. Admin can index to any user's collection.
