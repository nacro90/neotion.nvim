# Live Search Fixes Plan

## Issues (Priority Order)

### 1. Telescope State Not Cleared After Page Open ✅ FIXED
**Problem:** Sayfa açıldıktan sonra tekrar `:Neotion search` açıldığında önceki sonuçlar kalıyor.

**Root Cause:** `live_search` state'i destroy edilmiyor veya Telescope picker kapatılırken state temizlenmiyor.

**Solution Applied:**
- `live_search.lua` - `destroy()` fonksiyonunda tüm state alanları explicit olarak temizleniyor
- `picker.lua` - `select_default:replace` içinde `destroy()` çağrısı eklendi (belt and suspenders)
- `actions.close:enhance` hala mevcut (ESC ile kapatma için)

**Files:** `lua/neotion/ui/picker.lua`, `lua/neotion/ui/live_search.lua`

**Tests Added:** `spec/unit/ui/live_search_spec.lua`
- `'should clear all state fields before removal'`
- `'should be safe to call destroy multiple times'`

---

### 2. `:Neotion search {text}` Input Not Populated ✅ FIXED
**Problem:** `:Neotion search test` dediğinde arama yapılıyor ama Telescope input'unda "test" görünmüyor.

**Root Cause:** Telescope'a `default_text` parametresi geçilmiyor.

**Solution Applied:**
- `picker.lua` - `pickers.new()` ilk argümanına `{ default_text = initial_query or '' }` eklendi
- `last_prompt` initial_query ile initialize ediliyor (duplicate search trigger önleniyor)
- Hem `search_telescope_live()` hem `search_telescope()` güncellendi

**Files:** `lua/neotion/ui/picker.lua`

---

### 3. API Results Deduplication Missing ✅ FIXED (Round 2)
**Problem:** API'den gelen sonuçlar mevcut listeye append ediliyor, duplicate'ler oluşuyor.

**Initial Investigation:** Deduplication kodu doğru görünüyordu ama çalışmıyordu.

**Root Cause Found (via logs):**
```
API search complete | {"merged_count":8,"api_count":4}
```
4 API + 4 cached = 8 olmamalıydı, çünkü aynı sayfalar!

**Actual Bug:** ID format mismatch!
- API returns: `"2027b4fb-fc3e-80bc-a956-df97681d756a"` (dashed)
- Cache stores: `"2027b4fbfc3e80bca956df97681d756a"` (no dashes)
- `merge_results()` bunları farklı sayfalar olarak görüyordu!

**Solution Applied:**
- `live_search.lua:api_page_to_item()` - ID normalize edildi (dashes removed)
- Test eklendi: `'should normalize dashed IDs to match cache format'`

**Files:** `lua/neotion/ui/live_search.lua`

---

### 4. Page Content Cache Intermittently Empty ✅ FIXED
**Problem:** Sayfa cache'den açılıyor ama Neovim kapatıp açınca bazen "Loading..." gösteriyor, bazen cache'den açıyor. Intermittent davranış.

**User Scenario:**
1. Open page A → cache works
2. Open page B → cache works
3. Open page A again → cache works
4. Close Neovim, reopen
5. Open page A → cache works
6. Exit and re-enter page A → shows "Loading..." (BUG!)

**Root Cause Found (via schema analysis):**
```sql
-- page_content table has FK with CASCADE:
FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE
```

`save_page()` kullanıyordu:
```sql
INSERT OR REPLACE INTO pages ...
```

**Problem:** SQLite'da `INSERT OR REPLACE` = DELETE + INSERT. Bu CASCADE trigger ediyor!

**Bug Flow:**
1. `bg_refresh_page()` çağrılıyor (arka planda)
2. `save_page()` çalışıyor → `INSERT OR REPLACE` → pages row DELETE edilip yeniden INSERT
3. CASCADE: `page_content` row da SİLİNİYOR!
4. Content hash unchanged → `save_content()` skip ediliyor
5. `page_content` boş kalıyor → sonraki cache lookup fail

