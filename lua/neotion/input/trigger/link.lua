--- Link trigger handler for [[ page linking
---@class neotion.LinkTrigger

local M = {}

--- The trigger text for this handler
M.TRIGGER = '[['

--- Format a page link in markdown syntax
---@param title string|nil Page title
---@param id string Page ID
---@return string link Formatted link: [Title](notion://page/id)
function M.format_link(title, id)
  local display_title = title
  if not display_title or display_title == '' then
    display_title = 'Untitled'
  end
  return string.format('[%s](notion://page/%s)', display_title, id)
end

--- Calculate the replacement range for the trigger and query
---@param line string Line content
---@param trigger_col integer Column where trigger starts (1-indexed)
---@param query string Query text after trigger
---@return integer start_col Start column for replacement (1-indexed)
---@return integer end_col End column for replacement (1-indexed)
function M.calculate_replacement(line, trigger_col, query)
  local trigger_len = #M.TRIGGER
  local query_len = #query
  local end_col = trigger_col + trigger_len + query_len - 1
  return trigger_col, end_col
end

--- Get completion items for page search
--- Delegates to completion/pages module
---@param query string Search query
---@param callback fun(items: table[]) Callback with filtered items
function M.get_items(query, callback)
  local pages = require('neotion.input.completion.pages')
  pages.get_items(query, callback)
end

--- Handle the link trigger
--- Opens page picker and calls on_result callback with result
---@param ctx neotion.TriggerContext Trigger context
---@param query string Current query text
---@param on_result fun(result: neotion.TriggerResult) Callback with result
function M.handle(ctx, query, on_result)
  local picker = require('neotion.ui.picker')

  picker.search(query, function(item)
    if item then
      local result = {
        type = 'insert',
        text = M.format_link(item.title, item.id),
        replace_start = ctx.trigger_start,
        replace_end = ctx.trigger_start + #M.TRIGGER + #query - 1,
      }
      on_result(result)
    end
    -- Don't call on_result if cancelled (item is nil)
  end)
end

return M
