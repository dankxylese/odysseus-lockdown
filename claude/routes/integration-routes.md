# Integration Routes

Routes for calendar, email, tasks, webhooks, MCP, and contacts.

## Calendar Routes (routes/calendar_routes.py)

```
GET    /api/calendar/calendars              — list all calendars
GET    /api/calendar/events                 — list events {start, end, calendar_id}
POST   /api/calendar/events                 — create event
GET    /api/calendar/events/{id}            — get event
PUT    /api/calendar/events/{id}            — update event
DELETE /api/calendar/events/{id}            — delete event
POST   /api/calendar/sync                   — force CalDAV pull
GET    /api/calendar/settings               — get CalDAV connection settings
PUT    /api/calendar/settings               — update CalDAV settings
```

## Email Routes (routes/email_routes.py)

```
GET    /api/email/accounts               — list configured email accounts
POST   /api/email/accounts               — add account
PUT    /api/email/accounts/{id}          — update account
DELETE /api/email/accounts/{id}          — remove account
GET    /api/email/messages               — list messages {folder, unread_only, count}
GET    /api/email/messages/{uid}         — read full email
POST   /api/email/messages               — send new email
POST   /api/email/reply                  — send reply
PUT    /api/email/messages/{uid}         — update flags (read/unread)
DELETE /api/email/messages/{uid}         — delete
POST   /api/email/bulk                   — bulk action {action, uids, account}
GET    /api/email/folders                — list IMAP folders
POST   /api/email/move                   — move message to folder
POST   /api/email/search                 — search emails {query}
```

## Task Routes (routes/task_routes.py)

```
GET    /api/tasks                        — list tasks (owner-filtered)
POST   /api/tasks                        — create task
GET    /api/tasks/{id}                   — get task
PUT    /api/tasks/{id}                   — update task
DELETE /api/tasks/{id}                   — delete task
POST   /api/tasks/{id}/run               — run immediately
POST   /api/tasks/{id}/pause             — pause task
POST   /api/tasks/{id}/resume            — resume task
GET    /api/tasks/{id}/history           — execution history
POST   /api/tasks/{id}/webhook/{token}   — webhook trigger (no auth — path credential)
```

## Assistant Routes (routes/assistant_routes.py)

```
GET  /api/assistant/status    — personal assistant status + last run
POST /api/assistant/run       — trigger manual run
PUT  /api/assistant/config    — update assistant configuration
```

## Webhook Routes (routes/webhook_routes.py)

```
GET    /api/webhooks                    — list webhooks (owner-filtered)
POST   /api/webhooks                    — create webhook {name, url, secret, events}
PUT    /api/webhooks/{id}               — update webhook
DELETE /api/webhooks/{id}               — delete webhook
POST   /api/webhooks/{id}/test          — send test delivery
GET    /api/webhooks/{id}/deliveries    — delivery history (paginated)
POST   /api/webhooks/{id}/enable        — enable
POST   /api/webhooks/{id}/disable       — disable
```

## API Token Routes (routes/api_token_routes.py)

```
GET    /api/tokens              — list my tokens
POST   /api/tokens              — create token {name, scopes}
         Response: {id, name, token: "ody_..."}  ← shown once only
DELETE /api/tokens/{id}         — revoke token
GET    /api/tokens/{id}         — get token info (not the raw token)
```

## MCP Routes (routes/mcp_routes.py)

```
GET    /api/mcp/servers                 — list all servers + tools + status
POST   /api/mcp/servers                 — add server {name, transport, command, args, url}
DELETE /api/mcp/servers/{id}            — remove + disconnect
POST   /api/mcp/servers/{id}/reconnect  — reconnect
POST   /api/mcp/servers/{id}/call       — invoke tool {tool_name, arguments}
PUT    /api/mcp/servers/{id}/tools/{name}/disable — disable specific tool
PUT    /api/mcp/servers/{id}/tools/{name}/enable  — enable specific tool
```

## Contact Routes (routes/contacts_routes.py)

CardDAV contact management:

```
GET    /api/contacts            — list contacts
GET    /api/contacts/{id}       — get contact
POST   /api/contacts            — create contact
PUT    /api/contacts/{id}       — update contact
DELETE /api/contacts/{id}       — delete contact
POST   /api/contacts/search     — search {query}
POST   /api/contacts/sync       — force CardDAV sync
```

## Codex Routes (routes/codex_routes.py)

External plugin bridge using API token scopes. Mounts shared route groups from email, memory, calendar, documents so Codex sessions can only touch what their token allows:

```
/api/codex/email/*     — uses email:read|draft|send scopes
/api/codex/memory/*    — uses todos:read|write scopes
/api/codex/calendar/*  — requires calendar scope
/api/codex/documents/* — requires todos:read scope
/api/claude/*          — Claude AI integration bridge
```
