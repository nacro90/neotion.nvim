---Default keymaps for neotion formatting
---@module 'neotion.input.keymaps'

local M = {}

---@class neotion.KeymapDef
---@field lhs string Left-hand side (key combination)
---@field rhs string Right-hand side (<Plug> mapping)
---@field modes string|string[] Mode(s) for the keymap
---@field desc string Description for the keymap

---Default keymap definitions
---@type table<string, neotion.KeymapDef>
M.defaults = {
  -- Bold (normal mode operator)
  bold = {
    lhs = '<C-b>',
    rhs = '<Plug>(NeotionBold)',
    modes = 'n',
    desc = 'Bold (operator)',
  },
  bold_visual = {
    lhs = '<C-b>',
    rhs = '<Plug>(NeotionBold)',
    modes = 'x',
    desc = 'Bold selection',
  },
  bold_insert = {
    lhs = '<C-b>',
    rhs = '<Plug>(NeotionBoldPair)',
    modes = 'i',
    desc = 'Insert bold pair',
  },

  -- Italic (normal mode operator)
  -- Note: <C-i> may conflict with <Tab> in some terminals
  italic = {
    lhs = '<C-i>',
    rhs = '<Plug>(NeotionItalic)',
    modes = 'n',
    desc = 'Italic (operator)',
  },
  italic_visual = {
    lhs = '<C-i>',
    rhs = '<Plug>(NeotionItalic)',
    modes = 'x',
    desc = 'Italic selection',
  },
  italic_insert = {
    lhs = '<C-i>',
    rhs = '<Plug>(NeotionItalicPair)',
    modes = 'i',
    desc = 'Insert italic pair',
  },
  -- Alternative for terminals where <C-i> = <Tab>
  italic_alt = {
    lhs = '<M-i>',
    rhs = '<Plug>(NeotionItalic)',
    modes = 'n',
    desc = 'Italic (operator, alt)',
  },
  italic_alt_visual = {
    lhs = '<M-i>',
    rhs = '<Plug>(NeotionItalic)',
    modes = 'x',
    desc = 'Italic selection (alt)',
  },

  -- Underline
  underline = {
    lhs = '<C-u>',
    rhs = '<Plug>(NeotionUnderline)',
    modes = 'n',
    desc = 'Underline (operator)',
  },
  underline_visual = {
    lhs = '<C-u>',
    rhs = '<Plug>(NeotionUnderline)',
    modes = 'x',
    desc = 'Underline selection',
  },
  underline_insert = {
    lhs = '<C-u>',
    rhs = '<Plug>(NeotionUnderlinePair)',
    modes = 'i',
    desc = 'Insert underline pair',
  },

  -- Strikethrough
  strikethrough = {
    lhs = '<C-s>',
    rhs = '<Plug>(NeotionStrikethrough)',
    modes = 'n',
    desc = 'Strikethrough (operator)',
  },
  strikethrough_visual = {
    lhs = '<C-s>',
    rhs = '<Plug>(NeotionStrikethrough)',
    modes = 'x',
    desc = 'Strikethrough selection',
  },
  strikethrough_insert = {
    lhs = '<C-s>',
    rhs = '<Plug>(NeotionStrikethroughPair)',
    modes = 'i',
    desc = 'Insert strikethrough pair',
  },

  -- Code
  code = {
    lhs = '<C-`>',
    rhs = '<Plug>(NeotionCode)',
    modes = 'n',
    desc = 'Code (operator)',
  },
  code_visual = {
    lhs = '<C-`>',
    rhs = '<Plug>(NeotionCode)',
    modes = 'x',
    desc = 'Code selection',
  },
  code_insert = {
    lhs = '<C-`>',
    rhs = '<Plug>(NeotionCodePair)',
    modes = 'i',
    desc = 'Insert code pair',
  },
}

---Get a flattened list of all keymaps with their names
---@return {name: string, lhs: string, rhs: string, modes: string|string[], desc: string}[]
function M.get_keymap_list()
  local list = {}
  for name, def in pairs(M.defaults) do
    table.insert(list, {
      name = name,
      lhs = def.lhs,
      rhs = def.rhs,
      modes = def.modes,
      desc = def.desc,
    })
  end
  return list
end

---Setup buffer-local keymaps
---@param bufnr integer Buffer number
---@param enabled_keymaps table<string, boolean> Map of keymap names to enabled state (false = disabled)
function M.setup_buffer(bufnr, enabled_keymaps)
  enabled_keymaps = enabled_keymaps or {}

  for name, def in pairs(M.defaults) do
    -- Check if this keymap is explicitly disabled
    -- Also check for base name (e.g., 'bold' for 'bold_visual')
    local base_name = name:match('^(%w+)_') or name
    local is_enabled = enabled_keymaps[name] ~= false and enabled_keymaps[base_name] ~= false

    if is_enabled then
      local modes = type(def.modes) == 'table' and def.modes or { def.modes }
      for _, mode in ipairs(modes) do
        vim.keymap.set(mode, def.lhs, def.rhs, {
          buffer = bufnr,
          desc = 'Neotion: ' .. def.desc,
        })
      end
    end
  end
end

return M
