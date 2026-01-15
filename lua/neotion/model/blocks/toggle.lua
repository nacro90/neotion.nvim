---Toggle Block handler for Neotion
---MVP: Read/edit toggle content, always render collapsed, children deferred
---@class neotion.model.blocks.Toggle
local M = {}

local base = require('neotion.model.block')
local Block = base.Block

---@class neotion.ToggleBlock : neotion.Block
---@field text string Plain text content
---@field rich_text table[] Original rich_text array (preserved for round-trip)
---@field color string Block color (default: "default")
---@field target_type string? Target type for conversion
local ToggleBlock = setmetatable({}, { __index = Block })
ToggleBlock.__index = ToggleBlock

---Extract plain text from rich_text array
---@param rich_text table[]
---@return string
local function rich_text_to_plain(rich_text)
  if not rich_text or type(rich_text) ~= 'table' then
    return ''
  end
  local parts = {}
  for _, text in ipairs(rich_text) do
    if text.plain_text then
      table.insert(parts, text.plain_text)
    end
  end
  return table.concat(parts)
end

---Convert rich_text to Notion syntax with formatting markers
---@param rich_text table[]
---@return string
local function rich_text_to_notion_syntax(rich_text)
  local blocks_api = require('neotion.api.blocks')
  return blocks_api.rich_text_to_notion_syntax(rich_text)
end

---Create a new ToggleBlock from Notion API JSON
---@param raw table Notion API block JSON
---@return neotion.ToggleBlock
function ToggleBlock.new(raw)
  local self = setmetatable(Block.new(raw), ToggleBlock)

  -- Extract content from toggle block
  local block_data = raw.toggle or {}
  self.rich_text = block_data.rich_text or {}
  self.color = block_data.color or 'default'
  -- Use Notion syntax with formatting markers for display
  self.text = rich_text_to_notion_syntax(self.rich_text)
  self.original_text = self.text
  self.editable = true -- Toggle content is editable

  return self
end

---Format toggle to buffer lines
---@param opts? {indent?: integer, indent_size?: integer}
---@return string[]
function ToggleBlock:format(opts)
  opts = opts or {}
  local indent = opts.indent or 0
  local indent_size = opts.indent_size or 2
  local prefix = string.rep(' ', indent * indent_size)

  -- Toggle format: "> text"
  return { prefix .. '> ' .. self.text }
end

---Serialize toggle to Notion API JSON
---@return table Notion API block JSON
function ToggleBlock:serialize()
  -- Check if text changed from original
  local text_changed = self.text ~= self.original_text

  local result = vim.deepcopy(self.raw)
  result.toggle = result.toggle or {}

  if text_changed then
    -- Text changed: parse markers to rich_text format
    local notion = require('neotion.format.notion')
    result.toggle.rich_text = notion.parse_to_api(self.text)
  else
    -- Text unchanged: preserve original rich_text
    result.toggle.rich_text = self.rich_text
  end

  return result
end

---Update toggle from buffer lines
---@param lines string[]
function ToggleBlock:update_from_lines(lines)
  local content
  if #lines == 0 then
    content = ''
  else
    -- Take first line only (toggle is single-line in buffer)
    local line = vim.trim(lines[1])
    -- Strip "> " prefix if present
    if line:sub(1, 2) == '> ' then
      content = line:sub(3)
    else
      content = line
    end
  end

  if content ~= self.text then
    self.text = content
    self.dirty = true
  end

  -- Detect type conversion (toggle without "> " prefix becomes paragraph)
  local detection = require('neotion.model.blocks.detection')
  local first_line = #lines > 0 and vim.trim(lines[1]) or ''
  local should_convert, target = detection.should_convert('toggle', first_line)
  if should_convert and target then
    self.target_type = target
    self.dirty = true
  else
    self.target_type = nil
  end
end

---Get current text content
---@return string
function ToggleBlock:get_text()
  return self.text
end

---Check if this is an empty toggle
---@return boolean
function ToggleBlock:is_empty_paragraph()
  return self.text == nil or self.text == ''
end

---Check if block type has changed
---@return boolean
function ToggleBlock:type_changed()
  return self.target_type ~= nil
end

---Get the effective block type (target type if converting)
---@return string
function ToggleBlock:get_type()
  return self.target_type or self.type
end

---Get the stripped content (without prefix) for type conversion
---@return string
function ToggleBlock:get_converted_content()
  if not self.target_type then
    return self.text
  end
  local detection = require('neotion.model.blocks.detection')
  local _, prefix = detection.detect_type(self.text)
  if prefix then
    return detection.strip_prefix(self.text, prefix)
  end
  return self.text
end

---Check if content matches given lines
---@param lines string[]
---@return boolean
function ToggleBlock:matches_content(lines)
  if #lines == 0 then
    return self.text == ''
  end
  local line = vim.trim(lines[1])
  -- Strip "> " prefix if present
  if line:sub(1, 2) == '> ' then
    line = line:sub(3)
  end
  return line == self.text
end

---Get rich text segments from block's rich_text
---@return neotion.RichTextSegment[]
function ToggleBlock:get_rich_text_segments()
  local rich_text_mod = require('neotion.model.rich_text')
  return rich_text_mod.from_api(self.rich_text)
end

---Format block content with Notion syntax markers
---@return string
function ToggleBlock:format_with_markers()
  local segments = self:get_rich_text_segments()
  local notion = require('neotion.format.notion')
  return notion.render(segments)
end

---Get the gutter icon for this toggle block
---MVP: Always return collapsed icon (expand/collapse deferred)
---@return string
function ToggleBlock:get_gutter_icon()
  local icons = require('neotion.render.icons')
  local config = require('neotion.config')
  return icons.get_toggle_icon(false, config.get().icons)
end

---Override has_children to return false for MVP
---Children rendering deferred to future phase
---@return boolean
function ToggleBlock:has_children()
  return false
end

-- Module interface for registry
M.new = ToggleBlock.new
M.is_editable = function()
  return true
end
M.ToggleBlock = ToggleBlock

return M
