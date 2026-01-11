---Gutter Icons module for Neotion
---Provides sign column icons for different block types
---@class neotion.render.GutterIcons
local M = {}

---Icon mapping for each block type
---@type table<string, string|nil>
M.ICONS = {
  heading_1 = 'H1',
  heading_2 = 'H2',
  heading_3 = 'H3',
  bulleted_list_item = '•',
  numbered_list_item = '#',
  quote = '│',
  code = '<>',
  divider = '──',
  child_page = '->',
  -- paragraph = nil (no icon)
}

---Continuation marker for multi-line blocks
---@type string
M.CONTINUATION_MARKER = '│'

---Highlight group mapping for each block type
---@type table<string, string>
M.HIGHLIGHT_GROUPS = {
  heading_1 = 'NeotionGutterH1',
  heading_2 = 'NeotionGutterH2',
  heading_3 = 'NeotionGutterH3',
  bulleted_list_item = 'NeotionGutterList',
  numbered_list_item = 'NeotionGutterList',
  quote = 'NeotionGutterQuote',
  code = 'NeotionGutterCode',
  divider = 'NeotionGutterDivider',
  child_page = 'NeotionGutterChildPage',
}

---Default highlight group for unknown types
---@type string
M.DEFAULT_HIGHLIGHT = 'NeotionGutterDefault'

---Continuation marker highlight group
---@type string
M.CONTINUATION_HIGHLIGHT = 'NeotionGutterContinuation'

---Get the gutter icon for a block type
---@param block_type string
---@return string|nil icon, nil if no icon for this type
function M.get_icon(block_type)
  return M.ICONS[block_type]
end

---Get the highlight group for a block type's gutter icon
---@param block_type string
---@return string highlight group name
function M.get_highlight_group(block_type)
  return M.HIGHLIGHT_GROUPS[block_type] or M.DEFAULT_HIGHLIGHT
end

return M
