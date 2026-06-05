# Knowledge Base — Maintenance & Design

## Last Synced Commit
```
73673258199b353f9b3e04da9b37ae95077e2c8b
```
*(Run the update command below after each `git pull` to keep this in sync.)*

---

## Update Command

After pulling new commits, run this prompt in Claude Code from the repo root:

```
/claude Update the knowledge base in claude/ based on commits since 73673258199b353f9b3e04da9b37ae95077e2c8b.

Steps:
1. Run: git log 73673258199b353f9b3e04da9b37ae95077e2c8b..HEAD --name-only --pretty=format:"COMMIT %H %s"
2. For each changed file, read it and compare against the relevant docs in claude/
3. Update only the affected sections — do not rewrite files that haven't changed
4. Add new files to the appropriate section if entirely new modules appear
5. Update the "Last Synced Commit" hash in claude/README.md to the new HEAD

Focus on: new tools (claude/tools/native-tools.md + tool-index.md), route changes (claude/routes/), 
auth changes (claude/auth/), new integrations (claude/integrations/), new builtin actions (claude/scheduling/builtin-actions.md).
```

---

## Knowledge Base Design Principles

This knowledge base is built so Claude Code can answer "how does X work?" or "where do I add Y?" 
**without reading source files** for the common cases.

### Hierarchy Rules

1. **CLAUDE.md** (root) — one-line summaries + section pointers only. Never put implementation detail here.

2. **`claude/<topic>/main.md`** — loaded first for any query about that topic. Contains:
   - 2–3 sentence system overview
   - Key code snippets showing the critical paths (not the full file)
   - Internal links table showing which files implement which behaviour
   - Pointers to the deeper files in the same folder

3. **`claude/<topic>/<detail>.md`** — loaded only when main.md isn't sufficient. Contains:
   - Actual code snippets of core logic (the 10–30 lines that matter)
   - Exact file paths + line numbers for every referenced symbol
   - Cross-links to other topic `main.md` files where systems interact

### What Goes in the Docs (and What Doesn't)

| Include | Exclude |
|---|---|
| Core logic snippets (10–30 lines) | Full file contents |
| File:line references for key symbols | Boilerplate imports |
| How systems interact + data flow | Things derivable from reading file names |
| Design decisions & non-obvious constraints | Git history / commit reasons |
| All 60+ tool names + their do_* locations | Standard framework patterns |

### Cross-linking Convention

When a doc references another system:
- Link to the **main.md** of that topic: `[Auth middleware](../auth/main.md)`
- For specific detail: `[TOTP flow](../auth/totp.md)`
- For source: `[src/tool_security.py:54](../src/tool_security.py)` (relative from repo root)

### Code Snippet Format

```python
# FILE: src/example.py  LINE: 54-66
def key_function(x):
    # Only the critical lines that explain the behaviour
    return result
```

Always include the file path + line range so a reader can jump straight to source if needed.

---

## Topic → Source File Quick Map

| Topic | Primary sources |
|---|---|
| App entry & middleware | `app.py` |
| Auth logic | `core/auth.py`, `core/middleware.py` |
| Chat pipeline | `routes/chat_routes.py`, `src/chat_handler.py`, `src/chat_processor.py` |
| Agent loop | `src/agent_loop.py` |
| Tool parsing | `src/tool_parsing.py` |
| Tool execution | `src/tool_execution.py` |
| Tool index (RAG) | `src/tool_index.py` |
| All native tool impls | `src/tool_implementations.py` |
| Tool security gate | `src/tool_security.py` |
| MCP manager | `src/mcp_manager.py`, `src/builtin_mcp.py` |
| Memory | `src/memory.py`, `src/memory_vector.py` |
| Personal docs RAG | `src/personal_docs.py`, `src/rag_vector.py` |
| Context compaction | `src/context_compactor.py` |
| Task scheduler | `src/task_scheduler.py` |
| Background jobs | `src/bg_jobs.py`, `src/bg_monitor.py` |
| Event bus | `src/event_bus.py` |
| Built-in actions | `src/builtin_actions.py` |
| Calendar (CalDAV) | `src/caldav_sync.py`, `src/caldav_writeback.py` |
| Email | `routes/email_routes.py`, `routes/email_helpers.py` |
| Webhooks | `src/webhook_manager.py` |
| Prompt injection | `src/prompt_security.py` |
| URL/SSRF security | `src/url_security.py` |
| DB models | `core/database.py` |
| Request models | `src/request_models.py` |
| LLM HTTP client | `src/llm_core.py` |
| Endpoint resolution | `src/endpoint_resolver.py` |
| Context window math | `src/model_context.py` |
