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
  local bufnr = vim.api.nvim_get_current_buf()

  local function buf_map(mode, lhs, rhs, desc)
    if lhs and lhs ~= false then
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end
  end

  buf_map('n', keymaps.sync, '<Plug>(NeotionSync)', 'Sync with Notion')
  buf_map('n', keymaps.push, '<Plug>(NeotionPush)', 'Push to Notion')
  buf_map('n', keymaps.pull, '<Plug>(NeotionPull)', 'Pull from Notion')
  buf_map('n', keymaps.goto_parent, '<Plug>(NeotionGotoParent)', 'Go to parent page')
  buf_map('n', keymaps.goto_link, '<Plug>(NeotionGotoLink)', 'Follow link')
  buf_map('n', keymaps.search, '<Plug>(NeotionSearch)', 'Search pages')

  -- Override gf to follow links in neotion buffers
  buf_map('n', 'gf', '<Plug>(NeotionGotoLink)', 'Follow link under cursor')
end

-- Setup default formatting keymaps if enabled
local function setup_default_keymaps()
  if not config.input.shortcuts.default_keymaps then
    return
  end

  local keymaps_module = require('neotion.input.keymaps')
  local bufnr = vim.api.nvim_get_current_buf()

  -- Pass the shortcuts config to respect per-format toggles
  keymaps_module.setup_buffer(bufnr, config.input.shortcuts)
end

-- Setup input system (shortcuts + triggers)
local function setup_input_system()
  local input = require('neotion.input')
  local bufnr = vim.api.nvim_get_current_buf()

  -- Pass config for shortcuts and triggers
  input.setup(bufnr, {
    shortcuts = config.input.shortcuts,
    triggers = config.input.triggers or {},
  })
end

setup_keymaps()
setup_default_keymaps()
setup_input_system()
