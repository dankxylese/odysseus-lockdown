# Built-in Actions

**File:** `src/builtin_actions.py`

~50 registered action handlers for scheduled tasks. Registered in `BUILTIN_ACTIONS` dict.

## Registration Pattern

```python
# src/builtin_actions.py
BUILTIN_ACTIONS: dict[str, Callable] = {}

def register(name: str):
    def decorator(fn):
        BUILTIN_ACTIONS[name] = fn
        return fn
    return decorator

@register("check_inbox")
async def handle_check_inbox(task: ScheduledTask, session_manager) -> str:
    # ... implementation ...
    return "result summary"
```

## Email Actions

| Action | Description |
|---|---|
| `check_inbox` | List unread emails for the task owner |
| `summarize_inbox` | LLM summary of unread emails |
| `send_daily_email_summary` | Compose + send daily digest |
| `process_inbox` | Sort/label/archive based on rules |

## Calendar Actions

| Action | Description |
|---|---|
| `review_calendar` | List upcoming events for next N days |
| `send_calendar_summary` | Daily calendar digest |
| `create_recurring_event` | Auto-create repeating events |

## Research Actions

| Action | Description |
|---|---|
| `trigger_research` | Start deep research on a configured topic |
| `read_research` | Pull latest research result |
| `research_and_save` | Research + save to personal docs |

## Image Generation

| Action | Description |
|---|---|
| `generate_image` | Generate image from task.prompt and save to gallery |
| `generate_daily_image` | Daily image generation |

## Model Serving (Cookbook)

| Action | Description |
|---|---|
| `cookbook_serve` | Start serving a model. Supports `end_after_min` |
| `cookbook_stop` | Stop a serving session |

## Memory & Skills

| Action | Description |
|---|---|
| `memory_cleanup` | Deduplicate and prune old memories |
| `skill_audit` | Test + improve a batch of skills |
| `backfill_memories` | Import chat history into memory |

## Personal Assistant

The most complex built-in — proactively checks email, calendar, memories and suggests actions:

```python
@register("personal_assistant")
async def handle_personal_assistant(task: ScheduledTask, session_manager):
    # Runs as the task owner with ASSISTANT_ALWAYS_AVAILABLE tools
    # Checks: unread emails, upcoming calendar events, due notes/tasks
    # Builds context summary → asks agent what needs attention
    # Writes output to assistant_log session (src/assistant_log.py)
```

This is the default event-triggered task for every user. Created via `ensure_defaults()` at startup.

## System Maintenance

| Action | Description |
|---|---|
| `cleanup_uploads` | Remove orphaned upload files |
| `cleanup_bg_jobs` | Remove old bg job logs |
| `null_owner_sweep` | Assign ownerless data to primary admin |
| `sync_caldav` | Pull latest CalDAV calendar changes |

## Housekeeping Defaults

```python
# src/task_scheduler.py — HOUSEKEEPING_DEFAULTS
# Dict defining required default tasks per user:
{
    "personal_assistant": {
        "name": "Personal Assistant",
        "action": "personal_assistant",
        "trigger_type": "event",
        "trigger_event": "message_sent",
        "trigger_count": 10,   # fire every 10 messages
        "legacy_names": ["Assistant", "Daily Check-in"],
    },
    ...
}
```

`ensure_defaults(owner)` is called at startup and creates/upgrades these for every user.
