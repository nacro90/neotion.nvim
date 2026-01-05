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
      -- Complete with recent pages
      local buffer = require('neotion.buffer')
      local recent = buffer.get_recent()
      local completions = {}
      for _, item in ipairs(recent) do
        table.insert(completions, item.page_id)
      end
      return completions
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
    impl = function(args, _)
      -- Join all args as query string
      local query = nil
      if #args > 0 then
        query = table.concat(args, ' ')
      end
      require('neotion').search(query)
    end,
  },
  recent = {
    impl = function(_, _)
      require('neotion').recent()
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
  log = {
    impl = function(args, _)
      local log = require('neotion.log')
      local subcmd = args[1] or 'show'

      if subcmd == 'show' or subcmd == 'tail' then
        local n = tonumber(args[2]) or 100
        local lines = log.tail(n)
        if #lines == 0 then
          vim.notify('[neotion] Log is empty', vim.log.levels.INFO)
          return
        end

        -- Open in scratch buffer
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
        vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
        vim.api.nvim_buf_set_option(buf, 'filetype', 'log')
        vim.api.nvim_buf_set_name(buf, 'neotion://log')

        -- Open in split
        vim.cmd('split')
        vim.api.nvim_win_set_buf(0, buf)
        -- Go to end
        vim.cmd('normal! G')
      elseif subcmd == 'clear' then
        log.clear()
        vim.notify('[neotion] Log cleared', vim.log.levels.INFO)
      elseif subcmd == 'path' then
        local path = log.get_log_path()
        vim.notify('[neotion] Log path: ' .. path, vim.log.levels.INFO)
      elseif subcmd == 'level' then
        local new_level = args[2]
        if new_level then
          log.set_level(new_level)
          vim.notify('[neotion] Log level set to: ' .. new_level, vim.log.levels.INFO)
        else
          local current = log.get_level()
          local names = { 'DEBUG', 'INFO', 'WARN', 'ERROR', 'OFF' }
          vim.notify('[neotion] Current log level: ' .. (names[current] or 'UNKNOWN'), vim.log.levels.INFO)
        end
      else
        vim.notify('[neotion] Usage: :Neotion log [show|tail|clear|path|level]', vim.log.levels.INFO)
      end
    end,
    complete = function(subcmd_arg_lead)
      local subcmds = { 'show', 'tail', 'clear', 'path', 'level' }
      return vim
        .iter(subcmds)
        :filter(function(s)
          return s:find(subcmd_arg_lead, 1, true) == 1
        end)
        :totable()
    end,
  },
  -- Formatting subcommands (Phase 5.5)
  bold = {
    impl = function(_, opts)
      local formatting = require('neotion.commands.formatting')
      formatting.subcommands.bold(opts)
    end,
  },
  italic = {
    impl = function(_, opts)
      local formatting = require('neotion.commands.formatting')
      formatting.subcommands.italic(opts)
    end,
  },
  strikethrough = {
    impl = function(_, opts)
      local formatting = require('neotion.commands.formatting')
      formatting.subcommands.strikethrough(opts)
    end,
  },
  code = {
    impl = function(_, opts)
      local formatting = require('neotion.commands.formatting')
      formatting.subcommands.code(opts)
    end,
  },
  underline = {
    impl = function(_, opts)
      local formatting = require('neotion.commands.formatting')
      formatting.subcommands.underline(opts)
    end,
  },
  color = {
    impl = function(args, opts)
      local formatting = require('neotion.commands.formatting')
      -- Pass the full fargs including 'color' so handler can extract color name
      opts.fargs = vim.list_extend({ 'color' }, args)
      formatting.subcommands.color(opts)
    end,
    complete = function(subcmd_arg_lead)
      local formatting = require('neotion.commands.formatting')
      return vim
        .iter(formatting.color_names)
        :filter(function(s)
          return s:find(subcmd_arg_lead, 1, true) == 1
        end)
        :totable()
    end,
  },
  unformat = {
    impl = function(_, opts)
      local formatting = require('neotion.commands.formatting')
      formatting.subcommands.unformat(opts)
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

-- Formatting <Plug> mappings (Phase 5.5)
-- Note: Buffer-local mappings are set up by input.setup() when a neotion buffer is opened
-- These global mappings provide a fallback and documentation

-- Bold
vim.keymap.set('n', '<Plug>(NeotionBold)', function()
  return require('neotion.input.shortcuts').setup_operator('bold')
end, { expr = true, desc = 'Neotion: Bold (operator)' })

vim.keymap.set('n', '<Plug>(NeotionBoldToggle)', function()
  require('neotion.input.shortcuts').toggle_word('bold')
end, { desc = 'Neotion: Toggle bold on word' })

vim.keymap.set('x', '<Plug>(NeotionBold)', function()
  require('neotion.input.shortcuts').visual_format('bold')
end, { desc = 'Neotion: Bold (visual)' })

vim.keymap.set('i', '<Plug>(NeotionBoldPair)', function()
  return require('neotion.input.shortcuts').insert_pair('bold')
end, { expr = true, desc = 'Neotion: Insert bold pair' })

-- Italic
vim.keymap.set('n', '<Plug>(NeotionItalic)', function()
  return require('neotion.input.shortcuts').setup_operator('italic')
end, { expr = true, desc = 'Neotion: Italic (operator)' })

vim.keymap.set('n', '<Plug>(NeotionItalicToggle)', function()
  require('neotion.input.shortcuts').toggle_word('italic')
end, { desc = 'Neotion: Toggle italic on word' })

vim.keymap.set('x', '<Plug>(NeotionItalic)', function()
  require('neotion.input.shortcuts').visual_format('italic')
end, { desc = 'Neotion: Italic (visual)' })

vim.keymap.set('i', '<Plug>(NeotionItalicPair)', function()
  return require('neotion.input.shortcuts').insert_pair('italic')
end, { expr = true, desc = 'Neotion: Insert italic pair' })

-- Strikethrough
vim.keymap.set('n', '<Plug>(NeotionStrikethrough)', function()
  return require('neotion.input.shortcuts').setup_operator('strikethrough')
end, { expr = true, desc = 'Neotion: Strikethrough (operator)' })

vim.keymap.set('n', '<Plug>(NeotionStrikethroughToggle)', function()
  require('neotion.input.shortcuts').toggle_word('strikethrough')
end, { desc = 'Neotion: Toggle strikethrough on word' })

vim.keymap.set('x', '<Plug>(NeotionStrikethrough)', function()
  require('neotion.input.shortcuts').visual_format('strikethrough')
end, { desc = 'Neotion: Strikethrough (visual)' })

vim.keymap.set('i', '<Plug>(NeotionStrikethroughPair)', function()
  return require('neotion.input.shortcuts').insert_pair('strikethrough')
end, { expr = true, desc = 'Neotion: Insert strikethrough pair' })

-- Code
vim.keymap.set('n', '<Plug>(NeotionCode)', function()
  return require('neotion.input.shortcuts').setup_operator('code')
end, { expr = true, desc = 'Neotion: Code (operator)' })

vim.keymap.set('n', '<Plug>(NeotionCodeToggle)', function()
  require('neotion.input.shortcuts').toggle_word('code')
end, { desc = 'Neotion: Toggle code on word' })

vim.keymap.set('x', '<Plug>(NeotionCode)', function()
  require('neotion.input.shortcuts').visual_format('code')
end, { desc = 'Neotion: Code (visual)' })

vim.keymap.set('i', '<Plug>(NeotionCodePair)', function()
  return require('neotion.input.shortcuts').insert_pair('code')
end, { expr = true, desc = 'Neotion: Insert code pair' })

-- Underline
vim.keymap.set('n', '<Plug>(NeotionUnderline)', function()
  return require('neotion.input.shortcuts').setup_operator('underline')
end, { expr = true, desc = 'Neotion: Underline (operator)' })

vim.keymap.set('n', '<Plug>(NeotionUnderlineToggle)', function()
  require('neotion.input.shortcuts').toggle_word('underline')
end, { desc = 'Neotion: Toggle underline on word' })

vim.keymap.set('x', '<Plug>(NeotionUnderline)', function()
  require('neotion.input.shortcuts').visual_format('underline')
end, { desc = 'Neotion: Underline (visual)' })

vim.keymap.set('i', '<Plug>(NeotionUnderlinePair)', function()
  return require('neotion.input.shortcuts').insert_pair('underline')
end, { expr = true, desc = 'Neotion: Insert underline pair' })

-- Color (requires async color picker, then operator)
vim.keymap.set('n', '<Plug>(NeotionColor)', function()
  vim.ui.select(
    { 'red', 'blue', 'green', 'yellow', 'orange', 'pink', 'purple', 'brown', 'gray' },
    { prompt = 'Select color:' },
    function(color)
      if color then
        local shortcuts = require('neotion.input.shortcuts')
        shortcuts.setup_operator('color', color)
        vim.api.nvim_feedkeys('g@', 'n', false)
      end
    end
  )
end, { desc = 'Neotion: Color (operator)' })

vim.keymap.set('n', '<Plug>(NeotionColorToggle)', function()
  vim.ui.select(
    { 'red', 'blue', 'green', 'yellow', 'orange', 'pink', 'purple', 'brown', 'gray' },
    { prompt = 'Select color:' },
    function(color)
      if color then
        require('neotion.input.shortcuts').toggle_word('color', color)
      end
    end
  )
end, { desc = 'Neotion: Toggle color on word' })

vim.keymap.set('x', '<Plug>(NeotionColor)', function()
  vim.ui.select(
    { 'red', 'blue', 'green', 'yellow', 'orange', 'pink', 'purple', 'brown', 'gray' },
    { prompt = 'Select color:' },
    function(color)
      if color then
        require('neotion.input.shortcuts').visual_format('color', color)
      end
    end
  )
end, { desc = 'Neotion: Color (visual)' })

-- Autocmds for neotion buffers

-- Define highlight groups for read-only blocks
vim.api.nvim_set_hl(0, 'NeotionReadOnly', { bg = '#2a2a2a', italic = true, default = true })

-- Handle :w command for neotion buffers
vim.api.nvim_create_autocmd('BufWriteCmd', {
  pattern = 'neotion://*',
  callback = function(args)
    local buffer = require('neotion.buffer')
    local status = buffer.get_status(args.buf)

    -- Don't allow push during loading or syncing state
    if status == 'loading' then
      vim.notify('[neotion] Page is still loading', vim.log.levels.WARN)
      return
    elseif status == 'syncing' then
      vim.notify('[neotion] Sync already in progress', vim.log.levels.WARN)
      return
    end

    local sync = require('neotion.sync')
    sync.push(args.buf)
  end,
  desc = 'Neotion: Push changes to Notion',
})

-- Track buffer modifications
vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
  pattern = 'neotion://*',
  callback = function(args)
    local bufnr = args.buf
    local buffer = require('neotion.buffer')
    local model = require('neotion.model')

    -- Skip if buffer is in loading or syncing state
    local status = buffer.get_status(bufnr)
    if status == 'loading' or status == 'syncing' then
      return
    end

    -- Only track if buffer has blocks
    if not model.has_blocks(bufnr) then
      return
    end

    -- Refresh line ranges from extmarks
    local mapping = require('neotion.model.mapping')
    mapping.refresh_line_ranges(bufnr)

    -- Check for dirty blocks
    model.sync_blocks_from_buffer(bufnr)
    local dirty = model.get_dirty_blocks(bufnr)

    -- Update buffer status if modified
    if #dirty > 0 then
      local current_status = buffer.get_status(bufnr)
      if current_status == 'ready' then
        buffer.set_status(bufnr, 'modified')
      end
    end
  end,
  desc = 'Neotion: Track buffer modifications',
})

