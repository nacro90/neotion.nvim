# neotion.nvim - TODO & Development Notes

Projenin tüm planlama, geliştirme notları ve yapılacaklar listesi.

---

## Quick Status

| Phase | Status | Description |
|-------|--------|-------------|
| 1-6 | ✅ Done | Foundation, Formatting, Navigation, Rate Limiting |
| 7 | ✅ Done | SQLite Cache (pages, content, frecency) |
| 8 | ✅ Done | Live Search + Query Cache |
| 9.0-9.3 | ✅ Done | `/` Slash Commands (blocks, colors) |
| 9.4 | TODO | `[[` Link Completion |
| 9.5 | TODO | `@` Mention |
| 10 | ✅ Done | Editing Experience Refactor |
| **11** | **Active** | Editing Bug Fixes |

---

## Phase 11: Editing Bug Fixes (Active)

### Status Table

| Bug | Priority | Status | Description |
|-----|----------|--------|-------------|
| 11.1 | CRITICAL | ✅ Done | Cache sync sonrası güncellenmiyor |
| 11.2 | CRITICAL | 🔄 WIP | Enter orphan line'da soft break yapıyor |
| 11.3 | HIGH | TODO | List item virtual line pozisyon hatası |

**Sıra**: ~~11.1~~ → **11.2** → 11.3

---

### Bug 11.1: Cache Sync ✅ FIXED

**Commit**: `5f96daf` (2026-01-09)

**Problem**: Push/sync sonrası local cache eski kalıyor.

**Çözüm**:
- `sync/init.lua` → `M.execute` success callback'ine cache update eklendi
- `cache_pages.save_content()` ve `sync_state.update_after_push()` çağrılıyor
- 3 test eklendi

**Bonus**: Pull optimization (`c912355`) - content aynıysa re-render atlanıyor.

---

### Bug 11.2: Enter Orphan Soft Break 🔄 WIP

**Problem**: Orphan line üzerinde `<CR>` yeni block açmıyor, soft break yapıyor.

**Senaryo**:
```
1. "test paragraph" üzerinde `o` → orphan line aç
2. "between paragraph" yaz
3. <CR> bas → aynı satırda devam ❌
4. "between paragraph 2" yaz
5. Sync → tek block (2 satır) gidiyor
```

**Root Cause**:
```lua
-- input/editing.lua handle_enter()
local block = mapping.get_block_at_line(bufnr, line)
if not block then
  -- Orphan line → fallback soft break
  vim.api.nvim_feedkeys('\n', 'n', false)
end
```

**Çözüm**:
- `split_orphan_at_cursor()` helper fonksiyonu eklendi
- `handle_enter()` içinde non-list orphan için bu fonksiyon çağrılıyor
- 5 test eklendi (cursor positions, edge cases)

**Etkilenen Dosyalar**:
- `lua/neotion/input/editing.lua`
- `spec/unit/input/editing_spec.lua`

---

### Bug 11.3: List Virtual Line Position (TODO)

**Problem**: Yeni list item eklendiğinde virtual line yanlış pozisyonda.

**Görüntü**:
```
• - test item
        ← virtual line (YANLIŞ)
  - asagiya indik
```

**Beklenen**:
```
• - test item
  - asagiya indik
        ← virtual line (list grubu sonu)
```

**Çözüm**:
- `mapping.add_block()` sonrası explicit `render.refresh(bufnr)` çağrısı
- veya `rebuild_extmarks()` içinde virtual lines clear/reapply

**Etkilenen Dosyalar**:
- `lua/neotion/model/mapping.lua`
- `lua/neotion/render/init.lua`

---

## Phase 10: Editing Experience ✅ COMPLETED

Tamamlandı: 2026-01-09

| Sub-Phase | Status | Description |
|-----------|--------|-------------|
| 10.1-10.5 | ✅ | Block fixes, orphan handling, type detection |
| 10.6 | ✅ | Virtual lines for block spacing |
| 10.7 | ✅ | Empty paragraph spacing optimization |
| 10.7.1 | ✅ | Empty line sync to Notion |
| 10.7.2 | ⏸️ | Live virtual line for o/O (optional) |
| 10.8 | ✅ | Gutter icons (configurable) |
| 10.9 | ✅ | Enter/Shift+Enter editing model |
| 10.10 | ✅ | Continuation markers |

### Kararlar

