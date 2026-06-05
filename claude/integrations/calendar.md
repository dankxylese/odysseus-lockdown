# Calendar Integration

**Files:** `src/caldav_sync.py`, `src/caldav_writeback.py`, `routes/calendar_routes.py`
**Protocol:** CalDAV (compatible with Apple Calendar, Nextcloud, Radicale, Google Calendar via bridge)

## Architecture

```
Local DB (core/database.py: CalendarEvent)
  ↕ sync
CalDAV server (Nextcloud, Radicale, Apple iCloud, etc.)
  ↕ write-through
manage_calendar tool / /api/calendar/* routes
```

## CalDAV Sync (Pull)

```python
# src/caldav_sync.py — sync_calendars(owner)
# 1. Connect to CalDAV server with stored credentials
# 2. Fetch all calendars for the user
# 3. For each calendar: fetch events (VEVENT components)
# 4. Upsert into local DB (CalendarEvent table)
#    Key: calendar_id + event_uid  (to prevent PK collisions across owners)
#    Note: owner included in hash — prevents cross-owner UID collision (fix #2765)

def sync_calendars(owner: str) -> dict:
    settings = get_caldav_settings(owner)
    client = caldav.DAVClient(
        url=settings["url"],
        username=settings["username"],
        password=settings["password"],
    )
    principal = client.principal()
    calendars = principal.calendars()
    
    synced = 0
    for cal in calendars:
        events = cal.search(event=True)
        for event in events:
            upsert_event(event.icalendar_component, owner=owner, calendar_id=cal.id)
            synced += 1
    return {"synced": synced}
```

## CalDAV Write-back (Push)

```python
# src/caldav_writeback.py — write_event(event, owner)
# Called after local create/update/delete
# Pushes the change back to the CalDAV server

def create_event(event: CalendarEvent, owner: str):
    cal = get_caldav_calendar(event.calendar_id, owner)
    vevent = build_ical(event)
    cal.save_event(vevent)

def delete_event(event_uid: str, calendar_id: str, owner: str):
    # Fetch event by UID, delete from CalDAV
    # 404 from CalDAV = success (already deleted) — cross-session delete sync (#2e0250e)
```

## manage_calendar Tool

```python
# src/tool_implementations.py — do_manage_calendar()
# Actions:
"list_calendars"      # list all calendars for owner — call FIRST before mutating
"list_events"         # list events for a date range
"get_event"           # get single event by uid
"create_event"        # create + write-back
"update_event"        # update + write-back
"delete_event"        # delete local + CalDAV
"sync"                # force pull from CalDAV
```

**Important:** The agent is instructed to call `list_calendars` FIRST before any create/update/delete. This ensures the correct `calendar_id` is used rather than guessing.

## DB Model

```python
# core/database.py: CalendarEvent
class CalendarEvent:
    id: str            # local UUID
    uid: str           # iCal UID (from remote)
    calendar_id: str   # which calendar
    owner: str
    summary: str
    description: str
    location: str
    start_dt: datetime
    end_dt: datetime
    all_day: bool
    recurrence: str    # RRULE string
    status: str        # CONFIRMED | TENTATIVE | CANCELLED
```

## Multi-Account / Multi-Calendar

Each user can have multiple CalDAV servers configured. Each server has multiple calendars. `list_calendars` returns all of them with their IDs.

## Routes

```
GET    /api/calendar/calendars        — list calendars
GET    /api/calendar/events           — list events (with date range filter)
POST   /api/calendar/events           — create event
PUT    /api/calendar/events/{id}      — update event
DELETE /api/calendar/events/{id}      — delete event
POST   /api/calendar/sync             — force sync from CalDAV
```
