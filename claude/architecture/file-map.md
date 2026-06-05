# File Map — One-Line Descriptions

## Root
| File | Description |
|---|---|
| `app.py` | FastAPI entry point — middleware, router registration, lifespan hooks |
| `requirements.txt` | Python dependencies |
| `pyproject.toml` | Package metadata |
| `Dockerfile` | Python 3.12 image, drops to PUID/PGID via entrypoint |
| `docker-compose.yml` | Services: odysseus, chromadb, searxng |
| `docker-compose.podman.yml` | Podman-compatible variant with egress proxy |
| `docker-compose.gpu-nvidia.yml` | Adds nvidia runtime + CUDA env |
| `docker-compose.gpu-amd.yml` | Adds ROCm device mounts |

## core/ — Auth, Database, Models
| File | Description |
|---|---|
| `core/auth.py` | AuthManager — bcrypt users, session tokens, TOTP 2FA, privileges |
| `core/database.py` | SQLAlchemy ORM models: Session, ChatMessage, Document, ApiToken, ScheduledTask, Webhook, GalleryImage, Note, ModelEndpoint, McpServer, Contact |
| `core/models.py` | Pure dataclasses: ChatMessage, Session (no DB side-effects) |
| `core/session_manager.py` | Load/save sessions; lazy message hydration; add_message |
| `core/middleware.py` | SecurityHeadersMiddleware (CSP nonce, X-Frame-Options); INTERNAL_TOOL_HEADER constant |
| `core/exceptions.py` | SessionNotFoundError, InvalidFileUploadError, LLMServiceError, WebSearchError |
| `core/atomic_io.py` | `atomic_write_json()` — temp-file + rename for crash-safe JSON writes |
| `core/constants.py` | BASE_DIR, STATIC_DIR, SESSIONS_FILE, REQUEST_TIMEOUT, OPENAI_API_KEY |
| `core/platform_compat.py` | OS detection, safe_chmod, pid_alive, find_bash, kill_process_tree |
| `core/__init__.py` | Re-exports: llm_call*, stream_llm, AuthManager, exceptions, Session, SessionManager |

