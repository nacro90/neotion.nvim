---Divider Block handler for Neotion
---Read-only horizontal rule block
---@class neotion.model.blocks.Divider
local M = {}

local base = require('neotion.model.block')
local Block = base.Block

-- Divider character for rendering (Box Drawing Light Horizontal)
local DIVIDER_CHAR = '─'

---@class neotion.DividerBlock : neotion.Block
local DividerBlock = setmetatable({}, { __index = Block })
DividerBlock.__index = DividerBlock

---Create a new DividerBlock from Notion API JSON
---@param raw table Notion API block JSON
---@return neotion.DividerBlock
function DividerBlock.new(raw)
  local self = setmetatable(Block.new(raw), DividerBlock)

  -- Divider is never editable
  self.editable = false

  return self
end

---Format divider to buffer lines
---@param opts? {indent?: integer, indent_size?: integer}
---@return string[]
function DividerBlock:format(opts)
  -- Divider has fixed content, ignores indent
  return { '---' }
end

---Serialize divider to Notion API JSON
---@return table Notion API block JSON
function DividerBlock:serialize()
  -- Return unchanged raw JSON (divider has no editable content)
  return self.raw
end

---Update divider from buffer lines (no-op, divider is not editable)
---@param lines string[]
function DividerBlock:update_from_lines(lines)
  -- No-op: divider content cannot be changed
end

---Get current text content
---@return string
function DividerBlock:get_text()
  return ''
end

---Check if content matches given lines
---Always returns true since divider content is fixed
---@param lines string[]
---@return boolean
function DividerBlock:matches_content(lines)
  -- Divider content is always "---", so we always match
  return true
end

---Render divider with full-width overlay
---Only applies overlay if the line content is actually '---'
---@param ctx neotion.RenderContext
---@return boolean handled Returns true if overlay was applied
function DividerBlock:render(ctx)
  -- Verify the line still contains divider content before overlaying
  -- This prevents ghost overlays when lines are deleted/changed
  local lines = vim.api.nvim_buf_get_lines(ctx.bufnr, ctx.line, ctx.line + 1, false)
  if #lines == 0 or lines[1] ~= '---' then
    return false -- Line doesn't match, let default rendering handle it
  end

  ctx:overlay_line(DIVIDER_CHAR, 'NeotionDivider')
  return true
end

---Get the gutter icon for this divider block
---@return string divider icon
function DividerBlock:get_gutter_icon()
  return '──'
end

-- Module interface for registry
M.new = DividerBlock.new
M.is_editable = function()
  return false
end
M.DividerBlock = DividerBlock
M.DIVIDER_CHAR = DIVIDER_CHAR

return M
