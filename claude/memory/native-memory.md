# Native Memory

**File:** `src/memory.py`
**Class:** `MemoryManager`

JSON-backed key-value memory store. Works without ChromaDB — the only memory system available if ChromaDB is down.

## Persistence

```python
# data/memory.json
{
  "<uuid>": {
    "text": "User prefers dark themes",
    "timestamp": "2025-06-01T12:00:00",
    "category": "preference",
    "source": "chat",
    "owner": "alice",
    "metadata": {}
  },
  ...
}
```

Written atomically via `core/atomic_io.atomic_write_json()` — no corruption on crash.

## API

```python
# src/memory.py — MemoryManager
def add(text: str, category: str = "general", source: str = "chat", owner: str = None) -> str:
    """Add memory, return its ID."""
    id = str(uuid4())
    self.memories[id] = {"text": text, "timestamp": ..., "category": category, 
                          "source": source, "owner": owner, "metadata": {}}
    self._save()
    return id

def list(owner: str = None) -> list:
    """Return all memories, optionally filtered by owner."""
    
def delete(id: str) -> bool:
    """Remove a memory by ID."""

def search_fuzzy(query: str, owner: str = None, limit: int = 10) -> list:
    """BM25-like keyword match over memory text."""
    # Simple word overlap scoring, no external dependencies
```

## Memory Categories

Used for retrieval filtering and display grouping:
- `"preference"` — user preferences ("I prefer...", "I like...")
- `"fact"` — factual info ("My name is...", "I work at...")
- `"task"` — task-related context
- `"general"` — catch-all

## manage_memory Tool Actions

The `manage_memory` tool in `src/tool_implementations.py` wraps these methods:

```python
# action values the LLM can use:
"add"    → memory_manager.add(text, category)
"list"   → memory_manager.list(owner)
"delete" → memory_manager.delete(id)
"search" → memory_manager.search_fuzzy(query)
"edit"   → update text/category of existing memory
```

## Owner Isolation

All memories have an `owner` field. Non-admin users only see their own memories.
`owner_filter()` in `src/auth_helpers.py` applies this at the route level.
