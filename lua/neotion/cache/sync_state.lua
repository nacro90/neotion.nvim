---@class neotion.cache.sync_state
---@brief Sync state tracking for pages (hash comparison, timestamps)
local M = {}

---@class neotion.SyncState
---@field page_id string
---@field local_hash? string Hash of local content
---@field remote_hash? string Hash of remote content
---@field last_push_time? integer Unix timestamp of last push
---@field last_pull_time? integer Unix timestamp of last pull
---@field sync_status string 'unknown'|'synced'|'modified'|'conflict'|'error'

local log_module
local log

---@return neotion.Logger
local function get_log()
  if not log then
    log_module = log_module or require('neotion.log')
    log = log_module.get_logger('cache.sync_state')
  end
  return log
end

---Get database instance
---@return table|nil
local function get_db()
  local cache = require('neotion.cache')
  if not cache.is_initialized() then
    get_log().warn('Cache not initialized')
    return nil
  end
  return cache.get_db()
end

---Get sync state for a page
---@param page_id string
---@return neotion.SyncState|nil
function M.get_state(page_id)
  local db = get_db()
  if not db then
    return nil
  end

  local rows = db:query(
    [[
    SELECT page_id, local_hash, remote_hash, last_push_time, last_pull_time, sync_status
    FROM sync_state
    WHERE page_id = ?
  ]],
    { page_id }
  )

  if not rows or #rows == 0 then
    return nil
  end

  local row = rows[1]
  return {
    page_id = row.page_id,
    local_hash = row.local_hash,
    remote_hash = row.remote_hash,
    last_push_time = row.last_push_time,
    last_pull_time = row.last_pull_time,
    sync_status = row.sync_status or 'unknown',
  }
end

---Update sync state after pulling content from API
---@param page_id string
---@param content_hash string Hash of pulled content
---@return boolean success
function M.update_after_pull(page_id, content_hash)
  local db = get_db()
  if not db then
    return false
  end

  local now = os.time()

  local ok = db:execute(
    [[
    INSERT INTO sync_state (page_id, remote_hash, last_pull_time, sync_status)
    VALUES (?, ?, ?, 'synced')
    ON CONFLICT(page_id) DO UPDATE SET
      remote_hash = excluded.remote_hash,
      last_pull_time = excluded.last_pull_time,
      sync_status = 'synced'
  ]],
    { page_id, content_hash, now }
  )

  if ok then
    get_log().debug('Updated sync state after pull', { page_id = page_id, hash = content_hash })
  end

  return ok ~= nil
end

---Update sync state after pushing content to API
---@param page_id string
---@param content_hash string Hash of pushed content
---@return boolean success
function M.update_after_push(page_id, content_hash)
  local db = get_db()
  if not db then
    return false
  end

  local now = os.time()

  -- After push, both local and remote should have same hash
  local ok = db:execute(
    [[
    INSERT INTO sync_state (page_id, local_hash, remote_hash, last_push_time, sync_status)
    VALUES (?, ?, ?, ?, 'synced')
    ON CONFLICT(page_id) DO UPDATE SET
      local_hash = excluded.local_hash,
      remote_hash = excluded.remote_hash,
      last_push_time = excluded.last_push_time,
      sync_status = 'synced'
  ]],
    { page_id, content_hash, content_hash, now }
  )

  if ok then
    get_log().debug('Updated sync state after push', { page_id = page_id, hash = content_hash })
  end

  return ok ~= nil
end

---Check if content has changed compared to stored state
---@param page_id string
---@param new_hash string Hash to compare
---@return boolean changed True if content differs or no state exists
function M.has_changed(page_id, new_hash)
  local state = M.get_state(page_id)

  if not state then
    return true -- No state means we should treat as changed
  end

  -- Compare with both local and remote hash
  if state.remote_hash == new_hash then
    return false
  end
  if state.local_hash == new_hash then
    return false
  end

  return true
end

---Mark page as locally modified
---@param page_id string
---@param local_hash string Hash of modified content
---@return boolean success
function M.mark_modified(page_id, local_hash)
  local db = get_db()
  if not db then
    return false
  end

  -- Check if page exists in pages table first (FK constraint)
  local page_exists = db:query('SELECT 1 FROM pages WHERE id = ? LIMIT 1', { page_id })
  if not page_exists or #page_exists == 0 then
    get_log().warn('Cannot mark modified: page not in cache', { page_id = page_id })
    return false
  end

  local ok = db:execute(
    [[
    INSERT INTO sync_state (page_id, local_hash, sync_status)
    VALUES (?, ?, 'modified')
    ON CONFLICT(page_id) DO UPDATE SET
      local_hash = excluded.local_hash,
      sync_status = 'modified'
  ]],
    { page_id, local_hash }
  )

  if ok then
    get_log().debug('Marked page as modified', { page_id = page_id, hash = local_hash })
  end

  return ok ~= nil
end

---Delete sync state for a page
---@param page_id string
---@return boolean success
function M.delete_state(page_id)
  local db = get_db()
  if not db then
    return false
  end

  db:execute(
    [[
    DELETE FROM sync_state WHERE page_id = ?
  ]],
    { page_id }
  )

  get_log().debug('Deleted sync state', { page_id = page_id })
  return true
end

---Get all sync states
---@return neotion.SyncState[]
function M.get_all_states()
  local db = get_db()
  if not db then
    return {}
  end

  local rows = db:query([[
    SELECT page_id, local_hash, remote_hash, last_push_time, last_pull_time, sync_status
    FROM sync_state
    ORDER BY last_pull_time DESC
  ]])

  if not rows then
    return {}
  end

  local states = {}
  for _, row in ipairs(rows) do
    table.insert(states, {
      page_id = row.page_id,
      local_hash = row.local_hash,
      remote_hash = row.remote_hash,
      last_push_time = row.last_push_time,
      last_pull_time = row.last_pull_time,
      sync_status = row.sync_status or 'unknown',
    })
  end

  return states
end

return M
