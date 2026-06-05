# Tool Index — RAG-Based Tool Selection

**File:** `src/tool_index.py`

Instead of putting all 60+ tool descriptions in the system prompt (token waste, irrelevant noise), tool descriptions are embedded in ChromaDB and the top-K most relevant are retrieved per message.

## Initialization

```python
# src/tool_index.py — get_tool_index() (singleton)
# Called at startup warmup (app.py:907) and per agent round
def get_tool_index() -> Optional[ToolIndex]:
    # 1. Load fastembed model (ONNX, ~80MB, first call ~1-3s)
    # 2. Get/create ChromaDB collection: COLLECTION_NAME = "odysseus_tool_index"
    # 3. Index all BUILTIN_TOOL_DESCRIPTIONS (upsert by tool name hash)
    # 4. Return ToolIndex instance
```

The startup warmup moves the slow model load OFF the first user message.

## ALWAYS_AVAILABLE Tools

These tools are included in **every** agent round regardless of retrieval score:

```python
# src/tool_index.py:24-51
ALWAYS_AVAILABLE = frozenset({
    "bash", "python", "web_search", "web_fetch",
    "read_file", "write_file", "edit_file",
    "grep", "glob", "ls",
    "api_call",
    "list_served_models", "stop_served_model", "tail_serve_output",
    "serve_model", "serve_preset", "list_serve_presets",
    "list_cached_models", "list_cookbook_servers",
    "adopt_served_model",
    "app_api",
})
```

## ASSISTANT_ALWAYS_AVAILABLE

For personal assistant scheduled tasks:

```python
# src/tool_index.py:54-68
ASSISTANT_ALWAYS_AVAILABLE = frozenset({
    "list_email_accounts", "list_emails", "read_email", "send_email",
    "reply_to_email", "bulk_email", "archive_email", "delete_email", "mark_email_read",
    "manage_calendar", "manage_notes", "manage_tasks",
    "manage_memory", "web_search", "read_file",
    "create_document", "update_document",
    "resolve_contact", "search_chats",
    "api_call", "ui_control",
})
```

## Tool Description Embedding

Each tool has a rich description in `BUILTIN_TOOL_DESCRIPTIONS` (src/tool_index.py:75+).
These are longer than prompt descriptions — they're for embedding quality, not token efficiency.

Examples:
```python
"bash": "Run shell commands on the server. Install packages, check files, git operations, curl, system info, process management, networking.",
"web_search": "Quick single web lookup for a fact, current event, or doc mid-task. NOT for 'research X' / 'do research on X' requests — those are deep-research jobs (use trigger_research). web_search = one query; trigger_research = a full researched report in the sidebar.",
"manage_tasks": "Scheduled task management: list, create, edit, delete, pause, resume, or run cron tasks.",
```

## Retrieval

```python
# src/tool_index.py — ToolIndex.get_tools_for_query()
def get_tools_for_query(query: str, k: int = 16) -> set[str]:
    embedding = embed_model.encode([query])
    results = collection.query(
        query_embeddings=embedding.tolist(),
        n_results=k,
        include=["metadatas"],
    )
    return {r["tool_name"] for r in results["metadatas"][0]}
```

ChromaDB collection: `odysseus_tool_index`
Embedding model: fastembed `all-MiniLM-L6-v2` (same model used for memory + personal docs)
`get_chroma_client()` singleton → `src/chroma_client.py`

## Tool Index Rebuild

If tool descriptions change (new tool added, description updated):
```python
# Tool index auto-rebuilds via upsert on get_tool_index() call
# The hash of each tool name+description is stored as metadata
# Changed descriptions → re-embedded automatically
```

## ChromaDB Dependency

If ChromaDB is unreachable at startup:
- `get_rag_manager()` returns `None`
- Tool index falls back to `ALWAYS_AVAILABLE` only (no RAG selection)
- Personal docs unavailable
- Memory vector search unavailable
- Routes return 503 with `{"error": "RAG not available"}`
