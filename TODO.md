# TODO

Random fikirler ve yapilacaklar.

## Phase 10: Editing Experience

Editing deneyimini iyilestirmek icin tam bir refactor planliyoruz.

**Latest Progress (2026-01-08)**:
- ✅ Phase 10.6: Virtual lines for block spacing (commit: 8740bbf)
- ✅ Phase 10.7: Empty paragraph spacing optimization (commit: fb499e2)
- ✅ Phase 10.7.1: Empty line sync to Notion (creates empty paragraphs)
- ⏸️ Phase 10.7.2: Live virtual line positioning for o/O (low priority)
- ⏸️ Phase 10.8: Gutter icons
- ⏸️ Phase 10.9: Enter/Shift+Enter editing model

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

## Ideas

- [ ] **`:edit` ile Discard Changes**: Normal neovim buffer'i gibi "discard unsaved changes" davranisi
  - `:edit` → aninda pull calistir
  - API'den gelen response ile buffer'i guncelle (notu yeni acmis gibi)
  - Kaydedilmemis degisiklikleri at, cache'in ilk haline don
  - UX: Kullanici buffer'da degisiklik yapti ama vazgecti → `:e` ile temize don

- [ ] **Sync Sonrasi Cache Guncellemesi**: Basarili sync sonrasi local cache eski kaliyor
  - Push/sync basarili → local cache'i de guncelle
  - Suan: API'ye gonderiyoruz ama cache hala eski content tutuyor
  - Risk: Sonraki `:edit` veya pull eski cache'den okuyor
  - Fix: Sync success callback'inde cache update cagirilmali

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

- [ ] **Shift+Enter creates new block instead of soft break**: Paragraph içinde Shift+Enter yapınca yeni block açıyor
  - Beklenen: Aynı block içinde yeni satır (multiline paragraph)
  - Gerçekleşen: Yeni paragraph block oluşturuyor
  - Phase 10.9'da fix edilecek (Enter/Shift+Enter editing model)

- [x] **Code block detected as paragraph**: Code fence içeren content paragraph olarak algılanıyor ✅ FIXED (commit: a647eea)
  - Added code fence pattern (` ``` `) to detection.lua
  - Multi-line code block handling with state machine

- [ ] Block links (`notion://block/id`) desteklenmiyor
- [ ] Nested list items
- [ ] Auto-continuation (Enter after list item → new list item)
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
