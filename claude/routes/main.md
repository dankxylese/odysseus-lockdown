# HTTP Routes — Complete Reference

All routes registered in `app.py` via `setup_*_routes()` factory functions.

## Route Groups

- [chat-routes.md](chat-routes.md) — Chat, research, shell
- [data-routes.md](data-routes.md) — Sessions, memory, notes, documents, gallery
- [model-routes.md](model-routes.md) — Endpoints, models, cookbook, compare
- [integration-routes.md](integration-routes.md) — Calendar, email, tasks, webhooks, MCP, contacts

## Auth Routes (routes/auth_routes.py)

```
POST /api/auth/login                — submit username+password (+TOTP code)
POST /api/auth/logout               — clear session cookie
POST /api/auth/signup               — create first/additional user
GET  /api/auth/status               — {authenticated, username, is_admin}
GET  /api/auth/features             — {auth_enabled, totp_available, ...}
GET  /api/auth/settings             — public settings (no auth needed)
GET  /api/auth/integrations/presets — available integration presets
POST /api/auth/totp/generate        — generate TOTP secret + QR code
POST /api/auth/totp/confirm         — confirm TOTP setup, get backup codes
POST /api/auth/totp/disable         — disable 2FA (requires password)
GET  /api/auth/users                — list users (admin only)
PUT  /api/auth/users/{username}     — update user (admin only)
DELETE /api/auth/users/{username}   — delete user (admin only)
```

## System Routes (app.py)

```
GET /api/version     — {"version": "x.y.z"}
GET /api/health      — {"status": "healthy", "timestamp": "..."}
GET /api/ready       — readiness check (DB + data dir integrity)
GET /api/runtime     — {"in_docker": bool, "ollama_base_url": str}
GET /api/generated-image/{filename}  — serve generated images
```

## Admin Routes (routes/admin_wipe_routes.py)

```
POST /api/admin/wipe/sessions  — delete ALL sessions (danger)
POST /api/admin/wipe/memory    — delete ALL memories (danger)
POST /api/admin/wipe/skills    — delete ALL skills (danger)
```

## Backup Routes (routes/backup_routes.py)

```
GET  /api/backup        — export user data (JSON)
POST /api/backup/import — import user data
```

## Diagnostics (routes/diagnostics_routes.py)

```
GET /api/diagnostics     — system info + component health
GET /api/diagnostics/rag — ChromaDB + embedding model status
```

## Preferences (routes/prefs_routes.py)

```
GET  /api/prefs       — get user preferences
PUT  /api/prefs       — update preferences
```

## Settings (no dedicated route file — via manage_settings tool)

Settings are read/written via the `manage_settings` tool or directly via the Settings UI (which calls `/api/settings/*` routes built into various route files).

## Upload Routes (routes/upload_routes.py)

```
POST   /api/upload          — upload file (multipart)
DELETE /api/upload/{id}     — delete uploaded file
GET    /api/upload/{id}     — get upload info
```

## Complete URL Map (all prefixes)

| Prefix | Router File |
|---|---|
| `/api/auth/` | `routes/auth_routes.py` |
| `/api/upload` | `routes/upload_routes.py` |
| `/api/sessions` | `routes/session_routes.py` |
| `/api/memory` | `routes/memory_routes.py` |
| `/api/skills` | `routes/skills_routes.py` |
| `/api/chat` | `routes/chat_routes.py` |
| `/api/research` | `routes/research_routes.py` |
| `/api/history` | `routes/history_routes.py` |
| `/api/search` | `routes/search_routes.py` |
| `/api/presets` | `routes/preset_routes.py` |
| `/api/diagnostics` | `routes/diagnostics_routes.py` |
| `/api/cleanup` | `routes/cleanup_routes.py` |
| `/api/personal` | `routes/personal_routes.py` |
| `/api/embedding` | `routes/embedding_routes.py` |
| `/api/models` | `routes/model_routes.py` |
| `/api/model-endpoints` | `routes/model_routes.py` |
| `/api/tts` | `routes/tts_routes.py` |
| `/api/stt` | `routes/stt_routes.py` |
| `/api/documents` | `routes/document_routes.py` |
| `/api/gallery` | `routes/gallery_routes.py` |
| `/api/tasks` | `routes/task_routes.py` |
| `/api/assistant` | `routes/assistant_routes.py` |
| `/api/calendar` | `routes/calendar_routes.py` |
| `/api/shell` | `routes/shell_routes.py` |
| `/api/cookbook` | `routes/cookbook_routes.py` |
| `/api/hwfit` | `routes/hwfit_routes.py` |
| `/api/compare` | `routes/compare_routes.py` |
| `/api/prefs` | `routes/prefs_routes.py` |
| `/api/backup` | `routes/backup_routes.py` |
| `/api/mcp` | `routes/mcp_routes.py` |
| `/api/webhooks` | `routes/webhook_routes.py` |
| `/api/tokens` | `routes/api_token_routes.py` |
| `/api/notes` | `routes/note_routes.py` |
| `/api/email` | `routes/email_routes.py` |
| `/api/codex` | `routes/codex_routes.py` |
| `/api/vault` | `routes/vault_routes.py` |
| `/api/contacts` | `routes/contacts_routes.py` |
| `/companion` | `companion/routes.py` |
| `/api/admin` | `routes/admin_wipe_routes.py` |
| `/api/workspace` | `routes/workspace_routes.py` |
| `/api/editor-drafts` | `routes/editor_draft_routes.py` |
| `/api/signatures` | `routes/signature_routes.py` |
| `/api/copilot` | `routes/copilot_routes.py` |
| `/api/fonts` | `routes/font_routes.py` |
| `/api/emoji` | `routes/emoji_routes.py` |
