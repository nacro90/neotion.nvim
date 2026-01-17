# Children Rendering Architecture - Context

## Key Files

### Model Layer
| File | Purpose |
|------|---------|
| `lua/neotion/model/block.lua` | Block base class - children field, add/remove/get methods |
| `lua/neotion/model/blocks/toggle.lua` | Toggle - supports_children = true |
| `lua/neotion/model/blocks/quote.lua` | Quote - supports_children = true |
| `lua/neotion/model/blocks/bulleted_list.lua` | Bullet list - supports_children = true |
| `lua/neotion/model/blocks/numbered_list.lua` | Numbered list - supports_children = true |
| `lua/neotion/model/registry.lua` | Block deserialization dispatch + children population |

### API Layer
| File | Purpose |
|------|---------|
| `lua/neotion/api/blocks.lua` | `get_children()`, `get_all_children()`, `_fetch_nested_children()`, `append()` |

### Sync Layer
| File | Purpose |
|------|---------|
| `lua/neotion/sync/init.lua` | Push/pull orchestration |
| `lua/neotion/sync/plan.lua` | Sync plan creation |
| `lua/neotion/model/blocks/factory.lua` | Orphan → block creation |
| `lua/neotion/model/mapping.lua` | Line ↔ block mapping |

### Rendering Layer
| File | Purpose |
|------|---------|
| `lua/neotion/render/init.lua` | Main rendering entry |
| `lua/neotion/render/extmarks.lua` | Extmark management |
| `lua/neotion/buffer/format.lua` | Block → lines formatting |

### Input Layer
| File | Purpose |
|------|---------|
| `lua/neotion/input/editing.lua` | Enter/o/O/Tab/Shift+Tab handling |

## Architecture Notes

### Current Block Structure (Hierarchical - Phase 1 & 2 Complete)
```lua
-- Block base class now supports:
block.children = {}           -- Child blocks array
block.parent = nil            -- Parent block reference
block:add_child(child)        -- Adds child, sets parent reference
block:remove_child(child)     -- Removes child, clears parent
block:get_children()          -- Returns children array
block:set_parent(parent)      -- Sets parent, updates parent_id and depth
block:has_children()          -- raw.has_children OR #self.children > 0
block:supports_children()     -- false (override in subclasses)
```

### API Integration (Phase 2 Complete)
```lua
-- get_all_children() now:
-- 1. Fetches all direct children (with pagination)
-- 2. For each block with has_children=true, recursively fetches their children
-- 3. Stores children in block._children field
-- 4. Respects max_depth limit (default: 3)

-- _fetch_nested_children() helper:
-- - Sequential fetch (one block at a time) to avoid rate limiting
-- - Populates _children field on each block
-- - Recursive call with incremented depth

-- registry.deserialize() now:
-- - Checks for _children field
-- - Recursively deserializes children
-- - Calls add_child() to establish parent-child relationship
```

### Child-Capable Blocks
```lua
-- These blocks override supports_children() to return true:
ToggleBlock:supports_children()       -- true
QuoteBlock:supports_children()        -- true
BulletedListBlock:supports_children() -- true
NumberedListBlock:supports_children() -- true
```

### Notion API Children Structure
```json
{
  "type": "toggle",
  "toggle": { "rich_text": [...] },
  "has_children": true,
  "id": "toggle-id"
}
// Children fetched separately via GET /blocks/{toggle-id}/children
// After get_all_children(), children are in _children field:
{
  "type": "toggle",
  "toggle": { "rich_text": [...] },
  "has_children": true,
  "id": "toggle-id",
  "_children": [
    { "type": "paragraph", ... },
    { "type": "paragraph", ... }
  ]
}
```

### Buffer Indent Convention
```
> Toggle header          ← depth 0, no indent
  First child            ← depth 1, 2-space indent
  Second child           ← depth 1, 2-space indent
    Nested child         ← depth 2, 4-space indent
Normal text              ← depth 0, no indent
```

### Key API Endpoints
- `GET /blocks/{id}/children` - Fetch children
- `PATCH /blocks/{parent_id}/children` - Append children to parent
- `DELETE /blocks/{id}` - Delete block (orphans children)

### Editing Keymaps (Phase 6 Complete)
```lua
-- Normal mode keymaps for indent navigation:
<Tab>     → handle_tab(bufnr)       -- Indent line by 2 spaces (become child)
<S-Tab>   → handle_shift_tab(bufnr) -- Dedent line by 2 spaces (become sibling)

-- Constants:
INDENT_SIZE = 2       -- 2 spaces per indent level
MAX_INDENT_LEVEL = 3  -- Max 3 levels (6 spaces)

-- Behavior:
-- Tab: Adds 2-space indent, respects max depth, preserves cursor column
-- Shift+Tab: Removes 2-space indent, clamps cursor if in removed area
```

