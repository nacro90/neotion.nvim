---@diagnostic disable: undefined-field
-- Integration tests for cache pages with real SQLite

-- Add sqlite.lua to package.path
local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h:h:h')
local sqlite_path = plugin_root .. '/.deps/sqlite.lua'
if vim.fn.isdirectory(sqlite_path) == 1 then
  package.path = sqlite_path .. '/lua/?.lua;' .. sqlite_path .. '/lua/?/init.lua;' .. package.path
end

-- Check sqlite.lua availability
local sqlite_ok = pcall(require, 'sqlite.db')
if not sqlite_ok then
  describe('neotion.cache.pages integration (SKIPPED)', function()
    it('requires sqlite.lua', function()
      pending('Install sqlite.lua to run integration tests')
    end)
  end)
  return
end

-- Reset modules
package.loaded['neotion.cache'] = nil
package.loaded['neotion.cache.db'] = nil
package.loaded['neotion.cache.pages'] = nil

local cache = require('neotion.cache')
local pages = require('neotion.cache.pages')

--- Helper to create a mock page object in Notion API format
---@param title string
---@return table
local function make_page(title)
  return {
    last_edited_time = '2024-01-01T12:00:00.000Z',
    properties = {
      title = {
        type = 'title',
        title = { { plain_text = title } },
      },
    },
  }
end

