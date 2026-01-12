describe('neotion.api.databases', function()
  local databases

  before_each(function()
    package.loaded['neotion.api.databases'] = nil
    databases = require('neotion.api.databases')
  end)

  describe('get_title', function()
    it('should return Untitled for nil database', function()
      local title = databases.get_title(nil)

      assert.are.equal('Untitled', title)
    end)

    it('should return Untitled for database without title', function()
      local title = databases.get_title({})

      assert.are.equal('Untitled', title)
    end)

    it('should extract title from database', function()
      local db = {
        title = {
          { plain_text = 'My Database' },
        },
      }

      local title = databases.get_title(db)

      assert.are.equal('My Database', title)
    end)

    it('should concatenate multiple title parts', function()
      local db = {
        title = {
          { plain_text = 'Part 1 ' },
          { plain_text = 'Part 2' },
        },
      }

      local title = databases.get_title(db)

      assert.are.equal('Part 1 Part 2', title)
    end)

    it('should return Untitled for empty title array', function()
      local db = {
        title = {},
      }

      local title = databases.get_title(db)

      assert.are.equal('Untitled', title)
    end)
  end)

  describe('get_icon', function()
    it('should return nil for nil database', function()
      local icon = databases.get_icon(nil)

      assert.is_nil(icon)
    end)

    it('should return nil for database without icon', function()
      local icon = databases.get_icon({})

      assert.is_nil(icon)
    end)

    it('should return nil for vim.NIL icon', function()
      local db = { icon = vim.NIL }

      local icon = databases.get_icon(db)

      assert.is_nil(icon)
    end)

    it('should extract emoji icon', function()
      local db = {
        icon = {
          type = 'emoji',
          emoji = '📊',
        },
      }

      local icon = databases.get_icon(db)

      assert.are.equal('📊', icon)
    end)

    it('should return placeholder for external icon', function()
      local db = {
        icon = {
          type = 'external',
          external = { url = 'http://example.com/icon.png' },
        },
      }

      local icon = databases.get_icon(db)

      assert.are.equal('\u{f03e}', icon) -- nf-fa-image
    end)

    it('should return placeholder for file icon', function()
      local db = {
        icon = {
          type = 'file',
          file = { url = 'http://notion.so/file.png' },
        },
      }

      local icon = databases.get_icon(db)

      assert.are.equal('\u{f03e}', icon) -- nf-fa-image
    end)

    it('should return nil for unknown icon type', function()
      local db = {
        icon = {
          type = 'unknown_type',
        },
      }

      local icon = databases.get_icon(db)

      assert.is_nil(icon)
    end)
  end)

  describe('get (requires auth)', function()
    it('should call callback with error when no token', function()
      package.loaded['neotion.api.auth'] = {
        get_token = function()
          return { token = nil, error = 'No API token configured' }
        end,
      }

      local result = nil
      databases.get('test-db-id', function(r)
        result = r
      end)

      vim.wait(100, function()
        return result ~= nil
      end)

      assert.is_not_nil(result)
      assert.is_nil(result.database)
      assert.is_truthy(result.error:match('No API token'))

      package.loaded['neotion.api.auth'] = nil
    end)

    it('should normalize database ID by removing dashes', function()
      local called_endpoint = nil

      package.loaded['neotion.api.auth'] = {
        get_token = function()
          return { token = 'test-token', error = nil }
        end,
      }
      package.loaded['neotion.api.throttle'] = {
        get = function(endpoint, _, callback)
          called_endpoint = endpoint
          callback({ body = { id = 'test' }, error = nil })
        end,
      }

      package.loaded['neotion.api.databases'] = nil
      local dbs_fresh = require('neotion.api.databases')

      dbs_fresh.get('12345678-1234-1234-1234-123456789012', function() end)

      assert.is_truthy(called_endpoint:match('12345678123412341234123456789012'))
      assert.is_falsy(called_endpoint:match('-'))

      package.loaded['neotion.api.auth'] = nil
      package.loaded['neotion.api.throttle'] = nil
      package.loaded['neotion.api.databases'] = nil
    end)
  end)

  describe('query (requires auth)', function()
    it('should call callback with error when no token', function()
      package.loaded['neotion.api.auth'] = {
        get_token = function()
          return { token = nil, error = 'No API token configured' }
        end,
      }

      local result = nil
      databases.query('test-db-id', {}, function(r)
        result = r
      end)

      vim.wait(100, function()
        return result ~= nil
      end)

      assert.is_not_nil(result)
      assert.are.equal(0, #result.pages)
      assert.is_false(result.has_more)
      assert.is_truthy(result.error:match('No API token'))

      package.loaded['neotion.api.auth'] = nil
    end)

    it('should pass filter option to request body', function()
      local request_body = nil

      package.loaded['neotion.api.auth'] = {
        get_token = function()
          return { token = 'test-token', error = nil }
        end,
      }
      package.loaded['neotion.api.throttle'] = {
        post = function(_, _, body, callback)
          request_body = body
          callback({ body = { results = {} }, error = nil })
          return 'req-id'
        end,
      }

      package.loaded['neotion.api.databases'] = nil
      local dbs_fresh = require('neotion.api.databases')

      local filter = {
        property = 'Status',
        select = { equals = 'Done' },
      }
      dbs_fresh.query('test-db', { filter = filter }, function() end)

      assert.is_not_nil(request_body)
      assert.are.same(filter, request_body.filter)

      package.loaded['neotion.api.auth'] = nil
      package.loaded['neotion.api.throttle'] = nil
      package.loaded['neotion.api.databases'] = nil
    end)

    it('should pass sorts option to request body', function()
      local request_body = nil

      package.loaded['neotion.api.auth'] = {
        get_token = function()
          return { token = 'test-token', error = nil }
        end,
      }
      package.loaded['neotion.api.throttle'] = {
        post = function(_, _, body, callback)
          request_body = body
          callback({ body = { results = {} }, error = nil })
          return 'req-id'
        end,
      }

      package.loaded['neotion.api.databases'] = nil
      local dbs_fresh = require('neotion.api.databases')

      local sorts = {
        { property = 'Created', direction = 'descending' },
      }
      dbs_fresh.query('test-db', { sorts = sorts }, function() end)

      assert.is_not_nil(request_body)
      assert.are.same(sorts, request_body.sorts)

      package.loaded['neotion.api.auth'] = nil
      package.loaded['neotion.api.throttle'] = nil
      package.loaded['neotion.api.databases'] = nil
    end)

    it('should pass start_cursor for pagination', function()
      local request_body = nil

      package.loaded['neotion.api.auth'] = {
        get_token = function()
          return { token = 'test-token', error = nil }
        end,
      }
      package.loaded['neotion.api.throttle'] = {
        post = function(_, _, body, callback)
          request_body = body
          callback({ body = { results = {} }, error = nil })
          return 'req-id'
        end,
      }

      package.loaded['neotion.api.databases'] = nil
      local dbs_fresh = require('neotion.api.databases')

      dbs_fresh.query('test-db', { start_cursor = 'cursor-abc' }, function() end)

      assert.is_not_nil(request_body)
      assert.are.equal('cursor-abc', request_body.start_cursor)

      package.loaded['neotion.api.auth'] = nil
      package.loaded['neotion.api.throttle'] = nil
      package.loaded['neotion.api.databases'] = nil
    end)

    it('should return pages from response', function()
      package.loaded['neotion.api.auth'] = {
        get_token = function()
          return { token = 'test-token', error = nil }
        end,
      }
      package.loaded['neotion.api.throttle'] = {
        post = function(_, _, _, callback)
          callback({
            body = {
              results = { { id = 'page1' }, { id = 'page2' } },
              has_more = true,
              next_cursor = 'next-page-cursor',
            },
            error = nil,
          })
          return 'req-id'
        end,
      }

      package.loaded['neotion.api.databases'] = nil
      local dbs_fresh = require('neotion.api.databases')

      local result = nil
      dbs_fresh.query('test-db', {}, function(r)
        result = r
      end)

      vim.wait(100, function()
        return result ~= nil
      end)

      assert.are.equal(2, #result.pages)
      assert.is_true(result.has_more)
      assert.are.equal('next-page-cursor', result.next_cursor)
      assert.is_nil(result.error)

      package.loaded['neotion.api.auth'] = nil
      package.loaded['neotion.api.throttle'] = nil
      package.loaded['neotion.api.databases'] = nil
    end)
  end)

  describe('query_with_cancel', function()
    it('should return request handle with request_id', function()
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

      package.loaded['neotion.api.databases'] = nil
      local dbs_fresh = require('neotion.api.databases')

      local handle = dbs_fresh.query_with_cancel('test-db', {}, function() end)

      assert.is_table(handle)
      assert.is_string(handle.request_id)
      assert.are.equal('mock-request-id-123', handle.request_id)

      package.loaded['neotion.api.auth'] = nil
      package.loaded['neotion.api.throttle'] = nil
      package.loaded['neotion.api.databases'] = nil
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

      package.loaded['neotion.api.databases'] = nil
      local dbs_fresh = require('neotion.api.databases')

      local handle = dbs_fresh.query_with_cancel('test-db', {}, function() end)

      assert.is_function(handle.cancel)

      package.loaded['neotion.api.auth'] = nil
      package.loaded['neotion.api.throttle'] = nil
      package.loaded['neotion.api.databases'] = nil
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

      package.loaded['neotion.api.databases'] = nil
      local dbs_fresh = require('neotion.api.databases')

      local handle = dbs_fresh.query_with_cancel('test-db', {}, function() end)
      local result = handle.cancel()

      assert.is_true(result)
      assert.are.equal('request-to-cancel', cancelled_id)

      package.loaded['neotion.api.auth'] = nil
      package.loaded['neotion.api.throttle'] = nil
      package.loaded['neotion.api.databases'] = nil
    end)

    it('should return nil handle when no token', function()
      package.loaded['neotion.api.auth'] = {
        get_token = function()
          return { token = nil, error = 'No token' }
        end,
      }

      package.loaded['neotion.api.databases'] = nil
      local dbs_fresh = require('neotion.api.databases')

      local callback_called = false
      local handle = dbs_fresh.query_with_cancel('test-db', {}, function()
        callback_called = true
      end)

      assert.is_nil(handle)

      vim.wait(100, function()
        return callback_called
      end)

      assert.is_true(callback_called)

      package.loaded['neotion.api.auth'] = nil
      package.loaded['neotion.api.databases'] = nil
    end)

    it('should handle cancelled response', function()
      package.loaded['neotion.api.auth'] = {
        get_token = function()
          return { token = 'test-token', error = nil }
        end,
      }

      local stored_callback
      package.loaded['neotion.api.throttle'] = {
        post = function(_, _, _, callback)
          stored_callback = callback
          return 'req-id'
        end,
        cancel = function()
          return true
        end,
      }

      package.loaded['neotion.api.databases'] = nil
      local dbs_fresh = require('neotion.api.databases')

      local result = nil
      dbs_fresh.query_with_cancel('test-db', {}, function(r)
        result = r
      end)

      -- Simulate cancelled response
      stored_callback({ cancelled = true })

      vim.wait(100, function()
        return result ~= nil
      end)

      assert.are.equal(0, #result.pages)
      assert.is_false(result.has_more)
      assert.are.equal('Request cancelled', result.error)

      package.loaded['neotion.api.auth'] = nil
      package.loaded['neotion.api.throttle'] = nil
      package.loaded['neotion.api.databases'] = nil
    end)
  end)
end)
