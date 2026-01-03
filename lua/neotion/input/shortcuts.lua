--- Input shortcuts for neotion.nvim
--- Provides operator-pending, visual, and toggle formatting shortcuts
---@module 'neotion.input.shortcuts'

local M = {}

--- Available format types
M.FORMAT_TYPES = { 'bold', 'italic', 'strikethrough', 'code', 'underline', 'color' }

--- Marker definitions for each format type
---@type table<string, {start_marker: string|fun(arg?: string): string, end_marker: string}>
local MARKERS = {
  bold = { start_marker = '**', end_marker = '**' },
  italic = { start_marker = '*', end_marker = '*' },
  strikethrough = { start_marker = '~', end_marker = '~' },
  code = { start_marker = '`', end_marker = '`' },
  underline = { start_marker = '<u>', end_marker = '</u>' },
  color = {
    start_marker = function(color)
      return '<c:' .. (color or 'default') .. '>'
    end,
    end_marker = '</c>',
  },
}

--- Get marker pair for a format type
---@param format_type string Format type name
---@param arg? string Optional argument (e.g., color name)
---@return string|nil start_marker
---@return string|nil end_marker
function M.get_marker_pair(format_type, arg)
  local marker = MARKERS[format_type]
  if not marker then
    return nil, nil
  end

  local start_marker = marker.start_marker
  if type(start_marker) == 'function' then
    start_marker = start_marker(arg)
  end

  return start_marker, marker.end_marker
end

--- Wrap text with format markers
---@param text string Text to wrap
---@param format_type string Format type
---@param arg? string Optional argument (e.g., color name)
---@return string Wrapped text
function M.wrap_text(text, format_type, arg)
  local start_marker, end_marker = M.get_marker_pair(format_type, arg)
  if not start_marker then
    return text
  end
  return start_marker .. text .. end_marker
end

--- Check if text is wrapped with format markers
---@param text string Text to check
---@param format_type string Format type
---@return boolean
function M.is_wrapped(text, format_type)
  local marker = MARKERS[format_type]
  if not marker then
    return false
  end

  -- Handle color specially (variable start marker)
  if format_type == 'color' then
    return text:match('^<c:[%w_]+>.*</c>$') ~= nil
  end

  local start_marker = marker.start_marker
  local end_marker = marker.end_marker

  -- Escape special pattern characters
  local function escape_pattern(s)
    return s:gsub('[%(%)%.%%%+%-%*%?%[%]%^%$]', '%%%1')
  end

  local start_pattern = '^' .. escape_pattern(start_marker)
  local end_pattern = escape_pattern(end_marker) .. '$'

  return text:match(start_pattern) ~= nil and text:match(end_pattern) ~= nil
end

