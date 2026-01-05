---@diagnostic disable: undefined-field
-- Integration tests for db.lua with real SQLite
-- These tests require sqlite.lua to be installed

-- Add sqlite.lua to package.path and cpath (plenary.busted runs in separate context)
local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h:h:h')
local sqlite_path = plugin_root .. '/.deps/sqlite.lua'
if vim.fn.isdirectory(sqlite_path) == 1 then
  package.path = sqlite_path .. '/lua/?.lua;' .. sqlite_path .. '/lua/?/init.lua;' .. package.path
end

-- Check sqlite.lua availability first
local sqlite_ok, sqlite_err = pcall(require, 'sqlite.db')
if not sqlite_ok then
  describe('neotion.cache.db integration (SKIPPED - sqlite.lua not available)', function()
    it('requires sqlite.lua to be installed', function()
      pending('Install sqlite.lua to run integration tests: ' .. tostring(sqlite_err))
    end)
  end)
  return
end

-- Reset db module cache to pick up sqlite.db
package.loaded['neotion.cache.db'] = nil
local db_module = require('neotion.cache.db')

describe('neotion.cache.db integration', function()
  local db
  local test_db_path

  before_each(function()
    -- Create a temp database for each test
    test_db_path = vim.fn.tempname() .. '_neotion_test.db'
    db = db_module.new(test_db_path)
    assert.is_not_nil(db, 'Failed to create database')
  end)

  after_each(function()
    -- Clean up
    if db then
      db:close()
    end
    if test_db_path and vim.fn.filereadable(test_db_path) == 1 then
      vim.fn.delete(test_db_path)
    end
  end)

  describe('database creation', function()
    it('should create database file', function()
      assert.are.equal(1, vim.fn.filereadable(test_db_path))
    end)

    it('should be open after creation', function()
      assert.is_true(db:is_open())
    end)
  end)

  describe('schema initialization', function()
    it('should create schema_version table', function()
      local result = db:query('SELECT name FROM sqlite_master WHERE type="table" AND name="schema_version"')
      assert.are.equal(1, #result)
    end)

    it('should create pages table', function()
      local result = db:query('SELECT name FROM sqlite_master WHERE type="table" AND name="pages"')
      assert.are.equal(1, #result)
    end)

    it('should create page_content table', function()
      local result = db:query('SELECT name FROM sqlite_master WHERE type="table" AND name="page_content"')
      assert.are.equal(1, #result)
    end)

    it('should create block_hashes table', function()
      local result = db:query('SELECT name FROM sqlite_master WHERE type="table" AND name="block_hashes"')
      assert.are.equal(1, #result)
    end)

    it('should create sync_state table', function()
      local result = db:query('SELECT name FROM sqlite_master WHERE type="table" AND name="sync_state"')
      assert.are.equal(1, #result)
    end)

    it('should create sync_queue table', function()
      local result = db:query('SELECT name FROM sqlite_master WHERE type="table" AND name="sync_queue"')
      assert.are.equal(1, #result)
    end)

    it('should set schema version', function()
      local result = db:query('SELECT version FROM schema_version ORDER BY version DESC LIMIT 1')
      assert.are.equal(1, #result)
      assert.is_true(result[1].version >= 1)
    end)

    it('should create indexes', function()
      local result = db:query('SELECT name FROM sqlite_master WHERE type="index" AND name LIKE "idx_%"')
      assert.is_true(#result >= 4, 'Should have at least 4 custom indexes')
    end)
  end)

  describe('execute', function()
    it('should insert data', function()
      local now = os.time()
      local success = db:execute(
        'INSERT INTO pages (id, title, last_edited_time, cached_at) VALUES (?, ?, ?, ?)',
        { 'page1', 'Test Page', now, now }
      )
      assert.is_true(success)
    end)

    it('should return false on constraint violation', function()
      local now = os.time()
      db:execute(
        'INSERT INTO pages (id, title, last_edited_time, cached_at) VALUES (?, ?, ?, ?)',
        { 'dup', 'Page', now, now }
      )
      -- Insert duplicate - should fail
      local success = db:execute(
        'INSERT INTO pages (id, title, last_edited_time, cached_at) VALUES (?, ?, ?, ?)',
        { 'dup', 'Page 2', now, now }
      )
      assert.is_false(success)
    end)

    it('should handle UPDATE', function()
      local now = os.time()
      db:execute(
        'INSERT INTO pages (id, title, last_edited_time, cached_at) VALUES (?, ?, ?, ?)',
        { 'upd1', 'Original', now, now }
      )
      local success = db:execute('UPDATE pages SET title = ? WHERE id = ?', { 'Updated', 'upd1' })
      assert.is_true(success)

      local result = db:query('SELECT title FROM pages WHERE id = ?', { 'upd1' })
      assert.are.equal('Updated', result[1].title)
    end)

    it('should handle DELETE', function()
      local now = os.time()
      db:execute(
        'INSERT INTO pages (id, title, last_edited_time, cached_at) VALUES (?, ?, ?, ?)',
        { 'del1', 'ToDelete', now, now }
      )
      local success = db:execute('DELETE FROM pages WHERE id = ?', { 'del1' })
      assert.is_true(success)

      local result = db:query('SELECT * FROM pages WHERE id = ?', { 'del1' })
      assert.are.equal(0, #result)
    end)
  end)

  describe('query', function()
    it('should return empty table for no results', function()
      local result = db:query('SELECT * FROM pages WHERE id = ?', { 'nonexistent' })
      assert.is_table(result)
      assert.are.equal(0, #result)
    end)

    it('should return rows as tables', function()
      local now = os.time()
      db:execute(
        'INSERT INTO pages (id, title, last_edited_time, cached_at) VALUES (?, ?, ?, ?)',
        { 'q1', 'Query Test', now, now }
      )
      local result = db:query('SELECT id, title FROM pages WHERE id = ?', { 'q1' })
      assert.are.equal(1, #result)
      assert.are.equal('q1', result[1].id)
      assert.are.equal('Query Test', result[1].title)
    end)

    it('should return multiple rows', function()
      local now = os.time()
      db:execute(
        'INSERT INTO pages (id, title, last_edited_time, cached_at) VALUES (?, ?, ?, ?)',
        { 'multi1', 'Page 1', now, now }
      )
      db:execute(
        'INSERT INTO pages (id, title, last_edited_time, cached_at) VALUES (?, ?, ?, ?)',
        { 'multi2', 'Page 2', now, now }
      )
      db:execute(
        'INSERT INTO pages (id, title, last_edited_time, cached_at) VALUES (?, ?, ?, ?)',
        { 'multi3', 'Page 3', now, now }
      )

      local result = db:query('SELECT * FROM pages WHERE id LIKE ?', { 'multi%' })
      assert.are.equal(3, #result)
    end)

    it('should handle NULL values', function()
      local now = os.time()
      db:execute(
        'INSERT INTO pages (id, title, last_edited_time, cached_at, icon) VALUES (?, ?, ?, ?, ?)',
        { 'null1', 'Null Test', now, now, nil }
      )
      local result = db:query('SELECT icon FROM pages WHERE id = ?', { 'null1' })
      assert.is_nil(result[1].icon)
    end)
  end)

  describe('query_one', function()
    it('should return single row', function()
      local now = os.time()
      db:execute(
        'INSERT INTO pages (id, title, last_edited_time, cached_at) VALUES (?, ?, ?, ?)',
        { 'one1', 'Single', now, now }
      )
      local result = db:query_one('SELECT * FROM pages WHERE id = ?', { 'one1' })
      assert.is_table(result)
      assert.are.equal('one1', result.id)
    end)

    it('should return nil for no results', function()
      local result = db:query_one('SELECT * FROM pages WHERE id = ?', { 'nonexistent' })
      assert.is_nil(result)
    end)

    it('should return first row when multiple match', function()
      local now = os.time()
      db:execute(
        'INSERT INTO pages (id, title, last_edited_time, cached_at) VALUES (?, ?, ?, ?)',
        { 'first1', 'A', now, now }
      )
      db:execute(
        'INSERT INTO pages (id, title, last_edited_time, cached_at) VALUES (?, ?, ?, ?)',
        { 'first2', 'B', now, now }
      )
      local result = db:query_one('SELECT * FROM pages ORDER BY id LIMIT 1')
      assert.is_table(result)
      assert.are.equal('first1', result.id)
    end)
  end)

  describe('transaction', function()
    it('should commit on success', function()
      local now = os.time()
      local success = db:transaction(function()
        db:execute(
          'INSERT INTO pages (id, title, last_edited_time, cached_at) VALUES (?, ?, ?, ?)',
          { 'tx1', 'TX Test', now, now }
        )
        return true
      end)
      assert.is_true(success)

      local result = db:query('SELECT * FROM pages WHERE id = ?', { 'tx1' })
      assert.are.equal(1, #result)
    end)

    it('should rollback on failure', function()
      local now = os.time()
      local success = db:transaction(function()
        db:execute(
          'INSERT INTO pages (id, title, last_edited_time, cached_at) VALUES (?, ?, ?, ?)',
          { 'tx_fail', 'TX Fail', now, now }
        )
        return false -- Signal failure
      end)
      assert.is_false(success)

      local result = db:query('SELECT * FROM pages WHERE id = ?', { 'tx_fail' })
      assert.are.equal(0, #result)
    end)

    it('should rollback on error', function()
      local now = os.time()
      local success, err = db:transaction(function()
        db:execute(
          'INSERT INTO pages (id, title, last_edited_time, cached_at) VALUES (?, ?, ?, ?)',
          { 'tx_err', 'TX Error', now, now }
        )
        error('Simulated error')
      end)
      assert.is_false(success)
      assert.matches('Simulated error', err)

      local result = db:query('SELECT * FROM pages WHERE id = ?', { 'tx_err' })
      assert.are.equal(0, #result)
    end)
  end)

  describe('close', function()
    it('should close the database', function()
      db:close()
      assert.is_false(db:is_open())
    end)

    it('should be safe to call multiple times', function()
      db:close()
      db:close()
      assert.is_false(db:is_open())
    end)
  end)

  describe('foreign key cascade', function()
    it('should delete page_content when page is deleted', function()
      local now = os.time()
      db:execute(
        'INSERT INTO pages (id, title, last_edited_time, cached_at) VALUES (?, ?, ?, ?)',
        { 'fk1', 'FK Test', now, now }
      )
      db:execute(
        'INSERT INTO page_content (page_id, blocks_json, content_hash, block_count, fetched_at) VALUES (?, ?, ?, ?, ?)',
        { 'fk1', '[]', 'abc', 0, now }
      )

      -- Verify content exists
      local content = db:query('SELECT * FROM page_content WHERE page_id = ?', { 'fk1' })
      assert.are.equal(1, #content)

      -- Delete page
      db:execute('DELETE FROM pages WHERE id = ?', { 'fk1' })

      -- Content should be cascade deleted
      content = db:query('SELECT * FROM page_content WHERE page_id = ?', { 'fk1' })
      assert.are.equal(0, #content)
    end)

    it('should delete block_hashes when page is deleted', function()
      local now = os.time()
      db:execute(
        'INSERT INTO pages (id, title, last_edited_time, cached_at) VALUES (?, ?, ?, ?)',
        { 'fk2', 'FK Test 2', now, now }
      )
      db:execute(
        'INSERT INTO block_hashes (block_id, page_id, content_hash, block_type) VALUES (?, ?, ?, ?)',
        { 'block1', 'fk2', 'hash1', 'paragraph' }
      )

      -- Delete page
      db:execute('DELETE FROM pages WHERE id = ?', { 'fk2' })

      -- Block hashes should be cascade deleted
      local hashes = db:query('SELECT * FROM block_hashes WHERE page_id = ?', { 'fk2' })
      assert.are.equal(0, #hashes)
    end)
  end)

  describe('get_schema_version', function()
    it('should return current schema version', function()
      local version = db:get_schema_version()
      assert.is_number(version)
      assert.is_true(version >= 1)
    end)
  end)

  describe('vacuum', function()
    it('should run VACUUM without error', function()
      local success = db:vacuum()
      assert.is_true(success)
    end)
  end)

  describe('stats', function()
    it('should return database statistics', function()
      local now = os.time()
      db:execute(
        'INSERT INTO pages (id, title, last_edited_time, cached_at) VALUES (?, ?, ?, ?)',
        { 'stat1', 'Stats Test', now, now }
      )

      local stats = db:stats()
      assert.is_table(stats)
      assert.is_number(stats.page_count)
      assert.is_true(stats.page_count >= 1)
      assert.is_number(stats.size_bytes)
    end)
  end)
end)
