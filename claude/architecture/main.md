# Architecture Overview

Odysseus is a **FastAPI** async web application providing a self-hosted AI chat platform with agent capabilities.
Single Python process (`app.py`) that mounts all routers and manages a shared set of singleton service components.

## Framework & Stack

| Layer | Technology |
|---|---|
| Web framework | FastAPI (async) + Uvicorn |
| Database ORM | SQLAlchemy (sync) with `SessionLocal` sessions |
| Database file | `data/app.db` (SQLite) |
| Vector search | ChromaDB (external service, HTTP client) |
| Embeddings | fastembed (local ONNX — `all-MiniLM-L6-v2`) |
| Auth | bcrypt passwords + `secrets.token_hex(32)` sessions |
| LLM API | OpenAI-compatible HTTP (Ollama, vLLM, LM Studio, etc.) |
| Task scheduling | In-process asyncio loop (or external cron via env flag) |
| MCP | `mcp` SDK — stdio + SSE + HTTP transports |
| Config | `python-dotenv` `.env` + env vars |

**Key env vars:** `AUTH_ENABLED` (default `true`), `LOCALHOST_BYPASS` (`false`), `ALLOWED_ORIGINS`, `REQUEST_HARD_TIMEOUT` (45s), `ODYSSEUS_INPROCESS_TASKS` (1), `PUID`/`PGID` (Docker user).

## Component Initialization

`app.py` calls `initialize_managers()` ([src/app_initializer.py](../../src/app_initializer.py)) which returns a `components` dict wiring all singletons:

```
session_manager, memory_manager, memory_vector, upload_handler,
personal_docs_manager, api_key_manager, preset_manager,
chat_processor, research_handler, chat_handler, model_discovery, skills_manager
```

These are passed explicitly into each router's `setup_*_routes()` factory — no global state, everything is dependency-injected via closure.

## Middleware Stack (outer → inner)

```
CORSMiddleware          app.py:88   (allowed_origins from ALLOWED_ORIGINS env)
SecurityHeadersMiddleware  core/middleware.py  (CSP nonce, X-Frame-Options, etc.)
_RequestTimeoutMiddleware  app.py:134  (45s hard timeout, streaming paths exempt)
AuthMiddleware          app.py:252  (Bearer token + cookie + internal loopback)
```

Detailed request flow → [request-pipeline.md](request-pipeline.md)

## Startup Sequence

Full annotated startup → [startup-sequence.md](startup-sequence.md)

**Summary order:**
1. Load `.env` (UTF-8-BOM safe)
2. MIME type registration + Windows HF symlink env vars
3. FastAPI app + all middleware
4. RAG singleton init (ChromaDB ping, returns `None` if unreachable)
5. `initialize_managers()` — all service singletons
6. Register all routers (40+)
7. `_startup_event()` async tasks (MCP connect, tool index warmup, task scheduler, default tasks, skill audit loop)

## File Inventory

Full file-by-file descriptions → [file-map.md](file-map.md)

**Key directories:**

| Dir | Purpose |
|---|---|
| `app.py` | Entry point — middleware, router registration, lifespan |
| `core/` | Auth, DB models, session manager, exceptions, middleware |
| `src/` | All business logic — agent loop, tools, memory, MCP, scheduler |
| `routes/` | HTTP endpoint handlers (thin — delegate to `src/`) |
| `services/` | TTS, STT, YouTube |
| `mcp_servers/` | Standalone MCP server processes (email, image gen, memory, RAG) |
| `companion/` | Mobile companion app pairing |
| `static/` | SPA frontend (ES modules, no build step) |
| `data/` | Runtime data: DB, sessions, memory, uploads, generated images |
| `config/` | SearXNG `settings.yml` |

## SPA Routing

All these paths serve `static/index.html` — the JS detects `window.location.pathname` and auto-opens the matching modal:

```
/  /notes  /calendar  /email  /cookbook  /memory  /gallery  /tasks  /library
```

`/login` → `static/login.html`, `/backgrounds` → prototyping sandbox.
