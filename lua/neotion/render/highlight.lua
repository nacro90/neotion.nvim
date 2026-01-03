--- Highlight group definitions for neotion.nvim
--- Defines all highlight groups used for inline formatting and colors
---@module 'neotion.render.highlight'

local types = require('neotion.format.types')

local M = {}

--- Notion's color palette (approximated from Notion UI)
---@type table<string, string>
M.NOTION_COLORS = {
  -- Foreground colors
  red = '#e03e3e',
  blue = '#2f80ed',
  green = '#0f7b6c',
  yellow = '#dfab01',
  orange = '#d9730d',
  pink = '#ad1a72',
  purple = '#6940a5',
  brown = '#64473a',
  gray = '#9b9a97',

  -- Background colors
  red_background = '#fbe4e4',
  blue_background = '#ddebf1',
  green_background = '#ddedea',
  yellow_background = '#fbf3db',
  orange_background = '#faebdd',
  pink_background = '#f4dfeb',
  purple_background = '#eae4f2',
  brown_background = '#e9e5e3',
  gray_background = '#ebeced',
}

--- Highlight group definitions
---@type table<string, vim.api.keyset.highlight>
M.GROUPS = {
  -- Inline formatting
  NeotionBold = { bold = true },
  NeotionItalic = { italic = true },
  NeotionStrikethrough = { strikethrough = true },
  NeotionUnderline = { underline = true },
  NeotionCode = { link = '@markup.raw.markdown_inline' },

  -- Foreground colors
  NeotionColorRed = { fg = M.NOTION_COLORS.red },
  NeotionColorBlue = { fg = M.NOTION_COLORS.blue },
  NeotionColorGreen = { fg = M.NOTION_COLORS.green },
  NeotionColorYellow = { fg = M.NOTION_COLORS.yellow },
  NeotionColorOrange = { fg = M.NOTION_COLORS.orange },
  NeotionColorPink = { fg = M.NOTION_COLORS.pink },
  NeotionColorPurple = { fg = M.NOTION_COLORS.purple },
  NeotionColorBrown = { fg = M.NOTION_COLORS.brown },
  NeotionColorGray = { fg = M.NOTION_COLORS.gray },

  -- Background colors
  NeotionColorRedBg = { bg = M.NOTION_COLORS.red_background },
  NeotionColorBlueBg = { bg = M.NOTION_COLORS.blue_background },
  NeotionColorGreenBg = { bg = M.NOTION_COLORS.green_background },
  NeotionColorYellowBg = { bg = M.NOTION_COLORS.yellow_background },
  NeotionColorOrangeBg = { bg = M.NOTION_COLORS.orange_background },
  NeotionColorPinkBg = { bg = M.NOTION_COLORS.pink_background },
  NeotionColorPurpleBg = { bg = M.NOTION_COLORS.purple_background },
  NeotionColorBrownBg = { bg = M.NOTION_COLORS.brown_background },
  NeotionColorGrayBg = { bg = M.NOTION_COLORS.gray_background },

  -- Headings (link to treesitter markdown highlights)
  NeotionH1 = { link = '@markup.heading.1.markdown' },
  NeotionH2 = { link = '@markup.heading.2.markdown' },
  NeotionH3 = { link = '@markup.heading.3.markdown' },

  -- Read-only indicator
  NeotionReadOnly = { link = 'Comment' },

  -- Link styling
  NeotionLink = { link = '@markup.link.url' },
}

--- Get highlight group names for an annotation
---@param annotation neotion.Annotation
---@return string[]
function M.get_annotation_highlights(annotation)
  local highlights = {}

  if annotation.bold then
    table.insert(highlights, 'NeotionBold')
  end

  if annotation.italic then
    table.insert(highlights, 'NeotionItalic')
  end

  if annotation.strikethrough then
    table.insert(highlights, 'NeotionStrikethrough')
  end

  if annotation.underline then
    table.insert(highlights, 'NeotionUnderline')
  end

  if annotation.code then
    table.insert(highlights, 'NeotionCode')
  end

  if annotation.color and annotation.color ~= 'default' then
    local color_hl = types.ColorValue.to_highlight_name(annotation.color)
    if color_hl then
      table.insert(highlights, color_hl)
    end
  end

  return highlights
end

--- Get heading highlight group for a given level
---@param level integer 1-3
---@return string
function M.get_heading_highlight(level)
  if level < 1 then
    level = 1
  elseif level > 3 then
    level = 3
  end

  return 'NeotionH' .. level
end

--- Setup all highlight groups
function M.setup()
  for name, opts in pairs(M.GROUPS) do
    vim.api.nvim_set_hl(0, name, opts)
  end
end

return M
