# Tool Parsing

**File:** `src/tool_parsing.py`
**Entry:** `parse_tool_blocks(text: str) -> List[ToolBlock]`

Supports 5 different LLM output formats because different models use different tool-call syntax.

## Pattern Priority

Patterns tried in order. Once any pattern produces results, later patterns are skipped:

```
1. Fenced code blocks    ```bash ... ```
2. [TOOL_CALL] blocks    [TOOL_CALL] {tool => "bash", ...} [/TOOL_CALL]
3. XML <invoke> blocks   <tool_call><invoke name="bash">...</invoke></tool_call>
4. <tool_code> blocks    <tool_code>{tool => 'bash', args => '...'}</tool_code>
5. (DSML pre-normalized) DeepSeek markup → normalized to <invoke> before patterns run
```

## Pattern 1: Fenced Code Blocks (Standard)

```python
# src/tool_parsing.py:22-25
_TOOL_BLOCK_RE = re.compile(
    r"```(" + "|".join(TOOL_TAGS) + r")\s*\n([\s\S]*?)```",
    re.IGNORECASE,
)
```

`TOOL_TAGS` is the authoritative list of all valid tool names from `src/agent_tools.py`.

Example:
```
```bash
ls -la
```
```
→ `ToolBlock(tool_type="bash", content="ls -la")`

**Special case:** if fenced block content contains `<invoke ...>`, parse the invoke instead (some models wrap XML in a fenced block).

## Pattern 2: [TOOL_CALL] Blocks

```python
# src/tool_parsing.py:29-32
_TOOL_CALL_RE = re.compile(
    r"\[TOOL_CALL\]\s*\{([\s\S]*?)\}\s*\[/TOOL_CALL\]",
    re.IGNORECASE,
)
```

Parser extracts tool name + content via several sub-patterns:
- `--command "value"` 
- `command => "value"` or `command: "value"`
- `args => {content}` 
- `query/path/code => "value"`

## Pattern 3: XML `<invoke>` Blocks

```python
# src/tool_parsing.py:37-48
_XML_TOOL_CALL_RE = ...   # <tool_call> or <function_call> wrapper
_XML_INVOKE_RE = re.compile(r'<invoke\s+name=["\'](\w+)["\']>([\s\S]*?)</invoke>')
_XML_PARAM_RE  = re.compile(r'<parameter\s+name=["\'](\w+)["\']>([\s\S]*?)</parameter>')
```

Parameters extracted and passed through `function_call_to_tool_block()` (same converter as native function calling) so all tools and correct content formats work:
```python
# src/tool_parsing.py:249-272 — _parse_xml_invoke()
params = {name: value for each <parameter>}
return function_call_to_tool_block(tool_name.lower(), json.dumps(params))
```

## Pattern 4: `<tool_code>` Blocks (MiniMax-M2.5)

```python
# src/tool_parsing.py:52-55
_TOOL_CODE_RE = re.compile(r"<tool_code>\s*\{([\s\S]*?)\}\s*</tool_code>")
# Format: {tool => 'tool_name', args => '<command>ls</command>'}
```

## Pattern 5: DeepSeek DSML (Pre-normalization)

```python
# src/tool_parsing.py:60-85 — _normalize_dsml()
# DeepSeek models emit fullwidth-pipe delimited tags:
# <｜｜DSML｜｜tool_calls> → <tool_call>
# <｜｜DSML｜｜invoke name="bash"> → <invoke name="bash">
# etc.
# Applied first before any pattern matching
```

## TOOL_NAME_MAP — Alias Resolution

```python
# src/tool_parsing.py:88-177
_TOOL_NAME_MAP = {
    "shell": "bash", "terminal": "bash", "execute": "bash",
    "search": "web_search", "websearch": "web_search",
    "fetch": "web_fetch", "fetch_url": "web_fetch",
    "read": "read_file", "cat": "read_file",
    "write": "write_file", "save": "write_file",
    "document": "update_document",
    "schedule": "manage_tasks",
    "memory": "manage_memory",
    # ... 80+ aliases
}
```

Maps model-specific synonyms to canonical tool names. If the name isn't in the map but IS in `TOOL_TAGS`, it's used as-is.

## strip_tool_blocks()

```python
# src/tool_parsing.py:399-411
def strip_tool_blocks(text: str) -> str:
    """Remove all tool blocks from text for clean display to user."""
    text = _normalize_dsml(text)
    cleaned = _TOOL_BLOCK_RE.sub('', text)
    cleaned = _TOOL_CALL_RE.sub('', cleaned)
    cleaned = _XML_TOOL_CALL_RE.sub('', cleaned)
    cleaned = _TOOL_CODE_RE.sub('', cleaned)
    # Strip bare <invoke> not in <tool_call>
    cleaned = re.sub(r'<invoke\s+name=["\'].*?</invoke>', '', cleaned, flags=re.DOTALL)
    cleaned = re.sub(r'\n{3,}', '\n\n', cleaned)
    return cleaned.strip()
```

Used to show the user clean LLM text without the raw tool markup.

## ToolBlock Dataclass

```python
# src/agent_tools.py
@dataclass
class ToolBlock:
    tool_type: str    # canonical tool name
    content: str      # raw content/command/JSON
```
