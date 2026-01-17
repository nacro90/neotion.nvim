# Toggle Heading Block Support - Context

## Key Files

| File | Purpose |
|------|---------|
| `lua/neotion/model/blocks/heading.lua` | Main implementation - extend this |
| `lua/neotion/model/blocks/detection.lua` | Add toggle heading prefix patterns |
| `lua/neotion/model/blocks/factory.lua` | Update raw block creation |
| `lua/neotion/model/registry.lua` | No changes needed (same handler) |
| `lua/neotion/render/icons.lua` | Has toggle icons ready |
| `spec/unit/model/blocks/heading_spec.lua` | Add toggle tests |

## Architecture Notes

### Notion API Structure

```json
{
  "type": "heading_1",
  "heading_1": {
    "rich_text": [{...}],
    "color": "default",
    "is_toggleable": true  // Key property
  },
  "has_children": true  // When toggleable, can have children
}
```

### Buffer Syntax Mapping (Updated)

| Notion Type | is_toggleable | Buffer Format |
|-------------|---------------|---------------|
| heading_1 | false | `# Text` |
| heading_1 | true | `> # Text` |
| heading_2 | false | `## Text` |
| heading_2 | true | `> ## Text` |
| heading_3 | false | `### Text` |
| heading_3 | true | `> ### Text` |

**Neden `> # ` (space ile)?**
- Notion'da `>` yazıp space → toggle oluşur
- `> ## ` yazıp space → toggle heading oluşur
- Buffer syntax Notion UX ile tutarlı

### Current HeadingBlock Properties

```lua
---@class neotion.HeadingBlock : neotion.Block
---@field level integer         -- 1, 2, or 3
---@field original_level integer -- For detecting type change
---@field text string           -- Plain text content
---@field rich_text table[]     -- Original rich_text array
-- NEW:
---@field is_toggleable boolean -- Toggle heading flag
---@field original_is_toggleable boolean -- For detecting toggle change
```

### Detection Pattern Order (Critical!)

```lua
-- Toggle headings MUST come before toggle and regular headings
PREFIX_PATTERNS = {
  -- 1. Toggle headings first
  { pattern = '^(> ### )', prefix = '> ### ', type = 'heading_3', toggleable = true },
  { pattern = '^(> ## )', prefix = '> ## ', type = 'heading_2', toggleable = true },
  { pattern = '^(> # )', prefix = '> # ', type = 'heading_1', toggleable = true },
  
  -- 2. Regular toggle
  { pattern = '^(> )', prefix = '> ', type = 'toggle' },
  
  -- 3. Regular headings
  { pattern = '^(### )', prefix = '### ', type = 'heading_3' },
  { pattern = '^(## )', prefix = '## ', type = 'heading_2' },
  { pattern = '^(# )', prefix = '# ', type = 'heading_1' },
}
```

## Dependencies

- **External:** Notion API (is_toggleable support confirmed)
- **Internal:** 
  - RichText utilities (`utils/rich_text.lua`)
  - Block base class
  - Gutter icon system
  - **toggle-block-support task** (prerequisite)

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-01-15 | Extend HeadingBlock instead of new type | Notion uses same type with flag, less duplication |
| 2026-01-15 | Use `> # ` prefix (with space) | Consistent with Notion UX (`>` then space creates toggle) |
| 2026-01-15 | Track original_is_toggleable | Needed for type_changed() to detect toggle state changes |
| 2026-01-15 | Depend on toggle-block-support | Pattern order requires toggle detection first |

## Session Notes

### Session 1 - 2026-01-15

**Analysis completed:**
- HeadingBlock fully implemented at `lua/neotion/model/blocks/heading.lua`
- Toggle icons already exist in icons.lua
- Detection has `>` reserved but unused
- Factory hardcodes `is_toggleable: false`

**Key findings:**
- `is_toggleable` is a property of heading block, not a separate type
- Children of toggle heading are regular blocks with parent_id
- Expanded/collapsed state not in API (UI only)

**Update from user:**
- Notion'da `>` yazıp space → toggle oluşur
- `> ## ` yazıp space → toggle heading oluşur
- Syntax değişti: `># ` → `> # ` (space ile)
- Önce toggle block support gerekli (prerequisite)

**Next steps:**
1. Complete toggle-block-support first
2. Then modify HeadingBlock to handle is_toggleable
3. Update detection patterns (order critical)
4. Update factory
5. Add tests