## src/ — Business Logic
| File | Description |
|---|---|
| `src/agent_loop.py` | Multi-round streaming agent: system prompt, tool retrieval, execute, inject result |
| `src/agent_tools.py` | Facade re-exporting parse/execute/format + TOOL_TAGS + MAX_AGENT_ROUNDS |
| `src/agent_runs.py` | AgentRun DB persistence (tracks in-flight agent turns) |
| `src/ai_interaction.py` | AI-to-AI tools: debates, pipelines, self-managing agents, UI control |
| `src/action_intents.py` | Regex-based chat→agent routing (classify_tool_intent) |
| `src/api_key_manager.py` | Encrypted storage of service API keys (Brave, OpenAI, etc.) |
| `src/app_helpers.py` | `abs_join()` and other tiny path utilities |
| `src/app_initializer.py` | `initialize_managers()` — creates and wires all singleton services |
| `src/assistant_log.py` | Logs personal-assistant runs to a dedicated session |
| `src/auth_helpers.py` | `get_current_user()`, `require_admin()`, `owner_filter()` DB helper |
| `src/bg_jobs.py` | Detached subprocess execution (#!bg jobs), status tracking, output cap |
| `src/bg_monitor.py` | Always-on loop — re-invokes agent when a bg job completes |
| `src/builtin_actions.py` | ~50 built-in task action handlers (check_inbox, cookbook_serve, personal_assistant, etc.) |
| `src/builtin_mcp.py` | Registers Browser, Fetch, Google Calendar/Gmail/Drive, Filesystem MCP servers |
| `src/caldav_sync.py` | CalDAV pull sync — reads remote calendar events into local DB |
| `src/caldav_writeback.py` | CalDAV push — writes local changes back to remote CalDAV server |
| `src/chat_handler.py` | ChatHandler — builds LLM context (system prompt, memory, docs), calls LLM |
| `src/chat_helpers.py` | Shared chat utilities (title generation, message formatting) |
| `src/chat_processor.py` | ChatProcessor — BM25+RAG memory retrieval, personal-doc injection |
| `src/chroma_client.py` | `get_chroma_client()` singleton — HTTP client for ChromaDB service |
| `src/cleanup_service.py` | Prune orphaned uploads, temp files, old bg job logs |
| `src/config.py` | Pydantic settings: DataConfig, LLMConfig, SearchConfig, SecurityConfig |
| `src/constants.py` | DATA_DIR, PERSONAL_DIR, UPLOAD_DIR, SESSIONS_FILE paths |
| `src/context_budget.py` | Token budget calculations per model/context-window size |
| `src/context_compactor.py` | Auto-summarize old messages at 85% context usage via LLM |
| `src/cookbook_serve_lifecycle.py` | Kills scheduler-launched serves when `end_after_min` has passed |
| `src/copilot.py` | GitHub Copilot device-flow OAuth helper |
| `src/database.py` | App-level DB helpers (migrations, sweep, owner assignment) |
| `src/deep_research.py` | DeepResearcher — multi-turn query expansion, page crawling, LLM eval |
| `src/document_actions.py` | Document CRUD actions called by tool_implementations |
| `src/document_processor.py` | Multimodal content parsing, URL extraction, vision-model image analysis |
| `src/email_thread_parser.py` | Parse email thread headers, reconstruct In-Reply-To chains |
| `src/embeddings.py` | `get_embedding_client()` singleton — fastembed ONNX model |
| `src/endpoint_resolver.py` | Resolve LLM endpoint URL from session/defaults/env; validate model exists |
| `src/event_bus.py` | `fire_event()`, threshold counters, route events to matching tasks |
| `src/exceptions.py` | src-level exceptions (supplements core/exceptions.py) |
| `src/goal_based_extractor.py` | Extract structured goal/intent from a message for research |
| `src/integrations.py` | External service adapters: Miniflux, Gitea, Linkding, RSS |
| `src/llm_core.py` | HTTP client for OpenAI-compatible LLM APIs; retry, dead-host cooldown, streaming |
| `src/markitdown_runtime.py` | MarkItDown integration for document-to-markdown conversion |
| `src/mcp_manager.py` | McpManager — connect/disconnect MCP servers, call tools, track generation |
| `src/mcp_oauth.py` | OAuth flow helpers for MCP server authentication |
| `src/memory.py` | MemoryManager — JSON-backed memory store, CRUD, fuzzy search |
| `src/memory_provider.py` | MemoryProvider interface + NativeMemoryProvider adapter |
| `src/memory_vector.py` | MemoryVectorStore — ChromaDB-backed semantic memory recall/store |
| `src/model_context.py` | `get_context_length(model)`, `estimate_tokens(messages)` — context window math |
| `src/model_discovery.py` | List available models from endpoints, cache /models responses, health checks |
| `src/pdf_form_doc.py` | PDF form → document conversion |
| `src/pdf_forms.py` | PDF form field extraction and filling |
| `src/pdf_runtime.py` | PDF generation runtime (WeasyPrint/reportlab) |
| `src/personal_docs.py` | PersonalDocsManager — scan dirs, index to VectorRAG, search |
| `src/preset_manager.py` | PresetManager — load/save character presets (system prompt + temperature) |
| `src/prompt_security.py` | UNTRUSTED_CONTEXT_POLICY + `untrusted_context_message()` wrapper |
| `src/rag_manager.py` | RAGManager wrapper around VectorRAG |
| `src/rag_singleton.py` | `get_rag_manager()` — singleton with ChromaDB availability check |
| `src/rag_vector.py` | VectorRAG — ChromaDB semantic search for personal documents |
| `src/rate_limiter.py` | IP-based rate limiting for uploads and API calls |
| `src/readiness.py` | `check_readiness()` — DB + data dir integrity for /api/ready |
| `src/request_models.py` | Pydantic request/response models: ChatRequest, SessionCreate, etc. |
| `src/research_handler.py` | ResearchHandler — orchestrates deep research jobs |
| `src/research_utils.py` | Research helper utilities (query deduplication, result ranking) |
| `src/search/` | Web search subsystem (core, providers, cache, ranking, analytics, content) |
| `src/secret_storage.py` | Fernet encrypt/decrypt for DB column encryption |
| `src/session_actions.py` | Session CRUD actions called by tool_implementations |
| `src/settings.py` | `get_setting()` / `set_setting()` — user + system settings, DB-backed |
| `src/settings_scrub.py` | Scrub sensitive values from settings before returning to client |
| `src/task_endpoint.py` | HTTP client wrapper for task webhook delivery |
| `src/task_scheduler.py` | TaskScheduler — schedule types, execution loop, ensure_defaults |
| `src/teacher_escalation.py` | ask_teacher tool — escalate to a more capable model |
| `src/text_helpers.py` | Text utilities (truncate, clean, extract URLs, etc.) |
| `src/tls_overrides.py` | Custom TLS cert paths for internal CA |
| `src/tool_execution.py` | `execute_tool_block()` dispatcher + `format_tool_result()` + file I/O tools |
| `src/tool_implementations.py` | All `do_*()` functions for every native tool |
| `src/tool_index.py` | ToolIndex — RAG-based tool selection, ALWAYS_AVAILABLE, ChromaDB |
| `src/tool_parsing.py` | `parse_tool_blocks()` — 5 parsing patterns for LLM tool output formats |
| `src/tool_schemas.py` | FUNCTION_TOOL_SCHEMAS (OpenAI format) + `function_call_to_tool_block()` |
| `src/tool_security.py` | NON_ADMIN_BLOCKED_TOOLS, `is_public_blocked_tool()`, `blocked_tools_for_owner()` |
| `src/topic_analyzer.py` | Extract topic/intent for research query synthesis |
| `src/upload_handler.py` | File upload processing, cleanup, format detection |
| `src/upload_limits.py` | Per-type upload size limits |
| `src/url_safety.py` | URL safety checks (allow/deny lists) |
| `src/url_security.py` | SSRF prevention — private network detection, DNS validation |
| `src/user_time.py` | User timezone offset helpers |
| `src/visual_report.py` | Generate visual/chart reports from data |
| `src/webhook_manager.py` | WebhookManager — HMAC signing, private URL blocking, retry queue |
| `src/youtube_handler.py` | YouTube transcript + metadata extraction |

## routes/ — HTTP Handlers
| File | Description |
|---|---|
| `routes/chat_routes.py` | POST /api/chat, /api/chat_stream; GET /api/search |
| `routes/session_routes.py` | Session CRUD (create, list, get, rename, archive, delete, fork) |
| `routes/auth_routes.py` | Login, signup, logout, TOTP setup, status, features |
| `routes/memory_routes.py` | Memory CRUD + semantic search |
| `routes/skills_routes.py` | Skills CRUD + publish + nightly audit |
| `routes/upload_routes.py` | File upload, cleanup |
| `routes/personal_routes.py` | Personal doc index + search |
| `routes/research_routes.py` | Trigger deep research, poll status, get report |
| `routes/model_routes.py` | List models, endpoints, change defaults |
| `routes/shell_routes.py` | SSE shell execution (admin-gated) |
| `routes/calendar_routes.py` | Calendar CRUD + CalDAV sync |
| `routes/email_routes.py` | Email CRUD, IMAP/SMTP, bulk operations |
| `routes/task_routes.py` | Scheduled task CRUD + webhook handler + run-now |
| `routes/assistant_routes.py` | Personal assistant setup + manual run |
| `routes/document_routes.py` | Document (editor canvas) CRUD + versions |
| `routes/gallery_routes.py` | Image gallery import/delete/sharpen |
| `routes/note_routes.py` | Notes/todos CRUD + reminders |
| `routes/mcp_routes.py` | MCP server management (list/add/delete/reconnect/call) |
| `routes/webhook_routes.py` | Webhook CRUD + delivery logs |
| `routes/api_token_routes.py` | API token CRUD |
| `routes/admin_wipe_routes.py` | Danger Zone: delete all sessions/memory/skills |
| `routes/cookbook_routes.py` | Model download/serve/cache (Ollama/vLLM/llama.cpp) |
| `routes/backup_routes.py` | Export/import user data |
| `routes/compare_routes.py` | Model A/B comparison |
| `routes/copilot_routes.py` | GitHub Copilot device-flow login |
| `routes/prefs_routes.py` | User preferences |
| `routes/history_routes.py` | Chat history search |
| `routes/search_routes.py` | Web search (SearXNG proxy) |
| `routes/preset_routes.py` | Character preset CRUD |
| `routes/diagnostics_routes.py` | System diagnostics + health |
| `routes/cleanup_routes.py` | Cleanup orphaned uploads/data |
| `routes/embedding_routes.py` | Embedding model management |
| `routes/hwfit_routes.py` | Hardware model fitting (Cookbook "What Fits?" tab) |
| `routes/vault_routes.py` | Credential vault (encrypted secrets) |
| `routes/contacts_routes.py` | Contacts (CardDAV) |
| `routes/codex_routes.py` | Codex/Claude plugin HTTP bridge (uses api_token scopes) |
| `routes/editor_draft_routes.py` | Persisted image-editor drafts |
| `routes/signature_routes.py` | Reusable image stamps (signatures) |
| `routes/workspace_routes.py` | Workspace management |
| `routes/tts_routes.py` | Text-to-speech |
| `routes/stt_routes.py` | Speech-to-text |
| `routes/emoji_routes.py` | Twemoji SVG proxy (same-origin, lazy-cached) |
| `routes/font_routes.py` | Font serving for editor |
| `routes/chat_helpers.py` | Shared helpers used by chat_routes |

## mcp_servers/ — Standalone MCP Processes
| File | Description |
|---|---|
| `mcp_servers/email_server.py` | MCP server exposing email tools via stdio |
| `mcp_servers/image_gen_server.py` | MCP server for image generation |
| `mcp_servers/memory_server.py` | MCP server exposing memory tools |
| `mcp_servers/rag_server.py` | MCP server for personal doc RAG search |

## services/
| File | Description |
|---|---|
| `services/tts.py` | TTS service wrapper (ElevenLabs, local, etc.) |
| `services/stt.py` | STT service wrapper |
| `services/youtube.py` | YouTube transcript + comment extraction init |

## companion/
| File | Description |
|---|---|
| `companion/routes.py` | Mobile companion app pairing routes |
| `companion/pairing.py` | QR code + pairing token logic |
