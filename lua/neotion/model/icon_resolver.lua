---Icon resolver for child_page blocks
---Resolves page icons from cache or API asynchronously
---@module 'neotion.model.icon_resolver'

-- TODO(neotion:FEAT-12.4:LOW): Kitty graphics protocol support for image icons
-- External/file icon types are image URLs. Instead of Nerd Font placeholder,
-- display actual images using terminal graphics protocols:
-- - Kitty graphics protocol
-- - iTerm2 inline images
-- - Sixel (for compatible terminals)
-- Requires: image download, protocol detection, 3rd/image.nvim integration

local M = {}

local log = require('neotion.log').get_logger('model.icon_resolver')

-- Configuration
local MAX_CACHE_SIZE = 100

---@type table<string, string|nil> In-memory cache for resolved icons
local resolved_icons = {}

---@type string[] LRU order tracking for cache eviction
local cache_order = {}

---@type table<string, fun(icon: string|nil)[]> Pending callbacks per page (for deduplication)
local pending_callbacks = {}

---Cache an icon with LRU eviction
---@param page_id string
---@param icon string|nil
local function cache_icon(page_id, icon)
  -- If already in cache, just update the value (no order change needed for simple FIFO)
  if resolved_icons[page_id] ~= nil then
    resolved_icons[page_id] = icon
    return
  end

  -- Add to cache
  resolved_icons[page_id] = icon
  table.insert(cache_order, page_id)

  -- Evict oldest entries if over limit
  while #cache_order > MAX_CACHE_SIZE do
    local oldest = table.remove(cache_order, 1)
    resolved_icons[oldest] = nil
    log.debug('Evicted icon from cache', { page_id = oldest })
  end
end

---Try to get icon from cache (sync)
---@param page_id string
---@return string|nil icon The icon if found in cache
local function get_from_cache(page_id)
  local cache = require('neotion.cache.pages')
  local page = cache.get_page(page_id)
  if page and page.icon then
    return page.icon
  end
  return nil
end

---Fetch page metadata from API and cache the icon
---@param page_id string
---@param callback fun(icon: string|nil) Called when icon is resolved
local function fetch_from_api(page_id, callback)
  -- Already fetching this page - queue the callback
  if pending_callbacks[page_id] then
    table.insert(pending_callbacks[page_id], callback)
    log.debug('Queued callback for pending fetch', { page_id = page_id })
    return
  end

  -- Start new fetch
  pending_callbacks[page_id] = { callback }
  log.debug('Starting icon fetch', { page_id = page_id })

  local pages_api = require('neotion.api.pages')
  log.debug('Fetching page for icon', { page_id = page_id })
  pages_api.get(page_id, function(result)
    local callbacks = pending_callbacks[page_id]
    pending_callbacks[page_id] = nil

    if result.error or not result.page then
      log.debug('Icon fetch failed', { page_id = page_id, error = result.error })
      -- Call all queued callbacks with nil
      for _, cb in ipairs(callbacks) do
        cb(nil)
      end
      return
    end

    -- Extract and cache the icon
    local icon = pages_api.get_icon(result.page)
    log.debug('Page icon data from API', {
      requested_page_id = page_id,
      returned_page_id = result.page.id,
      page_title = result.page.properties and pages_api.get_title(result.page),
      has_icon_field = result.page.icon ~= nil,
      icon_type = result.page.icon and type(result.page.icon),
      icon_data = result.page.icon,
      extracted_icon = icon,
    })
    cache_icon(page_id, icon)
    log.debug('Icon resolved', { page_id = page_id, icon = icon })

    -- Also save to persistent cache
    local cache = require('neotion.cache.pages')
    cache.save_page(page_id, result.page)

    -- Call all queued callbacks
    for _, cb in ipairs(callbacks) do
      cb(icon)
    end
  end)
end

---Resolve icon for a page
---First checks in-memory cache, then persistent cache, then fetches from API
---@param page_id string
---@param on_resolved fun(icon: string|nil) Called when icon is resolved (may be sync or async)
---@return string|nil icon Returns immediately if found in cache, nil if async fetch started
function M.resolve(page_id, on_resolved)
  -- Check in-memory cache first
  if resolved_icons[page_id] ~= nil then
    local icon = resolved_icons[page_id]
    -- Schedule callback to be consistent (always async-like)
    vim.schedule(function()
      on_resolved(icon)
    end)
    return icon
  end

  -- Check persistent cache
  local cached_icon = get_from_cache(page_id)
  if cached_icon then
    cache_icon(page_id, cached_icon)
    vim.schedule(function()
      on_resolved(cached_icon)
    end)
    return cached_icon
  end

  -- Fetch from API (async)
  fetch_from_api(page_id, on_resolved)
  return nil
end

---Get cached icon without triggering fetch
---@param page_id string
---@return string|nil
function M.get_cached(page_id)
  if resolved_icons[page_id] ~= nil then
    return resolved_icons[page_id]
  end
  return get_from_cache(page_id)
end

---Clear the in-memory cache
function M.clear_cache()
  resolved_icons = {}
  cache_order = {}
  pending_callbacks = {}
end

---Check if a fetch is pending for a page
---@param page_id string
---@return boolean
function M.is_pending(page_id)
  return pending_callbacks[page_id] ~= nil
end

---Get cache statistics (for debugging)
---@return {size: integer, max_size: integer, pending: integer}
function M.get_stats()
  local pending_count = 0
  for _ in pairs(pending_callbacks) do
    pending_count = pending_count + 1
  end
  return {
    size = #cache_order,
    max_size = MAX_CACHE_SIZE,
    pending = pending_count,
  }
end

return M
