# Telescope Cursor Retention - Strategic Plan

## Executive Summary
Search picker'da API sonuçları geldiğinde cursor pozisyonu kayboluyor. Kullanıcı bir note üzerindeyken, refresh sonrası cursor ilk item'a atlıyor. Bu UX açısından can sıkıcı.

## Current State
- `picker.lua` içinde `restore_selection()` fonksiyonu var
- `selected_id` kaydedilip, refresh sonrası aynı ID'li item'a `set_selection()` yapılıyor
- `vim.defer_fn(..., 10)` ile timing yapılıyor
- Çalışmıyor - cursor hala ilk item'a atlıyor

## Pain Points
1. **Race condition**: `picker:refresh()` asenkron çalışıyor, `10ms` yeterli değil
2. **Item order değişiyor**: `merge_results()` API sonuçlarını öne koyuyor
3. **Telescope internal state**: refresh sonrası kendi selection logic'ini çalıştırıyor

## Proposed Solution
Telescope'un `picker:refresh()` sonrası selection logic'ini bypass edip, kendi restore mekanizmamızı güçlendirmek:

1. `vim.defer_fn` yerine `vim.schedule` + retry mekanizması
2. Picker refresh completion'ı beklemek için `manager:num_results()` kontrolü
3. Selection restore'u garantilemek için daha robust approach

## Implementation Phases

### Phase 1: Analysis & Test Setup
- [x] Mevcut kodu analiz et
- [ ] Failing test yaz (TDD)
- [ ] Telescope internals'ı daha iyi anla

### Phase 2: Fix Implementation
- [ ] `restore_selection()` fonksiyonunu güçlendir
- [ ] Timing mekanizmasını iyileştir
- [ ] Edge case'leri handle et (item listeden çıkarsa, etc.)

### Phase 3: Testing & Polish
- [ ] Unit test'leri geçir
- [ ] Manual test
- [ ] TODO comment'i kaldır

## Risks & Mitigations
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Telescope API değişikliği | Low | High | Version check |
| Timing hala tutmayabilir | Medium | Medium | Retry mekanizması |
| Performance overhead | Low | Low | Profiling |

## Success Metrics
- [ ] Cursor aynı note üzerinde kalıyor (refresh sonrası)
- [ ] Smooth UX - flicker yok
- [ ] Test coverage

## Timeline
- Estimated effort: S (Small)
- Started: 2026-01-16