--- Unwrap text by removing format markers
---@param text string Text to unwrap
---@param format_type string Format type
---@return string Unwrapped text
function M.unwrap_text(text, format_type)
  if not M.is_wrapped(text, format_type) then
    return text
  end

  local marker = MARKERS[format_type]
  if not marker then
    return text
  end

  -- Handle color specially
  if format_type == 'color' then
    local inner = text:match('^<c:[%w_]+>(.*)$')
    if inner then
      inner = inner:match('^(.*)</c>$')
    end
    return inner or text
  end

  local start_marker = marker.start_marker
  local end_marker = marker.end_marker

  -- Remove start marker
  local result = text:sub(#start_marker + 1)
  -- Remove end marker
  result = result:sub(1, #result - #end_marker)

  return result
end

--- Toggle format on text (wrap if unwrapped, unwrap if wrapped)
---@param text string Text to toggle
---@param format_type string Format type
---@param arg? string Optional argument (e.g., color name)
---@return string Toggled text
function M.toggle_text(text, format_type, arg)
  if M.is_wrapped(text, format_type) then
    return M.unwrap_text(text, format_type)
  else
    return M.wrap_text(text, format_type, arg)
  end
end

--- Get insert pair string (both markers concatenated)
---@param format_type string Format type
---@param arg? string Optional argument (e.g., color name)
---@return string Pair string to insert
function M.insert_pair_string(format_type, arg)
  local start_marker, end_marker = M.get_marker_pair(format_type, arg)
  if not start_marker then
    return ''
  end
  return start_marker .. end_marker
end

--- Get cursor offset within pair (where cursor should be after insertion)
---@param format_type string Format type
---@param arg? string Optional argument (e.g., color name)
---@return integer Cursor offset (number of chars from start)
function M.cursor_offset_in_pair(format_type, arg)
  local start_marker = M.get_marker_pair(format_type, arg)
  if not start_marker then
    return 0
  end
  return #start_marker
end

--- State for operator functions
---@type table<string, string>
local _opfunc_state = {}

--- Create operator function for a format type
---@param format_type string
---@param arg? string
---@return fun(motion_type: string)
local function create_opfunc(format_type, arg)
  return function(motion_type)
    if motion_type == '' then
      return
    end

    local start_pos = vim.fn.getpos("'[")
    local end_pos = vim.fn.getpos("']")

    local start_line = start_pos[2]
    local start_col = start_pos[3]
    local end_line = end_pos[2]
    local end_col = end_pos[3]

    -- Only support single-line for now
    if start_line ~= end_line then
      vim.notify('Neotion: Multi-line formatting not supported yet', vim.log.levels.WARN)
      return
    end

    local line = vim.fn.getline(start_line)
    local selected_text = line:sub(start_col, end_col)
    local new_text = M.toggle_text(selected_text, format_type, arg)

    local new_line = line:sub(1, start_col - 1) .. new_text .. line:sub(end_col + 1)
    vim.fn.setline(start_line, new_line)
  end
end

--- Set up operator-pending mode for a format type
---@param format_type string
---@param arg? string
---@return string Expression for mapping
function M.setup_operator(format_type, arg)
  _opfunc_state.format_type = format_type
  _opfunc_state.arg = arg
  vim.o.operatorfunc = "v:lua.require'neotion.input.shortcuts'._opfunc"
  return 'g@'
end

--- Global operator function (called by vim)
function M._opfunc(motion_type)
  local opfunc = create_opfunc(_opfunc_state.format_type, _opfunc_state.arg)
  opfunc(motion_type)
end

--- Apply format to visual selection
---@param format_type string
---@param arg? string
function M.visual_format(format_type, arg)
  -- Exit visual mode to set '< and '> marks
  local mode = vim.fn.mode()
  if mode == 'v' or mode == 'V' or mode == '\22' then
    vim.cmd('normal! ' .. vim.api.nvim_replace_termcodes('<Esc>', true, false, true))
  end

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local start_line = start_pos[2]
  local start_col = start_pos[3]
  local end_line = end_pos[2]
  local end_col = end_pos[3]

  -- Only support single-line for now
  if start_line ~= end_line then
    vim.notify('Neotion: Multi-line formatting not supported yet', vim.log.levels.WARN)
    return
  end

  local line = vim.fn.getline(start_line)
  local selected_text = line:sub(start_col, end_col)
  local new_text = M.toggle_text(selected_text, format_type, arg)

  local new_line = line:sub(1, start_col - 1) .. new_text .. line:sub(end_col + 1)
  vim.fn.setline(start_line, new_line)
end

--- Toggle format on word under cursor
---@param format_type string
---@param arg? string
function M.toggle_word(format_type, arg)
  local word = vim.fn.expand('<cword>')
  if word == '' then
    return
  end

  -- Find word boundaries on current line
  local line = vim.fn.getline('.')
  local col = vim.fn.col('.')
  local line_before = line:sub(1, col - 1)
  local line_after = line:sub(col)

  -- Find start of word
  local word_start = col - #(line_before:match('[%w_]*$') or '')
  -- Find end of word
  local word_end = col + #(line_after:match('^[%w_]*') or '') - 1

  local current_word = line:sub(word_start, word_end)
  local new_word = M.toggle_text(current_word, format_type, arg)

  local new_line = line:sub(1, word_start - 1) .. new_word .. line:sub(word_end + 1)
  vim.fn.setline('.', new_line)
end

--- Insert format pair and position cursor in middle (insert mode)
---@param format_type string
---@param arg? string
---@return string Keys to insert
function M.insert_pair(format_type, arg)
  local pair = M.insert_pair_string(format_type, arg)
  local offset = M.cursor_offset_in_pair(format_type, arg)
  local left_keys = string.rep('<Left>', #pair - offset)
  return pair .. vim.api.nvim_replace_termcodes(left_keys, true, false, true)
end

--- Set up all shortcuts for a buffer
--- Note: <Plug> mappings are defined globally in plugin/neotion.lua
--- This function can be extended to set up user-configured keymaps
---@param bufnr integer Buffer number
---@param opts? table Options
function M.setup(bufnr, opts)
  opts = opts or {}
  -- Currently no buffer-specific setup needed
  -- <Plug> mappings are global and defined in plugin/neotion.lua
  -- Future: could set up user-configured keymaps here based on opts
  local _ = bufnr -- silence unused warning
end

return M
