# Native Tools — Complete Reference

All `do_*()` implementations live in `src/tool_implementations.py` unless noted.
Tool names are what the LLM writes as the fenced block language tag.

## Shell & Code Execution

| Tool | Implementation | Description |
|---|---|---|
| `bash` | `src/tool_execution.py:_do_bash` | Run shell commands. 60s timeout, 10K output cap. cwd=data/ |
| `python` | `src/tool_execution.py:_do_python` | Execute Python. Isolated subprocess. Same limits |

## File System

| Tool | Implementation | Description |
|---|---|---|
| `read_file` | `src/tool_execution.py:_do_read_file` | Read file. Supports offset/limit for large files. 20K cap |
| `write_file` | `src/tool_execution.py:_do_write_file` | Write/create file on disk. Full rewrite |
| `edit_file` | `src/tool_execution.py:_do_edit_file` | Exact string-replace on disk file. Returns diff |
| `grep` | `src/tool_execution.py:_do_grep` | Search file contents by regex (ripgrep-backed). file:line:match |
| `glob` | `src/tool_execution.py:_do_glob` | Find files by pattern (e.g. `**/*.py`), newest first |
| `ls` | `src/tool_execution.py:_do_ls` | List directory (folders then files with sizes) |

## Web

| Tool | Implementation | Description |
|---|---|---|
| `web_search` | `src/tool_implementations.py:do_web_search` | Quick web search via SearXNG. Returns snippet results |
| `web_fetch` | `src/tool_implementations.py:do_web_fetch` | Fetch a URL, return extracted text. SSRF-protected |

## Documents (Editor Panel)

| Tool | Implementation | Description |
|---|---|---|
| `create_document` | `src/document_actions.py` | Create new document in editor panel |
| `edit_document` | `src/document_actions.py` | Edit existing document: find/replace blocks |
| `update_document` | `src/document_actions.py` | Full document rewrite (>50% changed) |
| `suggest_document` | `src/document_actions.py` | Add inline suggestions (accept/reject bubbles) |
| `manage_documents` | `src/tool_implementations.py` | List/read/delete editor documents |

## Memory

| Tool | Implementation | Description |
|---|---|---|
| `manage_memory` | `src/tool_implementations.py:do_manage_memory` | List/add/edit/delete/search persistent memories |

## Notes & Tasks

| Tool | Implementation | Description |
|---|---|---|
| `manage_notes` | `src/tool_implementations.py:do_manage_notes` | Notes/todos CRUD. Supports due_date for reminders |
| `manage_tasks` | `src/tool_implementations.py:do_manage_tasks` | Scheduled task CRUD (create/list/edit/delete/run/pause) |

## Calendar

| Tool | Implementation | Description |
|---|---|---|
| `manage_calendar` | `src/tool_implementations.py:do_manage_calendar` | Calendar event CRUD. Call `list_calendars` first! |

## Email

| Tool | Implementation | Description |
|---|---|---|
| `list_email_accounts` | `src/tool_implementations.py` | List configured email accounts |
| `list_emails` | `src/tool_implementations.py:do_list_emails` | List emails (newest first, incl. read by default) |
| `read_email` | `src/tool_implementations.py:do_read_email` | Read full email by UID |
| `send_email` | `src/tool_implementations.py:do_send_email` | Send new email via SMTP |
| `reply_to_email` | `src/tool_implementations.py:do_reply_to_email` | Send reply (threads via In-Reply-To/References) |
| `archive_email` | `src/tool_implementations.py` | Move to Archive folder |
| `delete_email` | `src/tool_implementations.py` | Move to Trash (or expunge) |
| `mark_email_read` | `src/tool_implementations.py` | Toggle \\Seen flag |
| `bulk_email` | `src/tool_implementations.py:do_bulk_email` | Batch action on many emails (delete/archive/mark) |

## AI Interaction

