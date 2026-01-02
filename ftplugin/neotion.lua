-- Filetype-specific settings for neotion buffers

local config = require('neotion.config').get()

-- Buffer-local options
vim.bo.filetype = 'neotion'
vim.bo.buftype = ''
vim.bo.modifiable = true

-- Window-local options for conceal
vim.wo.conceallevel = config.conceal_level
vim.wo.concealcursor = 'nc'

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
