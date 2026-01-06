# TODO

Random fikirler ve yapilacaklar.

## Phase 10: Editing Experience

Editing deneyimini iyilestirmek icin tam bir refactor planliyoruz.

### Block Management Issues

- [ ] **Block Absorption Problem**: `o` ile yeni satir acildiginda, icerik sonraki blogun icine absorbe oluyor
  - Root cause: Extmark gravity ayarlari
  - `right_gravity = true` ile fix yapildi ama `nvim_buf_set_lines` ile testler bozuldu
  - Gercek kullanici editing (InsertMode) farkli calisiyor

- [x] **Orphan Lines**: Bloklara ait olmayan satirlar icin strateji belirlenmeli
  - Yeni block olusturma ✓
  - Block type detection ✓

- [ ] **Block Type Detection**: Satir icerigi blockin beklenen tipine uymuyor
  - `# Heading` yazdim ama paragraph olarak kaydediliyor
  - Detection patterns: `detection.lua`

### New Block Creation

- [x] `o` ile yeni satir → block tipi belirlenmeli (paragraph default)
- [x] Type conversion: `- ` yazildi → bulleted_list_item'a donusum
- [x] Type conversion: `# ` yazildi → heading'e donusum
- [x] `---` → divider olusturma
- [x] Sync API: `blocks_api.append()` ile Notion'a gonderim
- [x] Positioned insert: `after_block_id` ile dogru pozisyona ekleme

### Testing Strategy

- [ ] `nvim_buf_set_lines` vs real editing farki
  - Integration testler `feedkeys` kullanabilir
  - Manual testing daha guvenilir suanlik

## Ideas

- [ ] `:edit` komutu `Neotion pull` tetiklesin - buffer resetlenirken son sync anina donmeli
- [ ] `[[` Link Completion (Phase 9.4)
- [ ] `@` Mention completion (page/date) (Phase 9.5)
- [ ] `/` Transforms: `/` → `[[`, `/` → `@`

## Known Issues

- [x] **Multi-line content rendering bug**: `buffer/init.lua:129` - `nvim_buf_set_lines` "replacement string item contains newlines" hatası veriyor
  - Multi-line block content'i render ederken oluşuyor
  - **FIX**: QuoteBlock, HeadingBlock, BulletedListBlock format() metodları newline'ları satırlara ayırıyor

- [ ] Block links (`notion://block/id`) desteklenmiyor
- [ ] Nested list items
- [ ] Auto-continuation (Enter after list item → new list item)
- [ ] Extmark + `nvim_buf_set_lines` interaction issues (testler pending)

## Future

- [ ] Toggle block support
- [ ] Table block support
- [ ] Image/file block support
- [ ] Database views
