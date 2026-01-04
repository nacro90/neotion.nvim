--- Format types for neotion.nvim
--- Defines Annotation and RichTextSegment types for inline formatting
---@module 'neotion.format.types'

local M = {}

---@alias neotion.ColorValue
---| 'default'
---| 'red' | 'blue' | 'green' | 'yellow' | 'orange' | 'pink' | 'purple' | 'brown' | 'gray'
---| 'red_background' | 'blue_background' | 'green_background' | 'yellow_background'
---| 'orange_background' | 'pink_background' | 'purple_background' | 'brown_background' | 'gray_background'

--- Color utilities
---@class neotion.ColorValueUtils
M.ColorValue = {}

---@type table<string, boolean>
local VALID_COLORS = {
  default = true,
  -- Foreground colors
  red = true,
  blue = true,
  green = true,
  yellow = true,
  orange = true,
  pink = true,
  purple = true,
  brown = true,
  gray = true,
  -- Background colors
  red_background = true,
  blue_background = true,
  green_background = true,
  yellow_background = true,
  orange_background = true,
  pink_background = true,
  purple_background = true,
  brown_background = true,
  gray_background = true,
}

--- Check if a color value is valid
---@param color any
---@return boolean
function M.ColorValue.is_valid(color)
  if type(color) ~= 'string' then
    return false
  end
  return VALID_COLORS[color] == true
end

--- Check if a color is a background color
---@param color string
---@return boolean
function M.ColorValue.is_background(color)
  return type(color) == 'string' and color:match('_background$') ~= nil
end

--- Convert color to highlight group name
---@param color string
---@return string|nil
function M.ColorValue.to_highlight_name(color)
  if color == 'default' then
    return nil
  end

  if M.ColorValue.is_background(color) then
    -- red_background -> NeotionColorRedBg
    local base = color:gsub('_background$', '')
    local capitalized = base:sub(1, 1):upper() .. base:sub(2)
    return 'NeotionColor' .. capitalized .. 'Bg'
  else
    -- red -> NeotionColorRed
    local capitalized = color:sub(1, 1):upper() .. color:sub(2)
    return 'NeotionColor' .. capitalized
  end
end

--- Get all valid color values
---@return string[]
function M.ColorValue.all()
  local colors = {}
  for color, _ in pairs(VALID_COLORS) do
    table.insert(colors, color)
  end
  table.sort(colors)
  return colors
end

--------------------------------------------------------------------------------
-- Annotation
--------------------------------------------------------------------------------

---@class neotion.Annotation
---@field bold boolean
---@field italic boolean
---@field strikethrough boolean
---@field underline boolean
---@field code boolean
---@field color neotion.ColorValue
local Annotation = {}
Annotation.__index = Annotation

M.Annotation = Annotation

---@class neotion.AnnotationOpts
---@field bold? boolean
---@field italic? boolean
---@field strikethrough? boolean
---@field underline? boolean
---@field code? boolean
---@field color? neotion.ColorValue

--- Create a new Annotation
---@param opts? neotion.AnnotationOpts
---@return neotion.Annotation
function Annotation.new(opts)
  opts = opts or {}
  local self = setmetatable({}, Annotation)

  self.bold = opts.bold or false
  self.italic = opts.italic or false
  self.strikethrough = opts.strikethrough or false
  self.underline = opts.underline or false
  self.code = opts.code or false
  self.color = opts.color or 'default'

  return self
end

--- Create Annotation from Notion API format
---@param api_annotation? table
---@return neotion.Annotation
function Annotation.from_api(api_annotation)
  if not api_annotation then
    return Annotation.new()
  end

  return Annotation.new({
    bold = api_annotation.bold or false,
    italic = api_annotation.italic or false,
    strikethrough = api_annotation.strikethrough or false,
    underline = api_annotation.underline or false,
    code = api_annotation.code or false,
    color = api_annotation.color or 'default',
  })
end

--- Convert to Notion API format
---@return table
function Annotation:to_api()
  return {
    bold = self.bold,
    italic = self.italic,
    strikethrough = self.strikethrough,
    underline = self.underline,
    code = self.code,
    color = self.color,
  }
end

