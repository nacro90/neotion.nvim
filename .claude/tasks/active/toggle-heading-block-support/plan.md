# Toggle Heading Block Support - Strategic Plan

## Executive Summary

Notion API'deki `is_toggleable` heading desteğini neotion.nvim'e eklemek. Heading block'lar (H1, H2, H3) toggle edilebilir hale gelebilecek. Buffer syntax: `> # Heading 1` formatı.

**Prerequisite:** `toggle-block-support` task (düz toggle için `> ` prefix)

## Current State

- **HeadingBlock** tamamen implemente: `heading_1`, `heading_2`, `heading_3`
- **Toggle block** ayrı task olarak planlandı (`toggle-block-support`)
- Factory'de `is_toggleable: false` hardcoded
- Detection'da `>` prefix toggle için reserve edilmiş

## Proposed Solution

**Option A: Extend HeadingBlock** (Seçildi)
- Ayrı block type yerine HeadingBlock'a `is_toggleable` property ekleme
- Buffer syntax: `> # `, `> ## `, `> ### ` (Notion'daki toggle heading ile tutarlı)
- Minimal code duplication, tek handler
- Type dönüşümleri kolay: `# ` ↔ `> # `

**Neden Option A?**
- Toggle heading Notion'da ayrı type değil, heading + flag
- Sync/serialize mantığı aynı, sadece property farklı
- Kod tekrarı minimum

## Buffer Syntax (Updated)

**Notion Davranışı:**
- `>` yazıp space = toggle block oluşur
- `> ## ` yazıp space = toggle heading oluşur

**Buffer Format:**
| Notion Type | is_toggleable | Buffer Format |
|-------------|---------------|---------------|
| heading_1 | false | `# Text` |
| heading_1 | true | `> # Text` |
| heading_2 | false | `## Text` |
| heading_2 | true | `> ## Text` |
| heading_3 | false | `### Text` |
| heading_3 | true | `> ### Text` |

**Önceki plan `># ` idi, güncellendi: `> # ` (space ile)**

## Implementation Phases

### Phase 1: Model Layer (Depends on toggle-block-support)
- [ ] HeadingBlock'a `is_toggleable` property ekle
- [ ] HeadingBlock'a `original_is_toggleable` property ekle
- [ ] `new()` - API'den is_toggleable parse et
- [ ] `serialize()` - is_toggleable'ı JSON'a yaz
- [ ] `format()` - `> ` prefix ekle (is_toggleable ise)
- [ ] `update_from_lines()` - `> # ` prefix'i parse et
- [ ] `type_changed()` - toggle state değişikliğini handle et

### Phase 2: Detection & Factory
- [ ] Detection'da toggle heading pattern'leri ekle (`> ### `, `> ## `, `> # `)
- [ ] Pattern order: toggle heading > regular toggle > regular heading
- [ ] Factory'de `is_toggleable` ayarlama mantığı

### Phase 3: Render & UI
- [ ] Gutter icon farklılaştırma (toggle vs regular heading)
- [ ] Expandable state visual (opsiyonel - client-only)

### Phase 4: Tests
- [ ] Unit tests: toggle heading parse/serialize
- [ ] Unit tests: type conversion (heading ↔ toggle heading)
- [ ] Integration tests (buffer edit → sync)

## Detection Pattern Order (Critical)

```lua
PREFIX_PATTERNS = {
  -- Toggle headings FIRST (must detect > # before # or > )
  { pattern = '^(> ### )', prefix = '> ### ', type = 'heading_3', toggleable = true },
  { pattern = '^(> ## )', prefix = '> ## ', type = 'heading_2', toggleable = true },
  { pattern = '^(> # )', prefix = '> # ', type = 'heading_1', toggleable = true },
  
  -- Regular toggle (after toggle headings)
  { pattern = '^(> )', prefix = '> ', type = 'toggle' },
  
  -- Regular headings
  { pattern = '^(### )', prefix = '### ', type = 'heading_3' },
  { pattern = '^(## )', prefix = '## ', type = 'heading_2' },
  { pattern = '^(# )', prefix = '# ', type = 'heading_1' },
  
  -- Quote (uses | to avoid conflict)
  { pattern = '^(| )', prefix = '| ', type = 'quote' },
}
```

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Pattern conflict (> # vs > vs #) | Medium | High | Strict pattern order: toggle heading > toggle > heading |
| Level+toggle karışıklığı | Low | Low | Clear state tracking, type_changed() logic |
| Rich text loss | Low | High | Existing round-trip preservation pattern |

## Success Metrics

- [ ] Toggle heading API'den doğru parse edilir
- [ ] Buffer'da `> # Text` doğru render edilir
- [ ] Edit sonrası serialize `is_toggleable: true` içerir
- [ ] Heading ↔ toggle heading dönüşümü çalışır
- [ ] Tüm testler geçer

## Dependencies

- **Blocked by:** `toggle-block-support` (düz toggle için `> ` prefix'i önce implement edilmeli)
- **Blocks:** None

## Notes

- Children (toggle content) ayrı blocks - parent_id ile ilişkili
- Expanded/collapsed state API'de YOK - UI only
- Bu feature sadece heading'in toggle olup olmadığını track eder

