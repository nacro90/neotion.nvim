# Phase 5.7: Basic Block Types - Implementation Plan

## Overview
Add 4 new block types to neotion.nvim with TDD approach:
1. **divider** - Read-only horizontal rule
2. **quote** - Editable block quote with rich text
3. **bulleted_list_item** - Editable bullet point (flat, no nesting)
4. **code** - Multi-line code block with language metadata

## Architecture Decisions

### Block Complexity Matrix
| Block | Editable | Multi-line | Rich Text | Children | Prefix |
|-------|----------|------------|-----------|----------|--------|
| divider | No | No | No | No | N/A |
| quote | Yes | No | Yes | No* | `\| ` |
| bulleted_list_item | Yes | No | Yes | No* | `- ` |
| code | Yes | Yes | No** | No | ` ``` ` |

*Children support deferred to Phase 9 (nesting)
**Code blocks use plain text, not rich_text formatting

### Syntax Decisions
```
divider:     "---" or "━━━" (nerd) → read-only display
quote:       "| text" (input) → "│ text" or "▋ text" (display)
bullet:      "-", "*", "+" (input) → "●", "○" (display based on icon preset)
code:        ```lang\ncode\n``` (markdown compatible)
```

### File Structure
```
lua/neotion/model/blocks/
├── divider.lua          # ~50 lines, simplest block
├── quote.lua            # ~150 lines, like paragraph + prefix
├── bulleted_list.lua    # ~150 lines, like paragraph + prefix
└── code.lua             # ~200 lines, multi-line handling
```

## Implementation Order (TDD)

### 1. Divider (Simplest - Warm-up)
**API Response:**
```json
{
  "type": "divider",
  "divider": {}
}
```

**Test Cases:**
- `divider.new(raw)` creates read-only block
- `divider:format()` returns `["---"]` or icon variant
- `divider:is_editable()` returns false
- `divider:serialize()` returns original raw (no changes)
- Registry recognizes `divider` type

**Display:**
```
nerd:  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ascii: ---
```

### 2. Quote (Editable with Prefix)
**API Response:**
```json
{
  "type": "quote",
  "quote": {
    "rich_text": [{"text": {"content": "Quote text"}}],
    "color": "default"
  }
}
```

**Test Cases:**
- `quote.new(raw)` extracts rich_text and color
- `quote:format()` returns `["| Quote text"]` with icon
- `quote:is_editable()` returns true
- `quote:update_from_lines(["| New text"])` updates text
- `quote:serialize()` preserves/updates rich_text
- Rich text formatting preserved (like paragraph)
- `quote:matches_content()` ignores prefix
- Registry recognizes `quote` type

**Display:**
```
nerd:  ▋ Quote text with **bold**
ascii: | Quote text with **bold**
```

### 3. Bulleted List Item (Similar to Quote)
**API Response:**
```json
{
  "type": "bulleted_list_item",
  "bulleted_list_item": {
    "rich_text": [{"text": {"content": "List item"}}],
    "color": "default"
  }
}
```

**Test Cases:**
- `bulleted_list.new(raw)` extracts rich_text
- `bulleted_list:format()` returns `["- List item"]` or `["● Item"]`
- `bulleted_list:is_editable()` returns true
- `bulleted_list:update_from_lines()` handles `-`, `*`, `+` prefixes
- `bulleted_list:serialize()` preserves/updates rich_text
- Rich text formatting preserved
- Registry recognizes `bulleted_list_item` type

**Display:**
```
nerd:  ● First item with *italic*
ascii: - First item with *italic*
```

### 4. Code (Multi-line, Language Metadata)
**API Response:**
```json
{
  "type": "code",
  "code": {
    "rich_text": [{"text": {"content": "const x = 1;\nconst y = 2;"}}],
    "language": "javascript",
    "caption": []
  }
}
```

**Test Cases:**
- `code.new(raw)` extracts content and language
- `code:format()` returns multi-line with fences
- `code:is_editable()` returns true
- `code:get_line_count()` returns correct count
- `code:update_from_lines()` parses fence + content
- `code:serialize()` preserves language, updates content
- Language preserved on round-trip
- Empty code block handling
- Registry recognizes `code` type

**Display:**
```
```javascript
const x = 1;
const y = 2;
```
```

**Line Range Complexity:**
- Code block spans multiple lines (fence_start, content, fence_end)
- Need `get_line_count()` method for mapping
- `update_from_lines()` must handle variable line count

## Registry Updates

```lua
-- lua/neotion/model/registry.lua
local type_to_module = {
  paragraph = 'paragraph',
  heading_1 = 'heading',
  heading_2 = 'heading',
  heading_3 = 'heading',
  -- Phase 5.7 additions:
  divider = 'divider',
  quote = 'quote',
  bulleted_list_item = 'bulleted_list',
  code = 'code',
}
```

## Icon Updates

Already defined in `render/icons.lua`:
```lua
PRESETS = {
  nerd = {
    quote = '▋',
    bullet = { '●', '○', '◆', '◇' },
  },
  ascii = {
    quote = '|',
    bullet = { '-', '*', '+', '-' },
  },
}
```

## Test Files

```
spec/unit/model/blocks/
├── divider_spec.lua     # ~15 tests
├── quote_spec.lua       # ~25 tests
├── bulleted_list_spec.lua # ~25 tests
└── code_spec.lua        # ~30 tests

