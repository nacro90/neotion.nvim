--- SQLite database wrapper for neotion cache
--- Provides connection management, query execution, and schema initialization
---@class neotion.cache.DB
local M = {}

local log_module = require('neotion.log')
local schema = require('neotion.cache.schema')
local log = log_module.get_logger('cache.db')

---@type table?
--- Cached at module level intentionally; cleared only on Neovim restart
local sqlite_db_module = nil

--- Check if sqlite.lua is available
--- @return boolean
function M.is_sqlite_available()
  if sqlite_db_module ~= nil then
    return true
  end

  local ok, lib = pcall(require, 'sqlite.db')
  if ok and lib then
    sqlite_db_module = lib
    log.debug('sqlite.lua loaded successfully')
    return true
  end

  log.debug('sqlite.lua require failed', { ok = ok, error = tostring(lib) })
  return false
end

--- Get the default database path
--- @return string path Default database file path
function M.get_default_path()
  local cache_dir = vim.fn.stdpath('cache')
  return cache_dir .. '/neotion.db'
end

---@class neotion.cache.DBInstance
---@field private _db table sqlite.lua database object
---@field private _path string database file path
---@field private _open boolean whether database is open
local DB = {}
DB.__index = DB

--- Create a new database instance
--- @param path string? Path to database file (nil = default path)
--- @return neotion.cache.DBInstance? instance Database instance or nil on error
function M.new(path)
  if not M.is_sqlite_available() then
    log.error('sqlite.lua is not available')
    return nil
  end

  path = path or M.get_default_path()

  -- Ensure directory exists (skip for :memory:)
  if path ~= ':memory:' then
    local dir = vim.fn.fnamemodify(path, ':h')
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, 'p')
    end
  end

  local instance = setmetatable({
    _path = path,
    _open = false,
    _db = nil,
  }, DB)

  local ok, err = instance:_open_db()
  if not ok then
    log.error('Failed to open database', { path = path, error = err })
    return nil
  end

  log.debug('Database opened', { path = path })
  return instance
end

--- Open the database and initialize schema
--- @return boolean success
--- @return string? error
function DB:_open_db()
  local ok, result = pcall(function()
    -- sqlite.lua: require("sqlite.db"):open(path)
    self._db = sqlite_db_module:open(self._path)
    if not self._db then
      error('Failed to open database')
    end

    -- Enable foreign keys
    self._db:execute('PRAGMA foreign_keys = ON')

    -- Initialize schema
    self:_init_schema()

    self._open = true
    return true
  end)

  if ok then
    return true
  else
    return false, tostring(result)
  end
end

--- Initialize database schema
function DB:_init_schema()
  -- Check current schema version
  local version = self:_get_raw_schema_version()

  if version == 0 then
    -- Fresh database - create all tables
    log.info('Initializing database schema', { version = schema.VERSION })
    local statements = schema.get_all_statements()
    for _, stmt in ipairs(statements) do
      self._db:execute(stmt)
    end

    -- Record schema version (use eval for parameterized INSERT)
    self._db:eval('INSERT INTO schema_version (version, applied_at) VALUES (:version, :applied_at)', {
      version = schema.VERSION,
      applied_at = os.time(),
    })
  elseif version < schema.VERSION then
    -- Need migration
    log.info('Migrating database schema', { from = version, to = schema.VERSION })
    for v = version + 1, schema.VERSION do
      local migration = schema.get_migration(v)
      if migration then
        for _, stmt in ipairs(migration) do
          self._db:execute(stmt)
        end
      end
      self._db:eval('INSERT INTO schema_version (version, applied_at) VALUES (:version, :applied_at)', {
        version = v,
        applied_at = os.time(),
      })
    end
  end
end

--- Get raw schema version (before tables might exist)
--- @return integer version
function DB:_get_raw_schema_version()
  -- Check if schema_version table exists
  -- Note: sqlite.lua eval() returns boolean if no rows, table if rows
  local result = self._db:eval("SELECT name FROM sqlite_master WHERE type='table' AND name='schema_version'")
  if type(result) ~= 'table' or #result == 0 then
    return 0
  end

  -- Get latest version
  result = self._db:eval('SELECT version FROM schema_version ORDER BY version DESC LIMIT 1')
  if type(result) == 'table' and #result > 0 then
    return result[1].version
  end

  return 0
