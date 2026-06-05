# Integrations

External services Odysseus connects to.

## Integration Map

| Integration | Transport | Files | Tools |
|---|---|---|---|
| CalDAV Calendar | HTTP (caldav lib) | `src/caldav_sync.py`, `src/caldav_writeback.py` | `manage_calendar` |
| IMAP/SMTP Email | IMAP + SMTP | `routes/email_routes.py`, `routes/email_helpers.py` | `list_emails`, `send_email`, etc. |
| Webhooks (outbound) | HTTP | `src/webhook_manager.py` | Fired by events |
| SearXNG (web search) | HTTP | `src/search/` | `web_search` |
| Miniflux | HTTP API | `src/integrations.py` | `api_call` |
| Gitea | HTTP API | `src/integrations.py` | `api_call` |
| Linkding | HTTP API | `src/integrations.py` | `api_call` |
| RSS Feeds | HTTP | `src/integrations.py` | `api_call` |
| Companion App | HTTP | `companion/` | pairing |
| Google (Calendar/Gmail/Drive) | OAuth + MCP | `src/builtin_mcp.py`, `src/mcp_oauth.py` | via MCP tools |

## Detailed Files

- [calendar.md](calendar.md) — CalDAV sync, writeback, event CRUD
- [email.md](email.md) — IMAP/SMTP, thread parser, multi-account
- [webhooks.md](webhooks.md) — WebhookManager, HMAC signing, delivery
- [external.md](external.md) — Miniflux, Gitea, Linkding, SearXNG, companion

## Configuration

All integrations configured via Settings UI or `manage_settings` tool:

```python
# src/settings.py — stored in core/database.py Settings table
# Keys:
# email_imap_host, email_imap_port, email_smtp_host, email_smtp_port
# email_username, email_password (encrypted)
# caldav_url, caldav_username, caldav_password (encrypted)
# searxng_url, searxng_results_count
# miniflux_url, miniflux_api_key (encrypted)
# gitea_url, gitea_token (encrypted)
# linkding_url, linkding_token (encrypted)
```

Sensitive values encrypted via `src/secret_storage.py` (Fernet encryption, key in `data/.app_key`).