spec/integration/
└── blocks_spec.lua      # Integration tests for new blocks
```

## Integration Test Scenarios

### Scenario 1: Mixed Block Types
```lua
it('should render page with all block types', function()
  -- Page with: heading, paragraph, divider, quote, bullet, code
  -- Verify format() produces correct buffer content
end)
```

### Scenario 2: Edit Quote and Save
```lua
it('should sync quote changes to API', function()
  -- Open page with quote
  -- Modify quote text
  -- Trigger sync
  -- Verify API call has correct rich_text
end)
```

### Scenario 3: Code Block Editing
```lua
it('should preserve language on code edit', function()
  -- Open page with javascript code
  -- Add new line to code
  -- Sync
  -- Verify language still "javascript"
end)
```

## Architect Review Feedback (Addressed)

### High Priority (Must Fix)

1. **Dual Formatting Systems**: `buffer/format.lua` already handles some block formatting.
   - **Decision**: Block model `format()` is the source of truth
   - `buffer/format.lua` will delegate to registry-deserialized blocks

2. **Quote Prefix Standardization**: Use `| ` consistently
   - Input: `| text` (pipe + space)
   - Display: `| text` (same) or `▋ text` (nerd icon)
   - Update `buffer/format.lua` line 56 from `'> '` to `'| '`

3. **Code Fence Parsing Strategy**: Greedy matching
   - First `` ``` `` opens, last `` ``` `` closes
   - Content with `` ``` `` inside is preserved literally
   - Language change during edit is supported

### Additional Test Cases (From Review)

**Divider:**
- Cursor positioning on read-only divider
- Returns exactly 1 line for mapping

**Quote:**
- Empty quote block (`| ` with no text)
- Quote with only whitespace after prefix
- Handle both `| ` and `> ` input (normalize to `| `)

**Bulleted List:**
- Prefix normalization: all (`-`, `*`, `+`) normalize to `-` in serialization
- List item with dash in content (e.g., `- -5 degrees`)
- Trailing whitespace handling

**Code Block (Critical):**
- Empty code block (no lines between fences)
- Code with fence characters inside content
- Language change during edit
- No language specified (empty string)
- Caption array preservation (read-only)
- Deleted opening/closing fence handling

### Design Decision: PrefixedBlock Helper

Quote and bulleted_list share prefix-handling logic:
```lua
-- Shared helper functions (inline, not separate module)
local function strip_prefix(line, patterns) end
local function add_prefix(line, prefix) end
```

## Known Limitations (Deferred to Phase 9)

1. **No Nesting:** Bullets and quotes won't support children
2. **No Indentation:** Flat list only
3. **No Syntax Highlighting:** Code blocks display plain text
4. **No Numbered Lists:** Only bulleted for now
5. **No Code Caption Editing:** Caption preserved but not displayed

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Multi-line code mapping | Use `#block:format({})` for line count |
| Icon rendering conflicts | Use existing icon system, test with both presets |
| Prefix parsing edge cases | Comprehensive tests for `-`, `*`, `+`, `\|` variants |
| Dual formatting conflict | Delegate from buffer/format to block model |
| Code fence in content | Greedy matching, document limitation |

## Acceptance Criteria

1. All 4 block types recognized and rendered
2. Editable blocks (quote, bullet, code) can be modified and synced
3. Rich text preserved for quote and bullet
4. Language metadata preserved for code
5. All tests pass (target: 100+ new tests)
6. CI green (format, typecheck, test)

## Manual Test Scenarios

### Test 1: Divider Display
```vim
:Neotion open <page_with_divider>
" Expected: See horizontal line, cannot edit it
```

### Test 2: Quote Editing
```vim
:Neotion open <page_with_quote>
" Navigate to quote, change text
:w
" Expected: Quote synced to Notion
```

### Test 3: Bullet List
```vim
:Neotion open <page_with_bullets>
" Expected: Bullets displayed with icons
" Edit bullet text, :w syncs
```

### Test 4: Code Block
```vim
:Neotion open <page_with_code>
" Expected: Code fences displayed
" Edit code content, language preserved on :w
```
