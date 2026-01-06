--- Block type completion source for slash commands
--- Generates items from the model registry
---@class neotion.BlocksCompletion

local M = {}

--- Block type display configuration
---@type table<string, {label: string, icon: string, description: string}>
local BLOCK_DISPLAY = {
  paragraph = { label = 'Text', icon = 'Aa', description = 'Plain text' },
  heading_1 = { label = 'Heading 1', icon = 'H1', description = '# Large heading' },
  heading_2 = { label = 'Heading 2', icon = 'H2', description = '## Medium heading' },
  heading_3 = { label = 'Heading 3', icon = 'H3', description = '### Small heading' },
  bulleted_list_item = { label = 'Bullet list', icon = '-', description = '- List item' },
  numbered_list_item = { label = 'Numbered list', icon = '1.', description = '1. Numbered item' },
  quote = { label = 'Quote', icon = '|', description = '| Quote block' },
  code = { label = 'Code', icon = '</>', description = '``` Code block' },
  divider = { label = 'Divider', icon = '---', description = 'Horizontal line' },
}

--- Get completion items for block types
--- Uses model registry to get supported types
---@param query string Filter query
---@param callback fun(items: table[]) Callback with filtered items
function M.get_items(query, callback)
  local registry = require('neotion.model.registry')

  -- Get supported types from registry
  local supported_types = registry.get_supported_types()

  local items = {}
  local query_lower = query:lower()

  for _, block_type in ipairs(supported_types) do
    local display = BLOCK_DISPLAY[block_type]
    if display then
      -- Check if matches query
      local matches = query == ''
        or display.label:lower():find(query_lower, 1, true)
        or block_type:lower():find(query_lower, 1, true)

      if matches then
        table.insert(items, {
          label = display.label,
          icon = display.icon,
          description = display.description,
          value = block_type,
        })
      end
    end
  end

  callback(items)
end

--- Get all block items without filtering
---@return table[] items All block completion items
function M.get_all()
  local items = {}
  M.get_items('', function(result)
    items = result
  end)
  return items
end

return M
