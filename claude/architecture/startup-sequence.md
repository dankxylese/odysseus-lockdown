# Startup Sequence

All startup logic lives in `app.py`. The lifespan context manager (`_lifespan`) calls `_startup_event()`.

## Phase 1 — Module Load (synchronous, before FastAPI starts)

```python
# app.py:6-19 — MIME types first (Windows registry can have wrong .js/.mjs types)
register_static_mime_types()

# app.py:26-28 — Windows: disable HF symlinks before any import touches huggingface_hub
if os.name == "nt":
    os.environ.setdefault("HF_HUB_DISABLE_SYMLINKS", "1")

# app.py:36 — UTF-8-BOM safe .env load (handles Windows Notepad-saved .env files)
load_dotenv(encoding="utf-8-sig")
```

## Phase 2 — App + Middleware (synchronous)

```python
# app.py:80-84
app = FastAPI(title="AI Chat Application", ...)

# Middleware registered OUTER→INNER (last added = outermost):
app.add_middleware(CORSMiddleware, ...)          # app.py:88
app.add_middleware(SecurityHeadersMiddleware)    # app.py:107
app.add_middleware(_RequestTimeoutMiddleware)    # app.py:148
app.add_middleware(AuthMiddleware)               # app.py:359 (conditional on AUTH_ENABLED)
```

## Phase 3 — Singletons & Routers (synchronous)

```python
# app.py:466 — all service singletons created here
components = initialize_managers(BASE_DIR, rag_manager)
# Returns: session_manager, memory_manager, upload_handler,
#          personal_docs_manager, api_key_manager, preset_manager,
#          chat_processor, research_handler, chat_handler,
#          model_discovery, skills_manager

# app.py:627 — Task scheduler created
task_scheduler = TaskScheduler(session_manager)
set_task_scheduler(task_scheduler)  # wires event_bus → scheduler

# app.py:674 — MCP manager
mcp_manager = McpManager()
set_mcp_manager(mcp_manager)  # wires agent_tools → mcp_manager
```

**Routers registered in order** (app.py:514–727):
auth → upload → emoji → workspace → sessions → admin_wipe → memory → skills → chat → research → history → search → presets → diagnostics → cleanup → personal → embedding → models → copilot → tts → stt → documents → signatures → gallery → editor_drafts → tasks → assistant → calendar → shell → cookbook → hwfit → compare → prefs → backup → fonts → mcp → ai_interaction → webhooks → api_tokens → notes → email → codex → claude → vault → contacts → companion

## Phase 4 — Async Startup (_startup_event)

Called at first request after the event loop is running. All heavy/blocking work is deferred here.

```python
# app.py:848 — _startup_event()

# 1. Purge leftover incognito sessions from previous process (app.py:854-868)
#    Sessions named "Nobody"/"Incognito" are ephemeral — delete on startup

# 2. bg_monitor — always-on loop that re-invokes agent when a #!bg job finishes
start_bg_monitor()                    # app.py:879

# 3. MCP connections (non-blocking, 20s timeout) (app.py:884-897)
asyncio.create_task(_startup_mcp_connections())
#   → register_builtin_servers(mcp_manager)   # Browser, Fetch, Google Calendar/Gmail/Drive
#   → mcp_manager.connect_all_enabled()        # user-configured servers from DB

# 4. Tool index pre-warm (app.py:904-913)
asyncio.create_task(_warmup_tool_index())
#   → get_tool_index() → loads fastembed model + indexes all tool descriptions
#   → get_tools_for_query("warmup", 8) — first real embed to warm the model
#   Moves 1–3s embedding model load OFF the first user message

# 5. LLM endpoint warmup + 60s keepalive loop (app.py:916-944)
asyncio.create_task(_warmup_endpoints())
asyncio.create_task(_keepalive_loop())  # pings every 60s

# 6. Default task reconciliation (app.py:946-991) — AWAITED (blocking)
await _ensure_default_tasks()
#   Reads auth.json → for each user calls task_scheduler.ensure_defaults(username)
#   Creates/upgrades Personal Assistant + housekeeping tasks if missing/stale

# 7. Skill owner backfill (app.py:993-1013)
#   Reads auth.json → assigns ownerless SKILL.md files to primary admin

# 8. Task scheduler start (app.py:1018-1025)
await task_scheduler.start()          # unless ODYSSEUS_INPROCESS_TASKS=0

# 9. Null-owner sweep loop (hourly) (app.py:1029-1039)
asyncio.create_task(_null_owner_sweep_loop())

# 10. Nightly skill audit loop (app.py:1046-1068)
asyncio.create_task(_skill_audit_nightly_loop())
#   Wakes at skill_audit_hour (default 02:00), tests skill_audit_batch (8) skills

# 11. Cookbook serve lifecycle monitor (app.py:1077-1078)
asyncio.create_task(cookbook_serve_lifecycle_loop())
```

## Shutdown (_shutdown_event)

```python
# app.py:1082
upload_cleanup_task.cancel()
await task_scheduler.stop()
await webhook_manager.close()
await mcp_manager.disconnect_all()
```

## Startup Dependencies Graph

```
app.py
  ├── initialize_managers() → src/app_initializer.py
  │     └── creates: session_manager, memory_manager, chat_handler, etc.
  ├── TaskScheduler(session_manager) → src/task_scheduler.py
  │     └── set_task_scheduler() → src/event_bus.py (wires event firing)
  ├── McpManager() → src/mcp_manager.py
  │     └── set_mcp_manager() → src/agent_tools.py (wires tool dispatch)
  └── _startup_event()
        ├── start_bg_monitor() → src/bg_monitor.py
        ├── register_builtin_servers() → src/builtin_mcp.py
        ├── _warmup_tool_index() → src/tool_index.py
        └── task_scheduler.start() → in-process scheduling loop
```
