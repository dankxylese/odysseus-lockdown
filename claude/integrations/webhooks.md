# Webhooks (Outbound)

**File:** `src/webhook_manager.py`
**Class:** `WebhookManager`

Delivers HTTP POST payloads to user-configured URLs when events occur.

## Supported Events

```python
SUPPORTED_EVENTS = [
    "session.created",     # new chat session
    "chat.completed",      # agent/chat turn finished
    "chat.message",        # individual message
    "webhook.test",        # manual test delivery
]
```

## Webhook Delivery

```python
# src/webhook_manager.py — deliver(webhook, event, payload)
async def deliver(webhook: Webhook, event: str, payload: dict):
    body = json.dumps(payload)
    
    # HMAC-SHA256 signature
    sig = hmac.new(
        webhook.secret.encode(),
        body.encode(),
        "sha256"
    ).hexdigest()
    
    headers = {
        "Content-Type": "application/json",
        "X-Odysseus-Event": event,
        "X-Odysseus-Signature": f"sha256={sig}",
        "X-Odysseus-Delivery": str(uuid4()),
    }
    
    # Private URL check before delivery
    await validate_public_http_url(webhook.url)   # raises if private
    
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.post(webhook.url, content=body, headers=headers)
```

## Private URL Protection

```python
# src/webhook_manager.py — _is_private_url()
# Checks both IP literals and DNS resolution
# Prevents: delivering to localhost, 10.x, 192.168.x, 172.16.x, etc.
# Same logic as src/url_security.py but inline for webhook delivery
```

This prevents SSRF via webhook delivery (attacker creates webhook pointing to internal services).

## Retry Logic

```python
# Delivery queue with backoff retries
# Max retries: 3
# Backoff: 5s, 30s, 5min
# Failed deliveries logged in WebhookDelivery table (core/database.py)
```

## DB Models (core/database.py)

```python
class Webhook:
    id: str
    owner: str
    name: str
    url: str
    secret: str          # HMAC signing secret
    events: str          # comma-separated event names
    enabled: bool
    created_at: datetime

class WebhookDelivery:
    id: str
    webhook_id: str
    event: str
    status_code: int
    delivered_at: datetime
    error: str
```

## Routes

```
GET    /api/webhooks              — list my webhooks
POST   /api/webhooks              — create webhook
PUT    /api/webhooks/{id}         — update
DELETE /api/webhooks/{id}         — delete
POST   /api/webhooks/{id}/test    — send test event
GET    /api/webhooks/{id}/deliveries — delivery history
```

## Firing Webhooks from Code

```python
# Routes call this after completing operations:
webhook_manager.fire_event("chat.completed", session_id=..., owner=..., payload={...})

# app.py:509
webhook_manager = WebhookManager(api_key_manager=api_key_manager)
webhook_manager.set_loop(asyncio.get_running_loop())
```
