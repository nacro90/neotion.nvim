--- Notion-faithful editing behavior for neotion.nvim
--- Provides Enter/Shift+Enter handling with block-aware behavior
---@module 'neotion.input.editing'

local M = {}

---@class neotion.EditingOpts
---@field enabled? boolean Enable editing keymaps (default: true)

---@type table<integer, boolean>
local attached_buffers = {}

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
---@return boolean
local function is_at_line_end()
  local col = get_cursor_col()
  local line = get_current_line()
  return col >= #line
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

---Detect list type from line content (for orphan lines)
---@param line_content string
---@return string|nil block_type Detected block type or nil
local function detect_list_type_from_content(line_content)
  if line_content:match('^%s*[%-%*%+]%s') then
    return 'bulleted_list_item'
  elseif line_content:match('^%s*%d+%.%s') then
    return 'numbered_list_item'
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
    block_type = detect_list_type_from_content(line_content)
    if not block_type then
      -- Not a list: split orphan line at cursor (Bug 11.2)
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
    else
      -- Non-empty: create new list item
      local prefix = get_list_prefix(block_type, line_content)
      if is_at_line_end() then
        -- At end: simple newline with prefix
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<CR>', true, false, true), 'n', false)
        vim.schedule(function()
          if prefix then
            local row = vim.api.nvim_win_get_cursor(0)[1]
            vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { prefix })
            vim.api.nvim_win_set_cursor(0, { row, #prefix })
          end
        end)
      else
        -- Mid-line: split and add prefix to new line
        local col = get_cursor_col()
        local before = line_content:sub(1, col)
        local after = line_content:sub(col + 1)
        local row = vim.api.nvim_win_get_cursor(0)[1]

        vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { before, (prefix or '') .. after })
        vim.api.nvim_win_set_cursor(0, { row + 1, #(prefix or '') })
      end
    end
    return
  end

  -- Quote and Code: soft break (stay in same block)
  if block_type == 'quote' or block_type == 'code' then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<CR>', true, false, true), 'n', false)
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

  attached_buffers[bufnr] = nil
end

return M
