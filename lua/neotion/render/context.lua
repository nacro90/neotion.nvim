---RenderContext - Abstraction for block-level rendering
---Provides a clean interface between block models and the extmark system
---@class neotion.render.context
local M = {}

---@class neotion.RenderContext
---@field bufnr integer Buffer number
---@field line integer 0-indexed line number
---@field is_cursor_line boolean Whether this is the cursor line (for anti-conceal)
---@field window_width integer Total window width
---@field text_width integer Available text width (excluding sign column, line numbers)
---@field block_start_line? integer Start line of the block (0-indexed)
---@field block_end_line? integer End line of the block (0-indexed)
local RenderContext = {}
RenderContext.__index = RenderContext

---Create a new RenderContext
---@param bufnr integer Buffer number
---@param line integer 0-indexed line number
---@param opts table Options
---@return neotion.RenderContext
function RenderContext.new(bufnr, line, opts)
  opts = opts or {}

  local self = setmetatable({}, RenderContext)
  self.bufnr = bufnr
  self.line = line
  self.is_cursor_line = opts.is_cursor_line or false
  self.window_width = opts.window_width or 80
  self.text_width = opts.text_width or self.window_width
  self.block_start_line = opts.block_start_line
  self.block_end_line = opts.block_end_line

  return self
end

---Check if current line is the start of the block
---@return boolean
function RenderContext:is_block_start()
  if self.block_start_line == nil then
    return false
  end
  return self.line == self.block_start_line
end

---Check if current line is the end of the block
---@return boolean
function RenderContext:is_block_end()
  if self.block_end_line == nil then
    return false
  end
  return self.line == self.block_end_line
end

---Apply full-width overlay line (e.g., for dividers)
---Completely covers the original line content with repeated character
---@param char string Single character to repeat
---@param hl_group string Highlight group
---@param opts? {width?: integer} Options
function RenderContext:overlay_line(char, hl_group, opts)
  opts = opts or {}
  local width = opts.width or self.text_width
  local text = string.rep(char, width)

  local extmarks = require('neotion.render.extmarks')
  extmarks.apply_virtual_text(self.bufnr, self.line, 0, text, hl_group, {
    position = 'overlay',
  })
end

---Apply highlight to a range
---@param start_col integer Start column (0-indexed)
---@param end_col integer End column (0-indexed, exclusive)
---@param hl_group string Highlight group
function RenderContext:highlight(start_col, end_col, hl_group)
  local extmarks = require('neotion.render.extmarks')
  extmarks.apply_highlight(self.bufnr, self.line, start_col, end_col, hl_group)
end

---Apply concealment with anti-conceal support
---Automatically skips concealment on cursor line
---@param start_col integer Start column (0-indexed)
---@param end_col integer End column (0-indexed, exclusive)
---@param replacement string Replacement character(s)
function RenderContext:conceal(start_col, end_col, replacement)
  -- Anti-conceal: don't conceal on cursor line
  if self.is_cursor_line then
    return
  end

  local extmarks = require('neotion.render.extmarks')
  extmarks.apply_concealment(self.bufnr, self.line, start_col, end_col, replacement)
end

---Apply virtual text at a position
---@param col integer Column (0-indexed)
---@param text string Virtual text content
---@param hl_group string Highlight group
---@param opts? {position?: string} Options (position: 'inline', 'eol', 'overlay')
function RenderContext:virtual_text(col, text, hl_group, opts)
  opts = opts or {}
  local position = opts.position or 'inline'

  local extmarks = require('neotion.render.extmarks')
  extmarks.apply_virtual_text(self.bufnr, self.line, col, text, hl_group, {
    position = position,
  })
end

---Clear all extmarks on this line
function RenderContext:clear()
  local extmarks = require('neotion.render.extmarks')
  extmarks.clear_line(self.bufnr, self.line)
end

M.RenderContext = RenderContext

return M
