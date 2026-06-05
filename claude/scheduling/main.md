# Scheduling & Background Jobs

Three systems for deferred/recurring work:

| System | File | When Used |
|---|---|---|
| TaskScheduler | `src/task_scheduler.py` | Recurring user-configured tasks (cron/daily/event/webhook) |
| Background Jobs | `src/bg_jobs.py` + `src/bg_monitor.py` | Long-running bash commands from the agent (`#!bg` prefix) |
| Event Bus | `src/event_bus.py` | Event-triggered tasks (fire when X threshold reached) |

## Files

- [task-scheduler.md](task-scheduler.md) — Schedule types, execution loop, `ensure_defaults()`
- [bg-jobs.md](bg-jobs.md) — Detached subprocess, status tracking, auto-continue
- [event-bus.md](event-bus.md) — `fire_event()`, threshold triggers, task routing
- [builtin-actions.md](builtin-actions.md) — All ~50 built-in action handlers

## Quick Overview

### Task Scheduler

```python
# src/task_scheduler.py — TaskScheduler
# In-process asyncio loop checking every 10s
# DB table: ScheduledTask (core/database.py)

# Schedule types:
# cron     — croniter expression (e.g. "0 9 * * 1-5")
# daily    — time of day (e.g. "09:00") with timezone
# weekly   — day + time (e.g. "Mon 09:00")
# monthly  — day-of-month + time
# once     — single datetime

# Trigger types:
# schedule — time-based (above)
# event    — fire when event counter hits threshold
# webhook  — external POST to /api/tasks/<id>/webhook/<token>
```

### Background Jobs

```python
# src/bg_jobs.py
# Agent writes: #!bg <command>  → launches as detached subprocess
# Job persists in data/bg_jobs/ (log, exit code, script)
# bg_monitor.py polls → when done, re-invokes agent with output
```

### Default Tasks

Every user gets these tasks auto-created at startup via `ensure_defaults()`:
- **Personal Assistant** — event-triggered, runs on inbox/calendar events
- **Housekeeping** — periodic cleanup tasks

See [builtin-actions.md](builtin-actions.md) for the full list.

## Routes

```
/api/tasks/*    — routes/task_routes.py
```

## Disabling In-Process Scheduler

```bash
# Set to use external cron instead of in-process loop
ODYSSEUS_INPROCESS_TASKS=0
# Then trigger tasks via: POST /api/tasks/<id>/run
```
