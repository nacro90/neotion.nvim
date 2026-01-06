--- Page completion source for triggers
--- Provides page search with cache-first strategy
---@class neotion.PagesCompletion

local M = {}

--- Convert a cached page row to a completion item
---@param row table Cache row from pages cache
---@return table item Completion item
local function cached_row_to_item(row)
  local icon = row.icon
  -- Handle nil or vim.NIL
  if not icon or icon == vim.NIL then
    icon = ''
  end

  return {
    id = row.id,
    title = row.title or '',
    icon = icon,
    parent_type = row.parent_type,
    parent_id = row.parent_id,
    frecency_score = row.frecency_score,
    from_cache = true,
  }
end

--- Get completion items for page search
--- Uses cache-first strategy with frecency ranking
---@param query string Search query
---@param callback fun(items: table[]) Callback with items
function M.get_items(query, callback)
  local pages_cache = require('neotion.cache.pages')

  -- Get cached pages with frecency ranking
  local cached_rows = pages_cache.search(query, 20)

  -- Convert to completion items
  local items = {}
  for _, row in ipairs(cached_rows) do
    table.insert(items, cached_row_to_item(row))
  end

  -- Return immediately with cached results
  callback(items)

  -- Note: Background API refresh could be added here
  -- For now, we rely on the picker's live_search for fresh results
end

--- Get all cached pages (for initial display)
---@param limit integer Maximum number of items
---@param callback fun(items: table[]) Callback with items
function M.get_recent(limit, callback)
  local pages_cache = require('neotion.cache.pages')

  -- Get recent pages by frecency
  local cached_rows = pages_cache.get_by_frecency(limit)

  local items = {}
  for _, row in ipairs(cached_rows) do
    table.insert(items, cached_row_to_item(row))
  end

  callback(items)
end

return M