**Solution Applied:**
- `INSERT OR REPLACE` → `INSERT ... ON CONFLICT ... DO UPDATE` (true UPSERT)
- Bu pattern DELETE trigger ETMİYOR, sadece UPDATE yapıyor
- 3 fonksiyon düzeltildi: `save_page()`, `save_content()`, `save_pages_batch()`

**Files:** `lua/neotion/cache/pages.lua`

**SQL Change:**
```sql
-- BEFORE (BROKEN):
INSERT OR REPLACE INTO pages (...) VALUES (...)

-- AFTER (FIXED):
INSERT INTO pages (...) VALUES (...)
ON CONFLICT(id) DO UPDATE SET
  title = excluded.title,
  icon = excluded.icon,
  ...
```

---

### 5. Telescope Selection Reset on API Response ✅ FIXED (Round 2)
**Problem:** API response geldiğinde Telescope'daki seçili row sıfırlanıyor (ilk item'a atlıyor).

**Root Cause:** `picker:refresh()` çağrıldığında Telescope selection'ı resetliyor.

**Initial Fix (Failed):** `vim.schedule()` ile selection restore - timing güvenilir değildi.

**Solution Applied (Round 2):**
- `picker.lua` - Selection restore logic eklendi:
  1. Refresh öncesi `action_state.get_selected_entry()` ile mevcut seçimi al
  2. Refresh sonrası aynı ID'li item'ı bul
  3. `picker:set_selection()` ile selection'ı restore et
  4. `vim.defer_fn(fn, 10)` ile 10ms delay - refresh tamamlanmasını bekle

**Key Fix:** `vim.schedule` yerine `vim.defer_fn` kullanıldı - Telescope refresh'in tamamlanması için minimum delay gerekli.

**Files:** `lua/neotion/ui/picker.lua`

---

### 6. State Cleanup Using BufWipeout ✅ FIXED
**Problem:** `actions.close:enhance` global action'ı modify ediyordu, her picker açılışında yeni hook ekleniyor ve birikiyor.

**Root Cause:** Telescope'un `actions.close:enhance` fonksiyonu global `actions.close`'u modifiye ediyor.

**Solution Applied:**
- `actions.close:enhance` → `{ 'BufDelete', 'BufWipeout' }` autocmd
- `BufDelete` daha erken fire ediyor - yeni picker açılmadan önce cleanup
- Buffer-local cleanup, global hook birikimi yok
- `once = true` ile tek seferlik çalışma garantisi

**Files:** `lua/neotion/ui/picker.lua`

---

### 7. Old API Response Updating New Picker ✅ FIXED (Round 2)
**Problem:** Telescope kapatıp yeniden açıldığında eski arama sonuçları görünüyordu (input boş olmasına rağmen).

**User Scenario:**
1. Search "karadeniz" → results arrive
2. Close Telescope
3. Open Telescope again (empty input)
4. "karadeniz" results shown! (BUG)

**Root Cause:**
- Slow API response for old query arrives AFTER new picker opens
- Callback closure captures instance_id but doesn't validate if instance still exists
- Old response updates new picker with stale results

**Solution Applied:**
- `picker.lua` - Instance validation in `on_results` callback:
  ```lua
  if not live_search.get_state(instance_id) then
    log.debug('Ignoring results for destroyed instance', { instance_id = instance_id })
    return
  end
  ```
- Destroy called BEFORE close ensures state is nil before new picker can open
- Same pattern applied to `on_error` callback

**Key Insight:** Async callbacks must validate their instance is still active before updating UI.

**Files:** `lua/neotion/ui/picker.lua`

**Tests Added:** `spec/unit/ui/live_search_spec.lua`
- `'should not call callbacks after instance is destroyed'`
- `'should allow new instance with same callbacks after destroy'`
- `'should not share state between instances'`
- `'should destroy only the specified instance'`

---

## Implementation Order ✅ COMPLETED

