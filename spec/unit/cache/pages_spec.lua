---@diagnostic disable: undefined-field
local pages = require('neotion.cache.pages')

describe('neotion.cache.pages', function()
  describe('without cache initialized', function()
    before_each(function()
      -- Ensure cache is not initialized
      local cache = require('neotion.cache')
      cache.close()
      cache._reset()
    end)

    it('save_page should return false', function()
      local result = pages.save_page('abc123', { properties = { title = { title = {} } } })
      assert.is_false(result)
    end)

    it('save_content should return false', function()
      local result = pages.save_content('abc123', {})
      assert.is_false(result)
    end)

    it('get_page should return nil', function()
      local result = pages.get_page('abc123')
      assert.is_nil(result)
    end)

    it('get_content should return nil', function()
      local result = pages.get_content('abc123')
      assert.is_nil(result)
    end)

    it('has_page should return false', function()
      local result = pages.has_page('abc123')
      assert.is_false(result)
    end)

    it('has_content should return false', function()
      local result = pages.has_content('abc123')
      assert.is_false(result)
    end)

    it('get_recent should return empty table', function()
      local result = pages.get_recent()
      assert.are.same({}, result)
    end)

    it('search should return empty table', function()
      local result = pages.search('test')
      assert.are.same({}, result)
    end)
  end)
end)
