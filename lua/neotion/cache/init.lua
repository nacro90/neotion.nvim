--- Cache orchestrator for neotion
--- Provides a unified interface for all cache operations
---@class neotion.Cache
local M = {}

local db_module = require('neotion.cache.db')
local log_module = require('neotion.log')
local log = log_module.get_logger('cache')

-- Re-export hash module for convenience
M.hash = require('neotion.cache.hash')

---@type neotion.cache.DBInstance?
local db_instance = nil

--- Check if sqlite.lua is available for caching
--- @return boolean available
function M.is_available()
  local available = db_module.is_sqlite_available()
  if not available then
    log.debug('sqlite.lua not available - cache disabled')
  end
  return available
end

--- Check if cache is initialized and ready
--- @return boolean initialized
function M.is_initialized()
  return db_instance ~= nil and db_instance:is_open()
end

--- Initialize the cache system
--- @param path string? Custom database path (nil = default)
--- @return boolean success
function M.init(path)
  if M.is_initialized() then
    log.debug('Cache already initialized')
    return true
  end

  if not M.is_available() then
    log.warn('Cache not available (sqlite.lua not installed)')
    return false
  end

  db_instance = db_module.new(path)
  if not db_instance then
    log.error('Failed to initialize cache database')
    return false
  end

  log.info('Cache initialized', { path = path or db_module.get_default_path() })
  return true
end

--- Get the database instance for direct access
--- @return neotion.cache.DBInstance? db
function M.get_db()
  return db_instance
end

--- Close the cache database
function M.close()
  if db_instance then
    db_instance:close()
    db_instance = nil
    log.debug('Cache closed')
  end
end

--- Get cache statistics
--- @return {page_count: integer, content_count: integer, size_bytes: integer, initialized: boolean}
function M.stats()
  if not M.is_initialized() then
    return {
      page_count = 0,
      content_count = 0,
      size_bytes = 0,
      initialized = false,
    }
  end

  local db_stats = db_instance:stats()
  return {
    page_count = db_stats.page_count,
    content_count = db_stats.content_count,
    size_bytes = db_stats.size_bytes,
    initialized = true,
  }
end

--- Run VACUUM to optimize the database
--- @return boolean success
function M.vacuum()
  if not M.is_initialized() then
    return false
  end
  return db_instance:vacuum()
end

--- Reset for testing (clears instance without closing)
--- @private
function M._reset()
  db_instance = nil
end

return M
