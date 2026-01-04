--- Render system for neotion.nvim
--- Orchestrates inline formatting rendering with anti-conceal support
---@module 'neotion.render.init'

local anti_conceal = require('neotion.render.anti_conceal')
local extmarks = require('neotion.render.extmarks')
local format = require('neotion.format.init')
local highlight = require('neotion.render.highlight')

local M = {}

---@class neotion.RenderConfig
---@field enabled boolean Whether rendering is enabled
---@field anti_conceal boolean Whether anti-conceal is enabled
---@field provider string Format provider name

--- Default config
---@type neotion.RenderConfig
local default_config = {
  enabled = true,
  anti_conceal = true,
  provider = 'notion',
}

--- Current config
---@type neotion.RenderConfig
local config = vim.tbl_deep_extend('force', {}, default_config)

--- Attached buffers
---@type table<integer, boolean>
local attached_buffers = {}

--- Debounce timers per buffer (Vimscript timer IDs from timer_start)
---@type table<integer, integer?>
local debounce_timers = {}

--- Global enabled state
local enabled = true

--- Get debounce delay from main config
---@return integer
local function get_debounce_ms()
  local neotion_config = require('neotion.config').get()
  return neotion_config.render and neotion_config.render.debounce_ms or 100
end

--- Safely stop a timer
---@param timer_id integer?
local function stop_timer(timer_id)
  if timer_id and type(timer_id) == 'number' then
    pcall(vim.fn.timer_stop, timer_id)
  end
end

--- Reset all state (for testing)
function M.reset()
  -- Cancel all pending debounce timers
  for _, timer in pairs(debounce_timers) do
    stop_timer(timer)
  end
  debounce_timers = {}

  for bufnr, _ in pairs(attached_buffers) do
    M.detach(bufnr)
  end
  attached_buffers = {}
  config = vim.tbl_deep_extend('force', {}, default_config)
  enabled = true
end

--- Check if rendering is globally enabled
---@return boolean
function M.is_enabled()
  return enabled
end

--- Set global enabled state
---@param value boolean
function M.set_enabled(value)
  enabled = value

  if not enabled then
    -- Detach all buffers
    for bufnr, _ in pairs(attached_buffers) do
      M.detach(bufnr)
    end
  end
end

--- Get current render config
---@return neotion.RenderConfig
function M.get_config()
  return vim.tbl_deep_extend('force', {}, config)
end

--- Set render config
---@param opts table Partial config to merge
function M.set_config(opts)
  config = vim.tbl_deep_extend('force', config, opts)
end

--- Check if renderer is attached to a buffer
---@param bufnr integer
---@return boolean
function M.is_attached(bufnr)
  return attached_buffers[bufnr] == true
end

--- Parse a buffer line and return parse result with segments and conceal regions
---@param bufnr integer
---@param line integer 0-indexed line number
---@return neotion.ParseResult
local function parse_line(bufnr, line)
  local lines = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)
  if #lines == 0 then
    return { segments = {}, conceal_regions = {} }
  end

  local text = lines[1]
  -- Use parse_with_concealment for render (has original positions)
  local notion = require('neotion.format.notion')
  return notion.parse_with_concealment(text)
end

--- Render a single line
---@param bufnr integer
---@param line integer 0-indexed line number
function M.render_line(bufnr, line)
  if not M.is_attached(bufnr) then
    return
  end

  -- Parse the line (with concealment info)
  local result = parse_line(bufnr, line)

  -- Clear existing marks first
  extmarks.clear_line(bufnr, line)

  -- Check if this is the cursor line
  local is_cursor_line = anti_conceal.should_show_raw(bufnr, line)

  -- Apply highlights for all segments
  for _, segment in ipairs(result.segments) do
    if segment.annotations:has_formatting() then
      local hl_groups = highlight.get_annotation_highlights(segment.annotations)
      for _, hl_group in ipairs(hl_groups) do
        extmarks.apply_highlight(bufnr, line, segment.start_col, segment.end_col, hl_group)
      end
    end
    -- Apply link highlight if segment has href
    if segment.href and segment.href ~= vim.NIL then
      extmarks.apply_highlight(bufnr, line, segment.start_col, segment.end_col, 'NeotionLink')
    end
  end

  -- Apply concealment only on non-cursor lines
  if not is_cursor_line then
    for _, region in ipairs(result.conceal_regions) do
      extmarks.apply_concealment(bufnr, line, region.start_col, region.end_col, region.replacement)
    end
  end
