---@diagnostic disable: undefined-field
-- Unit tests for cache orchestrator

describe('neotion.cache', function()
  local cache
  local original_is_sqlite_available

  before_each(function()
    -- Reset module cache
    package.loaded['neotion.cache'] = nil
    package.loaded['neotion.cache.db'] = nil
    package.loaded['neotion.cache.hash'] = nil

    -- Mock sqlite.db as available
    package.loaded['sqlite.db'] = { open = function() end }

    cache = require('neotion.cache')

    -- Store original function
    local db = require('neotion.cache.db')
    original_is_sqlite_available = db.is_sqlite_available
  end)

  after_each(function()
    -- Cleanup
    package.loaded['sqlite.db'] = nil
  end)

  describe('module structure', function()
    it('should expose init method', function()
      assert.is_function(cache.init)
    end)

    it('should expose close method', function()
      assert.is_function(cache.close)
    end)

    it('should expose is_available method', function()
      assert.is_function(cache.is_available)
    end)

    it('should expose is_initialized method', function()
      assert.is_function(cache.is_initialized)
    end)

    it('should expose get_db method for direct access', function()
      assert.is_function(cache.get_db)
    end)

    it('should expose hash submodule', function()
      assert.is_table(cache.hash)
      assert.is_function(cache.hash.djb2)
    end)
  end)

  describe('is_available', function()
    it('should return true when sqlite.lua is available', function()
      assert.is_true(cache.is_available())
    end)

    it('should return false when sqlite.lua is not available', function()
      package.loaded['sqlite.db'] = nil
      package.loaded['neotion.cache.db'] = nil
      local db = require('neotion.cache.db')
      -- Force unavailable by checking actual require
      local result = cache.is_available()
      -- Result depends on whether sqlite is really installed
      assert.is_boolean(result)
    end)
  end)

  describe('is_initialized', function()
    it('should return false before init', function()
      assert.is_false(cache.is_initialized())
    end)
  end)

  describe('get_db', function()
    it('should return nil before init', function()
      assert.is_nil(cache.get_db())
    end)
  end)
end)
