---
name: neovim-extmarks
description: Neovim extmark API kullanımı. Virtual text, highlighting, concealing, position tracking.
---

# Neovim Extmarks Skill

## Namespace Oluşturma
```lua
local ns = vim.api.nvim_create_namespace("neotion")
```

## Temel Extmark İşlemleri

### Oluşturma
```lua
local id = vim.api.nvim_buf_set_extmark(buf, ns, line, col, {
  -- Pozisyon ve range
  end_line = end_line,        -- Multi-line için
  end_col = end_col,
  
  -- Virtual text
  virt_text = {{"text", "HighlightGroup"}},
  virt_text_pos = "eol",      -- "eol", "overlay", "right_align", "inline"
  virt_text_win_col = nil,    -- Sabit kolon pozisyonu
  virt_text_hide = false,     -- 'conceallevel' ile gizle
  
  -- Highlighting
  hl_group = "HighlightGroup",
  hl_eol = false,             -- Satır sonuna kadar highlight
  hl_mode = "combine",        -- "replace", "combine", "blend"
  
  -- Concealing
  conceal = "",               -- Concealed text (tek karakter veya boş)
  
  -- Sign column
  sign_text = ">>",
  sign_hl_group = "SignHl",
  
  -- Line options
  line_hl_group = "LineHl",   -- Tüm satır highlight
  number_hl_group = "NumHl",  -- Satır numarası highlight
  cursorline_hl_group = "CursorLineHl",
  
  -- Behavior
  priority = 100,             -- Overlap durumunda öncelik
  strict = true,              -- Geçersiz pozisyonda hata ver
  
  -- Persistence
  undo_restore = true,        -- Undo/redo'da koru
  invalidate = false,         -- Düzenleme ile sil
  
  -- Virtual lines
  virt_lines = {
    {{"line1", "Hl1"}},
    {{"line2", "Hl2"}},
  },
  virt_lines_above = false,
  virt_lines_leftcol = false,
})
```

### Okuma
```lua
-- Tek extmark
local mark = vim.api.nvim_buf_get_extmark_by_id(buf, ns, id, {
  details = true,  -- Tüm options'ları döndür
})
-- Returns: {line, col, details_table} veya {}

-- Range'deki tüm extmark'lar
local marks = vim.api.nvim_buf_get_extmarks(buf, ns, start, end_, {
  details = true,
  overlap = true,  -- Range ile overlap eden tümü
  type = "highlight", -- Sadece bu tip
})
-- Returns: {{id, line, col, details}, ...}
```

### Silme
```lua
-- Tek extmark
vim.api.nvim_buf_del_extmark(buf, ns, id)

-- Namespace'teki tümü
vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
```

## Use Cases

### 1. Sync Status Indicator (EOL)
```lua
local function set_sync_status(buf, line, status)
  local icons = {
    synced = {"✓", "NeotionSynced"},
    modified = {"●", "NeotionModified"},
    syncing = {"↻", "NeotionSyncing"},
    error = {"⚠", "NeotionError"},
  }
  
  local icon = icons[status]
  vim.api.nvim_buf_set_extmark(buf, ns, line, 0, {
    virt_text = {icon},
    virt_text_pos = "eol",
    id = line + 1000000,  -- Stable ID for updates
  })
end
```

### 2. Block ID Concealing
```lua
local function conceal_block_marker(buf, line, marker_text)
  -- "╔ paragraph:abc123" -> gizle
  local col_start = 0
  local col_end = #marker_text
  
  vim.api.nvim_buf_set_extmark(buf, ns, line, col_start, {
    end_col = col_end,
    conceal = "",
  })
end
```

### 3. Color Highlighting
```lua
local function highlight_colored_text(buf, line, col_start, col_end, color)
  local hl_groups = {
    red = "NeotionRed",
    blue = "NeotionBlue",
    red_background = "NeotionRedBg",
  }
  
  vim.api.nvim_buf_set_extmark(buf, ns, line, col_start, {
    end_col = col_end,
    hl_group = hl_groups[color] or "Normal",
  })
end
```