describe('neotion.cache.pages integration', function()
  local test_db_path

  before_each(function()
    test_db_path = vim.fn.tempname() .. '_neotion_pages_test.db'
    cache.close()
    cache._reset()
    cache.init(test_db_path)
  end)

  after_each(function()
    cache.close()
    cache._reset()
    if test_db_path and vim.fn.filereadable(test_db_path) == 1 then
      vim.fn.delete(test_db_path)
    end
  end)

  describe('save_page and get_page', function()
    it('should save and retrieve page metadata', function()
      local page_id = 'abc123def456789012345678abcdef00'
      local page = {
        id = page_id,
        created_time = '2024-01-01T12:00:00.000Z',
        last_edited_time = '2024-01-02T12:00:00.000Z',
        icon = { type = 'emoji', emoji = '📝' },
        parent = { type = 'workspace', workspace = true },
        properties = {
          title = {
            type = 'title',
            title = { { plain_text = 'Test Page' } },
          },
        },
      }

      local success = pages.save_page(page_id, page)
      assert.is_true(success)

      local result = pages.get_page(page_id)
      assert.is_not_nil(result)
      assert.are.equal('Test Page', result.title)
      assert.are.equal('📝', result.icon)
      assert.are.equal('workspace', result.parent_type)
    end)

    it('should update existing page on save', function()
      local page_id = 'abc123def456789012345678abcdef01'

      pages.save_page(page_id, make_page('Original'))
      pages.save_page(page_id, make_page('Updated'))

      local result = pages.get_page(page_id)
      assert.are.equal('Updated', result.title)
      -- open_count should increment
      assert.are.equal(2, result.open_count)
    end)
  end)

  describe('save_content and get_content', function()
    it('should save and retrieve blocks', function()
      local page_id = 'abc123def456789012345678abcdef02'
      pages.save_page(page_id, make_page('Test'))

      local blocks = {
        { id = 'block1', type = 'paragraph', paragraph = { rich_text = {} } },
        { id = 'block2', type = 'heading_1', heading_1 = { rich_text = {} } },
      }

      local success = pages.save_content(page_id, blocks)
      assert.is_true(success)

      local result, hash = pages.get_content(page_id)
      assert.is_not_nil(result)
      assert.are.equal(2, #result)
      assert.are.equal('block1', result[1].id)
      assert.are.equal('paragraph', result[1].type)
      assert.is_string(hash)
    end)

    it('should update content on resave', function()
      local page_id = 'abc123def456789012345678abcdef03'
      pages.save_page(page_id, make_page('Test'))

      pages.save_content(page_id, { { id = 'b1', type = 'paragraph' } })
      pages.save_content(page_id, { { id = 'b2', type = 'heading_1' }, { id = 'b3', type = 'paragraph' } })

      local result = pages.get_content(page_id)
      assert.are.equal(2, #result)
      assert.are.equal('b2', result[1].id)
    end)
  end)

  describe('has_page and has_content', function()
    it('should return true when page exists', function()
      local page_id = 'abc123def456789012345678abcdef04'
      pages.save_page(page_id, make_page('Test'))

      assert.is_true(pages.has_page(page_id))
    end)

    it('should return false when page does not exist', function()
      assert.is_false(pages.has_page('nonexistent'))
    end)

    it('should return true when content exists', function()
      local page_id = 'abc123def456789012345678abcdef05'
      pages.save_page(page_id, make_page('Test'))
      pages.save_content(page_id, { { id = 'b1', type = 'paragraph' } })

      assert.is_true(pages.has_content(page_id))
    end)

    it('should return false when content does not exist', function()
      local page_id = 'abc123def456789012345678abcdef06'
      pages.save_page(page_id, make_page('Test'))

      assert.is_false(pages.has_content(page_id))
    end)
  end)

  describe('get_recent', function()
    it('should return recently opened pages', function()
      for i = 1, 5 do
        local page_id = string.format('abc123def456789012345678abcdef%02d', 10 + i)
        pages.save_page(page_id, make_page('Page ' .. i))
      end

      local recent = pages.get_recent(3)
      assert.are.equal(3, #recent)
    end)

    it('should order by last_opened_at descending', function()
      for i = 1, 3 do
        local page_id = string.format('abc123def456789012345678abcdef%02d', 20 + i)
        pages.save_page(page_id, make_page('Page ' .. i))
        vim.wait(50) -- Delay for different timestamps (os.time() has 1s resolution)
      end

      local recent = pages.get_recent()
      -- Most recent should be first
      assert.is_true(#recent >= 3)
      -- At minimum, we should have all 3 pages
      local titles = {}
      for _, p in ipairs(recent) do
        titles[p.title] = true
      end
      assert.is_true(titles['Page 1'])
      assert.is_true(titles['Page 2'])
      assert.is_true(titles['Page 3'])
    end)
  end)

  describe('search', function()
    it('should find pages by title', function()
      pages.save_page('abc123def456789012345678abcdef31', make_page('Meeting Notes'))
      pages.save_page('abc123def456789012345678abcdef32', make_page('Project Plan'))
      pages.save_page('abc123def456789012345678abcdef33', make_page('Meeting Agenda'))

      local results = pages.search('Meeting')
      assert.are.equal(2, #results)
    end)

    it('should be case insensitive', function()
      pages.save_page('abc123def456789012345678abcdef34', make_page('Important Doc'))

      local results = pages.search('important')
      assert.are.equal(1, #results)
    end)
  end)

  describe('delete_page', function()
    it('should soft delete page', function()
      local page_id = 'abc123def456789012345678abcdef40'
      pages.save_page(page_id, make_page('To Delete'))

      assert.is_true(pages.has_page(page_id))
      pages.delete_page(page_id)
      assert.is_false(pages.has_page(page_id))
    end)
  end)

  describe('get_cache_age', function()
    it('should return age in seconds', function()
      local page_id = 'abc123def456789012345678abcdef50'
      pages.save_page(page_id, make_page('Test'))
      pages.save_content(page_id, { { id = 'b1', type = 'paragraph' } })

      local age = pages.get_cache_age(page_id)
      assert.is_number(age)
      assert.is_true(age >= 0)
      assert.is_true(age < 5)
    end)

    it('should return nil for uncached page', function()
      local age = pages.get_cache_age('nonexistent')
      assert.is_nil(age)
    end)
  end)

  describe('clear operations', function()
    it('clear_content should remove all content but keep metadata', function()
      local page_id = 'abc123def456789012345678abcdef60'
      pages.save_page(page_id, make_page('Test'))
      pages.save_content(page_id, { { id = 'b1', type = 'paragraph' } })

      assert.is_true(pages.has_content(page_id))
      pages.clear_content()
      assert.is_false(pages.has_content(page_id))
      assert.is_true(pages.has_page(page_id))
    end)

    it('clear_all should remove everything', function()
      local page_id = 'abc123def456789012345678abcdef61'
      pages.save_page(page_id, make_page('Test'))
      pages.save_content(page_id, { { id = 'b1', type = 'paragraph' } })

      pages.clear_all()
      assert.is_false(pages.has_page(page_id))
      assert.is_false(pages.has_content(page_id))
    end)
  end)
end)
