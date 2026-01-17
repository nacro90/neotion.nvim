# Toggle Heading Block Support - Task Checklist

**Status:** ⏸️ Blocked (waiting for toggle-block-support)
**Last Updated:** 2026-01-15

## Current Focus
> Waiting for `toggle-block-support` task to complete

## Blocker
- [ ] **BLOCKED BY:** `toggle-block-support` task must be completed first
  - Toggle block implements `> ` prefix detection
  - Detection pattern order requires toggle before toggle heading

## Tasks

### Phase 1: Model Layer
- [ ] Add `is_toggleable` and `original_is_toggleable` fields to HeadingBlock
- [ ] Update `HeadingBlock.new()` to parse `is_toggleable` from API
- [ ] Update `format()` to add `> ` prefix when toggleable
- [ ] Update `update_from_lines()` to detect `> # ` prefix
- [ ] Update `serialize()` to include `is_toggleable` in output
- [ ] Update `type_changed()` to detect toggle state changes
- [ ] Update `get_gutter_icon()` for toggle heading distinction

### Phase 2: Detection & Factory
- [ ] Add toggle heading patterns to detection.lua (BEFORE toggle pattern)
- [ ] Pattern: `> ### `, `> ## `, `> # ` with toggleable flag
- [ ] Update factory.create_raw_block() for toggle headings
- [ ] Test type detection with toggle prefix

### Phase 3: Tests
- [ ] Unit test: Parse toggle heading from API JSON
- [ ] Unit test: format() produces `> # ` prefix
- [ ] Unit test: update_from_lines() parses `> ## `
- [ ] Unit test: serialize() outputs `is_toggleable: true`
- [ ] Unit test: type_changed() detects toggle state change
- [ ] Unit test: Level change within toggle headings (`> # ` → `> ## `)
- [ ] Unit test: Conversion heading ↔ toggle heading

### Phase 4: Integration & Polish
- [ ] Gutter icon differentiation (optional)
- [ ] Manual integration test (edit in buffer, sync to Notion)

## Completed
- [x] Task initialization and planning (2026-01-15)
- [x] Codebase analysis (2026-01-15)
- [x] Updated syntax: `># ` → `> # ` (with space) (2026-01-15)
- [x] Identified dependency on toggle-block-support (2026-01-15)

## Notes
- Syntax: `> # Heading` (space after `>` like Notion)
- This task depends on toggle-block-support completing first
- Pattern order in detection.lua is critical
