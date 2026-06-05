# CSP & Security Headers

**File:** `core/middleware.py`
**Class:** `SecurityHeadersMiddleware`

## Headers Added to Every Response

```python
# core/middleware.py — SecurityHeadersMiddleware.dispatch()
response.headers["X-Frame-Options"] = "DENY"
response.headers["X-Content-Type-Options"] = "nosniff"
response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
response.headers["X-XSS-Protection"] = "1; mode=block"

# CSP with per-request nonce (HTML responses only)
nonce = secrets.token_hex(16)
request.state.csp_nonce = nonce
response.headers["Content-Security-Policy"] = (
    f"default-src 'self'; "
    f"script-src 'self' 'nonce-{nonce}'; "
    f"style-src 'self' 'unsafe-inline'; "
    f"img-src 'self' data: blob:; "
    f"connect-src 'self'; "
    f"frame-ancestors 'none';"
)
```

## CSP Nonce Flow

Per-request nonce prevents XSS via injected scripts (even `<script>` tags won't run without the nonce):

```
1. SecurityHeadersMiddleware generates nonce = secrets.token_hex(16)
2. Stored on request.state.csp_nonce
3. Injected into CSP header: script-src 'self' 'nonce-<value>'
4. app.py:_serve_html_with_nonce() reads HTML file and replaces {{CSP_NONCE}}
5. index.html inline scripts carry: <script nonce="{{CSP_NONCE}}">...</script>
   → at serve time this becomes: <script nonce="abc123...">...</script>
6. Browser validates: script must carry matching nonce to execute
```

```python
# app.py:731-737
def _serve_html_with_nonce(request: Request, file_path: str) -> HTMLResponse:
    with open(file_path, "r", encoding="utf-8") as f:
        html = f.read()
    nonce = getattr(request.state, "csp_nonce", "")
    html = html.replace("{{CSP_NONCE}}", nonce)
    return HTMLResponse(html)
```

Applied to: `/` (index.html), `/login`, `/backgrounds`, all SPA routes.

## INTERNAL_TOOL_TOKEN

```python
# core/middleware.py
import secrets as _secrets
INTERNAL_TOOL_HEADER = "X-Odysseus-Internal-Token"
INTERNAL_TOOL_TOKEN  = _secrets.token_hex(32)   # 64-char hex, per-process
```

Generated fresh each process start. Used by the agent's loopback HTTP calls to authenticate as `internal-tool` user. Since it changes on restart, it cannot be pre-computed or extracted from persisted state.

## Request Timeout (DoS Protection)

```python
# app.py:120-148
REQUEST_HARD_TIMEOUT = float(os.getenv("REQUEST_HARD_TIMEOUT", "45"))

class _RequestTimeoutMiddleware(_BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        if any(request.url.path.startswith(p) for p in _TIMEOUT_EXEMPT_PREFIXES):
            return await call_next(request)
        try:
            return await asyncio.wait_for(call_next(request), timeout=45.0)
        except asyncio.TimeoutError:
            return JSONResponse({"detail": "Request exceeded 45s timeout"}, status_code=504)
```

Exempt paths (legitimately long): `/api/chat`, `/api/shell/stream`, `/api/research`, `/api/model/download`, `/api/upload`, `/api/image`.

## Rate Limiting

```python
# src/rate_limiter.py
# IP-based bucket limiting for:
# - File uploads: N per minute per IP
# - API calls: N per minute per IP/user
# Configured via settings
```

## Generated Image Security

```python
# app.py:396-416 — /api/generated-image/{filename}
# Filename validated: must match ^[a-f0-9]{8,64}\.(png|jpg|...) pattern
# Owner check: gallery row owner must match current user
# If no gallery row (not yet imported): allow (filename-as-credential)
# Returns with: Cache-Control: public, max-age=31536000, immutable
```
