# Security

Multiple layered defences against common attack vectors.

## Layers Overview

| Layer | File | Protects Against |
|---|---|---|
| Prompt injection | `src/prompt_security.py` | Malicious instructions in external data |
| SSRF prevention | `src/url_security.py` | Requests to internal network via agent |
| Tool security gate | `src/tool_security.py` | Non-admin users running privileged tools |
| Auth middleware | `app.py:252` | Unauthenticated access |
| CSP + security headers | `core/middleware.py` | XSS, clickjacking |
| Request timeout | `app.py:134` | DoS via hung requests |
| Rate limiting | `src/rate_limiter.py` | Upload/API abuse |
| Webhook private URL blocking | `src/webhook_manager.py` | SSRF via webhook delivery |
| MCP schema sanitization | `src/mcp_manager.py` | Hostile MCP server schemas |
| Encrypted secret storage | `src/secret_storage.py` | Credential leakage |

## Detailed Files

- [prompt-injection.md](prompt-injection.md) — UNTRUSTED_CONTEXT_POLICY, wrapping markers
- [url-security.md](url-security.md) — SSRF prevention, private network blocking
- [csp-headers.md](csp-headers.md) — CSP nonce, SecurityHeadersMiddleware

## Quick Reference

### Is this data trusted?
```
System prompt     → trusted
User message      → trusted
Chat history      → trusted (already validated)
Web results       → UNTRUSTED → wrap with untrusted_context_message()
Emails            → UNTRUSTED → wrap
Memories          → UNTRUSTED → wrap (could have been poisoned)
Tool output       → UNTRUSTED → wrap
Skills text       → UNTRUSTED → wrap
Personal docs     → UNTRUSTED → wrap
```

### Can this URL be fetched?
```
https://example.com        → OK
http://127.0.0.1/secret    → BLOCKED (loopback)
http://10.0.0.1/internal   → BLOCKED (private)
http://192.168.1.1/admin   → BLOCKED (private)
http://169.254.169.254/    → BLOCKED (AWS metadata)
https://evil.com/ → 10.0.0.1  → BLOCKED (DNS rebinding)
```

### Can this tool run?
```
Non-admin: bash, python, file I/O, manage_*, email, calendar → BLOCKED
Admin: everything → ALLOWED
Single user or AUTH_ENABLED=false → ALLOWED
```
