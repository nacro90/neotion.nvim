describe('neotion.api.pages', function()
  local pages

  before_each(function()
    package.loaded['neotion.api.pages'] = nil
    pages = require('neotion.api.pages')
  end)

  describe('get_title', function()
    it('should return Untitled for nil page', function()
      local title = pages.get_title(nil)

      assert.are.equal('Untitled', title)
    end)

    it('should return Untitled for page without properties', function()
      local title = pages.get_title({})

      assert.are.equal('Untitled', title)
    end)

    it('should extract title from page properties', function()
      local page = {
        properties = {
          Name = {
            type = 'title',
            title = {
              { plain_text = 'My Page Title' },
            },
          },
        },
      }

      local title = pages.get_title(page)

      assert.are.equal('My Page Title', title)
    end)

    it('should concatenate multiple title parts', function()
      local page = {
        properties = {
          Name = {
            type = 'title',
            title = {
              { plain_text = 'Part 1 ' },
              { plain_text = 'Part 2' },
            },
          },
        },
      }

      local title = pages.get_title(page)

      assert.are.equal('Part 1 Part 2', title)
    end)

    it('should return Untitled for empty title array', function()
      local page = {
        properties = {
          Name = {
            type = 'title',
            title = {},
          },
        },
      }

      local title = pages.get_title(page)

      assert.are.equal('Untitled', title)
    end)

    it('should handle title parts without plain_text', function()
      local page = {
        properties = {
          Name = {
            type = 'title',
            title = {
              { text = { content = 'ignored' } },
              { plain_text = 'visible' },
            },
          },
        },
      }

      local title = pages.get_title(page)

      assert.are.equal('visible', title)
    end)
  end)

  describe('get_parent', function()
    it('should return unknown for nil page', function()
      local parent_type, parent_id = pages.get_parent(nil)

      assert.are.equal('unknown', parent_type)
      assert.is_nil(parent_id)
    end)

    it('should return unknown for page without parent', function()
      local parent_type, parent_id = pages.get_parent({})

      assert.are.equal('unknown', parent_type)
      assert.is_nil(parent_id)
    end)

    it('should extract workspace parent', function()
      local page = {
        parent = {
          type = 'workspace',
        },
      }

      local parent_type, parent_id = pages.get_parent(page)

      assert.are.equal('workspace', parent_type)
      assert.is_nil(parent_id)
    end)

    it('should extract page parent', function()
      local page = {
        parent = {
          type = 'page_id',
          page_id = 'parent-page-id-123',
        },
      }

      local parent_type, parent_id = pages.get_parent(page)

      assert.are.equal('page', parent_type)
      assert.are.equal('parent-page-id-123', parent_id)
    end)

    it('should extract database parent', function()
      local page = {
        parent = {
          type = 'database_id',
          database_id = 'db-id-456',
        },
      }

      local parent_type, parent_id = pages.get_parent(page)

      assert.are.equal('database', parent_type)
      assert.are.equal('db-id-456', parent_id)
    end)

    it('should return unknown for unrecognized parent type', function()
      local page = {
        parent = {
          type = 'some_new_type',
        },
      }

      local parent_type, parent_id = pages.get_parent(page)

      assert.are.equal('unknown', parent_type)
      assert.is_nil(parent_id)
    end)
  end)

  describe('get_icon', function()
    it('should return nil for nil page', function()
      local icon = pages.get_icon(nil)

      assert.is_nil(icon)
    end)

    it('should return nil for page without icon', function()
      local icon = pages.get_icon({})

      assert.is_nil(icon)
    end)

    it('should return nil for page with nil icon', function()
      local page = { icon = nil }

      local icon = pages.get_icon(page)

      assert.is_nil(icon)
    end)

    it('should return nil for vim.NIL icon (userdata from cjson)', function()
      -- vim.NIL is how cjson represents JSON null - it's userdata, not nil
      -- This test ensures we don't crash when icon is vim.NIL
      local page = { icon = vim.NIL }

      local icon = pages.get_icon(page)

      assert.is_nil(icon)
    end)

    it('should extract emoji icon', function()
      local page = {
        icon = {
          type = 'emoji',
          emoji = '📝',
        },
      }

      local icon = pages.get_icon(page)

      assert.are.equal('📝', icon)
    end)

    it('should return placeholder for external icon', function()
      local page = {
        icon = {
          type = 'external',
          external = { url = 'http://example.com/icon.png' },
        },
      }

      local icon = pages.get_icon(page)

      assert.are.equal('🔗', icon)
    end)

    it('should return placeholder for file icon', function()
      local page = {
        icon = {
          type = 'file',
          file = { url = 'http://notion.so/file.png' },
        },
      }

      local icon = pages.get_icon(page)

      assert.are.equal('📄', icon)
    end)

    it('should return nil for unknown icon type', function()
      local page = {
        icon = {
          type = 'unknown_type',
        },
      }

      local icon = pages.get_icon(page)

      assert.is_nil(icon)
    end)
  end)

  -- Note: get() and search() are async and require mocking
  -- These would be integration tests or require a mock client
  describe('get (requires auth)', function()
    it('should call callback with error when no token', function()
      -- Mock auth to return no token
      package.loaded['neotion.api.auth'] = {
        get_token = function()
          return { token = nil, error = 'No API token configured' }
        end,
      }

      local result = nil
      pages.get('test-page-id', function(r)
        result = r
      end)

      -- Wait for callback
      vim.wait(100, function()
        return result ~= nil
      end)

      assert.is_not_nil(result)
      assert.is_nil(result.page)
      assert.is_truthy(result.error:match('No API token'))

      -- Clean up mock
      package.loaded['neotion.api.auth'] = nil
    end)
  end)

  describe('search (requires auth)', function()
    it('should call callback with error when no token', function()
      -- Mock auth to return no token
      package.loaded['neotion.api.auth'] = {
        get_token = function()
          return { token = nil, error = 'No API token configured' }
        end,
      }

      local result = nil
      pages.search('test query', function(r)
        result = r
      end)

      -- Wait for callback
      vim.wait(100, function()
        return result ~= nil
      end)

      assert.is_not_nil(result)
      assert.are.equal(0, #result.pages)
      assert.is_false(result.has_more)
      assert.is_truthy(result.error:match('No API token'))

      -- Clean up mock
      package.loaded['neotion.api.auth'] = nil
    end)
  end)

  describe('search_with_cancel', function()
    it('should return request handle with request_id', function()
      -- Mock auth and throttle
      package.loaded['neotion.api.auth'] = {
        get_token = function()
          return { token = 'test-token', error = nil }
        end,
      }
      package.loaded['neotion.api.throttle'] = {
        post = function(_, _, _, _)
          return 'mock-request-id-123'
        end,
        cancel = function(_)
          return true
        end,
      }

      -- Reload pages module to pick up mocks
      package.loaded['neotion.api.pages'] = nil
      local pages_fresh = require('neotion.api.pages')

      local handle = pages_fresh.search_with_cancel('test', function() end)

      assert.is_table(handle)
      assert.is_string(handle.request_id)
      assert.are.equal('mock-request-id-123', handle.request_id)

      -- Clean up mocks
      package.loaded['neotion.api.auth'] = nil
      package.loaded['neotion.api.throttle'] = nil
      package.loaded['neotion.api.pages'] = nil
    end)

    it('should return handle with cancel function', function()
      package.loaded['neotion.api.auth'] = {
        get_token = function()
          return { token = 'test-token', error = nil }
        end,
      }
      package.loaded['neotion.api.throttle'] = {
        post = function(_, _, _, _)
          return 'mock-request-id-456'
        end,
        cancel = function(_)
          return true
        end,
      }

      package.loaded['neotion.api.pages'] = nil
      local pages_fresh = require('neotion.api.pages')

      local handle = pages_fresh.search_with_cancel('test', function() end)

      assert.is_function(handle.cancel)

      -- Clean up
      package.loaded['neotion.api.auth'] = nil
      package.loaded['neotion.api.throttle'] = nil
      package.loaded['neotion.api.pages'] = nil
    end)

    it('should cancel request via handle.cancel()', function()
      local cancelled_id = nil

      package.loaded['neotion.api.auth'] = {
        get_token = function()
          return { token = 'test-token', error = nil }
        end,
      }
      package.loaded['neotion.api.throttle'] = {
        post = function(_, _, _, _)
          return 'request-to-cancel'
        end,
        cancel = function(id)
          cancelled_id = id
          return true
        end,
      }

      package.loaded['neotion.api.pages'] = nil
      local pages_fresh = require('neotion.api.pages')

      local handle = pages_fresh.search_with_cancel('test', function() end)
      local result = handle.cancel()

      assert.is_true(result)
      assert.are.equal('request-to-cancel', cancelled_id)

      -- Clean up
      package.loaded['neotion.api.auth'] = nil
      package.loaded['neotion.api.throttle'] = nil
      package.loaded['neotion.api.pages'] = nil
    end)

    it('should return nil handle when no token', function()
      package.loaded['neotion.api.auth'] = {
        get_token = function()
          return { token = nil, error = 'No token' }
        end,
      }

      package.loaded['neotion.api.pages'] = nil
      local pages_fresh = require('neotion.api.pages')

      local callback_called = false
      local handle = pages_fresh.search_with_cancel('test', function()
        callback_called = true
      end)

      -- Should return nil handle when auth fails
      assert.is_nil(handle)

      -- Wait for callback
      vim.wait(100, function()
        return callback_called
      end)

      assert.is_true(callback_called)

      -- Clean up
      package.loaded['neotion.api.auth'] = nil
      package.loaded['neotion.api.pages'] = nil
    end)
  end)
end)
