# Agent Loop

**File:** `src/agent_loop.py`
**Entry:** `async def stream_agent_loop(messages, session, endpoint, model, owner, ...) → AsyncGenerator`

The agent loop is a streaming multi-round conversation where the LLM writes tool blocks that execute automatically.

## System Prompt Injection

```python
# src/agent_loop.py:61-109 — _AGENT_PREAMBLE + _AGENT_RULES

_AGENT_PREAMBLE = """\
You are an AI assistant with tool access. To use a tool, write a fenced code 
block with the tool name as the language tag. The block executes automatically 
and you see the output."""

# _AGENT_RULES covers:
# - Tool block syntax (```bash, ```python, etc.)
# - 60s timeout, 10K output cap per tool
# - Document vs file tool guidance
# - Calendar: call list_calendars first
# - Bulk email: use bulk_email, not N individual calls
# - Email UIDs from tool output, not row numbers
# - UI link format: [Name](#kind-id)
# - Scheduling: "do X every morning" → create task, don't do it once
```

## Round Structure (MAX_AGENT_ROUNDS = 50)

```
Round N:
  1. [Tool retrieval]
     tool_index.get_tools_for_query(message, k=16)
     + ALWAYS_AVAILABLE tools (bash, python, web_search, etc.)
     + MCP tools from connected servers
     → inject into system prompt

  2. [Context budget check]
     estimate_tokens(messages) > 85% window → compact_context()

  3. [LLM stream]
     async for token in stream_llm(messages, ...):
         yield token   ← user sees tokens in real-time
         accumulate full response

  4. [Tool block detection]
     blocks = parse_tool_blocks(full_response)
     if not blocks: DONE — yield final text, break

  5. [Tool execution]
     for block in blocks:
         if is_public_blocked_tool(block.tool_type) and not is_admin(owner):
             result = {"error": "Tool blocked for non-admin users"}
         else:
             result = await execute_tool_block(block.tool_type, block.content, ...)

  6. [Result injection]
     messages.append({"role": "user", "content": f"Tool result ({tool}):\n{result}"})
     → loop back to Round N+1
```

## Tool Retrieval Per Round

```python
# src/agent_loop.py — get_tools_for_round()
from src.tool_index import get_tool_index
idx = get_tool_index()

# Top-K by cosine similarity to the user's message
relevant = idx.get_tools_for_query(user_message, k=16)

# Always include regardless of retrieval score
always = ALWAYS_AVAILABLE - blocked_tools_for_owner(owner)

# MCP tools from connected servers
mcp = [f"mcp__{server_id}__{tool}" for server_id, tools in mcp_manager.get_all_tools()]

# Disabled per-server tools filtered out
disabled_map = _load_mcp_disabled_map()

final_tools = relevant | always | mcp
```

Tool index detail → [../tools/tool-index.md](../tools/tool-index.md)

## System Prompt Tool Listing

Tool descriptions injected into the system prompt at each round:

```
## Available Tools

```bash
Run shell commands...
```

```python
Execute Python code...
```

mcp__browser_screenshot: Take a screenshot of the current page
  Args (JSON): {"url": string (required)}

[... up to ~20 tools ...]
```

MCP tool schemas are sanitized before injection (name/type caps, control char removal) — [src/mcp_manager.py:42-80](../../src/mcp_manager.py).

## Function Calling Mode (OpenAI-native)

When the endpoint supports native function calling (detected from endpoint config):
- Tools rendered as `FUNCTION_TOOL_SCHEMAS` (OpenAI format) instead of text descriptions
- LLM response parsed for `tool_calls` array instead of fenced blocks
- `function_call_to_tool_block()` converts OpenAI tool_call → ToolBlock
- Same execution path from that point on

Source: `src/tool_schemas.py` — `FUNCTION_TOOL_SCHEMAS` dict + `function_call_to_tool_block()`

## Loop Termination

The loop ends when:
1. LLM produces output with **no tool blocks** → final answer, `break`
2. `MAX_AGENT_ROUNDS` (50) reached → forced break
3. Tool execution returns a terminal error (permission denied, etc.)

## Agent Rules Injected (Key Behaviours)

Agents are instructed via `_AGENT_RULES` to:
- BIAS TOWARD ACTION — don't ask for clarification on minor ambiguity
- After a tool succeeds → one short confirmation sentence, no re-checking
- After a tool fails → retry or explain, never go silent
- Calendar → `list_calendars` first before mutating
- Bulk email → one `bulk_email` call, never loop N individual calls
- Scheduled requests ("do X every morning") → create a task, don't just do it once
- Entity links in replies use `[Text](#kind-id)` format for frontend clickability

## Key Constants

```python
# src/agent_tools.py (re-exported from various modules)
MAX_AGENT_ROUNDS = 50
MAX_OUTPUT_CHARS = 10_000    # tool output cap  (src/tool_execution.py:29)
MAX_READ_CHARS   = 20_000    # file read cap    (src/tool_execution.py:30)
MAX_DIFF_LINES   = 400       # edit_file diff   (src/tool_execution.py:31)
COMPACT_THRESHOLD = 0.85     # context compact  (src/context_compactor.py:38)
```
