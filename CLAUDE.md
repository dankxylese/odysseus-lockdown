# Odysseus — Claude Code Guide

Self-hosted AI chat platform: FastAPI backend, multi-user auth, agent tool loop, MCP servers, RAG memory, scheduled tasks.

**Before reading source, check the relevant doc below. Each section points to a focused file that explains the system without requiring source traversal.**

---

## Architecture & Startup
→ [claude/architecture/main.md](claude/architecture/main.md)
Full startup sequence, middleware stack, framework overview, file inventory.

## Chat & Agent Pipeline
→ [claude/chat/main.md](claude/chat/main.md)
How a message flows: HTTP → intent classification → context build → LLM → tool loop → response.

## Tool System
→ [claude/tools/main.md](claude/tools/main.md)
Three-tier tool system: RAG selection, 60+ native tools, MCP servers, parsing, execution, security gate.

## Authentication
→ [claude/auth/main.md](claude/auth/main.md)
Middleware flow, session cookies, Bearer tokens, TOTP 2FA, per-user privileges.

## Memory & RAG
→ [claude/memory/main.md](claude/memory/main.md)
Native memory JSON store, vector memory (ChromaDB), personal document RAG, context injection.

## Scheduling & Background Jobs
→ [claude/scheduling/main.md](claude/scheduling/main.md)
TaskScheduler (cron/event/webhook), background bash jobs, event bus, 50 built-in actions.

## Integrations
→ [claude/integrations/main.md](claude/integrations/main.md)
CalDAV calendar, IMAP/SMTP email, webhooks, Miniflux/Gitea/Linkding/SearXNG.

## Security
→ [claude/security/main.md](claude/security/main.md)
Prompt injection hardening, SSRF prevention, CSP nonce, rate limiting, request timeout.

## HTTP Routes
→ [claude/routes/main.md](claude/routes/main.md)
All endpoints grouped by domain with file locations.

---

*Knowledge base maintained at [claude/README.md](claude/README.md) — run the update command there after each `git pull`.*
