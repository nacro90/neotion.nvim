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

-- Disable swap files and backup
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false

-- Minimal UI settings
vim.opt.showmode = false
vim.opt.shortmess:append('I')

-- Source plenary plugin to register commands
if plenary_path then
  vim.cmd('source ' .. plenary_path .. '/plugin/plenary.vim')
end
