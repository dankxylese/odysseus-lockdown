# External Service Integrations

**File:** `src/integrations.py`

Non-standard integrations available via the `api_call` tool.

## api_call Tool

The primary mechanism for calling configured external services:

```python
# src/tool_implementations.py — do_api_call()
# Input JSON: {service: "miniflux", action: "get_unread", ...}
# Routes to the appropriate adapter in src/integrations.py
```

## Miniflux (RSS Reader)

```python
# Miniflux REST API
# Base URL + API key stored in settings

# Operations:
# get_feeds          → list all RSS feeds
# get_unread         → list unread articles
# get_articles       → list articles for feed
# mark_read          → mark article as read
# refresh_feeds      → trigger fetch

# Used by personal assistant to check RSS unread counts
```

## Gitea (Git Forge)

```python
# Gitea REST API
# Base URL + access token in settings

# Operations:
# list_repos         → user/org repositories
# list_issues        → open issues for repo
# create_issue       → open new issue
# list_prs           → open pull requests
# get_file           → read file from repo
```

## Linkding (Bookmarks)

```python
# Linkding REST API
# Base URL + API key in settings

# Operations:
# list_bookmarks     → recent/all bookmarks
# search_bookmarks   → search by tag/title
# add_bookmark       → save URL with tags
# delete_bookmark    → remove bookmark
```

## RSS Direct

```python
# Direct RSS/Atom feed parsing (no server required)
# Parses feed URL directly using feedparser
# Used when SearXNG isn't configured for news results
```

## SearXNG (Web Search)

```python
# src/search/providers.py + src/search/core.py
# External SearXNG instance (docker-compose: searxng service)
# Configuration: SEARXNG_URL env or settings.searxng_url

# web_search tool routes here:
# do_web_search(query) → searxng_search(query) → results
# Result count: settings.searxng_results_count (default 10)
```

SearXNG runs as a companion Docker service (no API key needed for local instance).

## Companion App

**Files:** `companion/routes.py`, `companion/pairing.py`

Mobile companion app pairing:
```python
# POST /api/companion/pair   — generate QR code with pairing token
# POST /api/companion/verify — confirm pairing from mobile
# Paired device gets a short-lived session token

# Pairing token: TOTP-based one-time code
# QR code: otpauth:// URL for mobile app
```

## Secret Storage

All API keys/tokens/passwords for integrations stored encrypted:
```python
# src/secret_storage.py — Fernet encryption
# Key: data/.app_key (generated on first run)
# Used for: email password, caldav password, api keys

def encrypt(value: str) -> str:
    return fernet.encrypt(value.encode()).decode()

def decrypt(value: str) -> str:
    return fernet.decrypt(value.encode()).decode()
```

Values stored encrypted in SQLite (Settings table). Never returned to client in plaintext via settings scrubber (`src/settings_scrub.py`).

## ntfy (Push Notifications)

```python
# Push notification channel for task reminders
# Configured via settings: ntfy_url, ntfy_topic
# Used by manage_notes reminder_channel="ntfy" setting
# Also supports: browser notifications, email reminders
```
