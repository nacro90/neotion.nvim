--- Anti-conceal system for neotion.nvim
--- Manages cursor-aware rendering: shows raw markers on cursor line, concealed elsewhere
---@module 'neotion.render.anti_conceal'

local M = {}

---@class neotion.AntiConcealState
---@field cursor_line integer 0-indexed current cursor line
---@field render_callback? fun(bufnr: integer, line: integer) Callback to re-render a line

--- Buffer states
---@type table<integer, neotion.AntiConcealState>
local buffer_states = {}

--- Autocmd group
local augroup = vim.api.nvim_create_augroup('NeotionAntiConceal', { clear = true })

--- Reset all state (for testing)
function M.reset()
  buffer_states = {}
  vim.api.nvim_clear_autocmds({ group = augroup })
end

--- Check if anti-conceal is attached to a buffer
---@param bufnr integer
---@return boolean
function M.is_attached(bufnr)
  return buffer_states[bufnr] ~= nil
end

--- Get current cursor line for a buffer
---@param bufnr integer
---@return integer|nil 0-indexed line number
function M.get_cursor_line(bufnr)
  local state = buffer_states[bufnr]
  if not state then
    return nil
  end
  return state.cursor_line
end

--- Get the current cursor line from the window
---@param bufnr integer
---@return integer 0-indexed line number
local function get_current_cursor_line(bufnr)
  -- Find a window displaying this buffer
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
      local cursor = vim.api.nvim_win_get_cursor(win)
      return cursor[1] - 1 -- Convert to 0-indexed
    end
  end
  return 0
end

--- Attach anti-conceal to a buffer
---@param bufnr integer
function M.attach(bufnr)
  if M.is_attached(bufnr) then
    return
  end

  local cursor_line = get_current_cursor_line(bufnr)

  buffer_states[bufnr] = {
    cursor_line = cursor_line,
    render_callback = nil,
  }

  -- Set up CursorMoved autocmd
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
    group = augroup,
    buffer = bufnr,
    callback = function()
      M.on_cursor_moved(bufnr)
    end,
  })

  -- Clean up on buffer delete
  vim.api.nvim_create_autocmd('BufDelete', {
    group = augroup,
    buffer = bufnr,
    callback = function()
      M.detach(bufnr)
    end,
  })
end

--- Detach anti-conceal from a buffer
---@param bufnr integer
function M.detach(bufnr)
  buffer_states[bufnr] = nil

  -- Clear autocmds for this buffer
  pcall(vim.api.nvim_clear_autocmds, { group = augroup, buffer = bufnr })
end

--- Update cursor line tracking and return old/new lines
---@param bufnr integer
---@return integer|nil old_line
---@return integer|nil new_line
function M.update_cursor_line(bufnr)
  local state = buffer_states[bufnr]
  if not state then
    return nil, nil
  end

  local old_line = state.cursor_line
  local new_line = get_current_cursor_line(bufnr)

  state.cursor_line = new_line

  return old_line, new_line
end

--- Check if a line should show raw markers (i.e., is cursor line in active window)
---@param bufnr integer
---@param line integer 0-indexed line number
---@return boolean
function M.should_show_raw(bufnr, line)
  local state = buffer_states[bufnr]
  if not state then
    return false
  end

  -- Only show raw if this buffer is displayed in current window
  local current_buf = vim.api.nvim_get_current_buf()
  if current_buf ~= bufnr then
    return false
  end

  -- Get actual cursor position from current window
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_line = cursor[1] - 1 -- 0-indexed

  return cursor_line == line
end

--- Set the render callback for a buffer
---@param bufnr integer
---@param callback fun(bufnr: integer, line: integer)
function M.set_render_callback(bufnr, callback)
  local state = buffer_states[bufnr]
  if state then
    state.render_callback = callback
  end
end

--- Get the render callback for a buffer
---@param bufnr integer
---@return fun(bufnr: integer, line: integer)|nil
function M.get_render_callback(bufnr)
  local state = buffer_states[bufnr]
  if state then
    return state.render_callback
  end
  return nil
end

--- Handle cursor movement
---@param bufnr integer
function M.on_cursor_moved(bufnr)
  local state = buffer_states[bufnr]
  if not state then
    return
  end

  local old_line, new_line = M.update_cursor_line(bufnr)

  -- If cursor line changed, re-render both lines
  if old_line ~= new_line and state.render_callback then
    -- Re-render old line (now should be concealed)
    state.render_callback(bufnr, old_line)
    -- Re-render new line (now should show raw)
    state.render_callback(bufnr, new_line)
  end
end

--- List all attached buffers
---@return integer[]
function M.list_attached()
  local buffers = {}
  for bufnr, _ in pairs(buffer_states) do
    table.insert(buffers, bufnr)
  end
  return buffers
end

return M
