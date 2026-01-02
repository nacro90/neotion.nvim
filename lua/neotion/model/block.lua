---Base Block class for Neotion
---All block types inherit from this base class
---Unsupported blocks use this directly (read-only)
---@class neotion.model.Block
local M = {}

---@class neotion.Block
---@field id string Block ID from Notion
---@field type neotion.BlockType Block type (paragraph, heading_1, etc.)
---@field raw table Original Notion JSON (preserved for round-trip)
---@field parent_id string|nil Parent block ID
---@field depth integer Nesting level (0 = top-level)
---@field editable boolean Whether this block can be edited
---@field dirty boolean Has unsaved changes
---@field line_start integer|nil Buffer line start (1-indexed)
---@field line_end integer|nil Buffer line end (1-indexed)
---@field original_text string Text content at last sync (for change detection)
local Block = {}
Block.__index = Block

---Create a new Block from Notion API JSON
---@param raw table Notion API block JSON
---@return neotion.Block
function Block.new(raw)
  vim.validate({
    raw = { raw, 'table' },
  })

  local self = setmetatable({}, Block)
  self.id = raw.id or ''
  self.type = raw.type or 'unsupported'
  self.raw = raw -- Preserve original JSON for round-trip
  self.parent_id = raw.parent and raw.parent.block_id or nil
  self.depth = 0
  self.editable = false -- Default: read-only (override in subclasses)
  self.dirty = false
  self.line_start = nil
  self.line_end = nil
  self.original_text = ''
  return self
end

---Get block ID
---@return string
function Block:get_id()
  return self.id
end

---Get block type
---@return string
function Block:get_type()
  return self.type
end

---Check if block is editable
---@return boolean
function Block:is_editable()
  return self.editable
end

---Check if block has unsaved changes
---@return boolean
function Block:is_dirty()
  return self.dirty
end

---Mark block as dirty (has changes)
---@param dirty boolean
function Block:set_dirty(dirty)
  self.dirty = dirty
end

---Set buffer line range for this block
---@param line_start integer 1-indexed start line
---@param line_end integer 1-indexed end line
function Block:set_line_range(line_start, line_end)
  self.line_start = line_start
  self.line_end = line_end
end

---Get buffer line range
---@return integer|nil line_start
---@return integer|nil line_end
function Block:get_line_range()
  return self.line_start, self.line_end
end

---Check if a line is within this block's range
---@param line integer 1-indexed line number
---@return boolean
function Block:contains_line(line)
  if not self.line_start or not self.line_end then
    return false
  end
  return line >= self.line_start and line <= self.line_end
end

---Format block to buffer lines (default: placeholder for unsupported)
---@param opts? {indent?: integer, indent_size?: integer}
---@return string[]
function Block:format(opts)
  opts = opts or {}
  local indent = opts.indent or 0
  local indent_size = opts.indent_size or 2
  local prefix = string.rep(' ', indent * indent_size)
  return { prefix .. '[' .. self.type .. ' - read only]' }
end

---Serialize block to Notion API JSON (default: passthrough original)
---@return table Notion API block JSON
function Block:serialize()
  -- For unsupported blocks, return original JSON unchanged
  return self.raw
end

---Update block from buffer lines (default: no-op for read-only)
---@param lines string[]
function Block:update_from_lines(lines)
  -- Read-only blocks don't update
  -- Override in editable subclasses
end

---Get current text content
---@return string
function Block:get_text()
  return ''
end

---Check if block content matches given lines
---@param lines string[]
---@return boolean
function Block:matches_content(lines)
  -- Default: always matches (read-only blocks don't change)
  return true
end

---Check if block has children
---@return boolean
function Block:has_children()
  return self.raw.has_children or false
end

---Check if block type has changed (requires delete+create instead of update)
---Override in subclasses that support type changes (e.g., heading level)
---@return boolean
function Block:type_changed()
  return false
end

M.Block = Block

return M
