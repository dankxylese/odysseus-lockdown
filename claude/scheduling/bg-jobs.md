# Background Jobs

**Files:** `src/bg_jobs.py`, `src/bg_monitor.py`

Detached subprocess execution for long-running commands. When the agent writes `#!bg <command>` as a bash tool call, the command runs in the background without blocking the chat stream.

## How It Works

```python
# src/bg_jobs.py — launch()
async def launch(command: str, session_id: str, owner: str, cwd: str = None, max_runtime_s: int = 3600) -> dict:
    job_id = str(uuid4())[:8]
    
    # Write script to file
    script_path = f"data/bg_jobs/{job_id}.sh"
    with open(script_path, "w") as f:
        f.write(f"#!/bin/bash\n{command}\n")
    
    # Launch detached subprocess (setsid = new session, survives server restart)
    log_path = f"data/bg_jobs/{job_id}.log"
    proc = await asyncio.create_subprocess_exec(
        "bash", "-c",
        f"setsid bash {script_path} > {log_path} 2>&1; echo $? > {job_id}.exit",
        cwd=cwd or "data/",
    )
    
    # Store metadata
    jobs_state[job_id] = {
        "session_id": session_id, "owner": owner,
        "command": command, "status": "running",
        "started_at": now, "max_runtime_s": max_runtime_s,
    }
    _save_jobs()   # atomic JSON write
    
    return {"job_id": job_id, "status": "running", "log_path": log_path}
```

## Status Tracking

```python
# src/bg_jobs.py — get_status(job_id)
def get_status(job_id: str) -> dict:
    # Check .exit file exists → job done
    exit_path = f"data/bg_jobs/{job_id}.exit"
    if os.path.exists(exit_path):
        exit_code = int(open(exit_path).read().strip())
        log = read_last_n_chars(f"data/bg_jobs/{job_id}.log", MAX_OUTPUT_CHARS)
        return {"status": "done", "exit_code": exit_code, "output": log}
    
    # Check max runtime exceeded
    elapsed = (now - job["started_at"]).total_seconds()
    if elapsed > job["max_runtime_s"]:
        return {"status": "timeout", "output": read_last_n_chars(log, ...)}
    
    return {"status": "running", "output": read_last_n_chars(log, 2000)}
```

Storage: `data/bg_jobs/<job_id>.log`, `.exit`, `.sh` + `data/bg_jobs.json`

Output cap: `MAX_OUTPUT_CHARS = 16_384`
Max runtime: 3600 seconds (1 hour) by default

## Auto-Continue: bg_monitor.py

```python
# src/bg_monitor.py — start_bg_monitor() → background asyncio task
# Polls job status every tick
# When a job transitions running → done:
#   1. Load the session that launched the job
#   2. Re-invoke the agent with the job output:
#      "Background job {job_id} completed.\nExit code: {code}\nOutput:\n{output}"
#   3. Mark job as "notified" so it's only processed once

# This ensures the agent never silently drops a completed background job.
# The user sees the final result in the same chat stream.
```

## Usage by Agent

The agent's `_AGENT_RULES` (in `src/agent_loop.py`) tells the model:
- For long-running commands (model downloads, installs): use `#!bg <command>`
- The job ID is shown in the response
- When the job completes, the agent is automatically re-invoked

## Files on Disk

```
data/bg_jobs/
├── <job_id>.sh      — the script content
├── <job_id>.log     — stdout + stderr combined
└── <job_id>.exit    — exit code (appears when done)

data/bg_jobs.json    — job metadata index (JSON array)
```
