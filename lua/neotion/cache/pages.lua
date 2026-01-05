--- Page content cache operations
--- Stores and retrieves page metadata and block content from SQLite
---@class neotion.cache.Pages
local M = {}

local log_module = require('neotion.log')
local log = log_module.get_logger('cache.pages')

--- Get the cache database instance
---@return neotion.cache.DBInstance?
local function get_db()
  local cache = require('neotion.cache')
  return cache.get_db()
end

--- Save page metadata to cache
---@param page_id string Normalized page ID (no dashes)
---@param page table Notion page object from API
---@return boolean success
function M.save_page(page_id, page)
  local db = get_db()
  if not db then
    log.debug('Cache not initialized, skipping save_page')
    return false
  end

  local pages_api = require('neotion.api.pages')
  local title = pages_api.get_title(page)
  local parent_type, parent_id = pages_api.get_parent(page)
  local icon = pages_api.get_icon(page)
  local icon_type = page.icon and page.icon.type or nil

  -- Parse timestamps
  local last_edited_time = 0
  if page.last_edited_time then
    -- ISO 8601 to unix timestamp (approximate)
    local pattern = '(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)'
    local y, m, d, h, min, s = page.last_edited_time:match(pattern)
    if y then
      last_edited_time = os.time({ year = y, month = m, day = d, hour = h, min = min, sec = s })
    end
  end

  local created_time = 0
  if page.created_time then
    local pattern = '(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)'
    local y, m, d, h, min, s = page.created_time:match(pattern)
    if y then
      created_time = os.time({ year = y, month = m, day = d, hour = h, min = min, sec = s })
    end
  end

  local now = os.time()

  -- Use INSERT OR REPLACE for upsert
  local sql = [[
    INSERT OR REPLACE INTO pages
    (id, title, icon, icon_type, parent_type, parent_id, last_edited_time, created_time, cached_at, last_opened_at, open_count, is_deleted)
    VALUES (:id, :title, :icon, :icon_type, :parent_type, :parent_id, :last_edited_time, :created_time, :cached_at, :last_opened_at,
            COALESCE((SELECT open_count FROM pages WHERE id = :id), 0) + 1, 0)
  ]]

  local success = db:execute(sql, {
    id = page_id,
    title = title,
    icon = icon,
    icon_type = icon_type,
    parent_type = parent_type,
    parent_id = parent_id,
    last_edited_time = last_edited_time,
    created_time = created_time,
    cached_at = now,
    last_opened_at = now,
  })

  if success then
    log.debug('Page metadata saved', { page_id = page_id, title = title })
  else
    log.warn('Failed to save page metadata', { page_id = page_id })
  end

  return success
end

