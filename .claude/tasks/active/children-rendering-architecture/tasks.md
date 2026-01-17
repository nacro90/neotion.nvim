# Children Rendering Architecture - Task Checklist

**Status:** 🔄 In Progress
**Last Updated:** 2026-01-15

## Current Focus
> Session 8: Fixed toggle children sync bug. New indent-related bug identified - needs investigation in next session.

## Tasks

### Phase 1: Model Layer - Children Storage ✅
- [x] Add `children: Block[]` field to `Block` base class
- [x] Implement `Block:add_child(block)` method
- [x] Implement `Block:remove_child(block)` method
- [x] Implement `Block:get_children()` method
- [x] Update `Block:has_children()` to check `#self.children > 0`
- [x] Add `Block:set_parent(parent_block)` method
- [x] Add `Block:supports_children()` method (override in child-capable blocks)
- [x] Unit tests for children methods

### Phase 2: API Integration - Recursive Fetch ✅
- [x] Modify `get_all_children()` to fetch nested children recursively
- [x] Add `_fetch_nested_children()` helper function
- [x] Store children in `_children` field of raw block
- [x] Update `registry.deserialize()` to populate parent block's children
- [x] Handle max_depth limit (default: 3 levels)
- [x] Sequential fetch to avoid rate limiting
- [x] Unit tests for recursive fetch and children deserialization

### Phase 3: Rendering - Indented Display ✅
- [x] Add `depth` parameter to `Block:format(opts)` via `opts.indent`
- [x] Calculate indent from depth: `string.rep(' ', indent * indent_size)`
- [x] Implement recursive rendering in `model/init.lua` (`format_block_recursive`)
- [x] Update extmark creation for hierarchical line ranges in `mapping.lua`
- [x] Update `mapping.lua` to track parent-child relationships (recursive search)
- [x] Unit tests for indented rendering (`format_blocks with children`)

### Phase 4: Detection - Indent Parsing ✅
- [x] Create `detect_indent_level(line)` helper
- [x] Create `find_parent_by_indent(lines, line_num, indent)` function
- [x] Modify `detect_orphan_lines()` to group by indent level
- [x] Track indent → parent_block_id mapping
- [x] Unit tests for indent detection

### Phase 5: Sync - Parent-aware Creation ✅
- [x] Modify `factory.create_from_orphans()` to detect parent
- [x] Group indented orphans under their parent
- [x] Use `blocks_api.append(parent_id, ...)` for children
- [x] Handle create order (parent before children)
- [ ] Integration tests for nested sync (deferred)

### Phase 6: Editing - Indent Navigation ✅
- [x] `Tab` in normal mode: indent block (become child)
- [x] `Shift+Tab` in normal mode: dedent block (become sibling)
- [x] Unit tests for indent editing (17 new tests)
- [ ] Update `handle_enter()` for nested block contexts (deferred - current behavior OK)
- [ ] Update `handle_o()` to respect nesting (deferred - current behavior OK)

### Phase 7: Polish & Edge Cases ✅
- [x] Handle deep nesting limits (max 3 levels)
- [x] Handle block deletion with children
- [x] Handle moving children between parents
- [ ] Update toggle expand/collapse state tracking (deferred - future feature)
- [ ] Performance testing with many children (deferred - future optimization)

## Completed
- [x] Task initialization and planning (2026-01-15)
- [x] Architecture analysis (2026-01-15)
- [x] Problem root cause identified (2026-01-15)
- [x] Toggle block basic support (prerequisite) (2026-01-15)
- [x] **Phase 1: Model Layer** (2026-01-15)
- [x] **Phase 2: API Integration** (2026-01-15)
  - `get_all_children()` now recursively fetches nested children
  - `_fetch_nested_children()` helper handles has_children blocks
  - `registry.deserialize()` populates parent's children array from `_children`
  - Max depth limit (3) prevents infinite recursion
  - Sequential fetching avoids API rate limiting
  - Full test coverage for children deserialization
- [x] **Phase 3: Rendering** (2026-01-15)
  - `format_block_recursive()` handles recursive children rendering
  - All block format methods support `opts.indent`
  - `mapping.lua` recursively searches children for block lookups
  - Tests for toggle, quote, bulleted list children indentation
- [x] **Phase 4: Detection - Indent Parsing** (2026-01-15)
  - `detect_indent_level(line)` - counts leading spaces, returns depth level
  - `find_parent_by_indent()` - finds parent block for indented orphan
  - `detect_orphan_lines()` now sets `parent_block_id` and `indent_level`
  - Content stripped of leading indent in orphan detection
  - Orphans split at indent level changes
  - Full test coverage in `spec/unit/model/indent_spec.lua`
