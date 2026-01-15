-- TODO(neotion:FEAT-13.7:MEDIUM): Add child_database block model support
-- Create ChildDatabaseBlock similar to ChildPageBlock with:
-- - Title display with database icon
-- - Icon resolution from cache (emoji or placeholder)
-- - Read-only block (not editable)

---Child Page Block handler for Neotion
---Read-only block representing a sub-page link
---@class neotion.model.blocks.ChildPage
local M = {}

local base = require('neotion.model.block')
local Block = base.Block

-- Default icon for child pages (used when actual icon not available)
-- Uses Nerd Font file_text icon (nf-fa-file_text U+F0F6)
local DEFAULT_ICON = '\u{f0f6}'

---@class neotion.ChildPageBlock : neotion.Block
---@field title string The child page title
---@field page_id string The child page ID (same as block ID for child_page blocks)
---@field icon string|nil Custom icon from page metadata (nil means use DEFAULT_ICON)
local ChildPageBlock = setmetatable({}, { __index = Block })
ChildPageBlock.__index = ChildPageBlock

---Create a new ChildPageBlock from Notion API JSON
---@param raw table Notion API block JSON
---@return neotion.ChildPageBlock
function ChildPageBlock.new(raw)
  local self = setmetatable(Block.new(raw), ChildPageBlock)

  -- Child page is never editable (read-only navigation element)
  self.editable = false

  -- Extract title from child_page data (trim whitespace)
  local child_page_data = raw.child_page or {}
  local raw_title = child_page_data.title or ''
  local trimmed = vim.trim(raw_title)
  self.title = trimmed ~= '' and trimmed or 'Untitled'

  -- The block ID is also the page ID for child_page blocks
  self.page_id = raw.id

  -- Icon starts as nil (will be resolved from cache/API later)
  self.icon = nil

  return self
end

---Set custom icon for this child page
---@param icon string|nil The icon to display (nil resets to default)
function ChildPageBlock:set_icon(icon)
  self.icon = icon
end

---Get the icon to display (custom or default)
---@return string
function ChildPageBlock:get_display_icon()
  return self.icon or DEFAULT_ICON
end

---Format child page to buffer lines
---@param opts? {indent?: integer, indent_size?: integer}
---@return string[]
function ChildPageBlock:format(opts)
  local indent = opts and opts.indent or 0
  local indent_size = opts and opts.indent_size or 2
  local prefix = string.rep(' ', indent * indent_size)

  -- Format: <icon> Page Title (use custom icon if set, else default)
  local display_icon = self:get_display_icon()
  return { prefix .. display_icon .. ' ' .. self.title }
end

---Serialize child page to Notion API JSON
---@return table Notion API block JSON
function ChildPageBlock:serialize()
  -- Return unchanged raw JSON (child_page has no editable content)
  return self.raw
end

---Update child page from buffer lines (no-op, child_page is not editable)
---@param lines string[]
function ChildPageBlock:update_from_lines(lines)
  -- No-op: child_page content cannot be changed from buffer
end

---Get current text content
---@return string
function ChildPageBlock:get_text()
  return self.title
end

---Check if content matches given lines
---@param lines string[]
---@return boolean
function ChildPageBlock:matches_content(lines)
  if #lines == 0 then
    return false
  end
  -- Check if the line contains the expected format (with current display icon)
  local display_icon = self:get_display_icon()
  local expected = display_icon .. ' ' .. self.title
  -- Strip leading whitespace for comparison
  local line = lines[1]:match('^%s*(.*)$')
  return line == expected
end

---Render child page with clickable link appearance
---@param ctx neotion.RenderContext
---@return boolean handled Returns true if rendering was applied
function ChildPageBlock:render(ctx)
  local lines = vim.api.nvim_buf_get_lines(ctx.bufnr, ctx.line, ctx.line + 1, false)
  if #lines == 0 then
    return false
  end

  local line = lines[1]
  -- Find the title portion (after the icon) - use current display icon
  local display_icon = self:get_display_icon()
  -- Escape special pattern characters in icon (emojis are usually safe, but be defensive)
  local escaped_icon = vim.pesc(display_icon)
  local icon_pattern = '^(%s*)' .. escaped_icon .. ' '
  local prefix = line:match(icon_pattern)
  if not prefix then
    return false
  end

  -- Apply link highlight to the entire line (icon + title)
  local start_col = #prefix
  local end_col = #line
  ctx:highlight(start_col, end_col, 'NeotionChildPage')

  return true
end

---Get the gutter icon for this child page block
---@return string navigation icon
function ChildPageBlock:get_gutter_icon()
  return '->'
end

---Get the page ID for navigation
---@return string page_id
function ChildPageBlock:get_page_id()
  return self.page_id
end

---Check if block has children
---Child pages don't render children inline (users navigate to see content)
---@return boolean always false for child_page
function ChildPageBlock:has_children()
  return false
end

-- Module interface for registry
M.new = ChildPageBlock.new
M.is_editable = function()
  return false
end
M.ChildPageBlock = ChildPageBlock
M.DEFAULT_ICON = DEFAULT_ICON

return M
