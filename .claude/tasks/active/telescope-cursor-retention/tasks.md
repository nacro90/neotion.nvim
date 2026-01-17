# Telescope Cursor Retention - Task Checklist

**Status:** In Progress (Testing)
**Last Updated:** 2026-01-16

## Summary
Telescope live search picker'da API refresh sonrası cursor'un aynı note üzerinde kalması sağlandı. `_completion_callbacks` mekanizması kullanıldı - bu callback'ler Telescope'un refresh cycle'ı tamamlandıktan SONRA çalışıyor.

## Completed Tasks

### Phase 1: Analysis
- [x] Mevcut `restore_selection()` kodunu analiz et (2026-01-16)
- [x] Telescope `picker:refresh()` ve `set_selection()` davranışını anla (2026-01-16)
- [x] Root cause belirle (2026-01-16)
  - Telescope refresh sonunda `nvim_win_set_cursor(results_win, {1, 0})` çağırıyor
  - Bu cursor reset, `_on_complete()` öncesinde oluyor
  - `_completion_callbacks` array'i `_on_complete()` içinde iterate ediliyor

### Phase 2: Failed Attempts (Documented in context.md)
- [x] `selection_strategy = "follow"` - Reference equality sorunu
- [x] `vim.schedule` - Telescope'un scheduled işleri öncesinde çalışıyor
- [x] Double `vim.schedule` - Hala erken
- [x] `vim.defer_fn(50)` - Log başarılı ama cursor hala 1. satırda
- [x] `vim.defer_fn + nvim_win_set_cursor` - Telescope'u bozdu

### Phase 3: Solution - _completion_callbacks
- [x] `_completion_callbacks` mekanizmasını keşfet (pickers.lua:1350-1354)
- [x] One-shot callback pattern implement et
- [x] `M._find_item_row()` helper fonksiyonunu çıkar (test edilebilirlik için)
- [x] `restore_selection()` fonksiyonunu helper'ı kullanacak şekilde güncelle

### Phase 4: Testing
- [x] `_find_item_row()` unit testleri yaz (7 test)
- [x] Tüm testler geçiyor (14/14 picker, 48/48 total)
- [ ] Manual test - Kullanıcı tarafından doğrulanacak

## Changes Made
- `lua/neotion/ui/picker.lua`:
  - `M._find_item_row(items, target_id)` helper fonksiyonu eklendi
  - `restore_selection()` fonksiyonu `_completion_callbacks` kullanacak şekilde yeniden yazıldı
  - Helper fonksiyon ile kod tekrarı giderildi

- `spec/unit/ui/picker_spec.lua`:
  - 7 yeni test eklendi (`_find_item_row` describe bloğu)
  - List reorder senaryosu testi
  - Item disappearing senaryosu testi

## Key Discovery
Telescope pickers.lua satır 1462-1468:
```lua
if self.sorting_strategy == "descending" then
  api.nvim_win_set_cursor(self.results_win, { self.max_results, 1 })
else
  api.nvim_win_set_cursor(self.results_win, { 1, 0 })  -- CURSOR RESET!
end
self:_on_complete()  -- CALLBACKS RUN AFTER
```

Bu sayede `_completion_callbacks`'e eklenen fonksiyonlar cursor reset'ten SONRA çalışıyor.
