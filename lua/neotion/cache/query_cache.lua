--- Query-based response cache for instant search results
--- Caches Notion API search responses to provide instant results
--- while background refresh fetches fresh data
---@class neotion.cache.QueryCache
local M = {}

local log_module = require('neotion.log')
local log = log_module.get_logger('cache.query_cache')

--- Get database instance
---@return table? db SQLite database wrapper or nil
local function get_db()
  local ok, cache = pcall(require, 'neotion.cache')
  if not ok then
    return nil
  end
  return cache.get_db()
end

--- Normalize query for consistent cache keys
--- Lowercases and trims whitespace
---@param query string? Query to normalize
---@return string normalized Normalized query
function M.normalize_query(query)
  if not query then
    return ''
  end
  -- Lowercase and trim leading/trailing whitespace
  return query:lower():match('^%s*(.-)%s*$') or ''
end

--- Store a query result in cache
--- Page IDs are stored in the order returned by Notion API (relevance order)
---@param query string Search query
---@param page_ids string[] Array of page IDs in Notion's relevance order
---@return boolean success True if saved successfully
function M.set(query, page_ids)
  local normalized = M.normalize_query(query)

  -- Don't cache empty queries - use frecency instead
  if normalized == '' then
    return false
  end

  local db = get_db()
  if not db then
    log.warn('Database not available for query cache')
    return false
  end

  local now = os.time()
  local page_ids_json = vim.json.encode(page_ids)

  local sql = [[
    INSERT OR REPLACE INTO query_cache (query, page_ids, result_count, cached_at)
    VALUES (:query, :page_ids, :result_count, :cached_at)
  ]]

  local success = db:execute(sql, {
    query = normalized,
    page_ids = page_ids_json,
    result_count = #page_ids,
    cached_at = now,
  })

  if success then
    log.debug('Cached query', { query = normalized, count = #page_ids })
    -- Evict old entries if over limit
    local config_ok, config = pcall(require, 'neotion.config')
    if config_ok then
      local cfg = config.get()
      local max_entries = cfg.search.query_cache_size or 500
      M.evict(max_entries)
    end
  else
    log.error('Failed to cache query', { query = normalized })
  end

  return success
end

--- Get cached result for a query
--- Returns nil for empty queries (use frecency instead)
---@param query string Search query
---@return table? result { page_ids: string[], cached_at: number, result_count: number } or nil
function M.get(query)
  local normalized = M.normalize_query(query)

  -- Empty queries should use frecency, not query cache
  if normalized == '' then
    return nil
  end

  local db = get_db()
  if not db then
    return nil
  end

  local sql = [[
    SELECT page_ids, cached_at, result_count
    FROM query_cache
    WHERE query = :query
  ]]

  local rows = db:query(sql, { query = normalized })
  if not rows or #rows == 0 then
    return nil
  end

  local row = rows[1]
  local ok, page_ids = pcall(vim.json.decode, row.page_ids)
  if not ok then
    log.warn('Failed to decode cached page_ids', { query = normalized, error = page_ids })
    -- Delete corrupted entry
    M.delete(normalized)
    return nil
  end

  return {
    page_ids = page_ids,
    cached_at = row.cached_at,
    result_count = row.result_count,
    is_fallback = false,
    matched_query = normalized,
  }
end

--- Get cached result with prefix fallback
--- If exact query not found, tries progressively shorter prefixes
---@param query string Search query
---@return table? result { page_ids: string[], cached_at: number, result_count: number, is_fallback: boolean, matched_query: string } or nil
function M.get_with_prefix_fallback(query)
  local normalized = M.normalize_query(query)

  if normalized == '' then
    return nil
  end

  -- Try exact match first
  local exact = M.get(normalized)
  if exact then
    exact.is_fallback = false
    exact.matched_query = normalized
    return exact
  end

  -- Try progressively shorter prefixes
  for len = #normalized - 1, 1, -1 do
    local prefix = normalized:sub(1, len)
    local result = M.get(prefix)
    if result then
      result.is_fallback = true
      result.matched_query = prefix
      return result
    end
  end

  return nil
end

--- Delete a cached query
---@param query string Search query to delete
function M.delete(query)
  local normalized = M.normalize_query(query)

  local db = get_db()
  if not db then
    return
  end

  db:execute('DELETE FROM query_cache WHERE query = :query', { query = normalized })
end

--- Clear all cached queries
function M.clear()
  local db = get_db()
  if not db then
    return
  end

  db:execute('DELETE FROM query_cache', {})
  log.info('Query cache cleared')
end

--- Get count of cached queries
---@return integer count Number of cached queries
function M.count()
  local db = get_db()
  if not db then
    return 0
  end

  local rows = db:query('SELECT COUNT(*) as cnt FROM query_cache', {})
  if not rows or #rows == 0 then
    return 0
  end

  return rows[1].cnt or 0
end

--- Evict oldest entries to stay under limit
--- Uses LRU strategy based on cached_at timestamp
---@param limit integer Maximum number of entries to keep
function M.evict(limit)
  local db = get_db()
  if not db then
    return
  end

  local current = M.count()
  if current <= limit then
    return
  end

  local to_delete = current - limit

  -- Delete oldest entries (smallest cached_at)
  local sql = [[
    DELETE FROM query_cache
    WHERE query IN (
      SELECT query FROM query_cache
      ORDER BY cached_at ASC
      LIMIT :to_delete
    )
  ]]

  db:execute(sql, { to_delete = to_delete })
  log.debug('Evicted query cache entries', { deleted = to_delete, limit = limit })
end

--- Get cache statistics
---@return table stats { query_count: number, total_page_ids: number, oldest_cached_at: number?, newest_cached_at: number? }
function M.get_stats()
  local db = get_db()
  if not db then
    return {
      query_count = 0,
      total_page_ids = 0,
      oldest_cached_at = nil,
      newest_cached_at = nil,
    }
  end

  local sql = [[
    SELECT
      COUNT(*) as query_count,
      COALESCE(SUM(result_count), 0) as total_page_ids,
      MIN(cached_at) as oldest_cached_at,
      MAX(cached_at) as newest_cached_at
    FROM query_cache
  ]]

  local rows = db:query(sql, {})
  if not rows or #rows == 0 then
    return {
      query_count = 0,
      total_page_ids = 0,
      oldest_cached_at = nil,
      newest_cached_at = nil,
    }
  end

  local row = rows[1]
  return {
    query_count = row.query_count or 0,
    total_page_ids = row.total_page_ids or 0,
    oldest_cached_at = row.oldest_cached_at,
    newest_cached_at = row.newest_cached_at,
  }
end

--- Reset for testing (clears cache)
function M._reset_for_testing()
  M.clear()
end

return M
