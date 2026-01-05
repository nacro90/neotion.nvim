-- Minimal init for running tests
-- Usage: nvim --headless -u spec/minimal_init.lua -c "PlenaryBustedDirectory spec/"

-- Disable loading user config
vim.opt.loadplugins = false

-- Add plugin to runtimepath
local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h')
vim.opt.rtp:prepend(plugin_root)

-- Add plenary to runtimepath - check multiple locations
local plenary_paths = {
  plugin_root .. '/.deps/plenary.nvim',
  vim.fn.stdpath('data') .. '/site/pack/vendor/start/plenary.nvim',
  vim.fn.stdpath('data') .. '/lazy/plenary.nvim',
  vim.env.HOME .. '/.local/share/nvim/lazy/plenary.nvim',
}

local plenary_path
for _, path in ipairs(plenary_paths) do
  if vim.fn.isdirectory(path) == 1 then
    vim.opt.rtp:prepend(path)
    plenary_path = path
    break
  end
end

-- Add sqlite.lua to runtimepath and package.path - check multiple locations
local sqlite_paths = {
  plugin_root .. '/.deps/sqlite.lua',
  vim.fn.stdpath('data') .. '/site/pack/vendor/start/sqlite.lua',
  vim.fn.stdpath('data') .. '/lazy/sqlite.lua',
  vim.env.HOME .. '/.local/share/nvim/lazy/sqlite.lua',
}

for _, path in ipairs(sqlite_paths) do
  if vim.fn.isdirectory(path) == 1 then
    vim.opt.rtp:prepend(path)
    -- Also add to package.path for direct require
    package.path = path .. '/lua/?.lua;' .. path .. '/lua/?/init.lua;' .. package.path
    break
  end
end

-- Disable swap files and backup
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false

-- Minimal UI settings
vim.opt.showmode = false
vim.opt.shortmess:append('I')

-- CRITICAL: Mock vim.ui.open to NEVER open browser during tests
-- This must be set before ANY module is loaded
local original_vim_ui_open = vim.ui.open
vim.ui.open = function(url)
  -- NEVER open browser - just log the URL
  vim.g._test_last_opened_url = url
  return nil -- Return nil like a failed open
end

-- Also prevent any rawset/rawget tricks from restoring original
local mt = getmetatable(vim.ui) or {}
local original_newindex = mt.__newindex
mt.__newindex = function(t, k, v)
  if k == 'open' then
    -- Silently ignore attempts to set vim.ui.open
    vim.g._test_attempted_ui_open_override = true
    return
  end
  if original_newindex then
    return original_newindex(t, k, v)
  end
  rawset(t, k, v)
end
setmetatable(vim.ui, mt)

-- Source plenary plugin to register commands
if plenary_path then
  vim.cmd('source ' .. plenary_path .. '/plugin/plenary.vim')
end
