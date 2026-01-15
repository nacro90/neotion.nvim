---Child Database Block handler for Neotion
---Read-only block representing an inline database link
---@class neotion.model.blocks.ChildDatabase
local M = {}

local base = require('neotion.model.block')
local Block = base.Block

-- Default icon for child databases (used when actual icon not available)
-- Uses Nerd Font database icon (nf-fa-database U+F1C0)
local DEFAULT_ICON = '\u{f1c0}'

---@class neotion.ChildDatabaseBlock : neotion.Block
---@field title string The child database title
---@field database_id string The child database ID (same as block ID for child_database blocks)
---@field icon string|nil Custom icon from database metadata (nil means use DEFAULT_ICON)
local ChildDatabaseBlock = setmetatable({}, { __index = Block })
ChildDatabaseBlock.__index = ChildDatabaseBlock

---Create a new ChildDatabaseBlock from Notion API JSON
---@param raw table Notion API block JSON
---@return neotion.ChildDatabaseBlock
function ChildDatabaseBlock.new(raw)
  local self = setmetatable(Block.new(raw), ChildDatabaseBlock)

  -- Child database is never editable (read-only navigation element)
  self.editable = false

  -- Extract title from child_database data (trim whitespace)
  local child_database_data = raw.child_database or {}
  local raw_title = child_database_data.title or ''
  local trimmed = vim.trim(raw_title)
  self.title = trimmed ~= '' and trimmed or 'Untitled'

  -- The block ID is also the database ID for child_database blocks
  self.database_id = raw.id

  -- Icon starts as nil (will be resolved from cache/API later)
  self.icon = nil

  return self
end

---Set custom icon for this child database
---@param icon string|nil The icon to display (nil resets to default)
function ChildDatabaseBlock:set_icon(icon)
  self.icon = icon
end

---Get the icon to display (custom or default)
---@return string
function ChildDatabaseBlock:get_display_icon()
  return self.icon or DEFAULT_ICON
end

---Format child database to buffer lines
---@param opts? {indent?: integer, indent_size?: integer}
---@return string[]
function ChildDatabaseBlock:format(opts)
  local indent = opts and opts.indent or 0
  local indent_size = opts and opts.indent_size or 2
  local prefix = string.rep(' ', indent * indent_size)

  -- Format: <icon> Database Title (use custom icon if set, else default)
  local display_icon = self:get_display_icon()
  return { prefix .. display_icon .. ' ' .. self.title }
end

---Serialize child database to Notion API JSON
---@return table Notion API block JSON
function ChildDatabaseBlock:serialize()
  -- Return unchanged raw JSON (child_database has no editable content)
  return self.raw
end

---Update child database from buffer lines (no-op, child_database is not editable)
---@param lines string[]
function ChildDatabaseBlock:update_from_lines(lines)
  -- No-op: child_database content cannot be changed from buffer
end

---Get current text content
---@return string
function ChildDatabaseBlock:get_text()
  return self.title
end

---Check if content matches given lines
---@param lines string[]
---@return boolean
function ChildDatabaseBlock:matches_content(lines)
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

---Render child database with clickable link appearance
---@param ctx neotion.RenderContext
---@return boolean handled Returns true if rendering was applied
function ChildDatabaseBlock:render(ctx)
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
  ctx:highlight(start_col, end_col, 'NeotionChildDatabase')

  return true
end

---Get the gutter icon for this child database block
---@return string navigation icon
function ChildDatabaseBlock:get_gutter_icon()
  return '->'
end

---Get the database ID for navigation
---@return string database_id
function ChildDatabaseBlock:get_database_id()
  return self.database_id
end

---Check if block has children
---Child databases don't render children inline (users navigate to see content)
---@return boolean always false for child_database
function ChildDatabaseBlock:has_children()
  return false
end

-- Module interface for registry
M.new = ChildDatabaseBlock.new
M.is_editable = function()
  return false
end
M.ChildDatabaseBlock = ChildDatabaseBlock
M.DEFAULT_ICON = DEFAULT_ICON

return M
