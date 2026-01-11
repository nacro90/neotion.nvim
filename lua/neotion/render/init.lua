--- Render system for neotion.nvim
--- Orchestrates inline formatting rendering with anti-conceal support
---@module 'neotion.render.init'

-- TODO(neotion:FEAT-12.3:LOW): Show actual page icons instead of fixed emoji
-- Fetch child page icon from cache/API asynchronously after initial render
-- Fall back to 📄 if icon unavailable. Requires background metadata fetch.

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

--- Last known line count per buffer (for detecting line additions in insert mode)
---@type table<integer, integer>
local last_line_counts = {}

--- Global enabled state
local enabled = true

--- Global augroup for WinResized handling
local global_augroup = nil

--- Setup global WinResized autocmd for refreshing dividers on resize
---@diagnostic disable-next-line: unused-local
local function setup_win_resized_autocmd()
  if global_augroup then
    return -- Already setup
  end

  global_augroup = vim.api.nvim_create_augroup('NeotionRenderGlobal', { clear = true })

  vim.api.nvim_create_autocmd('WinResized', {
    group = global_augroup,
    callback = function()
      -- Refresh all attached buffers when window is resized
      -- This ensures dividers and other full-width elements update
      for bufnr, _ in pairs(attached_buffers) do
        if vim.api.nvim_buf_is_valid(bufnr) then
          M.refresh(bufnr)
        end
      end
    end,
  })
end

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

  -- Clear existing marks first
  extmarks.clear_line(bufnr, line)

  -- Check if this is the cursor line
  local is_cursor_line = anti_conceal.should_show_raw(bufnr, line)

  -- Try block-level rendering first
  local mapping = require('neotion.model.mapping')
  -- Note: render_line receives 0-indexed line, but get_block_at_line expects 1-indexed
  local block = mapping.get_block_at_line(bufnr, line + 1)

  if block then
    -- Create RenderContext for block
    local RenderContext = require('neotion.render.context').RenderContext
    local win = vim.fn.bufwinid(bufnr)
    local window_width = 80
    local text_width = 80

    if win ~= -1 then
      local win_info = vim.fn.getwininfo(win)[1]
      if win_info then
        window_width = win_info.width
        text_width = win_info.width - (win_info.textoff or 0)
      end
    end

    local block_start, block_end = block:get_line_range()
    local ctx = RenderContext.new(bufnr, line, {
      is_cursor_line = is_cursor_line,
      window_width = window_width,
      text_width = text_width,
      block_start_line = block_start,
      block_end_line = block_end,
    })

    -- Let block handle rendering if it wants to
    if block:render(ctx) then
      return -- Block handled its own rendering
    end
  end

  -- Default text-based rendering
  local result = parse_line(bufnr, line)

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

  -- Apply block spacing (virtual lines between blocks)
  local neotion_config = require('neotion.config').get()
  if neotion_config.render.block_spacing then
    M.apply_block_spacing(bufnr)
  end

  -- Apply gutter icons (sign column block indicators)
  if neotion_config.render.gutter_icons then
    M.apply_gutter_icons(bufnr)
  end
end

