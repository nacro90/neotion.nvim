--- Icon presets for neotion.nvim
--- Provides Nerd Font and ASCII icon sets
---@module 'neotion.render.icons'

local M = {}

---@class neotion.IconSet
---@field heading string[] Icons for heading levels 1-3
---@field bullet string[] Icons for bullet points (cycles by level)
---@field checkbox_unchecked string Icon for unchecked checkbox
---@field checkbox_checked string Icon for checked checkbox
---@field quote string Icon for quote blocks
---@field toggle_collapsed string Icon for collapsed toggle
---@field toggle_expanded string Icon for expanded toggle

--- Icon presets
---@type table<string, neotion.IconSet>
M.PRESETS = {
  --- Nerd Font icons (default)
  nerd = {
    heading = { '󰲡 ', '󰲣 ', '󰲥 ' },
    bullet = { '●', '○', '◆', '◇' },
    checkbox_unchecked = '󰄱 ',
    checkbox_checked = '󰱒 ',
    quote = '▋',
    toggle_collapsed = '',
    toggle_expanded = '',
  },

  --- ASCII fallback
  ascii = {
    heading = { '# ', '## ', '### ' },
    bullet = { '-', '*', '+', '-' },
    checkbox_unchecked = '[ ]',
    checkbox_checked = '[x]',
    quote = '|',
    toggle_collapsed = '>',
    toggle_expanded = 'v',
  },
}

--- Empty icons (for disabled state)
---@type neotion.IconSet
local EMPTY_ICONS = {
  heading = {},
  bullet = {},
  checkbox_unchecked = '',
  checkbox_checked = '',
  quote = '',
  toggle_collapsed = '',
  toggle_expanded = '',
}

--- Get icon set based on config value
---@param config 'nerd'|'ascii'|false|neotion.IconSet|nil
---@return neotion.IconSet
function M.get_icons(config)
  if config == false then
    return EMPTY_ICONS
  end

  if config == nil or config == 'nerd' then
    return M.PRESETS.nerd
  end

  if config == 'ascii' then
    return M.PRESETS.ascii
  end

  -- Custom table - merge with defaults
  if type(config) == 'table' then
    return vim.tbl_deep_extend('force', M.PRESETS.nerd, config)
  end

  return M.PRESETS.nerd
end

--- Get heading icon for a given level
---@param level integer 1-3
---@param preset? 'nerd'|'ascii'|neotion.IconSet
---@return string
function M.get_heading_icon(level, preset)
  if level < 1 then
    return ''
  end

  local icons = M.get_icons(preset)

  if #icons.heading == 0 then
    return ''
  end

  -- Clamp to available levels
  local index = math.min(level, #icons.heading)
  return icons.heading[index]
end

--- Get bullet icon for a given nesting level
---@param level integer 1-based nesting level
---@param preset? 'nerd'|'ascii'|neotion.IconSet
---@return string
function M.get_bullet_icon(level, preset)
  local icons = M.get_icons(preset)

  if #icons.bullet == 0 then
    return ''
  end

  -- Cycle through available icons
  local index = ((level - 1) % #icons.bullet) + 1
  return icons.bullet[index]
end

--- Get checkbox icon
---@param checked boolean
---@param preset? 'nerd'|'ascii'|neotion.IconSet
---@return string
function M.get_checkbox_icon(checked, preset)
  local icons = M.get_icons(preset)

  if checked then
    return icons.checkbox_checked
  else
    return icons.checkbox_unchecked
  end
end

--- Get toggle icon
---@param expanded boolean
---@param preset? 'nerd'|'ascii'|neotion.IconSet
---@return string
function M.get_toggle_icon(expanded, preset)
  local icons = M.get_icons(preset)

  if expanded then
    return icons.toggle_expanded
  else
    return icons.toggle_collapsed
  end
end

--- Get quote icon
---@param preset? 'nerd'|'ascii'|neotion.IconSet
---@return string
function M.get_quote_icon(preset)
  local icons = M.get_icons(preset)
  return icons.quote
end

return M