| Tool | Implementation | Description |
|---|---|---|
| `chat_with_model` | `src/ai_interaction.py` | Send message to different AI model |
| `ask_teacher` | `src/teacher_escalation.py` | Escalate to more capable model |
| `pipeline` | `src/ai_interaction.py` | Multi-step AI pipeline, chain models |
| `list_models` | `src/tool_implementations.py` | List available AI models + endpoints |

## Session Management

| Tool | Implementation | Description |
|---|---|---|
| `manage_session` | `src/session_actions.py` | Rename/archive/delete/fork chats |
| `create_session` | `src/session_actions.py` | Create new chat |
| `list_sessions` | `src/session_actions.py` | List all chats with metadata |
| `send_to_session` | `src/session_actions.py` | Send message to another chat |
| `search_chats` | `src/tool_implementations.py` | Full-text search across chat history |

## Skills & Settings

| Tool | Implementation | Description |
|---|---|---|
| `manage_skills` | `src/tool_implementations.py` | Skills CRUD (add/update/publish/search/delete) |
| `manage_settings` | `src/tool_implementations.py:do_manage_settings` | Get/set any app setting, toggle tools on/off |

## Research

| Tool | Implementation | Description |
|---|---|---|
| `trigger_research` | `src/tool_implementations.py` | Start a deep research job (background) |
| `manage_research` | `src/tool_implementations.py` | List/read/delete saved research results |

## Model Serving (Cookbook)

| Tool | Implementation | Description |
|---|---|---|
| `serve_model` | `src/tool_implementations.py` | Start serving a local model |
| `serve_preset` | `src/tool_implementations.py` | Serve a saved serve preset |
| `stop_served_model` | `src/tool_implementations.py` | Stop a running model serve |
| `tail_serve_output` | `src/tool_implementations.py` | Tail the serve process logs |
| `list_served_models` | `src/tool_implementations.py` | List currently serving models |
| `list_serve_presets` | `src/tool_implementations.py` | List saved serve presets |
| `list_cached_models` | `src/tool_implementations.py` | List downloaded/cached models |
| `list_cookbook_servers` | `src/tool_implementations.py` | List cookbook server configs |
| `adopt_served_model` | `src/tool_implementations.py` | Register an externally-started serve |
| `download_model` | `src/tool_implementations.py` | Download a model (admin only) |

## System & Admin

| Tool | Implementation | Description |
|---|---|---|
| `manage_endpoints` | `src/tool_implementations.py` | Endpoint CRUD (add/delete/enable/disable) |
| `manage_mcp` | `src/tool_implementations.py` | MCP server management |
| `manage_webhooks` | `src/tool_implementations.py` | Webhook CRUD |
| `manage_tokens` | `src/tool_implementations.py` | API token CRUD |
| `api_call` | `src/tool_implementations.py:do_api_call` | HTTP request to configured integrations |
| `app_api` | `src/tool_implementations.py:do_app_api` | Internal loopback to any /api/* endpoint |

## UI Control

| Tool | Implementation | Description |
|---|---|---|
| `ui_control` | `src/ai_interaction.py:do_ui_control` | Open panels, toggle features, switch model, apply themes |

## Contacts & Vault

| Tool | Implementation | Description |
|---|---|---|
| `resolve_contact` | `src/tool_implementations.py` | Look up contact email by name (CardDAV + sent history) |
| `manage_contact` | `src/tool_implementations.py` | Contact CRUD |
| `vault_search` | `src/tool_implementations.py` | Search credential vault |
| `vault_get` | `src/tool_implementations.py` | Retrieve a vault secret |
| `vault_unlock` | `src/tool_implementations.py` | Unlock vault with master password |

## TOOL_TAGS — Authoritative Name List

Defined in `src/agent_tools.py` — all strings here are valid fenced block tags the LLM can use. If you add a tool, it MUST be in this set or `_TOOL_BLOCK_RE` won't match it.
