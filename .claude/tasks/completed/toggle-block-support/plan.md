# Toggle Block Support - Strategic Plan

## Executive Summary

Notion'daki toggle block desteğini neotion.nvim'e eklemek. Buffer syntax: `> Toggle text`. Bu feature toggle heading için prerequisite.

## Current State

- **Toggle blocks** Phase 9+'da deferred
- Icon altyapısı hazır (`icons.lua`: toggle_collapsed, toggle_expanded)
- Detection'da `>` prefix reserve edilmiş
- `buffer/format.lua`'da hardcoded fallback var: `▶ text`
- Children fetch API hazır (`blocks.get_children()`)
- **Children rendering YOK** - sadece top-level blocks render ediliyor

## Proposed Solution

### MVP Scope (Phase 1)
- Toggle block'u **collapsed olarak** render et
- Children'ı **gösterme** (Notion default behavior)
- Editing desteği (content update)
- API roundtrip (serialize/deserialize)

### Future Scope (Phase 2+)
- Expand/collapse UI (keymap ile)
- Children fetch & render
- Nested toggle support
- State persistence (cache'de expanded state)

## Buffer Syntax

```
> This is a toggle block
```

**Notion'daki davranış:**
- `>` yazıp space = toggle block oluşur
- `> ## ` yazıp space = toggle heading oluşur (ayrı task)

## Implementation Phases

### Phase 1: Model Layer
- [ ] Create `ToggleBlock` class in `lua/neotion/model/blocks/toggle.lua`
- [ ] Implement `new()` - Parse from Notion API
- [ ] Implement `format()` - Render as `> text`
- [ ] Implement `serialize()` - Convert to API JSON
- [ ] Implement `update_from_lines()` - Parse buffer edits
- [ ] Implement `type_changed()` - Handle type conversions
- [ ] `has_children()` → return `false` for MVP (children deferred)

### Phase 2: Detection & Factory
- [ ] Add toggle pattern to detection.lua: `^(> )` → type = 'toggle'
- [ ] Register toggle in registry.lua
- [ ] Update factory.create_raw_block() for toggle type

### Phase 3: Gutter Icons
- [ ] Implement `get_gutter_icon()` - Return toggle icon
- [ ] Use collapsed icon (MVP - expand deferred)

### Phase 4: Tests
- [ ] Unit test: Parse toggle from API
- [ ] Unit test: format() produces `> ` prefix
- [ ] Unit test: serialize() outputs correct JSON
- [ ] Unit test: update_from_lines() parses edits
- [ ] Unit test: type conversion (toggle ↔ paragraph)

## Notion API Structure

```json
{
  "type": "toggle",
  "toggle": {
    "rich_text": [
      {
        "type": "text",
        "text": { "content": "Toggle content" },
        "plain_text": "Toggle content",
        "annotations": {...}
      }
    ],
    "color": "default"
  },
  "has_children": true,
  "id": "uuid"
}
```

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Children data loss | Medium | High | MVP: read-only children, warn on edit |
| Quote conflict (`\|` vs `>`) | Low | Low | Quote uses `\| `, toggle uses `> ` |
| Rich text loss | Low | High | Reuse paragraph's rich text handling |

## Success Metrics

- [ ] Toggle block API'den doğru parse edilir
- [ ] Buffer'da `> Text` doğru render edilir
- [ ] Edit sonrası serialize doğru JSON üretir
- [ ] Toggle ↔ paragraph dönüşümü çalışır
- [ ] Tüm testler geçer

## Dependencies

- **Blocks on:** None (standalone feature)
- **Blocked by this:** Toggle heading support

## Notes

- Children rendering Phase 2+'da
- Expanded/collapsed state API'de YOK - UI only
- MVP: Her zaman collapsed göster, children'ı fetch etme
