---Paragraph Block handler for Neotion
---Fully supported: editable, serializable
---@class neotion.model.blocks.Paragraph
local M = {}

local base = require('neotion.model.block')
local Block = base.Block

---@class neotion.ParagraphBlock : neotion.Block
---@field text string Plain text content
---@field rich_text table[] Original rich_text array (preserved for round-trip)
local ParagraphBlock = setmetatable({}, { __index = Block })
ParagraphBlock.__index = ParagraphBlock

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

---Create a new ParagraphBlock from Notion API JSON
---@param raw table Notion API block JSON
---@return neotion.ParagraphBlock
function ParagraphBlock.new(raw)
  local self = setmetatable(Block.new(raw), ParagraphBlock)

  -- Extract content from paragraph block
  local block_data = raw.paragraph or {}
  self.rich_text = block_data.rich_text or {}
  -- Use Notion syntax with formatting markers for display
  self.text = rich_text_to_notion_syntax(self.rich_text)
  self.original_text = self.text
  self.editable = true -- Paragraph is fully supported

  return self
end

---Format paragraph to buffer lines
---@param opts? {indent?: integer, indent_size?: integer}
---@return string[]
function ParagraphBlock:format(opts)
  opts = opts or {}
  local indent = opts.indent or 0
  local indent_size = opts.indent_size or 2
  local prefix = string.rep(' ', indent * indent_size)

  if self.text == '' then
    return { '' }
  end

  -- Handle multi-line paragraphs (soft breaks from Notion)
  local lines = {}
  for line in (self.text .. '\n'):gmatch('([^\n]*)\n') do
    if line == '' and #lines == 0 then
      table.insert(lines, '')
    else
      table.insert(lines, prefix .. line)
    end
  end

  if #lines == 0 then
    return { prefix .. self.text }
  end

  return lines
end

---Serialize paragraph to Notion API JSON
---@return table Notion API block JSON
function ParagraphBlock:serialize()
  -- Check if text changed from original
  local text_changed = self.text ~= self.original_text

  local result = vim.deepcopy(self.raw)
  result.paragraph = result.paragraph or {}

  if text_changed then
    -- Text changed: create new plain text rich_text
    -- (This loses formatting but preserves content - zero data loss for text)
    result.paragraph.rich_text = {
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
    -- Text unchanged: preserve original rich_text (keeps formatting)
    result.paragraph.rich_text = self.rich_text
  end

  return result
end

---Update paragraph from buffer lines
---@param lines string[]
function ParagraphBlock:update_from_lines(lines)
  local content
  if #lines == 0 then
    content = ''
  elseif #lines == 1 then
    content = vim.trim(lines[1])
  else
    -- Multiple lines = soft breaks in Notion
    local trimmed = {}
    for _, line in ipairs(lines) do
      table.insert(trimmed, vim.trim(line))
    end
    content = table.concat(trimmed, '\n')
  end

  if content ~= self.text then
    self.text = content
    self.dirty = true
  end
end

---Get current text content
---@return string
function ParagraphBlock:get_text()
  return self.text
end

---Check if content matches given lines
---@param lines string[]
---@return boolean
function ParagraphBlock:matches_content(lines)
  local content
  if #lines == 0 then
    content = ''
  elseif #lines == 1 then
    content = vim.trim(lines[1])
  else
    local trimmed = {}
    for _, line in ipairs(lines) do
      table.insert(trimmed, vim.trim(line))
    end
    content = table.concat(trimmed, '\n')
  end
  return content == self.text
end

---Get rich text segments from block's rich_text
---Converts Notion API rich_text format to RichTextSegment array
---@return neotion.RichTextSegment[]
function ParagraphBlock:get_rich_text_segments()
  local rich_text_mod = require('neotion.model.rich_text')
  return rich_text_mod.from_api(self.rich_text)
end

---Format block content with Notion syntax markers
---Returns text with markers like **bold**, *italic*, <c:red>colored</c>
---@return string
function ParagraphBlock:format_with_markers()
  local segments = self:get_rich_text_segments()
  local notion = require('neotion.format.notion')
  return notion.render(segments)
end

-- Module interface for registry
M.new = ParagraphBlock.new
M.is_editable = function()
  return true
end
M.ParagraphBlock = ParagraphBlock

return M