--- Save page content (blocks) to cache
---@param page_id string Normalized page ID
---@param blocks table[] Array of block objects from API
---@return boolean success
function M.save_content(page_id, blocks)
  local db = get_db()
  if not db then
    log.debug('Cache not initialized, skipping save_content')
    return false
  end

  local hash = require('neotion.cache.hash')

  -- Serialize blocks to JSON
  local ok, blocks_json = pcall(vim.json.encode, blocks)
  if not ok then
    log.error('Failed to serialize blocks', { page_id = page_id, error = blocks_json })
    return false
  end

  local content_hash = hash.page_content(blocks)
  local now = os.time()

  local sql = [[
    INSERT OR REPLACE INTO page_content
    (page_id, blocks_json, content_hash, block_count, fetched_at)
    VALUES (:page_id, :blocks_json, :content_hash, :block_count, :fetched_at)
  ]]

  local success = db:execute(sql, {
    page_id = page_id,
    blocks_json = blocks_json,
    content_hash = content_hash,
    block_count = #blocks,
    fetched_at = now,
  })

  if success then
    log.info('Page content cached', { page_id = page_id, block_count = #blocks })
  else
    log.warn('Failed to cache page content', { page_id = page_id })
  end

  return success
end

--- Get page metadata from cache
---@param page_id string Normalized page ID
---@return table? page_meta Page metadata or nil if not found
function M.get_page(page_id)
  local db = get_db()
  if not db then
    return nil
  end

  local row = db:query_one('SELECT * FROM pages WHERE id = :id AND is_deleted = 0', { id = page_id })
  if row then
    log.debug('Page metadata cache hit', { page_id = page_id })
  end
  return row
end

--- Get page content (blocks) from cache
---@param page_id string Normalized page ID
---@return table[]? blocks Array of block objects or nil if not found
---@return string? content_hash Hash of the content
function M.get_content(page_id)
  local db = get_db()
  if not db then
    return nil, nil
  end

  local row =
    db:query_one('SELECT blocks_json, content_hash FROM page_content WHERE page_id = :page_id', { page_id = page_id })
  if not row then
    log.debug('Page content cache miss', { page_id = page_id })
    return nil, nil
  end

  local ok, blocks = pcall(vim.json.decode, row.blocks_json)
  if not ok then
    log.error('Failed to deserialize cached blocks', { page_id = page_id, error = blocks })
    return nil, nil
  end

  log.info('Page content cache hit', { page_id = page_id, block_count = #blocks })
  return blocks, row.content_hash
end

--- Check if page exists in cache
---@param page_id string Normalized page ID
---@return boolean exists
function M.has_page(page_id)
  local db = get_db()
  if not db then
    return false
  end

  local row = db:query_one('SELECT 1 FROM pages WHERE id = :id AND is_deleted = 0', { id = page_id })
  return row ~= nil
end

--- Check if page content exists in cache
---@param page_id string Normalized page ID
---@return boolean exists
function M.has_content(page_id)
  local db = get_db()
  if not db then
    return false
  end

  local row = db:query_one('SELECT 1 FROM page_content WHERE page_id = :page_id', { page_id = page_id })
  return row ~= nil
end

--- Update open statistics for a page
---@param page_id string Normalized page ID
---@return boolean success
function M.update_open_stats(page_id)
  local db = get_db()
  if not db then
    return false
  end

  local sql = [[
    UPDATE pages SET
      open_count = open_count + 1,
      last_opened_at = :now
    WHERE id = :id
  ]]

  return db:execute(sql, { id = page_id, now = os.time() })
end

--- Mark page as deleted (soft delete)
---@param page_id string Normalized page ID
---@return boolean success
function M.delete_page(page_id)
  local db = get_db()
  if not db then
    return false
  end

  local success = db:execute('UPDATE pages SET is_deleted = 1 WHERE id = :id', { id = page_id })
  if success then
    log.debug('Page marked as deleted', { page_id = page_id })
  end
  return success
end

--- Get recently opened pages (for frecency-based suggestions)
---@param limit integer? Maximum number of pages (default 20)
---@return table[] pages Array of page metadata
function M.get_recent(limit)
  local db = get_db()
  if not db then
    return {}
  end

  limit = limit or 20
  local sql = [[
    SELECT * FROM pages
    WHERE is_deleted = 0
    ORDER BY last_opened_at DESC
    LIMIT :limit
  ]]

  return db:query(sql, { limit = limit })
end

--- Search pages by title (for picker)
---@param query string Search query
---@param limit integer? Maximum number of results (default 50)
---@return table[] pages Array of matching pages
function M.search(query, limit)
  local db = get_db()
  if not db then
    return {}
  end

  limit = limit or 50
  local sql = [[
    SELECT * FROM pages
    WHERE is_deleted = 0 AND title LIKE :pattern
    ORDER BY open_count DESC, last_opened_at DESC
    LIMIT :limit
  ]]

  return db:query(sql, { pattern = '%' .. query .. '%', limit = limit })
end

--- Get cache age for a page
---@param page_id string Normalized page ID
---@return integer? age_seconds Seconds since last cache, or nil if not cached
function M.get_cache_age(page_id)
  local db = get_db()
  if not db then
    return nil
  end

  local row = db:query_one('SELECT fetched_at FROM page_content WHERE page_id = :page_id', { page_id = page_id })
  if not row then
    return nil
  end

  return os.time() - row.fetched_at
end

--- Clear all cached content (keeps page metadata)
---@return boolean success
function M.clear_content()
  local db = get_db()
  if not db then
    return false
  end

  local success = db:execute('DELETE FROM page_content')
  if success then
    log.info('All page content cleared from cache')
  end
  return success
end

--- Clear entire cache (pages and content)
---@return boolean success
function M.clear_all()
  local db = get_db()
  if not db then
    return false
  end

  local success = db:transaction(function()
    db:execute('DELETE FROM page_content')
    db:execute('DELETE FROM pages')
    return true
  end)

  if success then
    log.info('Cache cleared completely')
  end
  return success
end

return M
