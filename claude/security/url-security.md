# URL Security — SSRF Prevention

**File:** `src/url_security.py`

Prevents Server-Side Request Forgery (SSRF) where the agent or a webhook is tricked into making requests to internal network services.

## Core Function

```python
# src/url_security.py — validate_public_http_url(url)
async def validate_public_http_url(url: str) -> None:
    """Raise ValueError if the URL resolves to a private/internal address."""
    parsed = urlparse(url)
    
    # 1. Scheme must be http or https
    if parsed.scheme not in ("http", "https"):
        raise ValueError(f"Scheme {parsed.scheme} not allowed")
    
    # 2. Check IP literal directly (no DNS needed)
    hostname = parsed.hostname
    if _is_private_ip(hostname):
        raise ValueError(f"Private IP address not allowed: {hostname}")
    
    # 3. DNS resolution check (prevents DNS rebinding)
    ips = await _resolve_hostname_ips(hostname)
    for ip in ips:
        if _is_private_ip(ip):
            raise ValueError(f"Hostname {hostname} resolves to private IP: {ip}")
```

## Private IP Ranges Blocked

```python
# src/url_security.py — _is_private_ip()
import ipaddress

PRIVATE_NETWORKS = [
    ipaddress.ip_network("10.0.0.0/8"),        # Class A private
    ipaddress.ip_network("172.16.0.0/12"),      # Class B private
    ipaddress.ip_network("192.168.0.0/16"),     # Class C private
    ipaddress.ip_network("127.0.0.0/8"),        # Loopback
    ipaddress.ip_network("::1/128"),            # IPv6 loopback
    ipaddress.ip_network("169.254.0.0/16"),     # Link-local (AWS metadata)
    ipaddress.ip_network("fc00::/7"),           # IPv6 ULA
    ipaddress.ip_network("0.0.0.0/8"),          # "This" network
    ipaddress.ip_network("100.64.0.0/10"),      # Shared address space
    ipaddress.ip_network("198.18.0.0/15"),      # Benchmark testing
    ipaddress.ip_network("240.0.0.0/4"),        # Reserved
]
```

Note: `169.254.169.254` (AWS EC2 instance metadata endpoint) is covered by the link-local range.

## DNS Rebinding Defense

```python
# src/url_security.py — _resolve_hostname_ips()
async def _resolve_hostname_ips(hostname: str) -> list[str]:
    """Resolve hostname to all IP addresses it maps to."""
    # Uses socket.getaddrinfo() via asyncio.to_thread()
    # Returns all A + AAAA records
    # All are checked — even one private address = blocked
```

DNS rebinding attack: attacker controls DNS for `evil.com` and makes it resolve to `10.0.0.1` after the initial check. The resolution is done at request time (not cached), so this is checked immediately before fetching.

## Where Applied

```python
# src/tool_implementations.py — do_web_fetch()
await validate_public_http_url(url)   # raises if private

# src/webhook_manager.py — deliver()
await validate_public_http_url(webhook.url)   # raises if private

# Also checked inline in: research deep crawl, api_call tool
```

## src/url_safety.py (Separate)

A complementary file with allow/deny list patterns for the web_fetch tool:
- Blocks known malicious/phishing domains
- Allows only expected content types
- Different from url_security.py which is purely about network topology