### 4. Toggle Block Fold Indicator
```lua
local function set_toggle_indicator(buf, line, is_open)
  local icon = is_open and "▼" or "▶"
  
  vim.api.nvim_buf_set_extmark(buf, ns, line, 0, {
    virt_text = {{icon, "NeotionToggle"}},
    virt_text_pos = "overlay",
    id = line + 2000000,
  })
end
```

### 5. Breadcrumb (Virtual Line Above)
```lua
local function show_breadcrumb(buf, path)
  -- path = {"Workspace", "Projects", "neotion.nvim"}
  local parts = {}
  for i, p in ipairs(path) do
    table.insert(parts, {p, "NeotionBreadcrumb"})
    if i < #path then
      table.insert(parts, {" > ", "NeotionBreadcrumbSep"})
    end
  end
  
  vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
    virt_lines = {parts},
    virt_lines_above = true,
    id = 1,  -- Tek breadcrumb
  })
end
```

## Block ID ↔ Extmark Mapping
```lua
-- Buffer-local mapping table
local function get_mappings(buf)
  vim.b[buf].neotion_block_map = vim.b[buf].neotion_block_map or {}
  return vim.b[buf].neotion_block_map
end

local function register_block(buf, block_id, extmark_id)
  local map = get_mappings(buf)
  map[block_id] = extmark_id
end

local function get_block_position(buf, block_id)
  local map = get_mappings(buf)
  local extmark_id = map[block_id]
  if not extmark_id then return nil end
  
  local mark = vim.api.nvim_buf_get_extmark_by_id(buf, ns, extmark_id, {})
  if #mark == 0 then return nil end
  
  return {line = mark[1], col = mark[2]}
end

local function get_block_at_line(buf, line)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, {line, 0}, {line, -1}, {
    details = true,
  })
  
  for _, mark in ipairs(marks) do
    local id = mark[1]
    -- Reverse lookup
    for block_id, extmark_id in pairs(get_mappings(buf)) do
      if extmark_id == id then
        return block_id
      end
    end
  end
  
  return nil
end
```

## Highlight Groups Tanımlama
```lua
local function setup_highlights()
  local highlights = {
    NeotionSynced = {fg = "#98c379"},
    NeotionModified = {fg = "#e5c07b"},
    NeotionSyncing = {fg = "#61afef"},
    NeotionError = {fg = "#e06c75"},
    NeotionRed = {fg = "#e06c75"},
    NeotionBlue = {fg = "#61afef"},
    NeotionRedBg = {bg = "#e06c75", fg = "#282c34"},
    NeotionToggle = {fg = "#c678dd"},
    NeotionBreadcrumb = {fg = "#abb2bf", italic = true},
    NeotionBreadcrumbSep = {fg = "#5c6370"},
  }
  
  for name, opts in pairs(highlights) do
    vim.api.nvim_set_hl(0, name, opts)
  end
end
```

## Buffer Attach ile Değişiklik Takibi
```lua
vim.api.nvim_buf_attach(buf, false, {
  on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline)
    -- Extmark'lar otomatik güncellenir
    -- Ama mapping tablosunu kontrol et
    vim.schedule(function()
      validate_mappings(buf)
    end)
  end,
  on_reload = function(_, buf)
    -- Buffer reload oldu, extmark'lar kayboldu
    -- Frontmatter'dan rebuild et
    rebuild_extmarks_from_frontmatter(buf)
  end,
  on_detach = function(_, buf)
    -- Cleanup
    vim.b[buf].neotion_block_map = nil
  end,
})
```

## Performance Tips

1. **Batch operations** - Çok extmark eklerken `nvim_buf_set_extmark` yerine tek seferde
2. **Stable IDs kullan** - Update için silip yeniden oluşturma yerine aynı ID
3. **Namespace temizliği** - Gereksiz extmark'ları sil
4. **Priority yönetimi** - Overlap'lerde doğru sıralama
5. **Lazy rendering** - Sadece görünür satırlar için extmark oluştur (büyük dosyalar)