end

--- Render all lines in a buffer
---@param bufnr integer
function M.render_buffer(bufnr)
  if not M.is_attached(bufnr) then
    return
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  for line = 0, line_count - 1 do
    M.render_line(bufnr, line)
  end
end

--- Refresh buffer rendering (clear and re-render)
---@param bufnr integer
function M.refresh(bufnr)
  if not M.is_attached(bufnr) then
    return
  end

  extmarks.clear_buffer(bufnr)
  M.render_buffer(bufnr)
end

--- Attach renderer to a buffer
---@param bufnr integer
function M.attach(bufnr)
  if M.is_attached(bufnr) then
    return
  end

  if not enabled then
    return
  end

  attached_buffers[bufnr] = true

  -- Setup highlights
  highlight.setup()

  -- Attach anti-conceal if enabled
  if config.anti_conceal then
    anti_conceal.attach(bufnr)
    anti_conceal.set_render_callback(bufnr, function(buf, line)
      M.render_line(buf, line)
    end)
  end

  -- Initial render
  M.render_buffer(bufnr)

  -- Set up autocmd for buffer changes
  local augroup = vim.api.nvim_create_augroup('NeotionRender_' .. bufnr, { clear = true })

  vim.api.nvim_create_autocmd('TextChanged', {
    group = augroup,
    buffer = bufnr,
    callback = function()
      local debounce_ms = get_debounce_ms()
      if debounce_ms > 0 then
        -- Cancel pending timer
        stop_timer(debounce_timers[bufnr])
        -- Schedule debounced refresh using Vimscript timer
        debounce_timers[bufnr] = vim.fn.timer_start(debounce_ms, function()
          debounce_timers[bufnr] = nil
          if M.is_attached(bufnr) then
            M.refresh(bufnr)
          end
        end)
      else
        -- No debounce, immediate refresh
        M.refresh(bufnr)
      end
    end,
  })

  vim.api.nvim_create_autocmd('TextChangedI', {
    group = augroup,
    buffer = bufnr,
    callback = function()
      -- Only re-render current line in insert mode for performance
      local cursor = vim.api.nvim_win_get_cursor(0)
      M.render_line(bufnr, cursor[1] - 1)
    end,
  })

  -- Re-render on leaving insert mode to ensure full render
  vim.api.nvim_create_autocmd('InsertLeave', {
    group = augroup,
    buffer = bufnr,
    callback = function()
      M.refresh(bufnr)
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

--- Detach renderer from a buffer
---@param bufnr integer
function M.detach(bufnr)
  if not M.is_attached(bufnr) then
    return
  end

  -- Cancel pending debounce timer
  stop_timer(debounce_timers[bufnr])
  debounce_timers[bufnr] = nil

  -- Clear extmarks
  extmarks.clear_buffer(bufnr)

  -- Detach anti-conceal
  anti_conceal.detach(bufnr)

  -- Clear autocmds
  pcall(vim.api.nvim_del_augroup_by_name, 'NeotionRender_' .. bufnr)

  attached_buffers[bufnr] = nil
end

--- List all attached buffers
---@return integer[]
function M.list_attached()
  local buffers = {}
  for bufnr, _ in pairs(attached_buffers) do
    table.insert(buffers, bufnr)
  end
  return buffers
end

return M
