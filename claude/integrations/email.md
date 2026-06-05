# Email Integration

**Files:** `routes/email_routes.py`, `routes/email_helpers.py`, `routes/email_pollers.py`, `src/email_thread_parser.py`
**Protocols:** IMAP (read) + SMTP (send)

## Architecture

```
IMAP server ←→ routes/email_routes.py (list/read/delete/mark)
SMTP server ←→ routes/email_routes.py (send/reply)
Thread reconstruction ← src/email_thread_parser.py
Multi-account ← per-account credentials in settings
```

## Multi-Account Support

Users can configure multiple email accounts. Each has:
```python
{
    "account_id": "gmail",           # user-defined label
    "imap_host": "imap.gmail.com",
    "imap_port": 993,
    "smtp_host": "smtp.gmail.com",
    "smtp_port": 587,
    "username": "user@gmail.com",
    "password": "<encrypted>",       # src/secret_storage.py Fernet
    "is_default": True
}
```

The `list_email_accounts` tool returns all configured accounts. Email tools accept an `account` parameter matching the label.

## Email Tool Flow

```python
# list_emails — IMAP SEARCH + FETCH
# src/tool_implementations.py — do_list_emails(content)
# 1. Parse JSON: {folder, max_results, unread_only, account}
# 2. Connect IMAP (imaplib)
# 3. SEARCH for messages: UNSEEN if unread_only else ALL
# 4. FETCH headers: Subject, From, Date, Message-ID, UID
# 5. Generate AI summary of subject+from for each
# 6. Return formatted table with UIDs
```

**Critical:** Email UIDs are IMAP UIDs (integers), NOT row numbers from the list output. The `_AGENT_RULES` in `src/agent_loop.py` specifically warns the agent about this.

## Thread Reconstruction

```python
# src/email_thread_parser.py
# Parses In-Reply-To and References headers to build thread trees
# Used by read_email to show conversation context

def parse_thread(message) -> dict:
    in_reply_to = message.get("In-Reply-To")
    references = message.get("References", "").split()
    return {
        "thread_id": references[-1] if references else in_reply_to,
        "parent_id": in_reply_to,
        "ancestors": references,
    }
```

## reply_to_email Tool

```python
# Sends reply preserving threading headers
def do_reply_to_email(content):
    # Parse JSON: {uid, account, body}
    # Fetch original: Subject, From, Message-ID, References
    # Build reply:
    reply["To"] = original["From"]
    reply["Subject"] = "Re: " + strip_re_prefix(original["Subject"])
    reply["In-Reply-To"] = original["Message-ID"]
    reply["References"] = (original["References"] + " " + original["Message-ID"]).strip()
    # Send via SMTP
    # Mark original as Answered (\Answered flag)
```

## bulk_email Tool

```python
# src/tool_implementations.py — do_bulk_email()
# Single action on many emails at once
# Actions: delete, archive, mark_read, mark_unread
# 
# Input JSON: {action, uids: ["uid1", "uid2"], account}
# OR:         {action, all_unread: true, account}
#
# This is the correct tool for "mark all as read", "delete these 19 emails"
# Agent rules explicitly forbid looping individual calls
```

## Email Pollers: routes/email_pollers.py

Background IMAP IDLE polling for new email notifications:
```python
# Checks for new mail periodically
# Fires event "email_received" when new messages arrive
# Can be disabled via ODYSSEUS_INPROCESS_POLLERS=0
```

## Routes

```
GET  /api/email/accounts        — list configured accounts
GET  /api/email/messages        — list messages (folder, filters)
GET  /api/email/messages/{uid}  — read full email
POST /api/email/messages        — send new email
POST /api/email/reply           — send reply
POST /api/email/bulk            — bulk action
PUT  /api/email/messages/{uid}  — update flags
DELETE /api/email/messages/{uid} — delete
```
