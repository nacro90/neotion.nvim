-- TODO(neotion:FEAT-13.8:MEDIUM): Toggle checkbox in database view with <CR>
-- When cursor is on a checkbox column in database view, pressing <CR> should:
-- - Detect current cell is a checkbox property
-- - Toggle the value (true <-> false)
-- - Update via API and refresh display
-- - Show visual feedback on toggle

-- TODO(neotion:FEAT-13.9:MEDIUM): Date picker UI component
-- Create a reusable date picker popup for date property editing:
-- - Calendar view with month/year navigation
-- - Keyboard navigation (hjkl, arrows)
-- - Support date-only and date+time modes
-- - Quick keys: t=today, w=next week, m=next month
-- - ISO format output for Notion API

-- TODO(neotion:FEAT-13.10:MEDIUM): Edit date property in database view with <CR>
-- When cursor is on a date column in database view, pressing <CR> should:
-- - Open the date picker popup (FEAT-13.9)
-- - Pre-fill with current value if exists
-- - Update via API on selection
-- - Support clearing date with <Del> or backspace

-- TODO(neotion:FEAT-13.11:MEDIUM): Edit select/multi-select property in database view with <CR>
-- When cursor is on a select or multi-select column in database view, pressing <CR> should:
-- - Open a picker popup with available options from schema
-- - For select: single choice, closes on selection
-- - For multi-select: toggle multiple options, confirm with <CR>
-- - Show current selection highlighted
-- - Support search/filter within options
-- - Update via API on confirmation

-- TODO(neotion:FEAT-13.6:LOW): Database row editing support
-- Phase 13.6: Enable inline editing of database properties:
-- - Edit text/title properties inline
-- - Select/multi-select: popup picker for options
-- - Checkbox: toggle with keybind
-- - Date: date picker popup or inline parsing
-- - Number: inline edit with validation
-- - Create new row with <leader>n
-- - Delete row with <leader>d (confirm prompt)

--- Notion-faithful editing behavior for neotion.nvim
--- Provides Enter/Shift+Enter handling with block-aware behavior
---@module 'neotion.input.editing'

local M = {}

-- Constants for indent handling (used across multiple functions)
local INDENT_SIZE = 2
local MAX_INDENT_LEVEL = 3 -- Max 3 levels of nesting (6 spaces)

---@class neotion.EditingOpts
---@field enabled? boolean Enable editing keymaps (default: true)

---@type table<integer, boolean>
local attached_buffers = {}

---Detect indent level from line content
---@param line string Line content
---@return integer Indent level (0-based)
local function detect_indent_level(line)
  if not line or line == '' then
    return 0
  end
  local leading_spaces = 0
  for i = 1, #line do
    if line:sub(i, i) == ' ' then
      leading_spaces = leading_spaces + 1
    else
      break
    end
  end
  return math.floor(leading_spaces / INDENT_SIZE)
end

---Calculate child indent string respecting max depth
---@param parent_line string Parent line content
---@return string Indent string for child
local function get_child_indent(parent_line)
  local parent_level = detect_indent_level(parent_line)
  local child_level = math.min(parent_level + 1, MAX_INDENT_LEVEL)
  return string.rep(' ', child_level * INDENT_SIZE)
end

---Get the current block at cursor position
---@param bufnr integer
---@return neotion.Block|nil
local function get_current_block(bufnr)
  local mapping = require('neotion.model.mapping')
  local line = vim.api.nvim_win_get_cursor(0)[1]
  return mapping.get_block_at_line(bufnr, line)
end

---Get current line content
---@return string
local function get_current_line()
  local line = vim.api.nvim_get_current_line()
  return line or ''
end

---Get cursor column (0-indexed)
---@return integer
local function get_cursor_col()
  return vim.api.nvim_win_get_cursor(0)[2]
end

