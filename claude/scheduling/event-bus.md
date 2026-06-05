# Event Bus

**File:** `src/event_bus.py`

Lightweight event counter system that triggers tasks when a threshold is reached. No message queue — purely in-memory counters with DB-backed task state.

## Core API

```python
# src/event_bus.py

def fire_event(event_name: str, owner: str = None, payload: dict = None):
    """Increment counter for event_name, fire any tasks that hit threshold."""
    
    # Find tasks listening to this event
    tasks = db.query(ScheduledTask).filter(
        ScheduledTask.trigger_type == "event",
        ScheduledTask.trigger_event == event_name,
        ScheduledTask.status == "active",
        ScheduledTask.owner == (owner or system_owner),
    ).all()
    
    for task in tasks:
        task.trigger_counter += 1
        if task.trigger_counter >= task.trigger_count:
            task.trigger_counter = 0   # reset
            asyncio.create_task(task_scheduler.run_task(task.id))

def set_task_scheduler(scheduler: TaskScheduler):
    """Wired at startup — app.py:629"""
```

## Event Names

Common events fired throughout the codebase:

| Event | Where Fired | Meaning |
|---|---|---|
| `message_sent` | `routes/chat_routes.py` | User sent a chat message |
| `email_received` | `routes/email_routes.py` or poller | New email arrived |
| `calendar_event_created` | `routes/calendar_routes.py` | New calendar event |
| `note_created` | `routes/note_routes.py` | New note/todo created |
| `research_completed` | `routes/research_routes.py` | Deep research job finished |

## Creating an Event-Triggered Task

```python
# Via manage_tasks tool or POST /api/tasks
{
    "name": "Check inbox when email arrives",
    "action": "check_inbox",
    "trigger_type": "event",
    "trigger_event": "email_received",
    "trigger_count": 1,    # fire on every email
    "owner": "alice"
}
```

Or to batch-trigger (fire every 5 messages):
```python
{
    "trigger_type": "event",
    "trigger_event": "message_sent",
    "trigger_count": 5,    # fire after 5 messages
}
```

## Owner Routing for System Events

If an event has no specific owner:
```python
# Ownerless events → primary admin (first admin in auth.json)
owner = owner or _get_primary_owner()
```

This handles system-level events that aren't tied to a specific user's session.

## Wiring at Startup

```python
# app.py:629
from src.event_bus import set_task_scheduler
set_task_scheduler(task_scheduler)
# event_bus.fire_event() now routes to task_scheduler.run_task()
```