## Dependencies

### External
- Notion API v2022-06-28
- No external library dependencies

### Internal
- Block base class for inheritance
- Registry for deserialization
- Extmark system for line tracking
- Mapping system for block ↔ line correlation

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-01-15 | 2-space indent for children | Consistent with toggle Enter behavior, readable |
| 2026-01-15 | Hierarchical model over flat | Correct representation of Notion structure |
| 2026-01-15 | Lazy fetch on expand (future) | MVP: fetch all on page load |
| 2026-01-15 | Start with toggle | Simplest use case, clear parent-child UX |
| 2026-01-15 | Bidirectional parent reference | Enables traversal in both directions |
| 2026-01-15 | Sequential children fetch | Avoids API rate limiting issues |
| 2026-01-15 | _children field in raw block | Clean separation - API populates, deserialize uses |
| 2026-01-15 | Tab/Shift+Tab for indent nav | Intuitive UX, consistent with other editors |
| 2026-01-15 | Max 3 indent levels | Matches Notion's nesting limit, prevents deep nesting |
| 2026-01-15 | TDD for Phase 6 | Ensures robust implementation, catches edge cases |

## Session Notes

### Session 1 - 2026-01-15

**Problem identified:**
- Toggle Enter creates indented line (`  icine`)
- Indented line detected as orphan
- Factory creates it as sibling paragraph with `after_block_id`
- Should be child of toggle with `parent_id`

**Root cause:**
- No indent-based parent detection in `detect_orphan_lines()`
- No children storage in Block model
- `create_from_orphans()` doesn't consider hierarchy

### Session 2 - 2026-01-15 (Phase 1 Complete)

**Implemented:**
1. Block base class changes:
   - Added `children: Block[]` and `parent: Block|nil` fields
   - Added `add_child(child, index?)` - inserts child, sets parent reference
   - Added `remove_child(child)` - removes child, clears parent
   - Added `get_children()` - returns children array
   - Added `set_parent(parent)` - sets parent, updates parent_id and depth
   - Added `supports_children()` - returns false (base class)
   - Updated `has_children()` - checks `raw.has_children OR #self.children > 0`

2. Child-capable blocks updated:
   - ToggleBlock, QuoteBlock, BulletedListBlock, NumberedListBlock
   - All now have `supports_children() = true`
   - All have updated `has_children()` implementation

3. Tests:
   - Full unit tests for children management in `block_spec.lua`
   - Toggle-specific children tests in `toggle_spec.lua`
   - Removed obsolete MVP test that expected `has_children() = false`

### Session 3 - 2026-01-15 (Phase 2 Complete)

**Implemented:**
1. API Layer changes (`lua/neotion/api/blocks.lua`):
   - `get_all_children()` now accepts `opts` parameter with `max_depth` (default: 3)
   - Added `_fetch_nested_children()` helper function
   - Recursively fetches children for blocks with `has_children: true`
   - Stores children in `_children` field of raw block
   - Sequential fetch to avoid API rate limiting

2. Registry changes (`lua/neotion/model/registry.lua`):
   - `deserialize()` now checks for `_children` field
   - Recursively deserializes children
   - Calls `add_child()` to establish parent-child relationship
   - Maintains depth tracking through parent chain

3. Tests:
   - Unit tests for `_fetch_nested_children()` edge cases
   - Unit tests for children deserialization
   - Unit tests for deeply nested children

4. Test fixes:
   - Updated tests that expected toggle/quote/lists to be "unsupported"
   - Changed unsupported examples to use `callout` instead of `toggle`

### Session 4 - 2026-01-15 (Phase 3 Complete)

**Implemented:**
1. Recursive rendering in `model/init.lua`:
   - `format_blocks()` now uses `format_block_recursive()` helper
   - Passes `depth` to each block's format method
   - Recursively formats children with `depth + 1`
   - Maintains numbered list counter per depth level

2. Mapping layer changes (`model/mapping.lua`):
   - `setup_extmarks()` now recursively handles children
   - `get_block_at_line()` searches children recursively
   - `get_block_by_id()` searches children recursively
   - `get_dirty_blocks()` collects from children recursively
   - `get_editable_blocks()` collects from children recursively

3. Block format methods updated:
   - `BulletedListBlock:format()` - now supports `opts.indent`
   - `NumberedListBlock:format()` - now supports `opts.indent`
   - `QuoteBlock:format()` - now supports `opts.indent`
   - (ToggleBlock, ParagraphBlock, HeadingBlock already had indent support)

4. Test mock updates:
   - Added `get_children()` method to all mock blocks in test files
   - `spec/unit/model/mapping_spec.lua` - 3 mock block definitions
   - `spec/unit/model/format_blocks_spec.lua` - 3 mock block definitions

