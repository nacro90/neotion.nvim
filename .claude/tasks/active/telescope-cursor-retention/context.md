# Telescope Cursor Retention - Context

## Key Files
- `lua/neotion/ui/picker.lua` - Search picker, Telescope entegrasyonu
- `lua/neotion/ui/live_search.lua` - Live search orchestrator, debounce/cancel
- `~/.local/share/nvim/lazy/telescope.nvim/lua/telescope/pickers.lua` - Telescope picker internals

## Architecture Notes

### Current Flow
```
User types query
    ↓
TextChangedI autocmd triggers
    ↓
live_search.update_query() called
    ↓
Cache results shown immediately (on_results with is_final=false)
    ↓
API search starts (debounced)
    ↓
API returns results
    ↓
merge_results() combines API + cache
    ↓
picker:refresh() called
    ↓
restore_selection() attempts to restore cursor
    ↓
BUG: Cursor jumps to first item
```

### Telescope Internals (Important!)

**Entry Manager (`entry_manager.lua:59`)**
```lua
function EntryManager:find_entry(entry)
  for container in self.linked_states:iter() do
    if container[1] == entry then  -- REFERANS EŞİTLİĞİ!
      return count
    end
  end
  return nil
end
```
- `selection_strategy = "follow"` ÇALIŞMAZ çünkü referans eşitliği kullanıyor
- Her refresh'te yeni table'lar oluşturuyoruz

**Refresh Sonrası Cursor Sıfırlama (`pickers.lua:1462-1468`)**
```lua
if self.sorting_strategy == "descending" then
  api.nvim_win_set_cursor(self.results_win, { self.max_results, 1 })
else
  api.nvim_win_set_cursor(self.results_win, { 1, 0 })  -- CURSOR İLK SATIRA!
end
self:_on_complete()
```

**Completion Callbacks (`pickers.lua:1350-1354`)**
```lua
function Picker:_on_complete()
  for _, v in ipairs(self._completion_callbacks) do
    pcall(v, self)
  end
end
```
- `_completion_callbacks` array'ine callback ekleyebiliriz
- Bu callback refresh TAMAMEN bittikten sonra çağrılır

## Dependencies
- External: `telescope.nvim` (pickers, finders, sorters, actions, action_state)
- Internal: `neotion.ui.live_search`, `neotion.api.pages`, `neotion.cache`

## Denenen Çözümler (BAŞARISIZ)

| # | Yaklaşım | Neden Başarısız |
|---|----------|-----------------|
| 1 | `selection_strategy = "follow"` | Referans eşitliği kullanıyor, yeni table'lar eşleşmiyor |
| 2 | `vim.schedule` ile restore | Telescope'un scheduled işlemlerinden önce çalışıyor |
| 3 | Nested `vim.schedule` | Yine erken çalışıyor |
| 4 | `vim.defer_fn(50)` | Log'da "restored" yazıyor ama cursor yine sıfırlanıyor |
| 5 | `vim.defer_fn` + `nvim_win_set_cursor` | Telescope'u bozdu |

## Doğru Çözüm (PLANLI)

**Telescope'un `_completion_callbacks` Kullan:**
1. Refresh öncesi `selected_id` kaydet
2. `picker._completion_callbacks` array'ine bir callback ekle
3. Callback içinde `selected_id` ile item'ı bul ve `set_selection()` çağır
4. Callback bir kere çalıştıktan sonra kendini listeden çıkarsın

Bu yaklaşım neden doğru:
- `_on_complete()` refresh'in EN SONUNDA çağrılıyor
- Cursor sıfırlama (`nvim_win_set_cursor`) bundan ÖNCE yapılıyor
- Dolayısıyla callback'imiz cursor sıfırlamadan SONRA çalışacak

## Session Notes
### Session 1 - 2026-01-16
**Analiz:**
- Root cause: Telescope refresh sonunda `nvim_win_set_cursor(results_win, {1, 0})` çağırıyor
- Tüm timing-based çözümler başarısız çünkü Telescope'un async chain'i karmaşık
- `_completion_callbacks` mekanizması keşfedildi

**Next:**
- `_completion_callbacks` yaklaşımını uygula
- Integration test yaz

