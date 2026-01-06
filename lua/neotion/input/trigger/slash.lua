--- Slash command trigger handler for / commands
---@class neotion.SlashTrigger

local M = {}

--- The trigger text for this handler
M.TRIGGER = '/'

--- Block type to buffer prefix mapping
---@type table<string, string>
local BLOCK_PREFIXES = {
  paragraph = '',
  heading_1 = '# ',
  heading_2 = '## ',
  heading_3 = '### ',
  bulleted_list_item = '- ',
  quote = '| ',
  code = '```\n',
  divider = '---\n',
}

--- Get the buffer prefix for a block type
---@param block_type string Block type
---@return string prefix Buffer prefix to insert
function M.get_block_prefix(block_type)
  return BLOCK_PREFIXES[block_type] or ''
end

--- Get completion items for slash commands
--- Combines block types, colors, and transforms
---@param query string Filter query
---@param callback fun(items: table[]) Callback with filtered items
function M.get_items(query, callback)
  local blocks = require('neotion.input.completion.blocks')
  local colors = require('neotion.input.completion.colors')

  local all_items = {}

  -- Get block items
  blocks.get_items(query, function(block_items)
    for _, item in ipairs(block_items) do
      table.insert(all_items, item)
    end
  end)

  -- Get color items
  colors.get_items(query, function(color_items)
    for _, item in ipairs(color_items) do
      table.insert(all_items, item)
    end
  end)

  -- Future: Add transform items here (Phase 9.4)

  callback(all_items)
end

--- Handle the slash command trigger
--- Shows picker and calls on_result callback with result
---@param ctx neotion.TriggerContext Trigger context
---@param query string Current query text
---@param on_result fun(result: neotion.TriggerResult) Callback with result
function M.handle(ctx, query, on_result)
  local picker = require('neotion.ui.picker')

  -- Get filtered items
  local items = {}
  M.get_items(query, function(filtered)
    items = filtered
  end)

  -- Show picker
  picker.select(items, {
    prompt = '/ Slash Command',
    format_item = function(item)
      local display = item.label
      if item.icon and item.icon ~= '' then
        display = item.icon .. ' ' .. display
      end
      return display
    end,
  }, function(selection)
    if selection then
      local value = selection.value
      local result

      -- Handle different value types
      if type(value) == 'string' then
        -- Block type - insert prefix
        result = {
          type = 'insert',
          text = M.get_block_prefix(value),
          replace_start = ctx.trigger_start,
          replace_end = ctx.trigger_start + #M.TRIGGER + #query - 1,
        }
      elseif type(value) == 'table' then
        if value.type == 'transform' then
          -- Transform to another trigger
          result = {
            type = 'transform',
            trigger = value.trigger,
          }
        elseif value.type == 'color' then
          -- Color command (Phase 9.3)
          -- cursor_offset: negative = from end of text, cursor inside tags
          result = {
            type = 'insert',
            text = '<c:' .. value.color .. '></c>',
            replace_start = ctx.trigger_start,
            replace_end = ctx.trigger_start + #M.TRIGGER + #query - 1,
            cursor_offset = -3, -- Position after > of opening tag, before </c>
          }
        end
      end

      if result then
        on_result(result)
      end
    end
    -- Don't call on_result if cancelled (selection is nil)
  end)
end

return M
