-- neotion.nvim plugin initialization
-- This file is loaded automatically by Neovim

if vim.g.loaded_neotion then
  return
end
vim.g.loaded_neotion = true

-- Minimum version check
if vim.fn.has('nvim-0.10') ~= 1 then
  vim.notify('[neotion] Neovim 0.10+ is required', vim.log.levels.ERROR)
  return
end

---@class neotion.Subcommand
---@field impl fun(args: string[], opts: table)
---@field complete? fun(subcmd_arg_lead: string): string[]

---@type table<string, neotion.Subcommand>
local subcommand_tbl = {
  open = {
    impl = function(args, _)
      local page_id = args[1]
      if not page_id then
        vim.notify('[neotion] Usage: :Neotion open <page_id>', vim.log.levels.ERROR)
        return
      end
      require('neotion').open(page_id)
    end,
    complete = function(_)
      -- TODO: Complete with recent pages
      return {}
    end,
  },
  sync = {
    impl = function(_, _)
      require('neotion').sync()
    end,
  },
  push = {
    impl = function(_, _)
      require('neotion').push()
    end,
  },
  pull = {
    impl = function(_, _)
      require('neotion').pull()
    end,
  },
  search = {
    impl = function(_, _)
      require('neotion').search()
    end,
  },
  status = {
    impl = function(_, _)
      local status = require('neotion').status()
      if status then
        vim.notify('[neotion] Status: ' .. vim.inspect(status), vim.log.levels.INFO)
      else
        vim.notify('[neotion] Not a neotion buffer', vim.log.levels.WARN)
      end
    end,
  },
  create = {
    impl = function(args, _)
      local title = args[1]
      require('neotion').create(title)
    end,
  },
}

---@param opts table
local function neotion_cmd(opts)
  local fargs = opts.fargs
  local subcommand_key = fargs[1]

  if not subcommand_key then
    vim.notify('[neotion] Usage: :Neotion <subcommand> [args]', vim.log.levels.INFO)
    vim.notify('  Subcommands: ' .. table.concat(vim.tbl_keys(subcommand_tbl), ', '), vim.log.levels.INFO)
    return
  end

  local subcommand = subcommand_tbl[subcommand_key]
  if not subcommand then
    vim.notify('[neotion] Unknown subcommand: ' .. subcommand_key, vim.log.levels.ERROR)
    return
  end

  local args = #fargs > 1 and vim.list_slice(fargs, 2, #fargs) or {}
  subcommand.impl(args, opts)
end

vim.api.nvim_create_user_command('Neotion', neotion_cmd, {
  nargs = '*',
  desc = 'Neotion - Notion integration for Neovim',
  complete = function(arg_lead, cmdline, _)
    -- Check if completing subcommand argument
    local subcmd_key, subcmd_arg_lead = cmdline:match("^['<,'>]*Neotion[!]*%s(%S+)%s(.*)$")
    if subcmd_key and subcmd_arg_lead and subcommand_tbl[subcmd_key] and subcommand_tbl[subcmd_key].complete then
      return subcommand_tbl[subcmd_key].complete(subcmd_arg_lead)
    end

    -- Complete subcommand name
    if cmdline:match("^['<,'>]*Neotion[!]*%s+%w*$") then
      local subcommand_keys = vim.tbl_keys(subcommand_tbl)
      return vim
        .iter(subcommand_keys)
        :filter(function(key)
          return key:find(arg_lead, 1, true) == 1
        end)
        :totable()
    end

    return {}
  end,
})

-- Create <Plug> mappings (lazy loaded)
vim.keymap.set('n', '<Plug>(NeotionSync)', function()
  require('neotion').sync()
end, { desc = 'Neotion: Sync buffer' })

vim.keymap.set('n', '<Plug>(NeotionPush)', function()
  require('neotion').push()
end, { desc = 'Neotion: Push to Notion' })

vim.keymap.set('n', '<Plug>(NeotionPull)', function()
  require('neotion').pull()
end, { desc = 'Neotion: Pull from Notion' })

vim.keymap.set('n', '<Plug>(NeotionGotoParent)', function()
  require('neotion').goto_parent()
end, { desc = 'Neotion: Go to parent page' })

vim.keymap.set('n', '<Plug>(NeotionGotoLink)', function()
  require('neotion').goto_link()
end, { desc = 'Neotion: Follow link under cursor' })

vim.keymap.set('n', '<Plug>(NeotionSearch)', function()
  require('neotion').search()
end, { desc = 'Neotion: Search pages' })

vim.keymap.set('n', '<Plug>(NeotionBlockUp)', function()
  require('neotion').block_move('up')
end, { desc = 'Neotion: Move block up' })

vim.keymap.set('n', '<Plug>(NeotionBlockDown)', function()
  require('neotion').block_move('down')
end, { desc = 'Neotion: Move block down' })

vim.keymap.set('n', '<Plug>(NeotionBlockIndent)', function()
  require('neotion').block_indent()
end, { desc = 'Neotion: Indent block' })

vim.keymap.set('n', '<Plug>(NeotionBlockDedent)', function()
  require('neotion').block_dedent()
end, { desc = 'Neotion: Dedent block' })
