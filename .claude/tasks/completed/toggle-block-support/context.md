# Toggle Block Support - Context

## Key Files

| File | Purpose |
|------|---------|
| `lua/neotion/model/blocks/toggle.lua` | ToggleBlock class (DONE) |
| `lua/neotion/model/blocks/detection.lua` | Toggle pattern added (DONE) |
| `lua/neotion/model/blocks/factory.lua` | Uses generic handling (no changes needed) |
| `lua/neotion/model/registry.lua` | Toggle registered (DONE) |
| `lua/neotion/render/icons.lua` | Toggle icons (pre-existing) |
| `spec/unit/model/blocks/toggle_spec.lua` | Unit tests (DONE - 34 tests) |
| `spec/unit/model/blocks/detection_spec.lua` | Detection tests updated (52 tests) |

## Architecture Notes

### Notion API Structure

```json
{
  "type": "toggle",
  "toggle": {
    "rich_text": [{
      "type": "text",
      "text": { "content": "Toggle content" },
      "plain_text": "Toggle content",
      "annotations": { "bold": false, ... }
    }],
    "color": "default"
  },
  "has_children": true,
  "id": "uuid"
}
```

### Buffer Syntax

| State | Buffer Format |
|-------|---------------|
| Toggle (collapsed) | `> Text content` |
| Toggle (expanded) | Future: indent children below |

### Implementation Details

**ToggleBlock class:**
- Inherits from Block base class
- Similar structure to ParagraphBlock and QuoteBlock
- Uses rich_text_to_notion_syntax for display
- get_gutter_icon() returns collapsed toggle icon
- has_children() returns false (MVP)

**Detection:**
- Pattern: `^(> )` with prefix `> ` and type `toggle`
- TYPE_TO_PREFIX: `toggle = '> '`

**Registry:**
- Module name: `toggle`
- Maps to `neotion.model.blocks.toggle`

## Dependencies

- **External:** Notion API (toggle support)
- **Internal:**
  - Block base class
  - RichText utilities
  - Gutter icon system
  - Detection system

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-01-15 | MVP: Always render collapsed | Matches Notion default, children deferred |
| 2026-01-15 | Use `> ` prefix | Reserved in detection, consistent with Notion UX |
| 2026-01-15 | Reuse paragraph rich_text logic | Same API structure, avoid duplication |

## Session Notes

### Session 1 - 2026-01-15

**Completed:**
- Created ToggleBlock class with all methods
- Added detection pattern for `> ` prefix
- Registered toggle in registry
- Created 34 unit tests for toggle_spec.lua
- Updated detection_spec.lua with toggle tests
- All tests pass (34 toggle + 52 detection)

**Key implementation details:**
- ToggleBlock follows same pattern as QuoteBlock
- format() returns `> text`
- update_from_lines() strips `> ` prefix
- serialize() preserves rich_text or parses markers
- type_changed() detects conversion (toggle ↔ paragraph, etc.)
- get_gutter_icon() returns collapsed icon from icons.lua

**Next steps:**
- Manual testing with real Notion pages
- Future: expand/collapse UI, children rendering

