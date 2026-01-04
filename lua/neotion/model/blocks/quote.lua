---Quote Block handler for Neotion
---Editable block quote with rich text support
---@class neotion.model.blocks.Quote
local M = {}

local base = require('neotion.model.block')
local Block = base.Block

-- Quote prefix for buffer display
local QUOTE_PREFIX = '| '

---@class neotion.QuoteBlock : neotion.Block
---@field text string Plain text content (with formatting markers)
---@field rich_text table[] Original rich_text array (preserved for round-trip)
---@field color string Block color
---@field original_text string Text at creation (for change detection)
local QuoteBlock = setmetatable({}, { __index = Block })
QuoteBlock.__index = QuoteBlock

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

---Strip quote prefix from line
---Handles both | and > prefixes
---@param line string
---@return string
local function strip_prefix(line)
  -- Try | prefix (primary)
  local text = line:match('^|%s?(.*)$')
  if text then
    return text
  end

  -- Try > prefix (alternative, for markdown compatibility)
  text = line:match('^>%s?(.*)$')
  if text then
    return text
  end

  -- No recognized prefix, return as-is
  return line
end

---Create a new QuoteBlock from Notion API JSON
---@param raw table Notion API block JSON
---@return neotion.QuoteBlock
function QuoteBlock.new(raw)
  local self = setmetatable(Block.new(raw), QuoteBlock)

  -- Extract content from quote block
  local block_data = raw.quote or {}
  self.rich_text = block_data.rich_text or {}
  self.color = block_data.color or 'default'

  -- Use Notion syntax with formatting markers for display
  self.text = rich_text_to_notion_syntax(self.rich_text)
  self.original_text = self.text
  self.editable = true

  return self
end

---Format quote to buffer lines
---@param opts? {indent?: integer, indent_size?: integer}
---@return string[]
function QuoteBlock:format(opts)
  return { QUOTE_PREFIX .. self.text }
end

---Serialize quote to Notion API JSON
---@return table Notion API block JSON
function QuoteBlock:serialize()
  local text_changed = self.text ~= self.original_text

  local result = vim.deepcopy(self.raw)

  -- Ensure quote key exists
  result.quote = result.quote or {}

  if text_changed then
    -- Text changed: parse markers to rich_text format
    local notion = require('neotion.format.notion')
    result.quote.rich_text = notion.parse_to_api(self.text)
  else
    -- Text unchanged: preserve original rich_text
    result.quote.rich_text = self.rich_text
  end

  -- Always preserve color
  result.quote.color = self.color

  return result
end

---Update quote from buffer lines
---@param lines string[]
function QuoteBlock:update_from_lines(lines)
  if #lines == 0 then
    return
  end

  local line = lines[1]
  local new_text = strip_prefix(line)

  if new_text ~= self.text then
    self.text = new_text
    self.dirty = true
  end
end

---Get current text content (without prefix)
---@return string
function QuoteBlock:get_text()
  -- Return current text (may include formatting markers after edit)
  return self.text
end

---Check if content matches given lines
---@param lines string[]
---@return boolean
function QuoteBlock:matches_content(lines)
  if #lines == 0 then
    return self.text == ''
  end

  local line = lines[1]
  local text = strip_prefix(line)

  return text == self.text
end

---Render quote (uses default text-based rendering)
---@param ctx neotion.RenderContext
---@return boolean handled
function QuoteBlock:render(ctx)
  -- Quote uses default text rendering with inline formatting
  -- The | prefix is part of the buffer content
  return false
end

---Check if block has children (not supported in Phase 5.7)
---@return boolean
function QuoteBlock:has_children()
  -- Children support deferred to Phase 9
  return false
end

---Get rich text segments from block's rich_text
---Converts Notion API rich_text format to RichTextSegment array
---@return neotion.RichTextSegment[]
function QuoteBlock:get_rich_text_segments()
  local rich_text_mod = require('neotion.model.rich_text')
  return rich_text_mod.from_api(self.rich_text)
end

---Format block content with Notion syntax markers
---Returns text with markers like **bold**, *italic*, <c:red>colored</c>
---@return string
function QuoteBlock:format_with_markers()
  local segments = self:get_rich_text_segments()
  local notion = require('neotion.format.notion')
  return notion.render(segments)
end

-- Module interface for registry
M.new = QuoteBlock.new
M.is_editable = function()
  return true
end
M.QuoteBlock = QuoteBlock
M.QUOTE_PREFIX = QUOTE_PREFIX

return M