---Check if cursor is at line end
---In insert mode (real usage), cursor can be at #line (after last char)
---In normal mode (testing), cursor max is #line - 1 (on last char)
---Both cases should be treated as "at line end" for Enter handling
---@return boolean
local function is_at_line_end()
  local col = get_cursor_col()
  local line = get_current_line()
  -- Handle both insert mode (col == #line) and normal mode (col == #line - 1)
  -- Empty line: #line == 0, col == 0 -> true
  -- Normal mode on last char: col == #line - 1 -> true
  -- Insert mode after last char: col == #line -> true
  return #line == 0 or col >= #line - 1
end

---Get the prefix for list continuation
---@param block_type string
---@param line_content string
---@return string|nil prefix The prefix to use for new line
local function get_list_prefix(block_type, line_content)
  if block_type == 'bulleted_list_item' then
    -- Match existing bullet style: -, *, or +
    local bullet = line_content:match('^%s*([%-%*%+])%s')
    return bullet and (bullet .. ' ') or '- '
  elseif block_type == 'numbered_list_item' then
    -- Extract number and increment
    local num = line_content:match('^%s*(%d+)%.')
    if num then
      return tostring(tonumber(num) + 1) .. '. '
    end
    return '1. '
  end
  return nil
end

---Check if a list item line is empty (only has prefix)
---@param block_type string
---@param line_content string
---@return boolean
local function is_empty_list_item(block_type, line_content)
  if block_type == 'bulleted_list_item' then
    -- Check if line is just bullet prefix with optional whitespace
    return line_content:match('^%s*[%-%*%+]%s*$') ~= nil
  elseif block_type == 'numbered_list_item' then
    -- Check if line is just number prefix with optional whitespace
    return line_content:match('^%s*%d+%.%s*$') ~= nil
  end
  return false
end

---Check if a line is a numbered list item
---@param line_content string
---@return boolean
local function is_numbered_list_line(line_content)
  return line_content:match('^%s*%d+%.%s') ~= nil
end

---Get the number from a numbered list line
---@param line_content string
---@return integer|nil
local function get_list_number(line_content)
  local num = line_content:match('^%s*(%d+)%.')
  return num and tonumber(num) or nil
end

---Find the start of a numbered list sequence containing the given line
---@param bufnr integer
---@param line integer 1-indexed line number
---@return integer start_line 1-indexed start of the list sequence
local function find_list_start(bufnr, line)
  local start_line = line
  while start_line > 1 do
    local prev_content = vim.api.nvim_buf_get_lines(bufnr, start_line - 2, start_line - 1, false)[1]
    if not prev_content or not is_numbered_list_line(prev_content) then
      break
    end
    start_line = start_line - 1
  end
  return start_line
end

---Renumber a contiguous numbered list sequence starting from given line
---@param bufnr integer
---@param start_line integer 1-indexed line to start renumbering from
local function renumber_list_from_line(bufnr, start_line)
  local total_lines = vim.api.nvim_buf_line_count(bufnr)

  -- Find the actual start of this list sequence
  local list_start = find_list_start(bufnr, start_line)

  -- Get the starting number (usually 1, but could continue from previous)
  local expected_num = 1

  -- Renumber all consecutive numbered list items
  local current_line = list_start
  while current_line <= total_lines do
    local content = vim.api.nvim_buf_get_lines(bufnr, current_line - 1, current_line, false)[1]
    if not content or not is_numbered_list_line(content) then
      break
    end

    -- Replace number with expected number
    local new_content = content:gsub('^(%s*)%d+(%.%s)', '%1' .. expected_num .. '%2')
    if new_content ~= content then
      vim.api.nvim_buf_set_lines(bufnr, current_line - 1, current_line, false, { new_content })
    end

    expected_num = expected_num + 1
    current_line = current_line + 1
  end
end

---Detect block type from line content (for orphan lines)
---@param line_content string
---@return string|nil block_type Detected block type or nil
local function detect_block_type_from_content(line_content)
  if line_content:match('^%s*[%-%*%+]%s') then
    return 'bulleted_list_item'
  elseif line_content:match('^%s*%d+%.%s') then
    return 'numbered_list_item'
  elseif line_content:match('^> ') then
    return 'toggle'
  end
  return nil
end

---Split orphan line at cursor position (Bug 11.2 fix)
---Creates two separate lines instead of soft break
---@param bufnr integer
local function split_orphan_at_cursor(bufnr)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local col = cursor[2]
  local content = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ''

  local before = content:sub(1, col)
  local after = content:sub(col + 1)

  -- Replace current line and insert new line
  vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { before, after })
  -- Move cursor to start of new line
  vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
