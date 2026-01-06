--- Color completion source for slash commands
--- Provides Notion API-supported text and background colors
---@class neotion.ColorsCompletion

local M = {}

--- All Notion API text colors
---@type string[]
M.TEXT_COLORS = {
  'default',
  'gray',
  'brown',
  'orange',
  'yellow',
  'green',
  'blue',
  'purple',
  'pink',
  'red',
}

--- All Notion API background colors
---@type string[]
M.BACKGROUND_COLORS = {
  'gray_background',
  'brown_background',
  'orange_background',
  'yellow_background',
  'green_background',
  'blue_background',
  'purple_background',
  'pink_background',
  'red_background',
}

--- Color display configuration
--- Icons use colored squares where possible
---@type table<string, {label: string, icon: string}>
local COLOR_DISPLAY = {
  -- Text colors
  default = { label = 'Default', icon = '' },
  gray = { label = 'Gray', icon = '' },
  brown = { label = 'Brown', icon = '' },
  orange = { label = 'Orange', icon = '' },
  yellow = { label = 'Yellow', icon = '' },
  green = { label = 'Green', icon = '' },
  blue = { label = 'Blue', icon = '' },
  purple = { label = 'Purple', icon = '' },
  pink = { label = 'Pink', icon = '' },
  red = { label = 'Red', icon = '' },
  -- Background colors
  gray_background = { label = 'Gray background', icon = '' },
  brown_background = { label = 'Brown background', icon = '' },
  orange_background = { label = 'Orange background', icon = '' },
  yellow_background = { label = 'Yellow background', icon = '' },
  green_background = { label = 'Green background', icon = '' },
  blue_background = { label = 'Blue background', icon = '' },
  purple_background = { label = 'Purple background', icon = '' },
  pink_background = { label = 'Pink background', icon = '' },
  red_background = { label = 'Red background', icon = '' },
}

--- Check if a color is a background color
---@param color string Color name
---@return boolean is_background
function M.is_background_color(color)
  return color:find('_background') ~= nil
end

--- Format the color syntax for buffer insertion
---@param color string Color name
---@return string syntax Color syntax or empty for default
function M.format_color_syntax(color)
  if color == 'default' then
    return ''
  end
  return string.format('<c:%s></c>', color)
end

--- Get completion items for colors
---@param query string Filter query
---@param callback fun(items: table[]) Callback with filtered items
function M.get_items(query, callback)
  local items = {}
  local query_lower = query:lower()

  -- Add text colors
  for _, color in ipairs(M.TEXT_COLORS) do
    local display = COLOR_DISPLAY[color]
    if display then
      local matches = query == ''
        or display.label:lower():find(query_lower, 1, true)
        or color:lower():find(query_lower, 1, true)

      if matches then
        table.insert(items, {
          label = display.label,
          icon = display.icon,
          value = { type = 'color', color = color },
          description = color ~= 'default' and '<c:' .. color .. '>' or nil,
        })
      end
    end
  end

  -- Add background colors
  for _, color in ipairs(M.BACKGROUND_COLORS) do
    local display = COLOR_DISPLAY[color]
    if display then
      local matches = query == ''
        or display.label:lower():find(query_lower, 1, true)
        or color:lower():find(query_lower, 1, true)

      if matches then
        table.insert(items, {
          label = display.label,
          icon = display.icon,
          value = { type = 'color', color = color },
          description = '<c:' .. color .. '>',
        })
      end
    end
  end

  callback(items)
end

--- Get all color items without filtering
---@return table[] items All color completion items
function M.get_all()
  local items = {}
  M.get_items('', function(result)
    items = result
  end)
  return items
end

return M
