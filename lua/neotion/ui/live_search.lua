---@brief [[
---Live search orchestrator for neotion.nvim
---Handles debouncing, cancellation, and result merging for Telescope integration
---@brief ]]

local log_module = require('neotion.log')
local log = log_module.get_logger('ui.live_search')

---@class neotion.PageItem
---@field id string Page ID (32 hex chars)
---@field title string Page title
---@field icon string Icon emoji or empty string
---@field parent_type? string Parent type (workspace, page_id, database_id)
---@field parent_id? string Parent ID if applicable
---@field frecency_score? number Score from cache (for cached items)
---@field from_cache boolean Whether item came from cache

local M = {}

---@class neotion.LiveSearchState
---@field query string Current search query
---@field request_id? string|number Active API request ID
---@field cancel_fn? function Function to cancel active request
---@field debounce_timer? integer Vimscript timer ID
---@field cached_results neotion.PageItem[] Last cached results
---@field api_results? neotion.PageItem[] Last API results
---@field is_loading boolean Whether API request is in flight
---@field debounce_ms integer Debounce delay in ms
---@field show_cached boolean Show cached results instantly
---@field limit integer Maximum results to show
---@field callbacks neotion.LiveSearchCallbacks

---@class neotion.LiveSearchCallbacks
---@field on_results fun(items: neotion.PageItem[], is_final: boolean) Called when results are ready
---@field on_error? fun(error: string) Called on error
---@field on_loading? fun(is_loading: boolean) Called when loading state changes

---@class neotion.LiveSearchOptions
---@field debounce_ms? integer Debounce delay (default: from config)
---@field show_cached? boolean Show cached results instantly (default: from config)
---@field limit? integer Max results to show (default: from config)

---@type table<integer|string, neotion.LiveSearchState>
local states = {}

-- Mock functions for testing (nil = use real implementation)
---@type fun(query: string, limit: integer): neotion.PageItem[]|nil
local mock_cache_fetcher = nil

---@type fun(query: string, callback: fun(result: table)): {request_id: any, cancel: fun()}|nil
local mock_api_searcher = nil

--- Set mock cache fetcher for testing
---@param fn fun(query: string, limit: integer): neotion.PageItem[]|nil
function M._set_cache_fetcher(fn)
  mock_cache_fetcher = fn
end

--- Set mock API searcher for testing
---@param fn fun(query: string, callback: fun(result: table)): {request_id: any, cancel: fun()}|nil
function M._set_api_searcher(fn)
  mock_api_searcher = fn
end

--- Convert API page to PageItem
--- Uses api/pages.lua helper functions for consistent title/icon extraction
---@param page table Notion API page object
---@return neotion.PageItem
function M.api_page_to_item(page)
  local pages_api = require('neotion.api.pages')
  local parent_type, parent_id = pages_api.get_parent(page)

  -- Normalize ID (remove dashes) to match cache format for deduplication
  local normalized_id = page.id and page.id:gsub('-', '') or ''

  return {
    id = normalized_id,
    title = pages_api.get_title(page),
    icon = pages_api.get_icon(page) or '',
    parent_type = parent_type,
    parent_id = parent_id,
    from_cache = false,
  }
end

--- Convert cached row to PageItem
---@param row table SQLite row from cache
---@return neotion.PageItem
function M.cached_row_to_item(row)
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