--- Apply virtual lines between blocks for visual separation
---@param bufnr integer
function M.apply_block_spacing(bufnr)
  local mapping = require('neotion.model.mapping')
  local detection = require('neotion.model.blocks.detection')
  local blocks = mapping.get_blocks(bufnr)

  -- Detect orphan lines once (for empty orphan lookahead)
  local buffer_mod = require('neotion.buffer')
  local buf_data = buffer_mod.get_data(bufnr)
  local header_lines = buf_data and buf_data.header_line_count or 6
  local orphans = mapping.detect_orphan_lines(bufnr, header_lines)

  -- Pre-fetch orphan info: empty status and detected block type
  local orphan_is_empty = {}
  local orphan_types = {} -- Maps orphan.start_line to detected block type
  for _, orphan in ipairs(orphans) do
    local orphan_lines = vim.api.nvim_buf_get_lines(bufnr, orphan.start_line - 1, orphan.end_line, false)
    local all_empty = true
    local first_content_line = nil
    for _, line in ipairs(orphan_lines) do
      if vim.trim(line) ~= '' then
        all_empty = false
        first_content_line = first_content_line or line
      end
    end
    orphan_is_empty[orphan.start_line] = all_empty
    -- Detect block type from first non-empty line
    if first_content_line then
      local detected_type = detection.detect_type(first_content_line)
      orphan_types[orphan.start_line] = detected_type or 'paragraph'
    else
      orphan_types[orphan.start_line] = 'paragraph'
    end
  end

  -- Helper: check if a type is a list item
  local function is_list_type(block_type)
    return block_type == 'bulleted_list_item' or block_type == 'numbered_list_item'
  end

  -- Helper: get spacing_before for orphan block type
  local function orphan_spacing_before(block_type)
    if block_type == 'heading_1' then
      return 1
    end
    return 0
  end

  -- Apply spacing after each block
  for i, block in ipairs(blocks) do
    local _, end_line = block:get_line_range()
    if not end_line then
      goto continue
    end

    local next_block = blocks[i + 1]
    local spacing = block:spacing_after()

    -- Check for orphan immediately after this block
    local orphan_after = nil
    local orphan_type_after = nil
    for _, orphan in ipairs(orphans) do
      if orphan.start_line == end_line + 1 then
        orphan_after = orphan
        orphan_type_after = orphan_types[orphan.start_line]
        break
      end
    end

    -- Priority 1: Empty paragraph/orphan lookahead (always takes precedence)
    local has_empty_after = false
    if next_block and next_block:is_empty_paragraph() then
      spacing = 0
      has_empty_after = true
    elseif orphan_after and orphan_is_empty[orphan_after.start_line] then
      spacing = 0
      has_empty_after = true
    end

    -- Priority 2: List group logic (only if not overridden by empty lookahead)
    if not has_empty_after and block:is_list_item() then
      -- Check if next is a list item (either block or orphan)
      local next_is_list = (next_block and next_block:is_list_item())
        or (orphan_type_after and is_list_type(orphan_type_after))
      if not next_is_list then
        spacing = 1 -- End of list group
      else
        spacing = 0 -- Continue list group
      end
    end

    -- Priority 3: Add spacing_before from next block/orphan (additive, but only if spacing > 0)
    if spacing > 0 then
      if next_block then
        local extra_before = next_block:spacing_before()
        if extra_before > 0 then
          spacing = spacing + extra_before
        end
      elseif orphan_type_after then
        local extra_before = orphan_spacing_before(orphan_type_after)
        if extra_before > 0 then
          spacing = spacing + extra_before
        end
      end
    end

    -- Apply virtual lines at block end (0-indexed)
    if spacing > 0 then
      extmarks.apply_virtual_lines(bufnr, end_line - 1, spacing)
    end

    ::continue::
  end

  -- Apply spacing after orphan lines based on detected block type
  for idx, orphan in ipairs(orphans) do
    local orphan_type = orphan_types[orphan.start_line]

    -- Determine what comes after this orphan
    local next_orphan = orphans[idx + 1]
    local next_orphan_type = next_orphan and orphan_types[next_orphan.start_line]

    -- Find next block after this orphan
    local next_block_after_orphan = nil
    for _, block in ipairs(blocks) do
      local start_line = block:get_line_range()
      if start_line and start_line > orphan.end_line then
        next_block_after_orphan = block
        break
      end
    end

    -- Calculate spacing based on block type rules
    local spacing = 1 -- Default spacing

    -- List item grouping: no spacing if next is also a list item
    if is_list_type(orphan_type) then
      local next_is_list = (next_orphan_type and is_list_type(next_orphan_type))
        or (next_block_after_orphan and next_block_after_orphan:is_list_item())
      if next_is_list then
        spacing = 0
      end
    end

    -- Empty orphan: no spacing before next
    if orphan_is_empty[orphan.start_line] then
      spacing = 0
    end

    -- Add spacing_before from next element
    if spacing > 0 then
      if next_orphan_type then
        spacing = spacing + orphan_spacing_before(next_orphan_type)
      elseif next_block_after_orphan then
        spacing = spacing + next_block_after_orphan:spacing_before()
      end
    end

    -- Apply virtual lines at orphan end (0-indexed)
    if spacing > 0 then
      extmarks.apply_virtual_lines(bufnr, orphan.end_line - 1, spacing)
    end
  end
end

--- Apply gutter icons (sign column) for each block
---@param bufnr integer Buffer number
function M.apply_gutter_icons(bufnr)
  local mapping = require('neotion.model.mapping')
  local gutter = require('neotion.render.gutter_icons')
  local blocks = mapping.get_blocks(bufnr)

  for _, block in ipairs(blocks) do
    local start_line, end_line = block:get_line_range()
    if not start_line or not end_line then
      goto continue
    end

    local icon = block:get_gutter_icon()
    if not icon then
      goto continue
    end

    -- Get highlight group for this block type
    local hl_group = gutter.get_highlight_group(block.type)

    -- Apply icon to first line of block
    extmarks.apply_sign_text(bufnr, start_line - 1, icon, hl_group)

    -- Apply continuation markers to subsequent lines
    if end_line > start_line then
      for line = start_line + 1, end_line do
        extmarks.apply_sign_text(bufnr, line - 1, gutter.CONTINUATION_MARKER, 'NeotionGutterContinuation')
      end
    end

    ::continue::
  end
end

--- Refresh buffer rendering (clear and re-render)
---@param bufnr integer
function M.refresh(bufnr)
  if not M.is_attached(bufnr) then
    return
  end

  -- Refresh block line ranges before rendering
  -- This ensures blocks are mapped to correct lines after edits
  local mapping = require('neotion.model.mapping')
  if mapping.has_blocks(bufnr) then
    mapping.refresh_line_ranges(bufnr)
  end

  extmarks.clear_buffer(bufnr)
  extmarks.clear_virtual_lines(bufnr)
  extmarks.clear_gutter_icons(bufnr)
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

  -- Initialize line count tracking for insert mode virtual lines refresh
  last_line_counts[bufnr] = vim.api.nvim_buf_line_count(bufnr)

  -- Setup global autocmds (once)
  setup_win_resized_autocmd()

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
      local current_line_count = vim.api.nvim_buf_line_count(bufnr)
      local last_count = last_line_counts[bufnr] or current_line_count

      -- Check if line count changed (new line added or removed)
      if current_line_count ~= last_count then
        last_line_counts[bufnr] = current_line_count
        -- Line count changed - refresh virtual lines and spacing
        extmarks.clear_virtual_lines(bufnr)
        M.apply_block_spacing(bufnr)
      end

      -- Always re-render current line in insert mode for inline formatting
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

  -- Clear line count tracking
  last_line_counts[bufnr] = nil

  -- Clear extmarks (all namespaces)
  extmarks.clear_buffer(bufnr)
  extmarks.clear_virtual_lines(bufnr)
  extmarks.clear_gutter_icons(bufnr)

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
