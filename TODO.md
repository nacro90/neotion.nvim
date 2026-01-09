# TODO

Random fikirler ve yapilacaklar.

## Phase 10: Editing Experience ✅ COMPLETED

Editing deneyimi refactor tamamlandi (2026-01-09).

**Completed Sub-phases**:
- ✅ Phase 10.1-10.5: Block fixes, orphan handling, type detection
- ✅ Phase 10.6: Virtual lines for block spacing (commit: 8740bbf)
- ✅ Phase 10.7: Empty paragraph spacing optimization (commit: fb499e2)
- ✅ Phase 10.7.1: Empty line sync to Notion (creates empty paragraphs)
- ⏸️ Phase 10.7.2: Live virtual line positioning for o/O (low priority, optional)
- ✅ Phase 10.8: Gutter icons (configurable, default: off) (commit: 198edb8)
- ✅ Phase 10.9: Enter/Shift+Enter editing model (commit: d1318bc)
- ✅ Phase 10.10: Continuation markers (part of Phase 10.8)

### Block Management Issues

- [ ] **Block Absorption Problem**: `o` ile yeni satir acildiginda, icerik sonraki blogun icine absorbe oluyor
  - Root cause: Extmark gravity ayarlari
  - `right_gravity = true` ile fix yapildi ama `nvim_buf_set_lines` ile testler bozuldu
  - Gercek kullanici editing (InsertMode) farkli calisiyor

- [x] **Orphan Lines**: Bloklara ait olmayan satirlar icin strateji belirlenmeli
  - Yeni block olusturma ✓
  - Block type detection ✓

- [x] **Block Type Detection**: Satir icerigi blockin beklenen tipine uymuyor
  - Bug #10.1: First non-empty line type detection ✓
  - Bug #10.2: Orphan type boundary splitting ✓

- [x] **Chained Block Creation**: Birden fazla yeni block zincirleme olusturulurken temp_id sorunu
  - Bug #10.3: Sequential create execution with temp_id resolution ✓

- [x] **New Block Model Integration**: Sync sonrasi yeni bloklar model'e eklenmiyordu
  - Bug #10.4: `mapping.add_block()` ve `rebuild_extmarks()` eklendi ✓

- [x] **Zero Blocks Orphan Detection**: Sayfa sifir block ile acildiginda icerik orphan olarak algilanmiyordu
  - Bug #10.5: `detect_orphan_lines()` sifir block durumunu handle ediyor ✓

- [x] **Batch Block Creation**: Birden fazla block olusturulurken her biri ayri API call yapiyordu
  - Perf: Zincirleme block'lar tek `append` request'inde batch olarak gonderiliyor ✓
  - 5 block = 5 request → 5 block = 1 request

### New Block Creation

- [x] `o` ile yeni satir → block tipi belirlenmeli (paragraph default)
- [x] Type conversion: `- ` yazildi → bulleted_list_item'a donusum
- [x] Type conversion: `1. ` yazildi → numbered_list_item'a donusum
- [x] Type conversion: `# ` yazildi → heading'e donusum
- [x] `---` → divider olusturma
- [x] Sync API: `blocks_api.append()` ile Notion'a gonderim
- [x] Positioned insert: `after_block_id` ile dogru pozisyona ekleme

### Testing Strategy

- [ ] `nvim_buf_set_lines` vs real editing farki
  - Integration testler `feedkeys` kullanabilir
  - Manual testing daha guvenilir suanlik

---

## Phase 11: Editing Experience Bug Fixes

Editing experience'da tespit edilen kritik buglar. **Öncelikli** olarak çözülmeli.

### Bug 11.1: Sync Sonrası Cache Güncellenmiyor (CRITICAL)

**Durum**: Sync sonrası local cache eski kalıyor, plugin'i kapatıp açınca eski cache'den okuyor.

**Senaryo**:
1. Sayfa aç → cache'den yüklenir
2. Değişiklik yap → sync et → Notion'a gider ✅
3. Plugin'i kapat/aç → **eski cache'den yüklenir** ❌
4. Background refresh → sonunda güncellenir

**Beklenen**: Sync başarılı olduktan sonra local cache de güncel olmalı.

**Root Cause Analizi**:
- Push işlemi API'ye gönderiyor ama cache güncellenmedi
- `cache.pages` sadece pull sırasında güncelleniyor
- Log'da görülen: `Page content cache hit` → eski veri