end

--- Check if database is open
--- @return boolean
function DB:is_open()
  return self._open and self._db ~= nil
end

--- Execute a SQL statement (INSERT, UPDATE, DELETE)
--- @param sql string SQL statement with ? placeholders
--- @param params table? Parameters to bind
--- @return boolean success
function DB:execute(sql, params)
  if not self:is_open() then
    log.error('Database is not open')
    return false
  end

  local ok, result = pcall(function()
    if params and next(params) ~= nil then
      -- sqlite.lua: eval() supports both positional (?) and named (:name) parameters
      -- For positional: pass array like { 'value1', 'value2' }
      -- For named: pass table like { name = 'value' }
      -- Note: #params only works for arrays, use next() for both array and hash tables
      return self._db:eval(sql, params)
    else
      self._db:execute(sql)
      return true
    end
  end)

  if not ok then
    log.debug('Execute failed', { sql = sql:sub(1, 100), error = tostring(result) })
    return false
  end

  -- eval returns false on constraint violations, true on success
  if type(result) == 'boolean' and not result then
    log.debug('Execute constraint violation', { sql = sql:sub(1, 100) })
    return false
  end

  return true
end

--- Query the database (SELECT)
--- @param sql string SQL query with ? placeholders
--- @param params table? Parameters to bind
--- @return table[] rows Array of row tables
function DB:query(sql, params)
  if not self:is_open() then
    log.error('Database is not open')
    return {}
  end

  local ok, result = pcall(function()
    if params and next(params) ~= nil then
      return self._db:eval(sql, params)
    else
      return self._db:eval(sql)
    end
  end)

  if not ok then
    log.debug('Query failed', { sql = sql:sub(1, 100), error = tostring(result) })
    return {}
  end

  -- sqlite.lua eval() returns boolean if no rows, table if rows
  if type(result) ~= 'table' then
    return {}
  end

  return result
end

--- Query for a single row
--- @param sql string SQL query
--- @param params table? Parameters
--- @return table? row Single row or nil
function DB:query_one(sql, params)
  local rows = self:query(sql, params)
  if #rows > 0 then
    return rows[1]
  end
  return nil
end

--- Execute statements in a transaction
--- @param fn function Function to execute (should return true on success)
--- @return boolean success
--- @return string? error
function DB:transaction(fn)
  if not self:is_open() then
    return false, 'Database is not open'
  end

  self._db:execute('BEGIN TRANSACTION')

  local ok, result = pcall(fn)

  if ok and result then
    self._db:execute('COMMIT')
    return true
  else
    self._db:execute('ROLLBACK')
    if not ok then
      return false, tostring(result)
    end
    return false, 'Transaction returned false'
  end
end

--- Get current schema version
--- @return integer version
function DB:get_schema_version()
  if not self:is_open() then
    return 0
  end

  local row = self:query_one('SELECT version FROM schema_version ORDER BY version DESC LIMIT 1')
  if row then
    return row.version
  end
  return 0
end

--- Run VACUUM to optimize database
--- @return boolean success
function DB:vacuum()
  if not self:is_open() then
    return false
  end

  local ok = pcall(function()
    self._db:execute('VACUUM')
  end)

  if ok then
    log.debug('Database vacuumed')
  end

  return ok
end

--- Get database statistics
--- @return {page_count: integer, content_count: integer, size_bytes: integer}
function DB:stats()
  if not self:is_open() then
    return { page_count = 0, content_count = 0, size_bytes = 0 }
  end

  local page_row = self:query_one('SELECT COUNT(*) as count FROM pages WHERE is_deleted = 0')
  local content_row = self:query_one('SELECT COUNT(*) as count FROM page_content')

  local size_bytes = 0
  if vim.fn.filereadable(self._path) == 1 then
    size_bytes = vim.fn.getfsize(self._path)
  end

  return {
    page_count = page_row and page_row.count or 0,
    content_count = content_row and content_row.count or 0,
    size_bytes = size_bytes,
  }
end

--- Close the database connection
function DB:close()
  if self._db then
    pcall(function()
      self._db:close()
    end)
    self._db = nil
  end
  self._open = false
  log.debug('Database closed', { path = self._path })
end

return M