--- Check if annotation has default values (no formatting)
---@return boolean
function Annotation:is_default()
  return not self.bold
    and not self.italic
    and not self.strikethrough
    and not self.underline
    and not self.code
    and self.color == 'default'
end

--- Check if annotation has any formatting applied
---@return boolean
function Annotation:has_formatting()
  return self.bold or self.italic or self.strikethrough or self.underline or self.code or self.color ~= 'default'
end

--- Check equality with another annotation
---@param other neotion.Annotation
---@return boolean
function Annotation:equals(other)
  return self.bold == other.bold
    and self.italic == other.italic
    and self.strikethrough == other.strikethrough
    and self.underline == other.underline
    and self.code == other.code
    and self.color == other.color
end

--- Clone this annotation
---@return neotion.Annotation
function Annotation:clone()
  return Annotation.new({
    bold = self.bold,
    italic = self.italic,
    strikethrough = self.strikethrough,
    underline = self.underline,
    code = self.code,
    color = self.color,
  })
end

--------------------------------------------------------------------------------
-- RichTextSegment
--------------------------------------------------------------------------------

---@class neotion.RichTextSegment
---@field text string
---@field annotations neotion.Annotation
---@field href? string
---@field start_col integer 0-indexed
---@field end_col integer 0-indexed, exclusive
local RichTextSegment = {}
RichTextSegment.__index = RichTextSegment

M.RichTextSegment = RichTextSegment

---@class neotion.RichTextSegmentOpts
---@field annotations? neotion.Annotation
---@field href? string
---@field start_col? integer

--- Create a new RichTextSegment
---@param text string
---@param opts? neotion.RichTextSegmentOpts
---@return neotion.RichTextSegment
function RichTextSegment.new(text, opts)
  opts = opts or {}
  local self = setmetatable({}, RichTextSegment)

  self.text = text
  self.annotations = opts.annotations or Annotation.new()
  self.href = opts.href
  self.start_col = opts.start_col or 0
  self.end_col = self.start_col + #text

  return self
end

--- Create RichTextSegment from Notion API rich_text item
---@param api_item table
---@param start_col? integer
---@return neotion.RichTextSegment
function RichTextSegment.from_api(api_item, start_col)
  local text = api_item.plain_text or ''
  local annotations = Annotation.from_api(api_item.annotations)
  local href = api_item.href

  -- Normalize vim.NIL (userdata from JSON decode) to nil
  if href == vim.NIL then
    href = nil
  end

  -- Handle text type with link
  -- Note: api_item.text.link can be vim.NIL (userdata) from JSON decode
  if api_item.type == 'text' and api_item.text then
    local link = api_item.text.link
    if link and type(link) == 'table' and link.url then
      href = link.url
    end
  end

  return RichTextSegment.new(text, {
    annotations = annotations,
    href = href,
    start_col = start_col or 0,
  })
end

--- Convert internal notion:// scheme to Notion API URL
---@param href string
---@return string
local function normalize_href_for_api(href)
  -- notion://page/id → https://www.notion.so/id
  -- Pattern accepts both compact (abc123) and hyphenated (abc-123-def) UUIDs
  local page_id = href:match('^notion://page/([a-zA-Z0-9%-]+)$')
  if page_id then
    return 'https://www.notion.so/' .. page_id
  end

  -- notion://block/id → https://www.notion.so/id (block anchor not supported by API)
  local block_id = href:match('^notion://block/([a-zA-Z0-9%-]+)$')
  if block_id then
    return 'https://www.notion.so/' .. block_id
  end

  -- Already a valid URL, return as-is
  return href
end

--- Convert to Notion API format
---@return table
function RichTextSegment:to_api()
  local api_href = self.href and normalize_href_for_api(self.href) or nil

  local result = {
    type = 'text',
    text = {
      content = self.text,
      link = api_href and { url = api_href } or nil,
    },
    plain_text = self.text,
    annotations = self.annotations:to_api(),
  }

  if api_href then
    result.href = api_href
  end

  return result
end

--- Get text length
---@return integer
function RichTextSegment:length()
  return #self.text
end

--- Check if segment is plain text (no formatting, no link)
---@return boolean
function RichTextSegment:is_plain()
  return self.annotations:is_default() and not self.href
end

return M