1. [x] Issue #1 - State cleanup (destroy fonksiyonu)
2. [x] Issue #2 - default_text
3. [x] Issue #3 - Deduplication (ID normalization)
4. [x] Issue #4 - Page content cache CASCADE DELETE bug
5. [x] Issue #5 - Telescope selection reset on refresh (vim.defer_fn)
6. [x] Issue #6 - BufWipeout for state cleanup (replaces enhance)
7. [x] Issue #7 - Instance validation in callbacks (old response → new picker)

## Testing

Eklenen testler:
- `spec/unit/ui/live_search_spec.lua`:
  - `'should clear all state fields before removal'`
  - `'should be safe to call destroy multiple times'`
  - `'should normalize dashed IDs to match cache format'`
  - `'should not call callbacks after instance is destroyed'`
  - `'should allow new instance with same callbacks after destroy'`
  - `'should not share state between instances'`
  - `'should destroy only the specified instance'`

## Lessons Learned

- SQLite `INSERT OR REPLACE` = DELETE + INSERT → CASCADE tetikler!
- True UPSERT için `INSERT ... ON CONFLICT ... DO UPDATE` kullan
- Intermittent bug'lar genellikle race condition veya timing-dependent (bu durumda bg_refresh timing'i)
- `vim.schedule` vs `vim.defer_fn`: Schedule hemen sonraki event loop, defer_fn belirli ms sonra - Telescope refresh için defer_fn gerekli
- Async callback'ler closure ile yakalanan state'i kullanmadan önce hala geçerli olduğunu validate etmeli
- `BufDelete` vs `BufWipeout`: BufDelete daha erken fire ediyor, cleanup timing kritik olduğunda BufDelete kullan
- Telescope `action_state` global state tutuyor - yeni picker açıldığında eski picker'ın değerleri dönebilir (race condition)
- `TextChanged` autocmd içinde `vim.schedule` kullanarak Telescope'un tam initialize olmasını beklemek gerekir

---

### 8. TextChanged Returns Stale Query from Old Picker ✅ FIXED
**Problem:** Picker kapatılıp yeniden açıldığında, input boş olmasına rağmen eski query'nin sonuçları gösteriliyor.

**User Scenario:**
1. Search "karadeniz" → results arrive (3 items)
2. Close Telescope
3. Open Telescope again (empty input)
4. "karadeniz" results shown! (BUG) - should show empty query results (100 items)

**Root Cause:**
- `TextChanged` autocmd fire olduğunda `action_state.get_current_line()` eski picker'ın prompt değerini dönüyor
- Telescope'un global state'i henüz yeni picker için güncellenmemiş
- Race condition: yeni picker açılıyor ama Telescope internal state henüz sync olmamış

**Solution Applied:**
- `picker.lua` - TextChanged callback'i `vim.schedule()` ile sarmalandı
- `vim.schedule` bir event loop sonrasına erteler - bu sırada Telescope tam initialize olur
- Ek instance ve picker validity check'leri eklendi

**Key Code Change:**
```lua
vim.api.nvim_create_autocmd({ 'TextChangedI', 'TextChanged' }, {
  buffer = prompt_bufnr,
  callback = function()
    -- CRITICAL: Use vim.schedule to defer reading prompt value
    -- This ensures Telescope's global state is fully updated
    vim.schedule(function()
      -- Verify picker and instance are still valid
      if not picker or not picker.prompt_bufnr or not vim.api.nvim_buf_is_valid(picker.prompt_bufnr) then
        return
      end
      if not live_search.get_state(instance_id) then
        return
      end

      local current_prompt = action_state.get_current_line()
      if current_prompt ~= last_prompt then
        last_prompt = current_prompt
        live_search.update_query(instance_id, current_prompt)
      end
    end)
  end,
})
```

**Files:** `lua/neotion/ui/picker.lua`

**Tests Added:** `spec/unit/ui/live_search_spec.lua`
- `'should start new instance with empty query after destroying old instance'`
- `'should not leak query between rapidly created instances'`
- `'should handle update_query with stale query gracefully'`