-- Protect read-only blocks and header from editing
vim.api.nvim_create_autocmd('InsertEnter', {
  pattern = 'neotion://*',
  callback = function(args)
    local bufnr = args.buf
    local buffer = require('neotion.buffer')
    local model = require('neotion.model')

    -- Get buffer data to check header line count
    local data = buffer.get_data(bufnr)
    local header_line_count = data and data.header_line_count or 0

    -- Check cursor position
    local line = vim.api.nvim_win_get_cursor(0)[1]

    -- Check if cursor is in header area (protected)
    if line <= header_line_count then
      -- Use vim.schedule to ensure stopinsert works correctly
      vim.schedule(function()
        vim.cmd('stopinsert')
        vim.notify('[neotion] Header is read-only', vim.log.levels.WARN)
      end)
      return
    end

    -- Check if cursor is on a read-only block
    local block = model.get_block_at_line(bufnr, line)

    if block and not block:is_editable() then
      -- Use vim.schedule to ensure stopinsert works correctly
      vim.schedule(function()
        vim.cmd('stopinsert')
        vim.notify('[neotion] This block is read-only (' .. block:get_type() .. ')', vim.log.levels.WARN)
      end)
      return
    end

    -- If no block found and not in header, this is an untracked line (edge case)
    if not block and line > header_line_count then
      vim.schedule(function()
        vim.cmd('stopinsert')
        vim.notify('[neotion] Cannot edit this line', vim.log.levels.WARN)
      end)
      return
    end
  end,
  desc = 'Neotion: Protect read-only blocks and header',
})

-- Additional protection: Prevent character insertion on read-only lines
vim.api.nvim_create_autocmd('InsertCharPre', {
  pattern = 'neotion://*',
  callback = function(args)
    local bufnr = args.buf
    local buffer = require('neotion.buffer')
    local model = require('neotion.model')

    -- Get buffer data
    local data = buffer.get_data(bufnr)
    local header_line_count = data and data.header_line_count or 0

    -- Check cursor position
    local line = vim.api.nvim_win_get_cursor(0)[1]

    -- Check if in protected area
    local is_protected = false

    if line <= header_line_count then
      is_protected = true
    else
      local block = model.get_block_at_line(bufnr, line)
      if not block or not block:is_editable() then
        is_protected = true
      end
    end

    -- Clear the character to prevent insertion
    if is_protected then
      vim.v.char = ''
    end
  end,
  desc = 'Neotion: Prevent edits on read-only lines',
})

-- Clean up model data when buffer is deleted
vim.api.nvim_create_autocmd('BufDelete', {
  pattern = 'neotion://*',
  callback = function(args)
    local model = require('neotion.model')
    model.clear(args.buf)
  end,
  desc = 'Neotion: Clean up model data',
})