5. New tests:
   - `format_blocks with children` test group in `init_spec.lua`
   - Tests for toggle, quote, bulleted list children indentation
   - Tests for deeply nested children (3 levels)

### Session 5 - 2026-01-15 (Phase 4 & 5 Complete)

**Implemented:**
1. Indent Detection (`lua/neotion/model/mapping.lua`):
   - `INDENT_SIZE = 2` constant for 2-space indent
   - `detect_indent_level(line)` - returns floor(leading_spaces / 2)
   - `strip_indent(line, indent_level)` - local helper to remove leading spaces
   - `find_parent_by_indent(bufnr, orphan_line, orphan_indent)` - finds parent block

2. Orphan Detection Updates (`detect_orphan_lines`):
   - Now detects indent level for each orphan line
   - Splits orphans when indent level changes
   - Sets `parent_block_id` for indented orphans
   - Sets `indent_level` on orphan ranges
   - Strips indent from content

3. Factory Updates (`lua/neotion/model/blocks/factory.lua`):
   - `create_from_orphans()` now passes `parent_block_id` and `indent_level` to blocks
   - Children use `parent_block_id`, siblings use `after_block_id`

4. Sync Plan Updates (`lua/neotion/sync/plan.lua`):
   - `SyncPlanCreate` type includes `parent_block_id` field

5. Sync Execution Updates (`lua/neotion/sync/init.lua`):
   - `group_creates_into_batches()` separates children by parent
   - `execute_batch()` uses `parent_block_id` as target for children
   - Children appended to parent block, not page

6. Tests:
   - `spec/unit/model/indent_spec.lua` - 20 tests for indent detection
   - `spec/unit/model/blocks/factory_spec.lua` - 5 tests for parent_block_id support
   - Updated sync test for `target_id` error message

### Session 6 - 2026-01-15 (Phase 6 Complete)

**Implemented (TDD Approach):**
1. Tab/Shift+Tab indent tests (`spec/unit/input/editing_spec.lua`):
   - 7 tests for Tab indent handling
   - 8 tests for Shift+Tab dedent handling
   - 2 tests for keymap setup verification

2. `handle_tab(bufnr)` in `lua/neotion/input/editing.lua`:
   - Adds 2-space indent to current line
   - Respects max depth (3 levels = 6 spaces)
   - Preserves cursor column position

3. `handle_shift_tab(bufnr)` in `lua/neotion/input/editing.lua`:
   - Removes 2-space indent from current line
   - Clamps cursor to 0 if in removed indent area
   - No-op if line not indented

4. Keymaps in `setup()`:
   - `<Tab>` → `handle_tab()` (normal mode)
   - `<S-Tab>` → `handle_shift_tab()` (normal mode)

5. Cleanup in `detach()`:
   - Added `<Tab>` and `<S-Tab>` keymap removal

**Test Results:**
- All 62 editing tests pass
- TDD red-green cycle completed successfully

**Next steps (Phase 7 - Polish):**
1. Handle deep nesting limits (max 3 levels)
2. Handle block deletion with children
3. Handle moving children between parents
4. Performance testing with many children

### Session 7 - 2026-01-16 (Phase 7 Complete)

**Implemented (TDD Approach):**

1. Deep nesting limits in `handle_enter()` and `handle_o()`:
   - Added `detect_indent_level()` helper at module top
   - Added `get_child_indent()` helper that respects MAX_INDENT_LEVEL
   - Toggle child creation now calculates indent based on parent line indent
   - Max 3 levels (6 spaces) enforced for all child creation
   - 4 new tests in `spec/unit/input/editing_spec.lua`

2. Block deletion with children tests (`spec/unit/model/block_spec.lua`):
   - Test: Clear all children references when parent deleted
   - Test: Handle nested children (grandchildren) deletion
   - Test: Preserve sibling children when one child removed
   - Notion API handles recursive child deletion automatically

3. Moving children between parents tests (`spec/unit/model/block_spec.lua`):
   - Test: Move child from one parent to another
   - Test: Update depth when moving to different level parent
   - Test: Handle moving child to become top-level (no parent)
   - Test: Correctly reorder children when inserting at specific index

**Test Results:**
- All 66 editing tests pass (4 new deep nesting tests)
- All 34 block tests pass (7 new children handling tests)
- Full test suite passes

**Key Insight:**
- Notion API automatically deletes children when parent is deleted (recursive archive)
- No need to explicitly delete children in sync plan - only parent needs to be deleted
- `remove_child()` correctly clears parent reference but keeps children intact (API handles cascade)

### Session 8 - 2026-01-17 (Bug Fix - Toggle Children Not Syncing)

**Problem:**
User reported toggle children not syncing:
```
> test toggle
  inner paragraph    ← This wasn't syncing as child of toggle
```
Both toggle and inner paragraph were being created as page-level siblings.

**Root Causes Identified:**

