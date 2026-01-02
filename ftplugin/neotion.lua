-- Filetype-specific settings for neotion buffers

local config = require('neotion.config').get()

-- Buffer-local options
-- Note: buftype and modifiable are set by buffer/init.lua when creating the buffer
-- Don't override them here as they're intentionally set to 'acwrite' and false

-- Window-local options for conceal
-- Use vim.api with explicit window ID to avoid affecting wrong window
local win = vim.api.nvim_get_current_win()
vim.api.nvim_set_option_value('conceallevel', config.conceal_level, { win = win })
vim.api.nvim_set_option_value('concealcursor', 'nc', { win = win })

-- Setup buffer-local keymaps if configured
local function setup_keymaps()
  local keymaps = config.keymaps

  local function buf_map(lhs, rhs, desc)
    if lhs and lhs ~= false then
      vim.keymap.set('n', lhs, rhs, { buffer = true, desc = desc })
    end
  end

  buf_map(keymaps.sync, '<Plug>(NeotionSync)', 'Sync with Notion')
  buf_map(keymaps.push, '<Plug>(NeotionPush)', 'Push to Notion')
  buf_map(keymaps.pull, '<Plug>(NeotionPull)', 'Pull from Notion')
  buf_map(keymaps.goto_parent, '<Plug>(NeotionGotoParent)', 'Go to parent page')
  buf_map(keymaps.goto_link, '<Plug>(NeotionGotoLink)', 'Follow link')
  buf_map(keymaps.search, '<Plug>(NeotionSearch)', 'Search pages')
end

setup_keymaps()