- [x] **Phase 5: Sync - Parent-aware Creation** (2026-01-15)
  - `factory.create_from_orphans()` now passes `parent_block_id` to blocks
  - `SyncPlanCreate` type includes `parent_block_id` field
  - `group_creates_into_batches()` separates children by parent
  - `execute_batch()` uses parent_block_id as target for children
  - Children appended to parent block, not page
- [x] **Phase 6: Editing - Indent Navigation** (2026-01-15)
  - `handle_tab(bufnr)` - indents line by 2 spaces (max 3 levels)
  - `handle_shift_tab(bufnr)` - dedents line by 2 spaces
  - Tab/Shift+Tab keymaps added in setup()
  - Cursor position preserved during indent/dedent
  - 17 new unit tests in editing_spec.lua (TDD approach)
  - All 62 editing tests pass
- [x] **Phase 7: Polish & Edge Cases** (2026-01-16)
  - Deep nesting limits in `handle_enter()` and `handle_o()` for toggle blocks
  - `get_child_indent()` helper respects MAX_INDENT_LEVEL (3 levels = 6 spaces)
  - `detect_indent_level()` helper moved to module top for reuse
  - Block deletion with children tests (3 tests)
  - Moving children between parents tests (4 tests)
  - All 66 editing tests pass, all 34 block tests pass

### Session 8: Bug Fix - Toggle Children Sync ✅
- [x] Investigate why indented lines don't get parent_block_id
- [x] Write failing test for child block sync
- [x] Fix temp_id to real_id resolution for child batches
- [x] Fix orphan-to-orphan parent detection (detect_orphan_lines + factory)
- [x] Fix integration test page ID validation error
- [x] Fix is_at_line_end for normal mode testing
- [x] Fix live_search external icon test

### Session 9: Children Line Range Sync Bug ✅
- [x] Investigate duplicate children bug on save
- [x] Root cause: `refresh_line_ranges` only updated top-level blocks, not children
- [x] Fix: Updated `refresh_line_ranges` to recursively handle all blocks (including children)
- [x] Write failing tests for children line range refresh
- [x] All 47 mapping tests pass

### Session 10: Toggle Children Block Separation Bug ✅
**Bug 1: CR creates single block instead of multiple** ✅
- [x] Investigate: When pressing `<CR>` multiple times inside toggle child, all new lines become ONE paragraph block instead of separate blocks
- [x] Root cause: `detect_orphan_lines` treats consecutive indented lines as single orphan range
- [x] Fix: Modified `detect_orphan_lines` to treat each indented line (indent > 0) as separate orphan
- [x] Top-level (indent 0) paragraphs can still be multi-line (Notion supports this)
- [x] Updated test expectations for new behavior
- [x] All 25 indent tests pass

**Bug 2: No virt_line between blocks in buffer (Deferred)**
- [ ] Notion shows spacing between blocks, buffer doesn't
- [ ] Consider using extmark virt_lines to show block separators
- [ ] Low priority - cosmetic issue

### Session 11: Children Duplication on Sync Bug ✅
- [x] Investigate: Existing toggle children being duplicated on sync
- [x] Root cause: `add_block()` ignored `parent_block_id`, added all blocks to top-level
- [x] Fix: Updated `add_block()` to accept and use `parent_block_id` parameter
- [x] Fix: Updated `sync/init.lua` to pass `resolved_parent_id` to `add_block()`
- [x] Write 3 tests for `add_block with parent_block_id`
- [x] All 50 mapping tests pass
- [x] All 12 sync tests pass

### Session 12: Final Bug Fixes ✅
**Bug 1: New child block appears empty in Notion**
- [x] Investigated serialization path
- [x] Added debug logging to trace the issue
- [x] Verified unit tests pass for serialization
- [x] Manual testing confirmed fix working

**Bug 2: HTTP 400 error on page-level block after toggle children**
- [x] Root cause: `detect_orphan_lines` set `last_block_id` to child blocks
- [x] Page-level orphans were using child block as `after_block_id`
- [x] Fix: Added `if owner.depth == 0` check before updating `last_block_id`
- [x] Now only top-level blocks are used as `after_block_id` for page-level orphans

**Cleanup:**
- [x] Removed debug logging from `paragraph.lua`
- [x] Removed debug logging from `api/blocks.lua`
- [x] Removed debug logging from `sync/init.lua`
- [x] All tests pass (48 success, 0 failed)

## Blockers
None - All bugs fixed! Task completed.

## Notes
- Start with toggle as primary use case
- MVP: No lazy loading, fetch all children on page load
- MVP: No expand/collapse UI, always show children
- This is prerequisite for: toggle heading, callout, nested lists
- Estimated effort: L (8-13 sessions)












