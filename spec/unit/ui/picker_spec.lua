---@diagnostic disable: undefined-global
describe('neotion.ui.picker', function()
  local picker

  before_each(function()
    package.loaded['neotion.ui.picker'] = nil
    package.loaded['neotion.api.pages'] = nil
    picker = require('neotion.ui.picker')
  end)

  describe('page_to_item', function()
    it('should convert page with emoji icon', function()
      -- Mock pages API
      package.loaded['neotion.api.pages'] = {
        get_title = function()
          return 'Test Page'
        end,
        get_parent = function()
          return 'workspace', nil
        end,
      }
      picker = require('neotion.ui.picker')

      local page = {
        id = 'abc123',
        icon = { type = 'emoji', emoji = '📝' },
      }

      local item = picker.page_to_item(page)

      assert.are.equal('abc123', item.id)
      assert.are.equal('Test Page', item.title)
      assert.are.equal('📝', item.icon)
      assert.are.equal('workspace', item.parent_type)
    end)

    it('should handle page without icon', function()
      package.loaded['neotion.api.pages'] = {
        get_title = function()
          return 'No Icon Page'
        end,
        get_parent = function()
          return 'page_id', 'parent123'
        end,
      }
      picker = require('neotion.ui.picker')

      local page = {
        id = 'def456',
        icon = nil,
      }

      local item = picker.page_to_item(page)

      assert.are.equal('def456', item.id)
      assert.are.equal('No Icon Page', item.title)
      assert.are.equal('', item.icon)
      assert.are.equal('page_id', item.parent_type)
      assert.are.equal('parent123', item.parent_id)
    end)

    it('should handle external icon', function()
      package.loaded['neotion.api.pages'] = {
        get_title = function()
          return 'External Icon'
        end,
        get_parent = function()
          return 'database_id', 'db123'
        end,
      }
      picker = require('neotion.ui.picker')

      local page = {
        id = 'ghi789',
        icon = { type = 'external', external = { url = 'https://example.com/icon.png' } },
      }

      local item = picker.page_to_item(page)

      assert.are.equal('ghi789', item.id)
      assert.are.equal('', item.icon) -- External icons can't be displayed
    end)
  end)

  describe('select', function()
    it('should notify when no items found', function()
      local notified = false
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        if msg:match('No items found') then
          notified = true
          assert.are.equal(vim.log.levels.WARN, level)
        end
      end

      local called = false
      picker.select({}, {}, function(item)
        called = true
        assert.is_nil(item)
      end)

      assert.is_true(notified)
      assert.is_true(called)

      vim.notify = original_notify
    end)

    it('should use vim.ui.select when telescope not available', function()
      -- Ensure telescope is not available
      package.loaded['telescope'] = nil
      package.preload['telescope'] = function()
        error('telescope not installed')
      end

      local select_called = false
      local original_select = vim.ui.select
      vim.ui.select = function(items, opts, on_choice)
        select_called = true
        assert.are.equal(2, #items)
        assert.are.equal('Select Page', opts.prompt)
        on_choice(items[1])
      end

      local items = {
        { id = 'a', title = 'Page A' },
        { id = 'b', title = 'Page B' },
      }

      local result = nil
      picker.select(items, { prompt = 'Select Page' }, function(item)
        result = item
      end)

      assert.is_true(select_called)
      assert.are.equal('a', result.id)

      vim.ui.select = original_select
      package.preload['telescope'] = nil
    end)
  end)

  describe('search', function()
    it('should call pages API search and handle results', function()
      local search_called = false
      local search_query = nil

      package.loaded['neotion.api.pages'] = {
        search = function(query, callback)
          search_called = true
          search_query = query
          vim.schedule(function()
            callback({
              pages = {
                { id = 'page1', icon = { type = 'emoji', emoji = '📄' } },
                { id = 'page2', icon = nil },
              },
              has_more = false,
              error = nil,
            })
          end)
        end,
        get_title = function()
          return 'Mock Title'
        end,
        get_parent = function()
          return 'workspace', nil
        end,
      }

      -- Reset picker to use mocked pages API
      package.loaded['neotion.ui.picker'] = nil
      picker = require('neotion.ui.picker')

      -- Mock vim.ui.select for the picker
      local selected_items = nil
      local original_select = vim.ui.select
      vim.ui.select = function(items, _, on_choice)
        selected_items = items
        on_choice(nil)
      end

      picker.search('test query', function() end)

      -- Wait for scheduled callback
      vim.wait(100, function()
        return search_called
      end)

      assert.is_true(search_called)
      assert.are.equal('test query', search_query)

      vim.ui.select = original_select
    end)

    it('should handle search errors', function()
      package.loaded['neotion.api.pages'] = {
        search = function(_, callback)
          vim.schedule(function()
            callback({
              pages = {},
              has_more = false,
              error = 'API error',
            })
          end)
        end,
      }

      package.loaded['neotion.ui.picker'] = nil
      picker = require('neotion.ui.picker')

      local error_notified = false
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        if msg:match('Search failed') then
          error_notified = true
          assert.are.equal(vim.log.levels.ERROR, level)
        end
      end

      local callback_called = false
      picker.search('query', function(item)
        callback_called = true
        assert.is_nil(item)
      end)

      vim.wait(100, function()
        return callback_called
      end)

      assert.is_true(error_notified)
      assert.is_true(callback_called)

      vim.notify = original_notify
    end)
  end)
end)
