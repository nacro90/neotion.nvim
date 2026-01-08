---Numbered List Item Block handler for Neotion
---Editable numbered point with rich text support (flat, no nesting)
---@class neotion.model.blocks.NumberedList
local M = {}

local base = require('neotion.model.block')
local Block = base.Block

-- Pattern for matching numbered prefix (e.g., "1. ", "23. ")
-- Exported for external use (e.g., detection module)
local NUMBER_PREFIX_PATTERN = '^(%d+)%. '

---@class neotion.NumberedListBlock : neotion.Block
---@field text string Plain text content (with formatting markers)
---@field rich_text table[] Original rich_text array (preserved for round-trip)
---@field color string Block color
---@field original_text string Text at creation (for change detection)
---@field target_type string? Target type for conversion
---@field number integer The display number for this list item
local NumberedListBlock = setmetatable({}, { __index = Block })
NumberedListBlock.__index = NumberedListBlock

---Convert rich_text to Notion syntax with formatting markers
---@param rich_text table[]
---@return string
local function rich_text_to_notion_syntax(rich_text)
  local blocks_api = require('neotion.api.blocks')
  return blocks_api.rich_text_to_notion_syntax(rich_text)
end

---Strip numbered prefix from line
---Handles "1. ", "23. " etc. prefixes (space after dot required per markdown standard)
---@param line string
---@return string
local function strip_prefix(line)
  -- Try numbered prefix (e.g., "1. text", "23. text")
  local text = line:match('^%d+%. (.*)$')
  if text then
    return text
  end

  -- No recognized prefix, return as-is
  return line
end

---Create a new NumberedListBlock from Notion API JSON
---@param raw table Notion API block JSON
---@return neotion.NumberedListBlock
function NumberedListBlock.new(raw)
  local self = setmetatable(Block.new(raw), NumberedListBlock)

  -- Extract content from numbered_list_item block
  local block_data = raw.numbered_list_item or {}
  self.rich_text = block_data.rich_text or {}
  self.color = block_data.color or 'default'

  -- Use Notion syntax with formatting markers for display
  self.text = rich_text_to_notion_syntax(self.rich_text)
  self.original_text = self.text
  self.editable = true

  -- Notion doesn't store the number - it's determined by position
  -- Default to 1, can be updated by buffer manager
  self.number = 1

  return self
end

---Format numbered item to buffer lines
---Handles multi-line content - first line gets number prefix, rest are indented
---@param opts? {indent?: integer, indent_size?: integer}
---@return string[]
function NumberedListBlock:format(opts)
  local prefix = tostring(self.number) .. '. '
  -- Continuation lines get spaces matching prefix length
  local continuation_prefix = string.rep(' ', #prefix)

  if self.text == '' then
    return { prefix }
  end

  -- Handle multi-line content (soft breaks from Notion)
  local lines = {}
  local is_first = true
  for line in (self.text .. '\n'):gmatch('([^\n]*)\n') do
    if is_first then
      table.insert(lines, prefix .. line)
      is_first = false
    else
      table.insert(lines, continuation_prefix .. line)
    end
  end

  return lines
end

---Serialize numbered item to Notion API JSON
---@return table Notion API block JSON
function NumberedListBlock:serialize()
  local text_changed = self.text ~= self.original_text

  local result = vim.deepcopy(self.raw)

  -- Ensure numbered_list_item key exists
  result.numbered_list_item = result.numbered_list_item or {}

  if text_changed then
    -- Text changed: parse markers to rich_text format
    local notion = require('neotion.format.notion')
    result.numbered_list_item.rich_text = notion.parse_to_api(self.text)
  else
    -- Text unchanged: preserve original rich_text
    result.numbered_list_item.rich_text = self.rich_text
  end

  -- Always preserve color
  result.numbered_list_item.color = self.color

  return result
end

---Update numbered item from buffer lines
---@param lines string[]
function NumberedListBlock:update_from_lines(lines)
  if #lines == 0 then
    return
  end

  -- Handle multi-line content
  local content_lines = {}
  for i, line in ipairs(lines) do
    if i == 1 then
      -- First line: strip number prefix
      table.insert(content_lines, strip_prefix(line))
    else
      -- Continuation lines: strip leading spaces (indent)
      local stripped = line:match('^%s*(.*)$') or line
      table.insert(content_lines, stripped)
    end
  end

  local new_text = table.concat(content_lines, '\n')

  if new_text ~= self.text then
    self.text = new_text
    self.dirty = true
  end

  -- Detect type conversion
  local line = lines[1]
  local detection = require('neotion.model.blocks.detection')
  local should_convert, target = detection.should_convert('numbered_list_item', line)
  if should_convert and target then
    self.target_type = target
    -- Store the content without any prefix for conversion
    if target == 'paragraph' then
      self.text = line -- No prefix stripping for paragraph
    end
    self.dirty = true
  else
    self.target_type = nil
  end
end

---Get current text content (without prefix)
---@return string
function NumberedListBlock:get_text()
  return self.text
end

---Set the display number for this list item
---@param num integer
function NumberedListBlock:set_number(num)
  self.number = num
end

---Check if block type has changed
---@return boolean
function NumberedListBlock:type_changed()
  return self.target_type ~= nil
end

---Get the effective block type (target type if converting)
---@return string
function NumberedListBlock:get_type()
  return self.target_type or self.type
end

---Get content for conversion (strips prefix for target type)
---@return string
function NumberedListBlock:get_converted_content()
  if not self.target_type then
    return self.text
  end

  -- When converting to another type, strip any detected prefix
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
function NumberedListBlock:matches_content(lines)
  if #lines == 0 then
    return self.text == ''
  end

  local line = lines[1]
  local text = strip_prefix(line)

  return text == self.text
end

---Render numbered item (uses default text-based rendering)
---@param ctx neotion.RenderContext
---@return boolean handled
function NumberedListBlock:render(ctx)
  -- Numbered item uses default text rendering with inline formatting
  return false
end

---List items have no spacing after (they're grouped)
---Spacing is added at the end of the list group by render logic
---@return integer
function NumberedListBlock:spacing_after()
  return 0
end

---Check if block has children (nesting not supported)
---@return boolean
function NumberedListBlock:has_children()
  -- Children/nesting support deferred
  return false
end

---Get rich text segments from block's rich_text
---Converts Notion API rich_text format to RichTextSegment array
---@return neotion.RichTextSegment[]
function NumberedListBlock:get_rich_text_segments()
  local rich_text_mod = require('neotion.model.rich_text')
  return rich_text_mod.from_api(self.rich_text)
end

---Format block content with Notion syntax markers
---@return string
function NumberedListBlock:format_with_markers()
  local segments = self:get_rich_text_segments()
  local notion = require('neotion.format.notion')
  return notion.render(segments)
end

---Get the gutter icon for this numbered list block
---@return string numbered icon
function NumberedListBlock:get_gutter_icon()
  return '#'
end

-- Module interface for registry
M.new = NumberedListBlock.new
M.is_editable = function()
  return true
end
M.NumberedListBlock = NumberedListBlock
M.NUMBER_PREFIX_PATTERN = NUMBER_PREFIX_PATTERN

return M
