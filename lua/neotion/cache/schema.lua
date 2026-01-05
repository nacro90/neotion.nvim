--- SQLite schema definitions for neotion cache
--- Includes table definitions, indexes, and migrations
---@class neotion.cache.Schema
local M = {}

--- Current schema version
--- Increment this when making schema changes
M.VERSION = 1

--- Table creation statements
M.TABLES = {
  schema_version = [[
    CREATE TABLE IF NOT EXISTS schema_version (
      version INTEGER PRIMARY KEY,
      applied_at INTEGER NOT NULL
    )
  ]],

  pages = [[
    CREATE TABLE IF NOT EXISTS pages (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      icon TEXT,
      icon_type TEXT,
      parent_type TEXT,
      parent_id TEXT,
      last_edited_time INTEGER NOT NULL,
      created_time INTEGER,
      cached_at INTEGER NOT NULL,
      last_opened_at INTEGER,
      open_count INTEGER DEFAULT 0,
      is_deleted INTEGER DEFAULT 0
    )
  ]],

  page_content = [[
    CREATE TABLE IF NOT EXISTS page_content (
      page_id TEXT PRIMARY KEY,
      blocks_json TEXT NOT NULL,
      content_hash TEXT NOT NULL,
      block_count INTEGER NOT NULL,
      fetched_at INTEGER NOT NULL,
      FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE
    )
  ]],

  block_hashes = [[
    CREATE TABLE IF NOT EXISTS block_hashes (
      block_id TEXT PRIMARY KEY,
      page_id TEXT NOT NULL,
      content_hash TEXT NOT NULL,
      block_type TEXT NOT NULL,
      FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE
    )
  ]],

  sync_state = [[
    CREATE TABLE IF NOT EXISTS sync_state (
      page_id TEXT PRIMARY KEY,
      local_hash TEXT,
      remote_hash TEXT,
      last_push_time INTEGER,
      last_pull_time INTEGER,
      sync_status TEXT DEFAULT 'unknown',
      FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE
    )
  ]],

  sync_queue = [[
    CREATE TABLE IF NOT EXISTS sync_queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      page_id TEXT NOT NULL,
      block_id TEXT,
      operation TEXT NOT NULL,
      payload TEXT NOT NULL,
      priority INTEGER DEFAULT 0,
      created_at INTEGER NOT NULL,
      attempts INTEGER DEFAULT 0,
      last_error TEXT,
      FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE
    )
  ]],
}

--- Index creation statements
M.INDEXES = {
  'CREATE INDEX IF NOT EXISTS idx_pages_title ON pages(title)',
  'CREATE INDEX IF NOT EXISTS idx_pages_frecency ON pages(open_count DESC, last_opened_at DESC)',
  'CREATE INDEX IF NOT EXISTS idx_pages_deleted ON pages(is_deleted)',
  'CREATE INDEX IF NOT EXISTS idx_block_hashes_page_id ON block_hashes(page_id)',
  'CREATE INDEX IF NOT EXISTS idx_sync_queue_priority ON sync_queue(priority DESC, created_at ASC)',
}

--- Table creation order (respects foreign key dependencies)
local TABLE_ORDER = {
  'schema_version',
  'pages',
  'page_content',
  'block_hashes',
  'sync_state',
  'sync_queue',
}

--- Get all schema creation statements in correct order
--- @return string[] statements SQL statements to create schema
function M.get_all_statements()
  local statements = {}

  -- Tables in dependency order
  for _, name in ipairs(TABLE_ORDER) do
    table.insert(statements, M.TABLES[name])
  end

  -- Indexes
  for _, idx in ipairs(M.INDEXES) do
    table.insert(statements, idx)
  end

  return statements
end

--- Migrations table (version -> migration statements)
--- Each migration upgrades from version-1 to version
---@type table<integer, string[]>
local MIGRATIONS = {
  -- Version 1 is initial schema, no migration needed
  -- [2] = {
  --   'ALTER TABLE pages ADD COLUMN new_field TEXT',
  -- },
}

--- Get migration statements for a specific version
--- @param version integer Target version
--- @return string[]? migrations Array of SQL statements, or nil if no migration
function M.get_migration(version)
  return MIGRATIONS[version]
end

return M
