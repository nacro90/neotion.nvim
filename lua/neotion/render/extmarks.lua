--- Extmark utilities for neotion.nvim
--- Provides helpers for creating and managing extmarks for inline formatting
---@module 'neotion.render.extmarks'

local highlight = require('neotion.render.highlight')

local M = {}

--- Namespace for all neotion extmarks (inline formatting, concealment, etc.)
M.NAMESPACE = vim.api.nvim_create_namespace('neotion')

--- Separate namespace for virtual lines (block spacing)
--- This prevents clear_line from removing virtual lines during anti-conceal re-renders
M.VIRT_LINES_NAMESPACE = vim.api.nvim_create_namespace('neotion_virt_lines')

--- Clear all extmarks on a specific line
---@param bufnr integer
---@param line integer 0-indexed line number
function M.clear_line(bufnr, line)
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, M.NAMESPACE, { line, 0 }, { line, -1 }, {})

  for _, mark in ipairs(marks) do
    vim.api.nvim_buf_del_extmark(bufnr, M.NAMESPACE, mark[1])
  end
end

--- Clear all extmarks in a buffer
---@param bufnr integer
function M.clear_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  vim.api.nvim_buf_clear_namespace(bufnr, M.NAMESPACE, 0, -1)
end

--- Apply a highlight to a range
---@param bufnr integer
---@param line integer 0-indexed line number
---@param start_col integer 0-indexed start column
---@param end_col integer 0-indexed end column (exclusive)
---@param hl_group string Highlight group name
---@return integer extmark_id
function M.apply_highlight(bufnr, line, start_col, end_col, hl_group)
  return vim.api.nvim_buf_set_extmark(bufnr, M.NAMESPACE, line, start_col, {
    end_col = end_col,
    hl_group = hl_group,
  })
end

---@class neotion.VirtualTextOpts
---@field position? 'inline'|'overlay'|'eol' Virtual text position (default: 'inline')
---@field priority? integer Extmark priority

--- Apply virtual text at a position
---@param bufnr integer
---@param line integer 0-indexed line number
---@param col integer 0-indexed column
---@param text string Virtual text content
---@param hl_group? string Highlight group for virtual text
---@param opts? neotion.VirtualTextOpts
---@return integer extmark_id
function M.apply_virtual_text(bufnr, line, col, text, hl_group, opts)
  opts = opts or {}
  local position = opts.position or 'inline'

  local virt_text = { { text, hl_group } }

  return vim.api.nvim_buf_set_extmark(bufnr, M.NAMESPACE, line, col, {
    virt_text = virt_text,
    virt_text_pos = position,
    priority = opts.priority,
  })
end

--- Apply concealment to a range
---@param bufnr integer
---@param line integer 0-indexed line number
---@param start_col integer 0-indexed start column
---@param end_col integer 0-indexed end column (exclusive)
---@param replacement? string Optional replacement character (max 1 char)
---@return integer extmark_id
function M.apply_concealment(bufnr, line, start_col, end_col, replacement)
  return vim.api.nvim_buf_set_extmark(bufnr, M.NAMESPACE, line, start_col, {
    end_col = end_col,
    conceal = replacement or '',
  })
end

--- Apply virtual lines after a position (for block spacing)
--- Uses separate namespace to prevent clear_line from removing them
---@param bufnr integer Buffer number
---@param line integer 0-indexed line number
---@param count integer Number of empty virtual lines to add
---@return integer extmark_id
function M.apply_virtual_lines(bufnr, line, count)
  if count <= 0 then
    return -1
  end

  local virt_lines = {}
  for _ = 1, count do
    table.insert(virt_lines, { { '', 'Normal' } })
  end

  return vim.api.nvim_buf_set_extmark(bufnr, M.VIRT_LINES_NAMESPACE, line, 0, {
    virt_lines = virt_lines,
    virt_lines_above = false,
  })
end

--- Clear all virtual lines extmarks in a buffer
---@param bufnr integer
function M.clear_virtual_lines(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  vim.api.nvim_buf_clear_namespace(bufnr, M.VIRT_LINES_NAMESPACE, 0, -1)
end

--- Apply highlights for a rich text segment
---@param bufnr integer
---@param line integer 0-indexed line number
---@param segment neotion.RichTextSegment
function M.apply_segment_highlights(bufnr, line, segment)
  local hl_groups = highlight.get_annotation_highlights(segment.annotations)

  if #hl_groups == 0 then
    return
  end

  -- Apply each highlight group
  -- For multiple highlights, we apply them all to the same range
  -- Neovim will blend/combine them
  for _, hl_group in ipairs(hl_groups) do
    M.apply_highlight(bufnr, line, segment.start_col, segment.end_col, hl_group)
  end
end

--- Render all segments on a line with highlights
---@param bufnr integer
---@param line integer 0-indexed line number
---@param segments neotion.RichTextSegment[]
function M.render_line_segments(bufnr, line, segments)
  -- Clear existing marks on this line first
  M.clear_line(bufnr, line)

  -- Apply highlights for each segment
  for _, segment in ipairs(segments) do
    M.apply_segment_highlights(bufnr, line, segment)
  end
end

--- Get all extmarks on a line
---@param bufnr integer
---@param line integer 0-indexed line number
---@return table[] marks Array of extmark data
function M.get_line_marks(bufnr, line)
  return vim.api.nvim_buf_get_extmarks(bufnr, M.NAMESPACE, { line, 0 }, { line, -1 }, { details = true })
end

--- Get all extmarks in a buffer
---@param bufnr integer
---@return table[] marks Array of extmark data
function M.get_buffer_marks(bufnr)
  return vim.api.nvim_buf_get_extmarks(bufnr, M.NAMESPACE, 0, -1, { details = true })
end

return M
