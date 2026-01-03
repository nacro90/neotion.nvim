--- Formatting commands for neotion.nvim
--- Provides :Neotion bold/italic/color commands
---@module 'neotion.commands.formatting'

local M = {}

--- Valid color names for :Neotion color command
M.color_names = {
  'red',
  'blue',
  'green',
  'yellow',
  'orange',
  'pink',
  'purple',
  'brown',
  'gray',
  'red_background',
  'blue_background',
  'green_background',
  'yellow_background',
  'orange_background',
  'pink_background',
  'purple_background',
  'brown_background',
  'gray_background',
}

--- Apply format to visual selection or word under cursor
---@param format_type string
---@param arg? string
local function apply_format(format_type, arg)
  local shortcuts = require('neotion.input.shortcuts')
  local mode = vim.fn.mode()

  if mode == 'v' or mode == 'V' or mode == '\22' then
    -- Visual mode: apply to selection
    shortcuts.visual_format(format_type, arg)
  else
    -- Normal mode: toggle word under cursor
    shortcuts.toggle_word(format_type, arg)
  end
end

--- Remove all formatting markers from text
---@param text string
---@return string
local function remove_all_markers(text)
  local result = text

  -- Remove bold markers
  result = result:gsub('%*%*(.-)%*%*', '%1')
  -- Remove italic markers (careful not to match bold)
  result = result:gsub('%*([^*]+)%*', '%1')
  -- Remove strikethrough
  result = result:gsub('~(.-)~', '%1')
  -- Remove code
  result = result:gsub('`(.-)`', '%1')
  -- Remove underline
  result = result:gsub('<u>(.-)</u>', '%1')
  -- Remove color
  result = result:gsub('<c:[%w_]+>(.-)</c>', '%1')
  -- Remove links (keep visible text)
  result = result:gsub('%[(.-)%]%([^%)]+%)', '%1')

  return result
end

--- Subcommands table
M.subcommands = {}

--- :Neotion bold
---@param _ table Command options (unused)
function M.subcommands.bold(_)
  apply_format('bold')
end

--- :Neotion italic
---@param _ table Command options (unused)
function M.subcommands.italic(_)
  apply_format('italic')
end

--- :Neotion strikethrough
---@param _ table Command options (unused)
function M.subcommands.strikethrough(_)
  apply_format('strikethrough')
end

--- :Neotion code
---@param _ table Command options (unused)
function M.subcommands.code(_)
  apply_format('code')
end

--- :Neotion underline
---@param _ table Command options (unused)
function M.subcommands.underline(_)
  apply_format('underline')
end

--- :Neotion color <color>
---@param opts table Command options
function M.subcommands.color(opts)
  local args = opts.fargs or {}
  local color = args[2] -- First arg is 'color', second is the color name

  if not color then
    -- Prompt for color
    vim.ui.select(M.color_names, { prompt = 'Select color:' }, function(selected)
      if selected then
        apply_format('color', selected)
      end
    end)
    return
  end

  if not vim.tbl_contains(M.color_names, color) then
    vim.notify(
      'Invalid color: ' .. color .. '. Valid colors: ' .. table.concat(M.color_names, ', '),
      vim.log.levels.ERROR
    )
    return
  end

  apply_format('color', color)
end

--- :Neotion unformat - remove all formatting from selection/word
---@param _ table Command options (unused)
function M.subcommands.unformat(_)
  local mode = vim.fn.mode()

  if mode == 'v' or mode == 'V' or mode == '\22' then
    -- Visual mode: remove from selection
    vim.cmd('normal! ' .. vim.api.nvim_replace_termcodes('<Esc>', true, false, true))

    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local start_line = start_pos[2]
    local start_col = start_pos[3]
    local end_line = end_pos[2]
    local end_col = end_pos[3]

    if start_line ~= end_line then
      vim.notify('Neotion: Multi-line unformat not supported yet', vim.log.levels.WARN)
      return
    end

    local line = vim.fn.getline(start_line)
    local selected_text = line:sub(start_col, end_col)
    local new_text = remove_all_markers(selected_text)
    local new_line = line:sub(1, start_col - 1) .. new_text .. line:sub(end_col + 1)
    vim.fn.setline(start_line, new_line)
  else
    -- Normal mode: remove from word under cursor
    local word = vim.fn.expand('<cword>')
    if word == '' then
      return
    end

    local line = vim.fn.getline('.')
    local col = vim.fn.col('.')
    local line_before = line:sub(1, col - 1)
    local line_after = line:sub(col)

    local word_start = col - #(line_before:match('[%w_*~`<>/:%-]+$') or '')
    local word_end = col + #(line_after:match('^[%w_*~`<>/:%-]+') or '') - 1

    local current_word = line:sub(word_start, word_end)
    local new_word = remove_all_markers(current_word)
    local new_line = line:sub(1, word_start - 1) .. new_word .. line:sub(word_end + 1)
    vim.fn.setline('.', new_line)
  end
end

--- Get list of available subcommand names
---@return string[]
function M.get_subcommand_names()
  local names = {}
  for name, _ in pairs(M.subcommands) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

--- Handle formatting subcommand
---@param opts table Command options from nvim_create_user_command
---@return boolean True if handled
function M.handle(opts)
  local args = opts.fargs or {}
  local subcommand = args[1]

  if not subcommand then
    return false
  end

  local handler = M.subcommands[subcommand]
  if handler then
    handler(opts)
    return true
  end

  return false
end

--- Get completion for formatting commands
---@param arglead string Current argument being typed
---@param cmdline string Full command line
---@param cursorpos integer Cursor position
---@return string[] Completions
function M.complete(arglead, cmdline, cursorpos)
  local args = vim.split(cmdline, '%s+')

  -- If completing the first argument (format type)
  if #args <= 2 then
    return vim.tbl_filter(function(name)
      return name:find(arglead, 1, true) == 1
    end, M.get_subcommand_names())
  end

  -- If completing color argument
  if args[2] == 'color' and #args <= 3 then
    return vim.tbl_filter(function(color)
      return color:find(arglead, 1, true) == 1
    end, M.color_names)
  end

  return {}
end

return M
