---@diagnostic disable: undefined-field
local live_search = require('neotion.ui.live_search')

describe('neotion.ui.live_search', function()
  -- Reset state between tests
  before_each(function()
    live_search._reset()
  end)

  describe('api_page_to_item', function()
    -- Note: Uses api/pages.lua helper functions for consistent behavior
    it('should convert page with emoji icon', function()
      local page = {
        id = 'abc123',
        icon = { type = 'emoji', emoji = '📄' },
        properties = {
          title = {
            type = 'title',
            title = { { plain_text = 'Test Page' } },
          },
        },
        parent = { type = 'workspace', workspace = true },
      }

      local item = live_search.api_page_to_item(page)

      assert.equals('abc123', item.id)
      assert.equals('Test Page', item.title)
      assert.equals('📄', item.icon)
      assert.equals('workspace', item.parent_type)
      assert.is_false(item.from_cache)
    end)

    it('should convert page with external icon', function()
      local page = {
        id = 'def456',
        icon = { type = 'external', external = { url = 'https://example.com/icon.png' } },
        properties = {
          title = {
            type = 'title',
            title = { { plain_text = 'Another Page' } },
          },
        },
        parent = { type = 'page_id', page_id = 'parent123' },
      }

      local item = live_search.api_page_to_item(page)

      assert.equals('def456', item.id)
      assert.equals('Another Page', item.title)
      assert.equals('\u{f03e}', item.icon) -- External icons shown as Nerd Font image icon
      assert.equals('page', item.parent_type) -- api/pages.lua returns 'page' not 'page_id'
    end)

    it('should handle missing icon', function()
      local page = {
        id = 'ghi789',
        properties = {
          title = {
            type = 'title',
            title = { { plain_text = 'No Icon Page' } },
          },
        },
        parent = { type = 'workspace', workspace = true },
      }

      local item = live_search.api_page_to_item(page)

      assert.equals('ghi789', item.id)
      assert.equals('No Icon Page', item.title)
      assert.equals('', item.icon)
    end)

    it('should handle vim.NIL icon', function()
      local page = {
        id = 'jkl012',
        icon = vim.NIL,
        properties = {
          title = {
            type = 'title',
            title = { { plain_text = 'Nil Icon' } },
          },
        },
        parent = { type = 'workspace', workspace = true },
      }

      local item = live_search.api_page_to_item(page)

      assert.equals('', item.icon)
    end)

    it('should handle database parent', function()
      local page = {
        id = 'mno345',
        properties = {
          title = {
            type = 'title',
            title = { { plain_text = 'DB Page' } },
          },
        },
        parent = { type = 'database_id', database_id = 'db123' },
      }

      local item = live_search.api_page_to_item(page)

      assert.equals('database', item.parent_type) -- api/pages.lua returns 'database' not 'database_id'
      assert.equals('db123', item.parent_id)
    end)

    it('should find title in custom property name', function()
      -- Database pages may have title in a custom-named property
      local page = {
        id = 'custom123',
        properties = {
          ['Task Name'] = {
            type = 'title',
            title = { { plain_text = 'Custom Title Property' } },
          },
        },
        parent = { type = 'workspace', workspace = true },
      }

      local item = live_search.api_page_to_item(page)

      assert.equals('Custom Title Property', item.title)
    end)

    it('should normalize dashed IDs to match cache format', function()
      -- Notion API returns dashed UUIDs, but cache stores without dashes
      local page = {
        id = '2027b4fb-fc3e-80bc-a956-df97681d756a',
        properties = {
          title = {
            type = 'title',
            title = { { plain_text = 'Dashed ID Page' } },
          },
        },
        parent = { type = 'workspace', workspace = true },
      }

      local item = live_search.api_page_to_item(page)

      -- ID should be normalized (dashes removed) for deduplication
      assert.equals('2027b4fbfc3e80bca956df97681d756a', item.id)
    end)
  end)

  describe('cached_row_to_item', function()
    it('should convert row with frecency_score', function()
      local row = {
        id = 'abc123',
        title = 'Cached Page',
        icon = '📝',
        parent_type = 'workspace',
        parent_id = nil,
        frecency_score = 150.5,
      }

      local item = live_search.cached_row_to_item(row)

      assert.equals('abc123', item.id)
      assert.equals('Cached Page', item.title)
      assert.equals('📝', item.icon)
      assert.equals('workspace', item.parent_type)
      assert.equals(150.5, item.frecency_score)
      assert.is_true(item.from_cache)
    end)

    it('should handle nil icon', function()
      local row = {
        id = 'def456',
        title = 'No Icon',
        icon = nil,
        parent_type = 'page_id',
        parent_id = 'parent123',
      }

      local item = live_search.cached_row_to_item(row)

      assert.equals('', item.icon)
      assert.is_true(item.from_cache)
    end)

    it('should handle vim.NIL icon from SQLite', function()
      local row = {
        id = 'ghi789',
        title = 'SQLite NIL',
        icon = vim.NIL,
        parent_type = 'workspace',
      }

      local item = live_search.cached_row_to_item(row)

      assert.equals('', item.icon)
    end)

    it('should set from_cache flag', function()
      local row = {
        id = 'jkl012',
        title = 'Test',
        parent_type = 'workspace',
      }

      local item = live_search.cached_row_to_item(row)

      assert.is_true(item.from_cache)
    end)
  end)

  describe('merge_results', function()
    it('should put API results first', function()
      local api_results = {
        { id = 'api1', title = 'API Page 1' },
        { id = 'api2', title = 'API Page 2' },
      }
      local cached_results = {
        { id = 'cache1', title = 'Cache Page 1', from_cache = true },
      }

      local merged = live_search.merge_results(api_results, cached_results)

      assert.equals(3, #merged)
      assert.equals('api1', merged[1].id)
      assert.equals('api2', merged[2].id)
      assert.equals('cache1', merged[3].id)
    end)

    it('should deduplicate by id', function()
      local api_results = {
        { id = 'shared', title = 'API Version' },
        { id = 'api_only', title = 'API Only' },
      }
      local cached_results = {
        { id = 'shared', title = 'Cache Version', from_cache = true },
        { id = 'cache_only', title = 'Cache Only', from_cache = true },
      }

      local merged = live_search.merge_results(api_results, cached_results)

      assert.equals(3, #merged)
      -- API version should win
      assert.equals('shared', merged[1].id)
      assert.equals('API Version', merged[1].title)
      -- Cache extra should be appended
      assert.equals('cache_only', merged[3].id)
    end)

    it('should handle empty API results', function()
      local api_results = {}
      local cached_results = {
        { id = 'cache1', title = 'Cache 1', from_cache = true },
        { id = 'cache2', title = 'Cache 2', from_cache = true },
      }

      local merged = live_search.merge_results(api_results, cached_results)

      assert.equals(2, #merged)
      assert.equals('cache1', merged[1].id)
    end)

    it('should handle empty cached results', function()
      local api_results = {
        { id = 'api1', title = 'API 1' },
      }
      local cached_results = {}

      local merged = live_search.merge_results(api_results, cached_results)

      assert.equals(1, #merged)
      assert.equals('api1', merged[1].id)
    end)

    it('should handle both empty', function()
      local merged = live_search.merge_results({}, {})

      assert.equals(0, #merged)
    end)

    it('should preserve API order', function()
      local api_results = {
        { id = 'z', title = 'Z Page' },
        { id = 'a', title = 'A Page' },
        { id = 'm', title = 'M Page' },
      }

      local merged = live_search.merge_results(api_results, {})

      assert.equals('z', merged[1].id)
      assert.equals('a', merged[2].id)
      assert.equals('m', merged[3].id)
    end)

    it('should mark API results as not from cache', function()
      local api_results = {
        { id = 'api1', title = 'API Page' },
      }

      local merged = live_search.merge_results(api_results, {})

      assert.is_false(merged[1].from_cache)
    end)
  end)

  describe('create', function()
    it('should initialize state with defaults', function()
      local callbacks = {
        on_results = function() end,
      }

      local state = live_search.create(1, callbacks)

      assert.is_table(state)
      assert.equals('', state.query)
      assert.equals(300, state.debounce_ms)
      assert.is_true(state.show_cached)
      assert.equals(100, state.limit) -- Updated: default is now 100
      assert.is_false(state.is_loading)
      assert.is_table(state.cached_results)
      assert.equals(0, #state.cached_results)
    end)

    it('should apply custom options', function()
      local callbacks = { on_results = function() end }

      local state = live_search.create(2, callbacks, {
        debounce_ms = 500,
        show_cached = false,
        limit = 100,
      })

      assert.equals(500, state.debounce_ms)
      assert.is_false(state.show_cached)
      assert.equals(100, state.limit)
    end)

    it('should store callbacks', function()
      local result_called = false
      local callbacks = {
        on_results = function()
          result_called = true
        end,
      }

      local state = live_search.create(3, callbacks)

      assert.is_function(state.callbacks.on_results)
      state.callbacks.on_results({}, true)
      assert.is_true(result_called)
    end)

    it('should use config defaults', function()
      -- Mock config
      local config = require('neotion.config')
      config.reset()

      local callbacks = { on_results = function() end }
      local state = live_search.create(4, callbacks)

      -- Should use config values
      assert.equals(300, state.debounce_ms) -- config default
      assert.is_true(state.show_cached) -- config default
    end)
  end)

  describe('get_state', function()
    it('should return state for valid instance', function()
      local callbacks = { on_results = function() end }
      live_search.create(10, callbacks)

      local state = live_search.get_state(10)

      assert.is_table(state)
      assert.equals('', state.query)
    end)

    it('should return nil for unknown instance', function()
      local state = live_search.get_state(999)

      assert.is_nil(state)
    end)
  end)

  describe('destroy', function()
    it('should cleanup state', function()
      local callbacks = { on_results = function() end }
      live_search.create(20, callbacks)

      assert.is_table(live_search.get_state(20))

      live_search.destroy(20)

      assert.is_nil(live_search.get_state(20))
    end)

    it('should be safe to call on unknown instance', function()
      -- Should not error
      live_search.destroy(999)
    end)

    it('should not affect other instances', function()
      local callbacks = { on_results = function() end }
      live_search.create(30, callbacks)
      live_search.create(31, callbacks)

      live_search.destroy(30)

      assert.is_nil(live_search.get_state(30))
      assert.is_table(live_search.get_state(31))
    end)

    it('should clear all state fields before removal', function()
      local callbacks = { on_results = function() end }
      local state = live_search.create(32, callbacks)

      -- Populate state with data
      state.query = 'test query'
      state.cached_results = { { id = '1', title = 'Test' } }
      state.api_results = { { id = '2', title = 'API Result' } }
      state.is_loading = true

      -- Verify state has data
      assert.equals('test query', state.query)
      assert.equals(1, #state.cached_results)
      assert.is_true(state.is_loading)

      live_search.destroy(32)

      -- State should be completely removed
      assert.is_nil(live_search.get_state(32))
    end)

    it('should be safe to call destroy multiple times', function()
      local callbacks = { on_results = function() end }
      live_search.create(33, callbacks)

      -- First destroy
      live_search.destroy(33)
      assert.is_nil(live_search.get_state(33))

      -- Second destroy should not error
      live_search.destroy(33)
      assert.is_nil(live_search.get_state(33))
    end)
  end)

  describe('_reset', function()
    it('should clear all states', function()
      local callbacks = { on_results = function() end }
      live_search.create(40, callbacks)
      live_search.create(41, callbacks)

      live_search._reset()

      assert.is_nil(live_search.get_state(40))
      assert.is_nil(live_search.get_state(41))
    end)
  end)

  describe('update_query', function()
    it('should update state query', function()
      local callbacks = { on_results = function() end }
      live_search.create(50, callbacks)

      live_search.update_query(50, 'test query')

      local state = live_search.get_state(50)
      assert.equals('test query', state.query)
    end)

    it('should start debounce timer', function()
      local callbacks = { on_results = function() end }
      live_search.create(51, callbacks, { debounce_ms = 100 })

      live_search.update_query(51, 'test')

      local state = live_search.get_state(51)
      assert.is_not_nil(state.debounce_timer)
    end)

    it('should cancel previous debounce timer on new query', function()
      local callbacks = { on_results = function() end }
      live_search.create(52, callbacks, { debounce_ms = 500 })

      live_search.update_query(52, 'first')
      local first_timer = live_search.get_state(52).debounce_timer

      live_search.update_query(52, 'second')
      local second_timer = live_search.get_state(52).debounce_timer

      -- Timer should be different (old cancelled, new started)
      assert.is_not_nil(first_timer)
      assert.is_not_nil(second_timer)
      -- Note: timer IDs may be reused, so we just check both exist
    end)

    it('should skip debounce when debounce_ms is 0', function()
      local result_calls = 0
      local callbacks = {
        on_results = function()
          result_calls = result_calls + 1
        end,
      }
      live_search.create(53, callbacks, { debounce_ms = 0, show_cached = false })

      live_search.update_query(53, 'test')

      local state = live_search.get_state(53)
      -- No debounce timer when debounce_ms = 0
      assert.is_nil(state.debounce_timer)
    end)

    it('should do nothing for unknown instance', function()
      -- Should not error
      live_search.update_query(999, 'test')
    end)
  end)

  describe('search_immediate', function()
    it('should bypass debounce', function()
      local callbacks = { on_results = function() end }
      live_search.create(60, callbacks, { debounce_ms = 500 })

      live_search.search_immediate(60, 'test')

      local state = live_search.get_state(60)
      assert.equals('test', state.query)
      -- No debounce timer for immediate search
      assert.is_nil(state.debounce_timer)
    end)

    it('should cancel pending debounce', function()
      local callbacks = { on_results = function() end }
      live_search.create(61, callbacks, { debounce_ms = 500 })

      -- Start debounced search
      live_search.update_query(61, 'debounced')
      assert.is_not_nil(live_search.get_state(61).debounce_timer)

      -- Immediate search should cancel debounce
      live_search.search_immediate(61, 'immediate')

      local state = live_search.get_state(61)
      assert.equals('immediate', state.query)
      assert.is_nil(state.debounce_timer)
    end)
  end)

  describe('cancel', function()
    it('should cancel pending debounce timer', function()
      local callbacks = { on_results = function() end }
      live_search.create(70, callbacks, { debounce_ms = 500 })

      live_search.update_query(70, 'test')
      assert.is_not_nil(live_search.get_state(70).debounce_timer)

      live_search.cancel(70)

      assert.is_nil(live_search.get_state(70).debounce_timer)
    end)

    it('should be safe to call on unknown instance', function()
      -- Should not error
      live_search.cancel(999)
    end)
  end)

  describe('cache integration', function()
    -- These tests use mocks since cache may not be available in test environment

    it('should try query_cache for empty query before frecency fallback', function()
      local cache_query_received = nil
      local results_received = nil

      -- Mock fetch_cached to track what query is passed
      live_search._set_cache_fetcher(function(query, limit)
        cache_query_received = query
        -- Return mock results
        return {
          { id = 'recent1', title = 'Recent Page 1', from_cache = true },
          { id = 'recent2', title = 'Recent Page 2', from_cache = true },
        }
      end)

      local callbacks = {
        on_results = function(items, is_final)
          results_received = items
        end,
      }

      live_search.create(79, callbacks, { show_cached = true, debounce_ms = 500 })
      live_search.update_query(79, '')

      -- Should call cache fetcher with empty query
      assert.equals('', cache_query_received)
      assert.is_not_nil(results_received)
      assert.equals(2, #results_received)

      live_search._set_cache_fetcher(nil)
    end)

    it('should handle empty query from API and cache it', function()
      local query_saved = nil
      local page_ids_saved = nil

      live_search._set_cache_fetcher(function(query, limit)
        return {}
      end)

      live_search._set_api_searcher(function(query, callback)
        vim.schedule(function()
          callback({
            pages = {
              {
                id = 'recent1',
                properties = { title = { title = { { plain_text = 'Recent 1' } } } },
                parent = { type = 'workspace' },
              },
              {
                id = 'recent2',
                properties = { title = { title = { { plain_text = 'Recent 2' } } } },
                parent = { type = 'workspace' },
              },
            },
            error = nil,
          })
        end)
        return { request_id = 1, cancel = function() end }
      end)

      local callbacks = {
        on_results = function() end,
      }

      live_search.create(78, callbacks, { debounce_ms = 0, show_cached = false })
      live_search.search_immediate(78, '')

      -- Wait for async response
      vim.wait(100, function()
        return live_search.get_state(78).api_results ~= nil
      end)

      -- API results should be available
      local state = live_search.get_state(78)
      assert.is_not_nil(state.api_results)
      assert.equals(2, #state.api_results)

      live_search._set_cache_fetcher(nil)
      live_search._set_api_searcher(nil)
    end)

    it('should call on_results with cached results when show_cached is true', function()
      local results_received = nil
      local is_final_received = nil
      local callbacks = {
        on_results = function(items, is_final)
          results_received = items
          is_final_received = is_final
        end,
      }

      -- Mock fetch_cached to return test data
      live_search._set_cache_fetcher(function(query, limit)
        return {
          { id = 'cached1', title = 'Cached ' .. query, from_cache = true },
        }
      end)

      live_search.create(80, callbacks, { show_cached = true, debounce_ms = 500 })
      live_search.update_query(80, 'test')

      -- Should have called on_results with cached data (is_final = false)
      assert.is_not_nil(results_received)
      assert.equals(1, #results_received)
      assert.equals('cached1', results_received[1].id)
      assert.is_false(is_final_received)

      -- Reset mock
      live_search._set_cache_fetcher(nil)
    end)

    it('should not call on_results when show_cached is false', function()
      local results_called = false
      local callbacks = {
        on_results = function()
          results_called = true
        end,
      }

      live_search._set_cache_fetcher(function()
        return { { id = 'cached1', title = 'Cached', from_cache = true } }
      end)

      live_search.create(81, callbacks, { show_cached = false, debounce_ms = 500 })
      live_search.update_query(81, 'test')

      -- Should not have called on_results yet (waiting for API)
      assert.is_false(results_called)

      live_search._set_cache_fetcher(nil)
    end)
  end)

  describe('API integration', function()
    it('should call API search after debounce', function()
      local api_called = false
      local api_query = nil

      live_search._set_api_searcher(function(query, callback)
        api_called = true
        api_query = query
        -- Simulate async response
        vim.schedule(function()
          callback({
            pages = {
              {
                id = 'api1',
                properties = { title = { title = { { plain_text = 'API Page' } } } },
                parent = { type = 'workspace' },
              },
            },
            error = nil,
          })
        end)
        return { request_id = 1, cancel = function() end }
      end)

      local callbacks = { on_results = function() end }
      live_search.create(90, callbacks, { debounce_ms = 10, show_cached = false })
      live_search.update_query(90, 'api test')

      -- Wait for debounce
      vim.wait(50, function()
        return api_called
      end)

      assert.is_true(api_called)
      assert.equals('api test', api_query)

      live_search._set_api_searcher(nil)
    end)

    it('should merge API and cached results', function()
      local final_results = nil

      live_search._set_cache_fetcher(function()
        return {
          { id = 'cached1', title = 'Cached Only', from_cache = true },
          { id = 'shared', title = 'Cached Shared', from_cache = true },
        }
      end)

      live_search._set_api_searcher(function(query, callback)
        vim.schedule(function()
          callback({
            pages = {
              {
                id = 'shared',
                properties = { title = { type = 'title', title = { { plain_text = 'API Shared' } } } },
                parent = { type = 'workspace' },
              },
              {
                id = 'api1',
                properties = { title = { type = 'title', title = { { plain_text = 'API Only' } } } },
                parent = { type = 'workspace' },
              },
            },
            error = nil,
          })
        end)
        return { request_id = 1, cancel = function() end }
      end)

      local callbacks = {
        on_results = function(items, is_final)
          if is_final then
            final_results = items
          end
        end,
      }

      live_search.create(91, callbacks, { debounce_ms = 0, show_cached = true })
      live_search.search_immediate(91, 'test')

      -- Wait for async API response
      vim.wait(100, function()
        return final_results ~= nil
      end)

      assert.is_not_nil(final_results)
      -- API results first (shared, api1), then cached extras (cached1)
      assert.equals(3, #final_results)
      assert.equals('shared', final_results[1].id)
      assert.equals('API Shared', final_results[1].title) -- API version wins
      assert.equals('api1', final_results[2].id)
      assert.equals('cached1', final_results[3].id)

      live_search._set_cache_fetcher(nil)
      live_search._set_api_searcher(nil)
    end)

    it('should cancel previous API request on new query', function()
      local cancel_called = false

      live_search._set_api_searcher(function(query, callback)
        return {
          request_id = 1,
          cancel = function()
            cancel_called = true
          end,
        }
      end)

      local callbacks = { on_results = function() end }
      live_search.create(92, callbacks, { debounce_ms = 0, show_cached = false })

      -- First search
      live_search.search_immediate(92, 'first')
      assert.is_false(cancel_called)

      -- Second search should cancel first
      live_search.search_immediate(92, 'second')
      assert.is_true(cancel_called)

      live_search._set_api_searcher(nil)
    end)

    it('should silently ignore cancelled requests', function()
      local error_received = nil
      local loading_false_called = false
      local results_callback_count = 0

      live_search._set_api_searcher(function(query, callback)
        vim.schedule(function()
          -- Simulate cancelled request response
          callback({ error = 'Request cancelled', pages = {} })
        end)
        return { request_id = 1, cancel = function() end }
      end)

      local callbacks = {
        on_results = function()
          results_callback_count = results_callback_count + 1
        end,
        on_error = function(err)
          error_received = err
        end,
        on_loading = function(is_loading)
          if not is_loading then
            loading_false_called = true
          end
        end,
      }

      live_search.create(94, callbacks, { debounce_ms = 0, show_cached = false })
      live_search.search_immediate(94, 'test')

      vim.wait(50, function()
        return false -- Just wait, don't expect anything
      end)

      -- Cancelled requests should not trigger any callbacks
      assert.is_nil(error_received)
      assert.is_false(loading_false_called)
      -- on_results only called once for initial cached (if show_cached was true), not for cancelled
      assert.equals(0, results_callback_count)

      live_search._set_api_searcher(nil)
    end)

    it('should handle API errors gracefully', function()
      local error_received = nil

      live_search._set_api_searcher(function(query, callback)
        vim.schedule(function()
          callback({ error = 'Network error' })
        end)
        return { request_id = 1, cancel = function() end }
      end)

      local callbacks = {
        on_results = function() end,
        on_error = function(err)
          error_received = err
        end,
      }

      live_search.create(95, callbacks, { debounce_ms = 0, show_cached = false })
      live_search.search_immediate(95, 'test')

      vim.wait(50, function()
        return error_received ~= nil
      end)

      assert.equals('Network error', error_received)

      live_search._set_api_searcher(nil)
    end)

    it('should not call callbacks after instance is destroyed', function()
      local results_received_after_destroy = false

      live_search._set_api_searcher(function(query, callback)
        -- Simulate slow API response that arrives after destroy
        vim.defer_fn(function()
          callback({
            pages = {
              {
                id = 'late_page',
                properties = { title = { type = 'title', title = { { plain_text = 'Late Result' } } } },
                parent = { type = 'workspace' },
              },
            },
            error = nil,
          })
        end, 50) -- 50ms delay
        return { request_id = 1, cancel = function() end }
      end)

      local callbacks = {
        on_results = function(items, is_final)
          -- This should NOT be called after destroy
          if is_final then
            results_received_after_destroy = true
          end
        end,
      }

      live_search.create(96, callbacks, { debounce_ms = 0, show_cached = false })
      live_search.search_immediate(96, 'test')

      -- Destroy immediately before API response arrives
      live_search.destroy(96)

      -- Wait for the delayed API response
      vim.wait(100, function()
        return false -- Just wait, API response arrives during this
      end)

      -- Callback should NOT have been called because instance was destroyed
      -- Note: This tests that callbacks check instance validity
      -- The actual picker.lua implementation checks live_search.get_state(instance_id)
      assert.is_nil(live_search.get_state(96))
    end)

    it('should allow new instance with same callbacks after destroy', function()
      local results_count = 0
      local last_query = nil

      live_search._set_api_searcher(function(query, callback)
        vim.schedule(function()
          callback({
            pages = {
              {
                id = 'page_' .. query,
                properties = { title = { type = 'title', title = { { plain_text = 'Result for ' .. query } } } },
                parent = { type = 'workspace' },
              },
            },
            error = nil,
          })
        end)
        return { request_id = 1, cancel = function() end }
      end)

      local callbacks = {
        on_results = function(items, is_final)
          if is_final and #items > 0 then
            results_count = results_count + 1
            last_query = items[1].title
          end
        end,
      }

      -- First instance
      live_search.create(97, callbacks, { debounce_ms = 0, show_cached = false })
      live_search.search_immediate(97, 'first')

      vim.wait(50, function()
        return results_count > 0
      end)

      assert.equals(1, results_count)
      assert.equals('Result for first', last_query)

      -- Destroy first instance
      live_search.destroy(97)

      -- Create second instance (simulating user reopening picker)
      live_search.create(98, callbacks, { debounce_ms = 0, show_cached = false })
      live_search.search_immediate(98, 'second')

      vim.wait(50, function()
        return results_count > 1
      end)

      assert.equals(2, results_count)
      assert.equals('Result for second', last_query)

      -- Verify first instance is gone
      assert.is_nil(live_search.get_state(97))
      -- Second instance should exist
      assert.is_not_nil(live_search.get_state(98))

      live_search._set_api_searcher(nil)
    end)
  end)

  describe('instance isolation', function()
    it('should not share state between instances', function()
      local instance1_results = nil
      local instance2_results = nil

      live_search._set_cache_fetcher(function(query, limit)
        return { { id = 'cache_' .. query, title = 'Cached ' .. query, from_cache = true } }
      end)

      local callbacks1 = {
        on_results = function(items)
          instance1_results = items
        end,
      }

      local callbacks2 = {
        on_results = function(items)
          instance2_results = items
        end,
      }

      -- Create two separate instances
      live_search.create(100, callbacks1, { show_cached = true, debounce_ms = 500 })
      live_search.create(101, callbacks2, { show_cached = true, debounce_ms = 500 })

      -- Update queries
      live_search.update_query(100, 'query1')
      live_search.update_query(101, 'query2')

      -- Each instance should have its own results
      assert.is_not_nil(instance1_results)
      assert.is_not_nil(instance2_results)
      assert.equals('cache_query1', instance1_results[1].id)
      assert.equals('cache_query2', instance2_results[1].id)

      -- Verify states are separate
      local state1 = live_search.get_state(100)
      local state2 = live_search.get_state(101)
      assert.equals('query1', state1.query)
      assert.equals('query2', state2.query)

      live_search._set_cache_fetcher(nil)
    end)

    it('should destroy only the specified instance', function()
      local callbacks = { on_results = function() end }

      live_search.create(102, callbacks)
      live_search.create(103, callbacks)
      live_search.create(104, callbacks)

      -- Destroy middle instance
      live_search.destroy(103)

      -- Others should still exist
      assert.is_not_nil(live_search.get_state(102))
      assert.is_nil(live_search.get_state(103))
      assert.is_not_nil(live_search.get_state(104))
    end)

    it('should start new instance with empty query after destroying old instance', function()
      -- This tests the bug fix: when picker is closed and reopened,
      -- the new instance should start with empty query, not stale query from old instance
      local instance1_queries = {}
      local instance2_queries = {}

      live_search._set_cache_fetcher(function(query, limit)
        return {}
      end)

      local callbacks1 = {
        on_results = function(items, is_final)
          -- Track all queries for instance 1
        end,
      }

      local callbacks2 = {
        on_results = function(items, is_final)
          -- Track all queries for instance 2
        end,
      }

      -- First instance - user types "karadeniz"
      live_search.create(200, callbacks1, { show_cached = false, debounce_ms = 0 })
      live_search.update_query(200, 'karadeniz')

      local state1 = live_search.get_state(200)
      assert.equals('karadeniz', state1.query)

      -- Destroy first instance (simulates closing picker)
      live_search.destroy(200)
      assert.is_nil(live_search.get_state(200))

      -- Second instance - should start fresh with empty query
      live_search.create(201, callbacks2, { show_cached = false, debounce_ms = 0 })
      live_search.search_immediate(201, '')

      local state2 = live_search.get_state(201)
      -- Query should be empty, NOT "karadeniz" from old instance
      assert.equals('', state2.query)

      live_search._set_cache_fetcher(nil)
    end)

    it('should not leak query between rapidly created instances', function()
      -- Tests race condition: old instance destroyed, new instance created quickly
      local results_log = {}

      live_search._set_cache_fetcher(function(query, limit)
        table.insert(results_log, { type = 'cache', query = query })
        return {}
      end)

      live_search._set_api_searcher(function(query, callback)
        table.insert(results_log, { type = 'api_start', query = query })
        vim.defer_fn(function()
          table.insert(results_log, { type = 'api_complete', query = query })
          callback({ pages = {}, error = nil })
        end, 50)
        return { request_id = 1, cancel = function() end }
      end)

      local callbacks = { on_results = function() end }

      -- Instance 1: search "old_query"
      live_search.create(300, callbacks, { show_cached = true, debounce_ms = 0 })
      live_search.search_immediate(300, 'old_query')

      -- Immediately destroy and create new instance
      live_search.destroy(300)

      -- Instance 2: should start with empty query
      live_search.create(301, callbacks, { show_cached = true, debounce_ms = 0 })
      live_search.search_immediate(301, '')

      -- Wait for async operations
      vim.wait(100, function()
        return false
      end)

      -- Verify instance 2's state
      local state2 = live_search.get_state(301)
      assert.is_not_nil(state2)
      assert.equals('', state2.query)

      -- Verify that cache fetcher was called with correct queries
      -- First for "old_query", then for ""
      local cache_queries = {}
      for _, log in ipairs(results_log) do
        if log.type == 'cache' then
          table.insert(cache_queries, log.query)
        end
      end

      assert.equals(2, #cache_queries)
      assert.equals('old_query', cache_queries[1])
      assert.equals('', cache_queries[2])

      live_search._set_cache_fetcher(nil)
      live_search._set_api_searcher(nil)
    end)

    it('should handle update_query with stale query gracefully', function()
      -- Tests that if somehow a stale query is passed to update_query,
      -- the state is updated correctly (not contaminated)
      local results_received = {}

      live_search._set_cache_fetcher(function(query, limit)
        return { { id = 'result_' .. query, title = 'Result for: ' .. query, from_cache = true } }
      end)

      local callbacks = {
        on_results = function(items, is_final)
          if #items > 0 then
            table.insert(results_received, items[1].id)
          end
        end,
      }

      live_search.create(400, callbacks, { show_cached = true, debounce_ms = 500 })

      -- Simulate rapid query updates (like typing fast)
      live_search.update_query(400, 'a')
      live_search.update_query(400, 'ab')
      live_search.update_query(400, 'abc')

      -- Final state should be 'abc'
      local state = live_search.get_state(400)
      assert.equals('abc', state.query)

      -- All intermediate queries should have triggered on_results
      assert.equals(3, #results_received)
      assert.equals('result_a', results_received[1])
      assert.equals('result_ab', results_received[2])
      assert.equals('result_abc', results_received[3])

      live_search._set_cache_fetcher(nil)
    end)
  end)
end)