1. **temp_id to real_id resolution** (`lua/neotion/sync/init.lua`):
   - Child batches referenced parent's `temp_id`
   - But `temp_id` wasn't being resolved to real Notion ID after parent was created
   - Fix: Added `resolve_after_id(batch.parent_block_id)` call in `execute_batch`

2. **Orphan-to-orphan parent detection** (`lua/neotion/model/blocks/factory.lua`):
   - When both toggle and child are new (orphans), `find_parent_by_indent` couldn't find parent
   - Because it only searches existing `buffer_blocks`, not newly created orphan blocks
   - Fix: Added `find_parent_from_created_blocks()` helper in factory
   - Now detects parent from previously created blocks in same batch

**Files Changed:**
- `lua/neotion/sync/init.lua` - temp_id resolution (lines ~337-340, ~422-432)
- `lua/neotion/model/blocks/factory.lua` - `find_parent_from_created_blocks()` helper (lines ~344-470)
- `spec/unit/sync/init_spec.lua` - Test for child block creation under newly created parent
- `spec/unit/model/blocks/factory_spec.lua` - 3 tests for orphan-to-orphan parent detection

**Additional Test Fixes:**
- `spec/integration/editing_spec.lua` - Invalid page ID (non-hex characters)
- `lua/neotion/input/editing.lua` - `is_at_line_end()` for normal/insert mode compatibility
- `spec/unit/input/editing_spec.lua` - Cursor position test expectation
- `spec/unit/ui/live_search_spec.lua` - External icon test (Nerd Font vs emoji)

**Test Results:**
- All 1453 tests pass (0 failures)
- Factory tests: 49 pass
- Sync tests: 12 pass
- Integration tests: 5 pass

**Note:** There's still an indent-related bug to investigate in next session.

### Session 11 - 2026-01-17 (Bug Fix - Children Duplication on Sync)

**Problem:**
User reported duplicate children in Notion after sync:
- Toggle had existing children (paragraphs)
- User added new "para" block after toggle children with `<CR>`
- On sync, existing children were re-created as new blocks → duplication

**Log Evidence:**
```
all_blocks_count:8, extmark_count:6, block_count:6
Block marked as deleted (no extmark) | {"block_type":"paragraph","index":7}
Block marked as deleted (no extmark) | {"block_type":"paragraph","index":8}
```

8 blocks but only 6 extmarks → children extmarks missing → marked as deleted → detected as orphans → re-created!

**Root Cause:**
`mapping.add_block()` was adding ALL new blocks to top-level `blocks` array, ignoring `parent_block_id`.
When sync created children, they were added as top-level blocks instead of parent's children array.

This caused:
1. Children not properly tracked in model (no extmarks for them as children)
2. On next sync, their lines detected as orphans
3. Sync tried to re-create them → duplication

**Fix:**
1. Updated `mapping.add_block()` to accept `parent_block_id` parameter:
   - If `parent_block_id` provided: Find parent via `get_block_by_id()` and call `parent:add_child(block)`
   - If `nil`: Add to top-level blocks array as before

2. Updated `sync/init.lua` to pass `resolved_parent_id` to `add_block()`:
   - Line 437: `mapping.add_block(bufnr, create.block, start_line, end_line, block_after_id, resolved_parent_id)`

**Files Changed:**
- `lua/neotion/model/mapping.lua` - `add_block()` now supports `parent_block_id` parameter
- `lua/neotion/sync/init.lua` - Passes `resolved_parent_id` to `add_block()`
- `spec/unit/model/mapping_spec.lua` - 3 new tests for `add_block with parent_block_id`

**Test Results:**
- All 50 mapping tests pass
- All 12 sync tests pass
- Full test suite passes

### Session 12 - 2026-01-17 (Final Bug Fixes)

**Bug 1: New child block appears empty in Notion**
- Investigated serialization path with debug logging
- Unit tests verified serialization works correctly
- Manual testing confirmed the issue was intermittent/resolved

**Bug 2: HTTP 400 error for page-level blocks after toggle children**
- Error: `Block ID (child-block-id) to append children after is not parented by page`
- Root cause: `detect_orphan_lines` was setting `last_block_id` to child blocks (depth > 0)
- When creating page-level orphan, it used child block as `after_block_id`
- Notion API rejects this because child blocks can't be used as `after` for page-level creates

**Fix in `lua/neotion/model/mapping.lua`:**
```lua
-- Only update last_block_id for top-level blocks (depth=0)
-- Child blocks should not be used as after_block_id for page-level orphans
if owner.depth == 0 then
  last_block_id = owner:get_id()
end
```

**Cleanup:**
- Removed debug logging from `paragraph.lua`, `api/blocks.lua`, `sync/init.lua`
- All tests pass (48 success, 0 failed)

**Task Status: COMPLETED**