**Çözüm**:
- `sync.lua` success callback'inde cache update çağır
- Hem `pages` cache'i (content) hem `query_cache` (search list) güncellenmeli
- API response'unu cache'e yaz

**Etkilenen Dosyalar**:
- `lua/neotion/sync.lua` - success callback
- `lua/neotion/cache/pages.lua` - cache update logic
- `lua/neotion/cache/query_cache.lua` - search list invalidation

---

### Bug 11.2: Enter Orphan Line'da Soft Break Yapıyor (CRITICAL)

**Durum**: Orphan line (yeni oluşturulan, henüz sync edilmemiş satır) üzerinde `<CR>` yapınca yeni block açmıyor, sadece newline ekliyor (soft break gibi davranıyor).

**Senaryo**:
1. `test paragraph` üzerinde `o` bas → yeni satır aç (orphan)
2. `between paragraph` yaz
3. `<CR>` bas → **aynı satırda devam ediyor** ❌
4. `between paragraph 2` yaz
5. Sync et → **tek block olarak gidiyor** (2 satırlık paragraph)

**Beklenen**: `<CR>` yeni bir paragraph block başlatmalı.

**Root Cause Analizi**:
- `input/editing.lua` → `handle_enter()` block lookup yapıyor
- Orphan line için `mapping.get_block_at_line()` → `nil` dönüyor
- Block bulunamayınca fallback: `vim.api.nvim_feedkeys('\n', 'n', false)`
- Bu da soft break (Notion paragraph multi-line)

**Log'dan**:
```
[mapping] detect_orphan_lines complete | {"orphan_count":1}
[model.blocks.factory] Created new block from orphan lines | {"content_preview":"between paragraph\nbetween para"...}
```
→ İki satır tek block olarak gitti

**Çözüm**:
- Orphan line'da Enter → orphan'ı split et
- İlk kısım: mevcut orphan block olarak sync edilecek
- İkinci kısım: yeni orphan line
- Alternatif: Orphan'ı hemen sync et, sonra normal Enter davranışı

**Etkilenen Dosyalar**:
- `lua/neotion/input/editing.lua` - orphan handling
- `lua/neotion/model/mapping.lua` - orphan split helper

---

### Bug 11.3: List Item Virtual Line Pozisyon Hatası (VISUAL)

**Durum**: List item eklendiğinde virtual line (block spacing) yanlış pozisyonda kalıyor.

**Senaryo**:
1. List item'da Enter → yeni list item oluşuyor ✅
2. Notion'a sync → doğru gidiyor ✅
3. **Görsel**: Virtual line, yeni list item'ın altında değil, arasında kalıyor ❌

**Görüntü**:
```
• - test item
        ← virtual line (yanlış pozisyon)
  - asagiya indik
  - bir daha indik
```

**Beklenen**:
```
• - test item
  - asagiya indik
  - bir daha indik
        ← virtual line (list grubu sonu)
```

**Root Cause Analizi**:
- List item'lar `spacing_after() → 0` döner (grouped)
- Yeni list item eklendikten sonra `refresh()` çağrılıyor
- Ama extmark pozisyonları henüz güncellenmemiş olabilir
- Virtual line eski pozisyonda kalıyor

**Çözüm**:
- `apply_block_spacing()` → list group detection logic'i kontrol et
- Yeni block eklendikten sonra tam refresh gerekebilir
- Extmark rebuild sonrası virtual lines yeniden hesaplanmalı

**Etkilenen Dosyalar**:
- `lua/neotion/render/init.lua` - `apply_block_spacing()`
- `lua/neotion/model/mapping.lua` - `rebuild_extmarks()`

---

### Implementation Order

| Bug | Priority | Complexity | Description |
|-----|----------|------------|-------------|
| 11.1 | CRITICAL | Medium | Cache sync - data loss riski |
| 11.2 | CRITICAL | Medium | Enter behavior - UX broken |
| 11.3 | HIGH | Low | Virtual line visual glitch |

**Önerilen Sıra**: 11.1 → 11.2 → 11.3

---

## Ideas