--- Merge API results with cached results
--- API results come first, cached extras appended (deduplicated by id)
---@param api_results neotion.PageItem[]
---@param cached_results neotion.PageItem[]
---@return neotion.PageItem[]
function M.merge_results(api_results, cached_results)
  local seen = {}
  local merged = {}

  -- API results first (preserve Notion's relevance order)
  for _, item in ipairs(api_results) do
    if not seen[item.id] then
      seen[item.id] = true
      item.from_cache = false
      table.insert(merged, item)
    end
  end

  -- Cached extras (frecency sorted)
  for _, item in ipairs(cached_results) do
    if not seen[item.id] then
      seen[item.id] = true
      item.from_cache = true
      table.insert(merged, item)
    end
  end

  return merged
end

--- Create a new live search instance
---@param instance_id integer|string Unique identifier (e.g., bufnr or counter)
---@param callbacks neotion.LiveSearchCallbacks
---@param opts? neotion.LiveSearchOptions
---@return neotion.LiveSearchState
function M.create(instance_id, callbacks, opts)
  local config = require('neotion.config')
  local cfg = config.get()

  opts = opts or {}

  -- Handle boolean option with nil-safe default
  local show_cached = opts.show_cached
  if show_cached == nil then
    show_cached = cfg.search.show_cached
  end

  ---@type neotion.LiveSearchState
  local state = {
    query = '',
    request_id = nil,
    cancel_fn = nil,
    debounce_timer = nil,
    cached_results = {},
    api_results = nil,
    is_loading = false,
    debounce_ms = opts.debounce_ms or cfg.search.debounce_ms,
    show_cached = show_cached,
    limit = opts.limit or cfg.search.limit,
    callbacks = callbacks,
  }

  states[instance_id] = state
  return state
end

--- Get current state for an instance
---@param instance_id integer|string
---@return neotion.LiveSearchState?
function M.get_state(instance_id)
  return states[instance_id]
end

--- Destroy instance and cleanup all resources
---@param instance_id integer|string
function M.destroy(instance_id)
  local state = states[instance_id]
  if state then
    log.debug('Destroying live search instance', { instance_id = instance_id })

    -- Cancel any pending debounce timer
    if state.debounce_timer then
      vim.fn.timer_stop(state.debounce_timer)
      state.debounce_timer = nil
    end

    -- Cancel any pending API request
    if state.cancel_fn then
      state.cancel_fn()
      state.cancel_fn = nil
    end

    -- Clear all state to prevent any lingering references
    state.query = ''
    state.cached_results = {}
    state.api_results = nil
    state.is_loading = false
    state.request_id = nil
  end

  states[instance_id] = nil
end

--- Reset all state (for testing)
function M._reset()
  for id, _ in pairs(states) do
    M.destroy(id)
  end
  states = {}
  mock_cache_fetcher = nil
  mock_api_searcher = nil
end

--- Stop debounce timer if active
---@param state neotion.LiveSearchState
local function stop_debounce_timer(state)
  if state.debounce_timer then
    vim.fn.timer_stop(state.debounce_timer)
    state.debounce_timer = nil
  end
end

--- Cancel active API request if any
---@param state neotion.LiveSearchState
local function cancel_api_request(state)
  if state.cancel_fn then
    state.cancel_fn()
    state.cancel_fn = nil
  end
  state.request_id = nil
end

--- Convert page IDs to PageItems by looking up page metadata
---@param page_ids string[]
---@param limit integer
---@return neotion.PageItem[]
local function page_ids_to_items(page_ids, limit)
  local ok, cache_pages = pcall(require, 'neotion.cache.pages')
  if not ok then
    return {}
  end

  local items = {}
  for i, page_id in ipairs(page_ids) do
    if i > limit then
      break
    end
    -- Normalize ID (remove dashes) for lookup - handles both old and new cache entries
    local normalized_id = page_id:gsub('-', '')
    local page_data = cache_pages.get_page(normalized_id)
    if page_data then
      table.insert(items, M.cached_row_to_item(page_data))
    end
  end
  return items
end

--- Fetch cached results
--- Strategy:
--- 1. Empty query -> recent pages (frecency sorted)
--- 2. query_cache first (preserves Notion order)
--- 3. frecency fallback (for queries not yet in cache)
---@param query string
---@param limit integer
---@return neotion.PageItem[]
local function fetch_cached(query, limit)
  -- Use mock if set (for testing)
  if mock_cache_fetcher then
    local results = mock_cache_fetcher(query, limit) or {}
    log.debug('Cache fetch (mock)', { query = query, count = #results })
    return results
  end

  -- Ensure cache is initialized
  local cache_ok, cache = pcall(require, 'neotion.cache')
  if cache_ok and cache.is_available() and not cache.is_initialized() then
    local init_ok = cache.init()
    log.debug('Cache init during fetch_cached', { success = init_ok })
  end

  local ok, cache_pages = pcall(require, 'neotion.cache.pages')
  if not ok then
    log.debug('Cache module not available')
    return {}
  end

  local normalized_query = (query or ''):match('^%s*(.-)%s*$') or ''

  -- Try query cache first for ALL queries (including empty)
  -- This preserves Notion's relevance order
  local qc_ok, query_cache = pcall(require, 'neotion.cache.query_cache')
  if qc_ok then
    local cached_query
    if normalized_query == '' then
      -- For empty query, just do exact match
      cached_query = query_cache.get('')
    else
      -- For non-empty, try prefix fallback
      cached_query = query_cache.get_with_prefix_fallback(query)
    end

    if cached_query then
      local items = page_ids_to_items(cached_query.page_ids, limit)
      log.debug('Query cache hit', {
        query = normalized_query,
        matched = cached_query.matched_query,
        is_fallback = cached_query.is_fallback or false,
        count = #items,
      })
      return items
    end
  end

  -- Fallback: Empty query -> recent pages (frecency sorted)
  if normalized_query == '' then
    local rows = cache_pages.get_recent(limit)
    log.debug('Empty query fallback - showing recent pages (frecency)', { count = #rows })
    local items = {}
    for _, row in ipairs(rows) do
      table.insert(items, M.cached_row_to_item(row))
    end
    return items
  end

  -- Fallback: non-empty query -> frecency-based search
  local rows = cache_pages.search(query, limit)
  log.debug('Frecency cache search fallback', { query = query, count = #rows, limit = limit })

  local items = {}
  for _, row in ipairs(rows) do
    table.insert(items, M.cached_row_to_item(row))
  end
  return items
end

--- Start API search
---@param state neotion.LiveSearchState
---@param query string
local function start_api_search(state, query)
  -- Cancel previous request if any
  cancel_api_request(state)

  state.is_loading = true
  if state.callbacks.on_loading then
    state.callbacks.on_loading(true)
  end

  local function handle_response(result)
    -- Silently ignore cancelled requests - a new request has already started
    if result.error == 'Request cancelled' then
      return
    end

    state.is_loading = false
    if state.callbacks.on_loading then
      state.callbacks.on_loading(false)
    end

    if result.error then
      if state.callbacks.on_error then
        state.callbacks.on_error(result.error)
      end
      return
    end

    -- Convert API pages to items
    local api_items = {}
    for _, page in ipairs(result.pages or {}) do
      table.insert(api_items, M.api_page_to_item(page))
    end
    state.api_results = api_items

    -- Merge with cached results
    local merged = M.merge_results(api_items, state.cached_results)

    -- Save API results to cache for future searches
    if result.pages and #result.pages > 0 then
      -- Ensure cache is initialized before saving
      local cache_ok, cache = pcall(require, 'neotion.cache')
      if cache_ok and cache.is_available() and not cache.is_initialized() then
        local init_ok = cache.init()
        log.debug('Cache init before saving API results', { success = init_ok })
      end

      -- Save page metadata to pages cache
      local pages_cache_ok, cache_pages = pcall(require, 'neotion.cache.pages')
      if pages_cache_ok then
        local saved = cache_pages.save_pages_batch(result.pages)
        log.debug('Saved API results to pages cache', { count = saved })
      end

      -- Save query->page_ids mapping to query cache (preserves Notion order)
      -- IMPORTANT: Normalize IDs (remove dashes) to match pages table format
      local qc_ok, query_cache_mod = pcall(require, 'neotion.cache.query_cache')
      if qc_ok then
        local page_ids = {}
        for _, page in ipairs(result.pages) do
          local normalized_id = page.id and page.id:gsub('-', '')
          if normalized_id then
            table.insert(page_ids, normalized_id)
          end
        end
        query_cache_mod.set(query, page_ids)
        log.debug('Saved query to query cache', { query = query, count = #page_ids })
      end
    end

    log.debug('API search complete', { api_count = #api_items, merged_count = #merged })

    -- Call callback with final results
    state.callbacks.on_results(merged, true)
  end

  -- Use mock if set (for testing)
  if mock_api_searcher then
    local result = mock_api_searcher(query, handle_response)
    if result then
      state.request_id = result.request_id
      state.cancel_fn = result.cancel
    end
    return
  end

  -- Real implementation using pages API
  local ok, pages_api = pcall(require, 'neotion.api.pages')
  if not ok then
    handle_response({ error = 'API module not available' })
    return
  end

  local result = pages_api.search_with_cancel(query, handle_response)
  if result then
    state.request_id = result.request_id
    state.cancel_fn = result.cancel
  end
end

--- Update search query with debouncing
--- Called on every prompt change
---@param instance_id integer|string
---@param query string
function M.update_query(instance_id, query)
  local state = states[instance_id]
  if not state then
    return
  end

  state.query = query
  stop_debounce_timer(state)

  -- Show cached results immediately if enabled
  if state.show_cached then
    local cached = fetch_cached(query, state.limit)
    state.cached_results = cached
    -- Call on_results with is_final = false (more results coming from API)
    state.callbacks.on_results(cached, false)
  end

  -- Debounce API call
  local debounce_ms = state.debounce_ms
  if debounce_ms == 0 then
    -- No debounce, start API search immediately
    start_api_search(state, query)
  else
    -- Start debounce timer
    state.debounce_timer = vim.fn.timer_start(debounce_ms, function()
      state.debounce_timer = nil
      vim.schedule(function()
        -- Double-check query hasn't changed and state still exists
        if states[instance_id] and states[instance_id].query == query then
          start_api_search(states[instance_id], query)
        end
      end)
    end)
  end
end

--- Force immediate search (bypass debounce)
--- Useful for initial load or explicit refresh
---@param instance_id integer|string
---@param query string
function M.search_immediate(instance_id, query)
  local state = states[instance_id]
  if not state then
    return
  end

  state.query = query
  stop_debounce_timer(state)

  -- Show cached results immediately if enabled
  if state.show_cached then
    local cached = fetch_cached(query, state.limit)
    state.cached_results = cached
    -- Call on_results with is_final = false (more results coming from API)
    state.callbacks.on_results(cached, false)
  end

  -- Start API search immediately (no debounce)
  start_api_search(state, query)
end

--- Cancel any pending search
---@param instance_id integer|string
function M.cancel(instance_id)
  local state = states[instance_id]
  if not state then
    return
  end

  stop_debounce_timer(state)

  -- Cancel API request if in flight
  if state.cancel_fn then
    state.cancel_fn()
    state.cancel_fn = nil
  end
end

return M