| Konu | Karar |
|------|-------|
| Block spacing | Virtual lines (buffer'da yok, sadece görsel) |
| Block indicators | Gutter icons (configurable, default: off) |
| Enter davranışı | Enter = yeni block, Shift+Enter = soft break |
| Multi-line | Sol tarafta continuation marker `│` |

### Spacing Rules

| Block Tipi | Sonrasında Virtual Lines |
|------------|-------------------------|
| paragraph | 1 |
| heading_* | 1 |
| bulleted_list_item | 0 (grouped) |
| numbered_list_item | 0 (grouped) |
| List grubu sonu | 1 |
| quote, code, divider, callout | 1 |

| Block Tipi | Öncesinde Extra |
|------------|-----------------|
| heading_1 | +1 (toplam 2) |

### Enter Behavior by Block Type

| Block Type | Enter | Empty + Enter |
|------------|-------|---------------|
| paragraph | New paragraph | New paragraph |
| bulleted_list | `- ` continuation | Exit to paragraph |
| numbered_list | `N. ` continuation | Exit to paragraph |
| heading_* | New paragraph | N/A |
| quote, code | Soft break | Exit to paragraph |

### Gutter Icons

| Block Type | Icon |
|------------|------|
| heading_1/2/3 | H1/H2/H3 |
| bulleted_list | • |
| numbered_list | # |
| quote | │ |
| code | <> |
| divider | ── |
| callout | ! |
| paragraph | (none) |

---

## Future Phases

### Phase 9.4: Link Completion `[[`

Sayfa link completion. `[[` yazınca sayfa listesi açılır.

### Phase 9.5: Mention Completion `@`

Date/page mention. `@` yazınca tarih ve sayfa seçenekleri.

### Block Type Roadmap

**Desteklenen (Editable)**:
- ✅ paragraph, heading_1/2/3, bulleted_list_item, quote, code

**Desteklenen (Read-only)**:
- ✅ divider, callout, toggle

**Tier 1 (Basit)**:
- ✅ numbered_list_item
- [ ] to_do - checkbox `[ ]`/`[x]`

**Tier 2 (Orta)**:
- [ ] callout (editable)
- [ ] toggle (editable)
- [ ] bookmark
- [ ] equation

**Tier 3 (Karmaşık)**:
- [ ] table
- [ ] column_list/column
- [ ] synced_block

**Tier 4 (Media)**:
- [ ] image, video, file, pdf, embed

**Tier 5 (Advanced)**:
- [ ] database views
- [ ] link_to_page
- [ ] table_of_contents

---

## Known Issues

### Open

- [ ] Block links (`notion://block/id`) desteklenmiyor
- [ ] Nested list items
- [ ] Extmark + `nvim_buf_set_lines` interaction issues
- [ ] Color tags not syncing to Notion (`<c:red>text</c>`)
- [ ] Live virtual line positioning for o/O (workaround: `<esc>`)

### Resolved

- [x] Multi-line content rendering bug (fixed: split newlines)
- [x] Empty line sync (fixed: Phase 10.7.1)
- [x] Shift+Enter soft break (fixed: Phase 10.9)
- [x] Code block detection (fixed: fence pattern)
- [x] Auto-continuation (fixed: Phase 10.9)
- [x] Cache sync after push (fixed: Bug 11.1)

---

## Ideas

- [ ] `:edit` ile Discard Changes - pull çağır, unsaved değişiklikleri at
- [ ] `/` Transforms: `/` → `[[`, `/` → `@`

---

## Architecture Notes

### Sync-Cache Flow

Detaylı flow: Serena memory `sync-cache-flow`

**Push Flow**:
```
Buffer → plan → execute → API → success → cache update → callback
```

**Pull Flow**:
```
API fetch → hash compare → (skip if same) → cache → render → model setup
```

**Key Pattern**:
```lua
-- Cache update after sync
if cache.is_initialized() then
  cache_pages.save_content(page_id, serialized_blocks)
  sync_state.update_after_push(page_id, content_hash)
end
```

### Test Files

| Area | Test File |
|------|-----------|
| Sync | `spec/unit/sync/init_spec.lua` |
| Cache | `spec/unit/cache/*.lua` |
| Render | `spec/unit/render/*.lua` |
| Model | `spec/unit/model/*.lua` |
| Input | `spec/unit/input/*.lua` |

---

## Serena Memories

| Memory | Content |
|--------|---------|
| project-structure | Proje yapısı |
| sync-cache-flow | Sync/cache akışları |
| phase10-gutter-icons | Gutter icons implementasyonu |
| phase-5-6-render-system-analysis | Render sistemi |
| phase3-search-and-picker | Search/picker |
| phase2-fixes-and-tests | Phase 2 notları |
