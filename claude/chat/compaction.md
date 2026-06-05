# Context Compaction

**File:** `src/context_compactor.py`

When the message history approaches the model's context window limit, the oldest messages are summarized via the same LLM to create a compact replacement.

## Trigger

```python
# src/context_compactor.py:38-40
COMPACT_THRESHOLD = 0.85  # trigger at 85% of context window
SUMMARY_MAX_TOKENS = 1024
SMALL_CONTEXT_LIMIT = 8192  # models with context <= this get aggressive trimming
```

Check happens at the start of each agent round:
```python
window = get_context_length(model)            # src/model_context.py
used   = estimate_tokens(messages)            # rough count
if used / window > COMPACT_THRESHOLD:
    messages = await compact_context(messages, endpoint, model)
```

## Compaction Process

```python
# src/context_compactor.py — compact_context()
# 1. Identify messages to summarize (oldest N, keep recent K untouched)
# 2. Send summary request to LLM:
summary_messages = [
    {"role": "system", "content": SELF_SUMMARY_SYSTEM_PROMPT},
    {"role": "user",   "content": format_for_summary(old_messages)},
]
summary = await llm_call_async(summary_messages, endpoint, model,
                                max_tokens=SUMMARY_MAX_TOKENS)

# 3. Replace old messages with one summary message:
compacted = [
    {"role": "assistant", "content": f"[Conversation Summary]\n{summary}"},
    *recent_messages,
]
```

## Summary Prompt Format

```python
# src/context_compactor.py:43-69
SELF_SUMMARY_SYSTEM_PROMPT = """You are summarizing a conversation...

## Conversation Summary
**Turns summarized:** {count}  |  **Compactions so far:** {n}

### User Goal
One sentence describing what the user is trying to accomplish.

### What Was Done
- Completed actions, decisions, key outputs
- Specific file paths, function names, variable names, URLs, config values
- Errors encountered and how they were resolved

### Current State
What is the system/code/task state right now?

### Pending / Next Steps
- What remains, open questions, blockers

### Key Context
- Constraints, preferences, decisions that must not be forgotten
- Specific values: model names, ports, paths, credentials, versions

Keep under 1000 tokens. Be dense."""
```

## Tool Message Sanitization

Before compaction (and before every LLM call), orphaned tool messages are cleaned:

```python
# src/context_compactor.py:72-95 — _sanitize_tool_messages()
# Problem: front-trimming history can cut the assistant `tool_calls` parent
# while keeping its tool response, causing OpenAI API error:
# "messages with role 'tool' must be a response to a preceding message with tool_calls"
#
# Fix: drop any role:"tool" message that doesn't have a matching tool_calls parent
# Also: drop dangling assistant messages with tool_calls but no following tool response
```

## Context Window Lookup: src/model_context.py

```python
# src/model_context.py — get_context_length(model_name)
# Lookup table of known models → context window sizes
# Examples:
#   llama3.2         → 131072
#   gpt-4o           → 128000
#   deepseek-r1-70b  → 65536
#   mistral-7b       → 32768
# Falls back to 4096 for unknown models

def estimate_tokens(messages: list) -> int:
    # Rough heuristic: total chars / 4
    total = sum(len(str(m.get("content", ""))) for m in messages)
    return total // 4
```

## When Compaction Fires

Compaction fires per agent round, not per conversation. A long multi-tool task (50 rounds) may compact 3-4 times. Each compaction creates a `[Conversation Summary]` assistant message that subsequent rounds can reference.
