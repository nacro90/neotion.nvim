describe('neotion.model.icon_resolver', function()
  local icon_resolver
  local mock_cache
  local mock_pages_api

  before_each(function()
    -- Clear module cache
    package.loaded['neotion.model.icon_resolver'] = nil
    package.loaded['neotion.cache.pages'] = nil
    package.loaded['neotion.api.pages'] = nil

    -- Create mock cache
    mock_cache = {
      pages = {},
      get_page = function(page_id)
        return mock_cache.pages[page_id]
      end,
      save_page = function(page_id, page)
        mock_cache.pages[page_id] = {
          id = page_id,
          icon = page.icon and page.icon.emoji,
        }
        return true
      end,
    }

    -- Create mock API
    mock_pages_api = {
      pending_callbacks = {},
      get = function(page_id, callback)
        mock_pages_api.pending_callbacks[page_id] = callback
      end,
      get_icon = function(page)
        if page and page.icon and page.icon.type == 'emoji' then
          return page.icon.emoji
        end
        return nil
      end,
    }

    -- Inject mocks
    package.loaded['neotion.cache.pages'] = mock_cache
    package.loaded['neotion.api.pages'] = mock_pages_api

    icon_resolver = require('neotion.model.icon_resolver')
    icon_resolver.clear_cache()
  end)

  describe('resolve', function()
    it('should return cached icon from persistent cache', function()
      mock_cache.pages['page123'] = { id = 'page123', icon = '🚀' }

      local result = nil
      local sync_result = icon_resolver.resolve('page123', function(icon)
        result = icon
      end)

      -- Should return sync
      assert.are.equal('🚀', sync_result)

      -- Callback should also be called (async via vim.schedule)
      vim.wait(100, function()
        return result ~= nil
      end)
      assert.are.equal('🚀', result)
    end)

    it('should fetch from API when not in cache', function()
      local result = nil
      local sync_result = icon_resolver.resolve('page456', function(icon)
        result = icon
      end)

      -- Should return nil (async fetch started)
      assert.is_nil(sync_result)

      -- Simulate API response
      mock_pages_api.pending_callbacks['page456']({
        page = {
          id = 'page456',
          icon = { type = 'emoji', emoji = '📝' },
        },
      })

      assert.are.equal('📝', result)
    end)

    it('should cache resolved icon in memory', function()
      -- First resolve - triggers API call
      icon_resolver.resolve('page789', function() end)

      -- Simulate API response
      mock_pages_api.pending_callbacks['page789']({
        page = {
          id = 'page789',
          icon = { type = 'emoji', emoji = '🎯' },
        },
      })

      -- Second resolve - should use in-memory cache
      local sync_result = icon_resolver.resolve('page789', function() end)
      assert.are.equal('🎯', sync_result)
    end)

    it('should handle API error gracefully', function()
      local result = 'not_called'
      icon_resolver.resolve('bad_page', function(icon)
        result = icon
      end)

      -- Simulate API error
      mock_pages_api.pending_callbacks['bad_page']({
        error = 'Not found',
      })

      assert.is_nil(result)
    end)

    it('should not duplicate pending requests', function()
      local call_count = 0
      local original_get = mock_pages_api.get
      mock_pages_api.get = function(page_id, callback)
        call_count = call_count + 1
        original_get(page_id, callback)
      end

      -- Multiple resolves for same page
      icon_resolver.resolve('dup_page', function() end)
      icon_resolver.resolve('dup_page', function() end)
      icon_resolver.resolve('dup_page', function() end)

      -- Should only call API once
      assert.are.equal(1, call_count)
    end)

    it('should call all queued callbacks when fetch completes', function()
      local callback_results = {}

      -- Queue multiple callbacks for same page
      icon_resolver.resolve('multi_cb', function(icon)
        table.insert(callback_results, { cb = 1, icon = icon })
      end)
      icon_resolver.resolve('multi_cb', function(icon)
        table.insert(callback_results, { cb = 2, icon = icon })
      end)
      icon_resolver.resolve('multi_cb', function(icon)
        table.insert(callback_results, { cb = 3, icon = icon })
      end)

      -- Simulate API response
      mock_pages_api.pending_callbacks['multi_cb']({
        page = {
          id = 'multi_cb',
          icon = { type = 'emoji', emoji = '🎯' },
        },
      })

      -- All callbacks should have been called with the icon
      assert.are.equal(3, #callback_results)
      assert.are.equal('🎯', callback_results[1].icon)
      assert.are.equal('🎯', callback_results[2].icon)
      assert.are.equal('🎯', callback_results[3].icon)
    end)
  end)

  describe('get_cached', function()
    it('should return nil when not cached', function()
      local result = icon_resolver.get_cached('unknown_page')
      assert.is_nil(result)
    end)

    it('should return icon from in-memory cache', function()
      -- Populate via resolve
      mock_cache.pages['cached_page'] = { id = 'cached_page', icon = '🔥' }
      icon_resolver.resolve('cached_page', function() end)

      local result = icon_resolver.get_cached('cached_page')
      assert.are.equal('🔥', result)
    end)

    it('should return icon from persistent cache', function()
      mock_cache.pages['persistent_page'] = { id = 'persistent_page', icon = '💡' }

      local result = icon_resolver.get_cached('persistent_page')
      assert.are.equal('💡', result)
    end)
  end)

  describe('is_pending', function()
    it('should return false when no fetch pending', function()
      assert.is_false(icon_resolver.is_pending('some_page'))
    end)

    it('should return true when fetch is pending', function()
      icon_resolver.resolve('pending_page', function() end)
      assert.is_true(icon_resolver.is_pending('pending_page'))
    end)

    it('should return false after fetch completes', function()
      icon_resolver.resolve('complete_page', function() end)

      -- Complete the fetch
      mock_pages_api.pending_callbacks['complete_page']({
        page = { id = 'complete_page', icon = { type = 'emoji', emoji = '✅' } },
      })

      assert.is_false(icon_resolver.is_pending('complete_page'))
    end)
  end)

  describe('clear_cache', function()
    it('should clear in-memory cache', function()
      mock_cache.pages['clear_test'] = { id = 'clear_test', icon = '🧹' }
      icon_resolver.resolve('clear_test', function() end)

      -- Verify cached
      assert.are.equal('🧹', icon_resolver.get_cached('clear_test'))

      -- Clear
      icon_resolver.clear_cache()

      -- In-memory cleared, but persistent still there
      local result = icon_resolver.get_cached('clear_test')
      assert.are.equal('🧹', result) -- Still gets from persistent
    end)
  end)
end)