- [ ] **`:edit` ile Discard Changes**: Normal neovim buffer'i gibi "discard unsaved changes" davranisi
  - `:edit` → aninda pull calistir
  - API'den gelen response ile buffer'i guncelle (notu yeni acmis gibi)
  - Kaydedilmemis degisiklikleri at, cache'in ilk haline don
  - UX: Kullanici buffer'da degisiklik yapti ama vazgecti → `:e` ile temize don

- [ ] `[[` Link Completion (Phase 9.4)
- [ ] `@` Mention completion (page/date) (Phase 9.5)
- [ ] `/` Transforms: `/` → `[[`, `/` → `@`

## Known Issues

- [x] **Multi-line content rendering bug**: `buffer/init.lua:129` - `nvim_buf_set_lines` "replacement string item contains newlines" hatası veriyor
  - Multi-line block content'i render ederken oluşuyor
  - **FIX**: QuoteBlock, HeadingBlock, BulletedListBlock format() metodları newline'ları satırlara ayırıyor

- [x] **Empty line doesn't sync to Notion**: `o` → boş satır → `<esc>` → sync → "No changes to sync" ✅ FIXED
  - Root cause: Boş orphan line `segment_count=0` → block oluşturulmaz
  - Fixed: `create_from_lines()` now creates empty paragraph for all-empty lines
  - Fixed: `split_orphan_by_type_boundaries()` creates paragraph segment for all-empty orphans
  - Creates: Empty paragraph `{ type: "paragraph", paragraph: { rich_text: [] } }` to Notion
  - Phase 10.7.1 completed

- [ ] **Live virtual line positioning for o/O**: `o`/`O` ile insert mode'a girince virtual line cursor'un yanlış tarafında
  - Workaround: `<esc>` basınca düzeliyor ✅
  - Priority: LOW (Phase 10.7.2 veya Phase 10.9'da düzelecek)

- [x] **Shift+Enter creates new block instead of soft break**: ✅ FIXED (Phase 10.9)
  - Shift+Enter now does soft break (same block, newline)
  - Enter behavior is block-type aware (list continues, quote/code soft break)

- [x] **Code block detected as paragraph**: Code fence içeren content paragraph olarak algılanıyor ✅ FIXED (commit: a647eea)
  - Added code fence pattern (` ``` `) to detection.lua
  - Multi-line code block handling with state machine

- [ ] Block links (`notion://block/id`) desteklenmiyor
- [ ] Nested list items
- [x] Auto-continuation (Enter after list item → new list item) ✅ FIXED (Phase 10.9)
- [ ] Extmark + `nvim_buf_set_lines` interaction issues (testler pending)
- [ ] **Color tags not syncing to Notion**: `<c:red>text</c>` buffer formatı Notion'a gönderilirken rich_text color annotation'a dönüştürülmüyor
  - Buffer → Notion serialize işlemi color tag'leri parse etmeli
  - `format/notion.lua` veya `model/rich_text.lua` içinde fix gerekebilir

## Block Type Support Roadmap

Basitten karmasiga dogru block tipi destegi:

### Desteklenen (Editable)
- [x] paragraph
- [x] heading_1, heading_2, heading_3
- [x] bulleted_list_item
- [x] quote
- [x] code

### Desteklenen (Read-only)
- [x] divider
- [x] callout
- [x] toggle (icerik gizli)

### Tier 1: Basit Text-based
- [x] **numbered_list_item** - bulleted_list_item ile neredeyse ayni, `1. ` prefix ✓
- [ ] **to_do** - checkbox, `[ ]` / `[x]` prefix + checked state

### Tier 2: Orta Karmasiklik
- [ ] **callout** (editable) - icon + color + text, simdilik read-only
- [ ] **toggle** (editable) - children block'lari goster/gizle
- [ ] **bookmark** - URL + title + description
- [ ] **equation** - LaTeX math, KaTeX rendering

### Tier 3: Karmasik
- [ ] **table** - satir/sutun, table_row children
- [ ] **column_list** / **column** - yan yana layout
- [ ] **synced_block** - baska sayfadan referans

### Tier 4: Media & Embeds
- [ ] **image** - URL veya uploaded
- [ ] **video** - embed URL
- [ ] **file** / **pdf** - attachment
- [ ] **embed** - external content (iframe)

### Tier 5: Advanced
- [ ] **database** views (inline/full page)
- [ ] **link_to_page** - sayfa referansi
- [ ] **table_of_contents**
- [ ] **breadcrumb**
