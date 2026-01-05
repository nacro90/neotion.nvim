---@diagnostic disable: undefined-field
-- Integration tests for cache orchestrator with real SQLite

-- Add sqlite.lua to package.path (plenary.busted runs in separate context)
local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h:h:h')
local sqlite_path = plugin_root .. '/.deps/sqlite.lua'
if vim.fn.isdirectory(sqlite_path) == 1 then
  package.path = sqlite_path .. '/lua/?.lua;' .. sqlite_path .. '/lua/?/init.lua;' .. package.path
end

-- Check sqlite.lua availability first
local sqlite_ok, sqlite_err = pcall(require, 'sqlite.db')
if not sqlite_ok then
  describe('neotion.cache integration (SKIPPED - sqlite.lua not available)', function()
    it('requires sqlite.lua to be installed', function()
      pending('Install sqlite.lua to run integration tests: ' .. tostring(sqlite_err))
    end)
  end)
  return
end

-- Reset cache module to pick up sqlite.db
package.loaded['neotion.cache'] = nil
package.loaded['neotion.cache.db'] = nil
local cache = require('neotion.cache')

describe('neotion.cache integration', function()
  local test_db_path

  before_each(function()
    -- Create a temp database for each test
    test_db_path = vim.fn.tempname() .. '_neotion_cache_test.db'

    -- Reset cache state
    cache.close()
    cache._reset()
  end)

  after_each(function()
    -- Clean up
    cache.close()
    cache._reset()
    if test_db_path and vim.fn.filereadable(test_db_path) == 1 then
      vim.fn.delete(test_db_path)
    end
  end)

  describe('is_available', function()
    it('should return true when sqlite.lua is installed', function()
      assert.is_true(cache.is_available())
    end)
  end)

  describe('init', function()
    it('should initialize cache with custom path', function()
      local success = cache.init(test_db_path)
      assert.is_true(success)
      assert.is_true(cache.is_initialized())
    end)

    it('should create database file', function()
      cache.init(test_db_path)
      assert.are.equal(1, vim.fn.filereadable(test_db_path))
    end)

    it('should return true when already initialized', function()
      cache.init(test_db_path)
      local success = cache.init(test_db_path)
      assert.is_true(success)
    end)
  end)

  describe('get_db', function()
    it('should return database instance after init', function()
      cache.init(test_db_path)
      local db = cache.get_db()
      assert.is_not_nil(db)
      assert.is_true(db:is_open())
    end)

    it('should return nil before init', function()
      assert.is_nil(cache.get_db())
    end)
  end)

  describe('close', function()
    it('should close the cache', function()
      cache.init(test_db_path)
      cache.close()
      assert.is_false(cache.is_initialized())
    end)

    it('should be safe to call multiple times', function()
      cache.init(test_db_path)
      cache.close()
      cache.close()
      assert.is_false(cache.is_initialized())
    end)
  end)

  describe('stats', function()
    it('should return stats when initialized', function()
      cache.init(test_db_path)
      local stats = cache.stats()
      assert.is_table(stats)
      assert.is_true(stats.initialized)
      assert.is_number(stats.page_count)
      assert.is_number(stats.size_bytes)
    end)

    it('should return empty stats when not initialized', function()
      local stats = cache.stats()
      assert.is_table(stats)
      assert.is_false(stats.initialized)
      assert.are.equal(0, stats.page_count)
    end)
  end)

  describe('vacuum', function()
    it('should run vacuum when initialized', function()
      cache.init(test_db_path)
      local success = cache.vacuum()
      assert.is_true(success)
    end)

    it('should return false when not initialized', function()
      local success = cache.vacuum()
      assert.is_false(success)
    end)
  end)

  describe('hash submodule', function()
    it('should be accessible via cache.hash', function()
      assert.is_function(cache.hash.djb2)
    end)

    it('should compute hashes correctly', function()
      local hash = cache.hash.djb2('test')
      assert.is_string(hash)
      assert.are.equal(8, #hash)
    end)
  end)
end)
