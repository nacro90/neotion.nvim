---Bulleted List Item Block handler for Neotion
---Editable bullet point with rich text support (flat, no nesting)
---@class neotion.model.blocks.BulletedList
local M = {}

local base = require('neotion.model.block')
local Block = base.Block

-- Bullet prefix for buffer display
local BULLET_PREFIX = '- '

---@class neotion.BulletedListBlock : neotion.Block
---@field text string Plain text content (with formatting markers)
---@field rich_text table[] Original rich_text array (preserved for round-trip)
---@field color string Block color
---@field original_text string Text at creation (for change detection)
---@field target_type string? Target type for conversion (Phase 5.8)
local BulletedListBlock = setmetatable({}, { __index = Block })
BulletedListBlock.__index = BulletedListBlock

---Convert rich_text to Notion syntax with formatting markers
---@param rich_text table[]
---@return string
local function rich_text_to_notion_syntax(rich_text)
  local blocks_api = require('neotion.api.blocks')
  return blocks_api.rich_text_to_notion_syntax(rich_text)
end

---Strip bullet prefix from line
---Handles -, *, + prefixes
---@param line string
---@return string
local function strip_prefix(line)
  -- Try - prefix (primary)
  local text = line:match('^%-%s(.*)$')
  if text then
    return text
  end

  -- Try - with no space
  text = line:match('^%-(.+)$')
  if text then
    return text
  end

  -- Try * prefix
  text = line:match('^%*%s(.*)$')
  if text then
    return text
  end

  -- Try * with no space
  text = line:match('^%*(.+)$')
  if text then
    return text
  end

  -- Try + prefix
  text = line:match('^%+%s(.*)$')
  if text then
    return text
  end

  -- Try + with no space
  text = line:match('^%+(.+)$')
  if text then
    return text
  end

  -- No recognized prefix, return as-is
  return line
end

---Create a new BulletedListBlock from Notion API JSON
---@param raw table Notion API block JSON
---@return neotion.BulletedListBlock
function BulletedListBlock.new(raw)
  local self = setmetatable(Block.new(raw), BulletedListBlock)

  -- Extract content from bulleted_list_item block
  local block_data = raw.bulleted_list_item or {}
  self.rich_text = block_data.rich_text or {}
  self.color = block_data.color or 'default'

  -- Use Notion syntax with formatting markers for display
  self.text = rich_text_to_notion_syntax(self.rich_text)
  self.original_text = self.text
  self.editable = true

  return self
end

---Format bullet to buffer lines
---Handles multi-line content (soft breaks from Notion) - first line gets bullet prefix, rest are indented
---@param opts? {indent?: integer, indent_size?: integer}
---@return string[]
function BulletedListBlock:format(opts)
  -- Continuation lines get 2-space indent to align with bullet content
  local continuation_prefix = '  '

  if self.text == '' then
    return { BULLET_PREFIX }
  end

  -- Handle multi-line content (soft breaks from Notion)
  local lines = {}
  local is_first = true
  for line in (self.text .. '\n'):gmatch('([^\n]*)\n') do
    if is_first then
      table.insert(lines, BULLET_PREFIX .. line)
      is_first = false
    else
      table.insert(lines, continuation_prefix .. line)
    end
  end

  return lines
end

---Serialize bullet to Notion API JSON
---@return table Notion API block JSON
function BulletedListBlock:serialize()
  local text_changed = self.text ~= self.original_text

  local result = vim.deepcopy(self.raw)

  -- Ensure bulleted_list_item key exists
  result.bulleted_list_item = result.bulleted_list_item or {}

  if text_changed then
    -- Text changed: parse markers to rich_text format
    local notion = require('neotion.format.notion')
    result.bulleted_list_item.rich_text = notion.parse_to_api(self.text)
  else
    -- Text unchanged: preserve original rich_text
    result.bulleted_list_item.rich_text = self.rich_text
  end

  -- Always preserve color
  result.bulleted_list_item.color = self.color

  return result
end

---Update bullet from buffer lines
---@param lines string[]
function BulletedListBlock:update_from_lines(lines)
  if #lines == 0 then
    return
  end

  local line = lines[1]
  local new_text = strip_prefix(line)

  if new_text ~= self.text then
    self.text = new_text
    self.dirty = true
  end

  -- Phase 5.8: Detect type conversion
  -- Check if the prefix was removed or changed to a different type
  local detection = require('neotion.model.blocks.detection')
  local should_convert, target = detection.should_convert('bulleted_list_item', line)
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
function BulletedListBlock:get_text()
  return self.text
end

---Check if block type has changed (Phase 5.8)
---@return boolean
function BulletedListBlock:type_changed()
  return self.target_type ~= nil
end

---Get the effective block type (target type if converting)
---@return string
function BulletedListBlock:get_type()
  return self.target_type or self.type
end

---Get content for conversion (strips prefix for target type)
---@return string
function BulletedListBlock:get_converted_content()
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
function BulletedListBlock:matches_content(lines)
  if #lines == 0 then
    return self.text == ''
  end

  local line = lines[1]
  local text = strip_prefix(line)

  return text == self.text
end

---Render bullet (uses default text-based rendering)
---@param ctx neotion.RenderContext
---@return boolean handled
function BulletedListBlock:render(ctx)
  -- Bullet uses default text rendering with inline formatting
  return false
end

---List items have no spacing after (they're grouped)
---Spacing is added at the end of the list group by render logic
---@return integer
function BulletedListBlock:spacing_after()
  return 0
end

---Check if block has children (nesting not supported in Phase 5.7)
---@return boolean
function BulletedListBlock:has_children()
  -- Children/nesting support deferred to Phase 9
  return false
end

---Get rich text segments from block's rich_text
---Converts Notion API rich_text format to RichTextSegment array
---@return neotion.RichTextSegment[]
function BulletedListBlock:get_rich_text_segments()
  local rich_text_mod = require('neotion.model.rich_text')
  return rich_text_mod.from_api(self.rich_text)
end

---Format block content with Notion syntax markers
---@return string
function BulletedListBlock:format_with_markers()
  local segments = self:get_rich_text_segments()
  local notion = require('neotion.format.notion')
  return notion.render(segments)
end

---Get the gutter icon for this bulleted list block
---@return string bullet icon
function BulletedListBlock:get_gutter_icon()
  return '•'
end

-- Module interface for registry
M.new = BulletedListBlock.new
M.is_editable = function()
  return true
end
M.BulletedListBlock = BulletedListBlock
M.BULLET_PREFIX = BULLET_PREFIX

return M
