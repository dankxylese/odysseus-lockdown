# Task Scheduler

**File:** `src/task_scheduler.py`
**Class:** `TaskScheduler`

In-process asyncio loop that fires scheduled tasks at their due time.

## DB Model (core/database.py: ScheduledTask)

```python
class ScheduledTask:
    id: str
    owner: str
    name: str
    action: str          # built-in action name or "custom"
    prompt: str          # what to tell the agent when running
    status: str          # "active" | "paused" | "error" | "completed"
    schedule_type: str   # "cron" | "daily" | "weekly" | "monthly" | "once"
    cron_expr: str       # croniter expression (for cron type)
    schedule_time: str   # "HH:MM" (for daily/weekly/monthly)
    schedule_day: str    # day name or number (for weekly/monthly)
    timezone: str        # e.g. "Europe/London"
    trigger_type: str    # "schedule" | "event" | "webhook"
    trigger_event: str   # event name (for event type)
    trigger_counter: int # current event count
    trigger_count: int   # threshold to fire
    next_run: datetime   # next scheduled execution time
    last_run: datetime
    webhook_token: str   # UUID token for webhook auth
    then_task_id: str    # chain: run this task after completion
```

## Schedule Types

### Cron

```python
from croniter import croniter
next_run = croniter(cron_expr, last_run).get_next(datetime)
# Example cron_expr: "0 9 * * 1-5"  (9am Mon–Fri)
```

### Daily/Weekly/Monthly

```python
# Daily: next occurrence of HH:MM in user's timezone
# Uses zoneinfo for timezone handling
# schedule_time = "09:00"

# Weekly: next occurrence of day + time
# schedule_day = "Monday"

# Monthly: next occurrence of day-of-month + time
# schedule_day = "15"
```

### Once

```python
# next_run = specific datetime
# After firing: status = "completed", no re-schedule
```

## Execution Loop

```python
# src/task_scheduler.py — TaskScheduler._run_loop()
async def _run_loop(self):
    while not self._stopped:
        await asyncio.sleep(10)   # check every 10 seconds
        now = datetime.utcnow()
        
        # Find all due tasks
        db = SessionLocal()
        due = db.query(ScheduledTask).filter(
            ScheduledTask.status == "active",
            ScheduledTask.trigger_type == "schedule",
            ScheduledTask.next_run <= now,
        ).all()
        
        for task in due:
            asyncio.create_task(self.run_task(task.id))
            # Update next_run immediately so concurrent loop doesn't double-fire
            task.next_run = compute_next_run(task)
            task.last_run = now
        db.commit()
```

## run_task()

```python
async def run_task(task_id: str):
    task = get_task(task_id)
    
    if task.action in BUILTIN_ACTIONS:
        # Call registered handler
        handler = BUILTIN_ACTIONS[task.action]
        result = await handler(task, session_manager)
    else:
        # Custom task: send prompt to agent
        result = await _run_custom_task(task)
    
    # Update last_run, status
    # Fire then_task_id if set (task chaining)
    if task.then_task_id:
        asyncio.create_task(run_task(task.then_task_id))
```

## ensure_defaults()

Called at startup for every user. Creates/upgrades built-in tasks if missing or stale:

```python
# src/task_scheduler.py — ensure_defaults(owner)
# HOUSEKEEPING_DEFAULTS dict defines the required built-in tasks
# Each entry: {name, action, schedule_type, trigger_type, ...}
#
# If task exists with different config: upgrade it
# If task missing: create it
# Legacy names: check old names too, rename if found
```

## Task Chaining

```python
# ScheduledTask.then_task_id: str
# After task A completes → automatically run task B
# Used for: "run research → then summarize results → then send email"
```

## Webhook Tasks

External systems can trigger tasks:
```
POST /api/tasks/<task_id>/webhook/<webhook_token>
  Body: {any JSON payload}

# Task handler receives payload as context
# webhook_token validated against task.webhook_token (UUID)
# Exempt from AuthMiddleware (path-embedded credential)
```

## Routes

```
GET    /api/tasks              — list my tasks
POST   /api/tasks              — create task
PUT    /api/tasks/{id}         — update task
DELETE /api/tasks/{id}         — delete task
POST   /api/tasks/{id}/run     — run now
POST   /api/tasks/{id}/pause   — pause
POST   /api/tasks/{id}/resume  — resume
POST   /api/tasks/{id}/webhook/{token}  — webhook trigger
```