end

---Handle Enter key in insert mode
---Block-aware behavior based on current block type
---@param bufnr integer
function M.handle_enter(bufnr)
  local block = get_current_block(bufnr)
  local line_content = get_current_line()

  -- Determine block type: from block or from line content (orphan)
  local block_type
  if block then
    block_type = block:get_type()
  else
    -- Orphan line: detect type from content
    block_type = detect_block_type_from_content(line_content)
    if not block_type then
      -- Not a recognized type: split orphan line at cursor (Bug 11.2)
      split_orphan_at_cursor(bufnr)
      return
    end
  end

  -- List items: continue or exit
  if block_type == 'bulleted_list_item' or block_type == 'numbered_list_item' then
    if is_empty_list_item(block_type, line_content) then
      -- Empty list item: convert to paragraph (remove prefix)
      vim.api.nvim_set_current_line('')
      -- Stay in insert mode at beginning of line
      vim.api.nvim_win_set_cursor(0, { vim.api.nvim_win_get_cursor(0)[1], 0 })
      -- Renumber list after removing item
      if block_type == 'numbered_list_item' then
        renumber_list_from_line(bufnr, vim.api.nvim_win_get_cursor(0)[1])
      end
    else
      -- Non-empty: create new list item
      local prefix = get_list_prefix(block_type, line_content)
      local col = get_cursor_col()
      local row = vim.api.nvim_win_get_cursor(0)[1]

      if is_at_line_end() then
        -- At end: insert new line with prefix after current line
        vim.api.nvim_buf_set_lines(bufnr, row, row, false, { prefix or '' })
        vim.api.nvim_win_set_cursor(0, { row + 1, #(prefix or '') })
      else
        -- Mid-line: split and add prefix to new line
        local before = line_content:sub(1, col)
        local after = line_content:sub(col + 1)

        vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { before, (prefix or '') .. after })
        vim.api.nvim_win_set_cursor(0, { row + 1, #(prefix or '') })
      end
      -- Renumber list after adding new item
      if block_type == 'numbered_list_item' then
        renumber_list_from_line(bufnr, row)
      end
    end
    return
  end

  -- Quote and Code: soft break (stay in same block)
  if block_type == 'quote' or block_type == 'code' then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<CR>', true, false, true), 'n', false)
    return
  end

  -- Toggle: create indented child block (respecting max depth)
  if block_type == 'toggle' then
    local col = get_cursor_col()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local indent = get_child_indent(line_content)

    if is_at_line_end() then
      -- At end: insert indented empty line
      vim.api.nvim_buf_set_lines(bufnr, row, row, false, { indent })
      vim.api.nvim_win_set_cursor(0, { row + 1, #indent })
    else
      -- Mid-line: split and move remainder to indented child
      local before = line_content:sub(1, col)
      local after = line_content:sub(col + 1)

      vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { before, indent .. after })
      vim.api.nvim_win_set_cursor(0, { row + 1, #indent })
    end
    return
  end

  -- Paragraph, Heading, and others: standard newline
  -- The sync layer will interpret this as new block
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<CR>', true, false, true), 'n', false)
end

---Handle Shift+Enter in insert mode
---Always creates a soft break (newline within same block)
---@param _bufnr integer
function M.handle_shift_enter(_bufnr)
  -- Simple newline without any block-aware logic
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<CR>', true, false, true), 'n', false)
end

---Handle 'o' in normal mode (open line below)
---If on a list item, prefixes new line with list marker
---@param bufnr integer
function M.handle_o(bufnr)
  local block = get_current_block(bufnr)
  local line_content = get_current_line()

  -- Determine block type
  local block_type
  if block then
    block_type = block:get_type()
  else
    block_type = detect_block_type_from_content(line_content)
  end

  -- List items: add prefix to new line
  if block_type == 'bulleted_list_item' or block_type == 'numbered_list_item' then
    local prefix = get_list_prefix(block_type, line_content)
    if prefix then
      local row = vim.api.nvim_win_get_cursor(0)[1]
      vim.api.nvim_buf_set_lines(bufnr, row, row, false, { prefix })
      vim.api.nvim_win_set_cursor(0, { row + 1, #prefix })
      -- Renumber list after adding new item
      if block_type == 'numbered_list_item' then
        renumber_list_from_line(bufnr, row)
      end
      -- Schedule startinsert to ensure it runs after all buffer modifications
      vim.schedule(function()
        vim.cmd('startinsert!')
      end)
      return
    end
  end

  -- Toggle: create indented child line below (respecting max depth)
  if block_type == 'toggle' then
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local indent = get_child_indent(line_content)
    vim.api.nvim_buf_set_lines(bufnr, row, row, false, { indent })
    vim.api.nvim_win_set_cursor(0, { row + 1, #indent })
    vim.schedule(function()
      vim.cmd('startinsert!')
    end)
    return
  end

  -- Default: standard 'o' behavior
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('o', true, false, true), 'n', false)
end

---Handle 'O' in normal mode (open line above)
---If on a list item, prefixes new line with list marker
---@param bufnr integer
function M.handle_O(bufnr)
  local block = get_current_block(bufnr)
  local line_content = get_current_line()

  -- Determine block type
  local block_type
  if block then
    block_type = block:get_type()
  else
    block_type = detect_block_type_from_content(line_content)
  end

  -- List items: add prefix to new line above
  if block_type == 'bulleted_list_item' or block_type == 'numbered_list_item' then
    local prefix = get_list_prefix(block_type, line_content)
    if prefix then
      local row = vim.api.nvim_win_get_cursor(0)[1]
      vim.api.nvim_buf_set_lines(bufnr, row - 1, row - 1, false, { prefix })
      vim.api.nvim_win_set_cursor(0, { row, #prefix })
      -- Renumber list after adding new item above
      if block_type == 'numbered_list_item' then
        renumber_list_from_line(bufnr, row - 1)
      end
      -- Schedule startinsert to ensure it runs after all buffer modifications
      vim.schedule(function()
        vim.cmd('startinsert!')
      end)
      return
    end
  end

  -- Default: standard 'O' behavior
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('O', true, false, true), 'n', false)
end

---Handle Tab key - indent current line (become child of previous sibling)
---@param bufnr integer
function M.handle_tab(bufnr)
  local line_content = get_current_line()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local col = get_cursor_col()

  -- Calculate current indent level
  local leading_spaces = 0
  for i = 1, #line_content do
    if line_content:sub(i, i) == ' ' then
      leading_spaces = leading_spaces + 1
    else
      break
    end
  end
  local current_level = math.floor(leading_spaces / INDENT_SIZE)

  -- Don't indent beyond max depth
  if current_level >= MAX_INDENT_LEVEL then
    return
  end

  -- Add indent
  local indent = string.rep(' ', INDENT_SIZE)
  local new_line = indent .. line_content
  vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { new_line })

  -- Adjust cursor position
  vim.api.nvim_win_set_cursor(0, { row, col + INDENT_SIZE })
end

---Handle Shift+Tab key - dedent current line (become sibling of parent)
---@param bufnr integer
function M.handle_shift_tab(bufnr)
  local line_content = get_current_line()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local col = get_cursor_col()

  -- Calculate current indent level
  local leading_spaces = 0
  for i = 1, #line_content do
    if line_content:sub(i, i) == ' ' then
      leading_spaces = leading_spaces + 1
    else
      break
    end
  end

  -- Can't dedent if not indented
  if leading_spaces == 0 then
    return
  end

  -- Remove one level of indent (or remaining spaces if less than INDENT_SIZE)
  local spaces_to_remove = math.min(INDENT_SIZE, leading_spaces)
  local new_line = line_content:sub(spaces_to_remove + 1)
  vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { new_line })

  -- Adjust cursor position (clamp to 0 if cursor was in removed indent area)
  local new_col = math.max(0, col - spaces_to_remove)
  vim.api.nvim_win_set_cursor(0, { row, new_col })
end

---Check if buffer has editing attached
---@param bufnr integer
---@return boolean
function M.is_attached(bufnr)
  return attached_buffers[bufnr] == true
end

---Setup editing keymaps for a buffer
---@param bufnr integer
---@param opts? neotion.EditingOpts
function M.setup(bufnr, opts)
  opts = opts or {}

  -- Check if already attached
  if M.is_attached(bufnr) then
    return
  end

  -- Check if enabled (default: true)
  if opts.enabled == false then
    return
  end

  -- Insert mode: Enter -> block-aware new block/line
  vim.keymap.set('i', '<CR>', function()
    M.handle_enter(bufnr)
  end, {
    buffer = bufnr,
    desc = 'Neotion: Block-aware Enter',
  })

  -- Insert mode: Shift+Enter -> soft break (same block)
  vim.keymap.set('i', '<S-CR>', function()
    M.handle_shift_enter(bufnr)
  end, {
    buffer = bufnr,
    desc = 'Neotion: Soft break (same block)',
  })

  -- Normal mode: o -> open line below with list prefix
  vim.keymap.set('n', 'o', function()
    M.handle_o(bufnr)
  end, {
    buffer = bufnr,
    desc = 'Neotion: Open line below (list-aware)',
  })

  -- Normal mode: O -> open line above with list prefix
  vim.keymap.set('n', 'O', function()
    M.handle_O(bufnr)
  end, {
    buffer = bufnr,
    desc = 'Neotion: Open line above (list-aware)',
  })

  -- Normal mode: Tab -> indent line (become child)
  vim.keymap.set('n', '<Tab>', function()
    M.handle_tab(bufnr)
  end, {
    buffer = bufnr,
    desc = 'Neotion: Indent line (become child)',
  })

  -- Normal mode: Shift+Tab -> dedent line (become sibling)
  vim.keymap.set('n', '<S-Tab>', function()
    M.handle_shift_tab(bufnr)
  end, {
    buffer = bufnr,
    desc = 'Neotion: Dedent line (become sibling)',
  })

  attached_buffers[bufnr] = true

  -- Clean up on buffer delete
  vim.api.nvim_create_autocmd('BufDelete', {
    buffer = bufnr,
    callback = function()
      attached_buffers[bufnr] = nil
    end,
    once = true,
  })
end

---Detach editing from a buffer
---@param bufnr integer
function M.detach(bufnr)
  if not M.is_attached(bufnr) then
    return
  end

  -- Remove keymaps
  pcall(vim.keymap.del, 'i', '<CR>', { buffer = bufnr })
  pcall(vim.keymap.del, 'i', '<S-CR>', { buffer = bufnr })
  pcall(vim.keymap.del, 'n', 'o', { buffer = bufnr })
  pcall(vim.keymap.del, 'n', 'O', { buffer = bufnr })
  pcall(vim.keymap.del, 'n', '<Tab>', { buffer = bufnr })
  pcall(vim.keymap.del, 'n', '<S-Tab>', { buffer = bufnr })

  attached_buffers[bufnr] = nil
end

return M
