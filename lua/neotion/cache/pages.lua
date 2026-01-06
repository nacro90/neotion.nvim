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
  -- page.icon can be vim.NIL (userdata) when null in JSON, so check type
  local icon_type = (page.icon and type(page.icon) == 'table') and page.icon.type or nil

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

  -- Use INSERT ... ON CONFLICT ... DO UPDATE for upsert
  -- CRITICAL: Do NOT use INSERT OR REPLACE - it triggers DELETE which cascades to page_content!
  -- IMPORTANT: Do NOT increment open_count on save - only update_open_stats should do that
  -- IMPORTANT: Preserve last_opened_at - only update_open_stats should set it
  local sql = [[
    INSERT INTO pages
    (id, title, icon, icon_type, parent_type, parent_id, last_edited_time, created_time, cached_at, last_opened_at, open_count, is_deleted)
    VALUES (:id, :title, :icon, :icon_type, :parent_type, :parent_id, :last_edited_time, :created_time, :cached_at, NULL, 0, 0)
    ON CONFLICT(id) DO UPDATE SET
      title = excluded.title,
      icon = excluded.icon,
      icon_type = excluded.icon_type,
      parent_type = excluded.parent_type,
      parent_id = excluded.parent_id,
      last_edited_time = excluded.last_edited_time,
      created_time = excluded.created_time,
      cached_at = excluded.cached_at,
      is_deleted = 0
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

  -- Use INSERT ... ON CONFLICT for consistency (and future-proofing)
  local sql = [[
    INSERT INTO page_content
    (page_id, blocks_json, content_hash, block_count, fetched_at)
    VALUES (:page_id, :blocks_json, :content_hash, :block_count, :fetched_at)
    ON CONFLICT(page_id) DO UPDATE SET
      blocks_json = excluded.blocks_json,
      content_hash = excluded.content_hash,
      block_count = excluded.block_count,
      fetched_at = excluded.fetched_at
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

--- Search pages by title with frecency ranking
--- Frecency formula: score = open_count * 10 + max(0, (1 - age_days/30) * 100)
--- - Frequency: Each open adds 10 permanent points
--- - Recency: Recent opens add up to 100 points (decays to 0 over 30 days)
---@param query string Search query
---@param limit integer? Maximum number of results (default 50)
---@return table[] pages Array of matching pages ordered by frecency
function M.search(query, limit)
  local db = get_db()
  if not db then
    return {}
  end

  limit = limit or 50
  local now = os.time()

  -- Frecency calculation:
  -- - open_count * 10 = frequency score (permanent)
  -- - recency score = 100 points that decay to 0 over 30 days
  -- - If never opened (last_opened_at is NULL), recency = 0
  local sql = [[
    SELECT *,
      (
        COALESCE(open_count, 0) * 10 +
        CASE
          WHEN last_opened_at IS NULL THEN 0
          WHEN :now - last_opened_at >= 2592000 THEN 0
          ELSE (1.0 - (:now - last_opened_at) / 2592000.0) * 100.0
        END
      ) AS frecency_score
    FROM pages
    WHERE is_deleted = 0 AND title LIKE :pattern
    ORDER BY frecency_score DESC
    LIMIT :limit
  ]]

  return db:query(sql, { pattern = '%' .. query .. '%', limit = limit, now = now })
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

--- Save multiple pages in a single transaction (for search results)
--- Does NOT increment open_count - these are just API results being cached
---@param pages table[] Array of Notion page objects from API
---@return integer count Number of pages saved
function M.save_pages_batch(pages)
  local db = get_db()
  if not db then
    log.debug('Cache not initialized, skipping save_pages_batch')
    return 0
  end

  if #pages == 0 then
    return 0
  end

  local pages_api = require('neotion.api.pages')
  local count = 0

  local success = db:transaction(function()
    for _, page in ipairs(pages) do
      local page_id = page.id and page.id:gsub('-', '')
      if page_id then
        local title = pages_api.get_title(page)
        local parent_type, parent_id = pages_api.get_parent(page)
        local icon = pages_api.get_icon(page)
        local icon_type = (page.icon and type(page.icon) == 'table') and page.icon.type or nil

        -- Parse timestamps
        local last_edited_time = 0
        if page.last_edited_time then
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

        -- Use INSERT ... ON CONFLICT to avoid triggering CASCADE delete on page_content
        local sql = [[
          INSERT INTO pages
          (id, title, icon, icon_type, parent_type, parent_id, last_edited_time, created_time, cached_at, last_opened_at, open_count, is_deleted)
          VALUES (:id, :title, :icon, :icon_type, :parent_type, :parent_id, :last_edited_time, :created_time, :cached_at, NULL, 0, 0)
          ON CONFLICT(id) DO UPDATE SET
            title = excluded.title,
            icon = excluded.icon,
            icon_type = excluded.icon_type,
            parent_type = excluded.parent_type,
            parent_id = excluded.parent_id,
            last_edited_time = excluded.last_edited_time,
            created_time = excluded.created_time,
            cached_at = excluded.cached_at,
            is_deleted = 0
        ]]

        if
          db:execute(sql, {
            id = page_id,
            title = title,
            icon = icon,
            icon_type = icon_type,
            parent_type = parent_type,
            parent_id = parent_id,
            last_edited_time = last_edited_time,
            created_time = created_time,
            cached_at = now,
          })
        then
          count = count + 1
        end
      end
    end
    return true
  end)

  if success then
    log.info('Batch saved pages', { count = count })
  end
  return count
end

--- Evict lowest frecency pages when cache exceeds limit (soft delete)
---@param max_pages integer Maximum number of pages to keep
---@return integer evicted Number of pages evicted
function M.maybe_evict(max_pages)
  local db = get_db()
  if not db then
    return 0
  end

  -- Count current pages
  local count_row = db:query_one('SELECT COUNT(*) as count FROM pages WHERE is_deleted = 0')
  local current_count = count_row and count_row.count or 0

  if current_count <= max_pages then
    return 0
  end

  local to_evict = current_count - max_pages
  local now = os.time()

  -- Soft delete lowest frecency pages
  -- Frecency = open_count * 10 + recency_bonus (0-100 based on 30 day decay)
  local sql = [[
    UPDATE pages SET is_deleted = 1
    WHERE id IN (
      SELECT id FROM pages
      WHERE is_deleted = 0
      ORDER BY (
        COALESCE(open_count, 0) * 10 +
        CASE
          WHEN last_opened_at IS NULL THEN 0
          WHEN :now - last_opened_at >= 2592000 THEN 0
          ELSE (1.0 - (:now - last_opened_at) / 2592000.0) * 100.0
        END
      ) ASC
      LIMIT :limit
    )
  ]]

  local success = db:execute(sql, { now = now, limit = to_evict })
  if success then
    log.info('Evicted low-frecency pages', { count = to_evict })
    return to_evict
  end

  return 0
end

return M
