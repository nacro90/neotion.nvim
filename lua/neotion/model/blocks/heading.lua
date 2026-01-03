---Heading Block handler for Neotion
---Supports heading_1, heading_2, heading_3
---Fully supported: editable, serializable
---@class neotion.model.blocks.Heading
local M = {}

local base = require('neotion.model.block')
local Block = base.Block

---@class neotion.HeadingBlock : neotion.Block
---@field level integer 1, 2, or 3
---@field original_level integer Level at creation (for detecting type change)
---@field text string Plain text content
---@field rich_text table[] Original rich_text array (preserved for round-trip)
local HeadingBlock = setmetatable({}, { __index = Block })
HeadingBlock.__index = HeadingBlock

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

---Create a new HeadingBlock from Notion API JSON
---@param raw table Notion API block JSON
---@return neotion.HeadingBlock
function HeadingBlock.new(raw)
  local self = setmetatable(Block.new(raw), HeadingBlock)

  -- Determine heading level
  if raw.type == 'heading_1' then
    self.level = 1
  elseif raw.type == 'heading_2' then
    self.level = 2
  elseif raw.type == 'heading_3' then
    self.level = 3
  else
    self.level = 1 -- Fallback
  end

  -- Store original level for detecting type changes
  self.original_level = self.level

  -- Extract content from heading block
  local block_data = raw[raw.type] or {}
  self.rich_text = block_data.rich_text or {}
  -- Use Notion syntax with formatting markers for display
  self.text = rich_text_to_notion_syntax(self.rich_text)
  self.original_text = self.text
  self.editable = true -- Heading is fully supported

  return self
end

---Check if heading level (type) has changed
---Notion API doesn't support type changes, so we need delete+create
---@return boolean
function HeadingBlock:type_changed()
  return self.level ~= self.original_level
end

---Format heading to buffer lines
---@param opts? {indent?: integer, indent_size?: integer}
---@return string[]
function HeadingBlock:format(opts)
  opts = opts or {}
  local indent = opts.indent or 0
  local indent_size = opts.indent_size or 2
  local prefix = string.rep(' ', indent * indent_size)
  local heading_prefix = string.rep('#', self.level) .. ' '

  return { prefix .. heading_prefix .. self.text }
end

---Serialize heading to Notion API JSON
---@return table Notion API block JSON
function HeadingBlock:serialize()
  -- Check if text changed from original
  local text_changed = self.text ~= self.original_text

  local result = vim.deepcopy(self.raw)
  local new_block_key = 'heading_' .. self.level
  local original_block_key = self.raw.type

  -- Handle level change: remove old key, update type
  if new_block_key ~= original_block_key then
    -- Remove old heading data
    result[original_block_key] = nil
    -- Update block type
    result.type = new_block_key
  end

  -- Ensure new heading key exists
  result[new_block_key] = result[new_block_key] or {}

  if text_changed or new_block_key ~= original_block_key then
    -- Text or level changed: create new plain text rich_text
    result[new_block_key].rich_text = {
      {
        type = 'text',
        text = { content = self.text, link = nil },
        plain_text = self.text,
        href = nil,
        annotations = {
          bold = false,
          italic = false,
          strikethrough = false,
          underline = false,
          code = false,
          color = 'default',
        },
      },
    }
  else
    -- Text unchanged: preserve original rich_text
    result[new_block_key].rich_text = self.rich_text
  end

  return result
end

---Update heading from buffer lines
---@param lines string[]
function HeadingBlock:update_from_lines(lines)
  if #lines == 0 then
    return
  end

  local line = vim.trim(lines[1])

  -- Parse heading prefix (# ## ###) and extract level + text
  local hashes, text = line:match('^(#+)%s*(.*)$')
  if hashes then
    -- Update level if changed (cap at 3)
    local new_level = math.min(#hashes, 3)
    if new_level ~= self.level then
      self.level = new_level
      self.type = 'heading_' .. new_level -- Update block type
      self.dirty = true
    end
    -- Update text if changed
    if text ~= self.text then
      self.text = text
      self.dirty = true
    end
  else
    -- No prefix found, update text only
    if line ~= self.text then
      self.text = line
      self.dirty = true
    end
  end
end

---Get current text content
---@return string
function HeadingBlock:get_text()
  return self.text
end

---Check if content matches given lines
---@param lines string[]
---@return boolean
function HeadingBlock:matches_content(lines)
  if #lines == 0 then
    return self.text == ''
  end

  local line = vim.trim(lines[1])
  local text = line:match('^#+%s*(.*)$') or line

  return text == self.text
end

---Get rich text segments from block's rich_text
---Converts Notion API rich_text format to RichTextSegment array
---@return neotion.RichTextSegment[]
function HeadingBlock:get_rich_text_segments()
  local rich_text_mod = require('neotion.model.rich_text')
  return rich_text_mod.from_api(self.rich_text)
end

---Format block content with Notion syntax markers
---Returns text with markers like **bold**, *italic*, <c:red>colored</c>
---@return string
function HeadingBlock:format_with_markers()
  local segments = self:get_rich_text_segments()
  local notion = require('neotion.format.notion')
  return notion.render(segments)
end

-- Module interface for registry
M.new = HeadingBlock.new
M.is_editable = function()
  return true
end
M.HeadingBlock = HeadingBlock

return M
