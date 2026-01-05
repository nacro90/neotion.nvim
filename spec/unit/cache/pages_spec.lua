---@diagnostic disable: undefined-field

-- Ensure sqlite.lua is in path (same logic as minimal_init.lua)
local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h:h:h')
local sqlite_path = plugin_root .. '/.deps/sqlite.lua'
if vim.fn.isdirectory(sqlite_path) == 1 then
  package.path = sqlite_path .. '/lua/?.lua;' .. sqlite_path .. '/lua/?/init.lua;' .. package.path
end

-- Reset modules first to ensure clean state
package.loaded['neotion.cache'] = nil
package.loaded['neotion.cache.db'] = nil
package.loaded['neotion.cache.pages'] = nil
package.loaded['neotion.cache.schema'] = nil
package.loaded['neotion.cache.hash'] = nil
package.loaded['neotion.cache.sync_state'] = nil

local db_module = require('neotion.cache.db')

-- Skip all tests if SQLite is not available
if not db_module.is_sqlite_available() then
  describe('neotion.cache.pages', function()
    it('SKIPPED: sqlite.lua not available', function()
      pending('sqlite.lua not installed')
    end)
  end)
  return
end

-- Helper: create a mock Notion page object
---@param overrides? table
---@return table
local function mock_page(overrides)
  local base = {
    id = 'test-page-id',
    properties = {
      Name = {
        type = 'title',
        title = { { plain_text = 'Test Page' } },
      },
    },
    parent = { type = 'workspace' },
    icon = { type = 'emoji', emoji = '📝' },
    last_edited_time = '2024-01-15T10:00:00.000Z',
    created_time = '2024-01-01T09:00:00.000Z',
  }
  if overrides then
    return vim.tbl_deep_extend('force', base, overrides)
  end
  return base
end

-- Helper: reset neotion cache modules without touching sqlite
local function reset_cache_modules()
  package.loaded['neotion.cache'] = nil
  package.loaded['neotion.cache.pages'] = nil
  package.loaded['neotion.cache.db'] = nil
  package.loaded['neotion.cache.schema'] = nil
  package.loaded['neotion.cache.hash'] = nil
  package.loaded['neotion.cache.sync_state'] = nil
end

-- Helper: setup fresh cache for each test
local function setup_cache()
  reset_cache_modules()
  local cache = require('neotion.cache')
  cache.init(':memory:')
  local pages_mod = require('neotion.cache.pages')
  return cache, pages_mod
end

describe('neotion.cache.pages', function()
  describe('with cache initialized', function()
    describe('save_page', function()
      it('should save page metadata', function()
        local cache, pages_mod = setup_cache()

        local page = mock_page({ id = 'page-1' })
        local result = pages_mod.save_page('page-1', page)

        assert.is_true(result)
        assert.is_true(pages_mod.has_page('page-1'))

        cache.close()
      end)

      it('should NOT increment open_count on save', function()
        -- BUG FIX TEST: open_count should stay 0 when just saving
        local cache, pages_mod = setup_cache()

        local page = mock_page({ id = 'page-no-increment' })

        pages_mod.save_page('page-no-increment', page)
        pages_mod.save_page('page-no-increment', page) -- Second save
        pages_mod.save_page('page-no-increment', page) -- Third save

        local saved = pages_mod.get_page('page-no-increment')
        assert.is_not_nil(saved)
        assert.are.equal(0, saved.open_count) -- Should be 0, NOT 3

        cache.close()
      end)

      it('should NOT update last_opened_at on save', function()
        -- BUG FIX TEST: last_opened_at should be NULL when just saving
        local cache, pages_mod = setup_cache()

        local page = mock_page({ id = 'page-no-open' })

        pages_mod.save_page('page-no-open', page)

        local saved = pages_mod.get_page('page-no-open')
        assert.is_not_nil(saved)
        assert.is_nil(saved.last_opened_at) -- Should be NULL, not current time

        cache.close()
      end)

      it('should preserve open_count on update', function()
        local cache, pages_mod = setup_cache()

        local page = mock_page({ id = 'page-preserve' })
        pages_mod.save_page('page-preserve', page)

        -- Simulate user opening the page
        pages_mod.update_open_stats('page-preserve')
        pages_mod.update_open_stats('page-preserve')

        -- Now update page metadata (e.g., from API refresh)
        local updated_page = mock_page({
          id = 'page-preserve',
          properties = {
            Name = { type = 'title', title = { { plain_text = 'Updated Title' } } },
          },
        })
        pages_mod.save_page('page-preserve', updated_page)

        local saved = pages_mod.get_page('page-preserve')
        assert.are.equal(2, saved.open_count) -- Should be preserved
        assert.are.equal('Updated Title', saved.title)

        cache.close()
      end)

      it('should preserve last_opened_at on update', function()
        local cache, pages_mod = setup_cache()

        local page = mock_page({ id = 'page-preserve-time' })
        pages_mod.save_page('page-preserve-time', page)

        -- Simulate user opening the page
        pages_mod.update_open_stats('page-preserve-time')

        local after_open = pages_mod.get_page('page-preserve-time')
        local original_opened_at = after_open.last_opened_at

        -- Wait a bit and update page
        vim.wait(50, function()
          return false
        end)
        pages_mod.save_page('page-preserve-time', page)

        local saved = pages_mod.get_page('page-preserve-time')
        assert.are.equal(original_opened_at, saved.last_opened_at) -- Should be preserved

        cache.close()
      end)
    end)

    describe('update_open_stats', function()
      it('should increment open_count', function()
        local cache, pages_mod = setup_cache()

        local page = mock_page({ id = 'page-open' })
        pages_mod.save_page('page-open', page)

        pages_mod.update_open_stats('page-open')

        local saved = pages_mod.get_page('page-open')
        assert.are.equal(1, saved.open_count)

        cache.close()
      end)

      it('should set last_opened_at', function()
        local cache, pages_mod = setup_cache()

        local page = mock_page({ id = 'page-open-time' })
        pages_mod.save_page('page-open-time', page)

        local before = os.time()
        pages_mod.update_open_stats('page-open-time')
        local after = os.time()

        local saved = pages_mod.get_page('page-open-time')
        assert.is_not_nil(saved.last_opened_at)
        assert.is_true(saved.last_opened_at >= before)
        assert.is_true(saved.last_opened_at <= after)

        cache.close()
      end)
    end)

    describe('search with frecency', function()
      it('should order results by frecency score', function()
        local cache, pages_mod = setup_cache()

        -- Create pages with different frecency characteristics
        local page1 = mock_page({ id = 'frecency-1' })
        local page2 = mock_page({ id = 'frecency-2' })
        local page3 = mock_page({ id = 'frecency-3' })

        -- Save all pages (open_count = 0 for all)
        pages_mod.save_page('frecency-1', page1)
        pages_mod.save_page('frecency-2', page2)
        pages_mod.save_page('frecency-3', page3)

        -- Simulate different open patterns:
        -- page1: opened 5 times (highest frequency)
        for _ = 1, 5 do
          pages_mod.update_open_stats('frecency-1')
        end
        -- page2: opened 2 times
        for _ = 1, 2 do
          pages_mod.update_open_stats('frecency-2')
        end
        -- page3: never opened (open_count = 0)

        local results = pages_mod.search('Test', 10)

        -- Should return all 3 pages ordered by frecency
        assert.are.equal(3, #results)
        -- frecency-1 should be first (highest open_count)
        assert.are.equal('frecency-1', results[1].id)
        -- frecency-2 should be second
        assert.are.equal('frecency-2', results[2].id)
        -- frecency-3 should be last (never opened)
        assert.are.equal('frecency-3', results[3].id)

        cache.close()
      end)

      it('should factor in recency (recently opened beats old frequently opened)', function()
        local cache, pages_mod = setup_cache()

        local old_page = mock_page({ id = 'old-frequent' })
        local new_page = mock_page({ id = 'new-recent' })

        pages_mod.save_page('old-frequent', old_page)
        pages_mod.save_page('new-recent', new_page)

        -- old_page: opened 3 times but long ago
        for _ = 1, 3 do
          pages_mod.update_open_stats('old-frequent')
        end

        -- Manually set last_opened_at to 60 days ago for old-frequent
        local db = cache.get_db()
        local sixty_days_ago = os.time() - (60 * 24 * 60 * 60)
        db:execute('UPDATE pages SET last_opened_at = :time WHERE id = :id', {
          time = sixty_days_ago,
          id = 'old-frequent',
        })

        -- new_page: opened just once, but recently
        pages_mod.update_open_stats('new-recent')

        local results = pages_mod.search('', 10)

        -- new-recent should rank higher due to recency bonus
        -- new_page: 1*10 + ~100 (recent) = ~110
        -- old_page: 3*10 + 0 (old, no recency bonus) = 30
        assert.are.equal(2, #results)
        assert.are.equal('new-recent', results[1].id)
        assert.are.equal('old-frequent', results[2].id)

        cache.close()
      end)
    end)

    describe('save_pages_batch', function()
      it('should save multiple pages in one transaction', function()
        local cache, pages_mod = setup_cache()

        -- Use realistic 32-char hex IDs (Notion page IDs without dashes)
        local pages_to_save = {
          mock_page({ id = 'aaaaaaaaaaaa1111111111111111aaaa' }),
          mock_page({ id = 'bbbbbbbbbbbb2222222222222222bbbb' }),
          mock_page({ id = 'cccccccccccc3333333333333333cccc' }),
        }

        local count = pages_mod.save_pages_batch(pages_to_save)

        assert.are.equal(3, count)
        assert.is_true(pages_mod.has_page('aaaaaaaaaaaa1111111111111111aaaa'))
        assert.is_true(pages_mod.has_page('bbbbbbbbbbbb2222222222222222bbbb'))
        assert.is_true(pages_mod.has_page('cccccccccccc3333333333333333cccc'))

        cache.close()
      end)

      it('should not increment open_count on batch save', function()
        local cache, pages_mod = setup_cache()

        local page = mock_page({ id = 'dddddddddddd4444444444444444dddd' })
        pages_mod.save_pages_batch({ page })
        pages_mod.save_pages_batch({ page }) -- Second batch save

        local saved = pages_mod.get_page('dddddddddddd4444444444444444dddd')
        assert.is_not_nil(saved)
        assert.are.equal(0, saved.open_count)

        cache.close()
      end)

      it('should return 0 for empty batch', function()
        local cache, pages_mod = setup_cache()

        local count = pages_mod.save_pages_batch({})
        assert.are.equal(0, count)

        cache.close()
      end)
    end)

    describe('maybe_evict', function()
      it('should not evict when under limit', function()
        local cache, pages_mod = setup_cache()

        -- Save a few pages
        for i = 1, 5 do
          local page = mock_page({ id = string.format('evict-test-%02d', i) })
          pages_mod.save_page(string.format('evict-test-%02d', i), page)
        end

        -- Evict with high limit (should do nothing)
        local evicted = pages_mod.maybe_evict(100)
        assert.are.equal(0, evicted)

        -- All pages should still be there
        for i = 1, 5 do
          assert.is_true(pages_mod.has_page(string.format('evict-test-%02d', i)))
        end

        cache.close()
      end)

      it('should soft-delete lowest frecency pages when over limit', function()
        local cache, pages_mod = setup_cache()

        -- Save 10 pages
        for i = 1, 10 do
          local page = mock_page({ id = string.format('evict-%02d', i) })
          pages_mod.save_page(string.format('evict-%02d', i), page)
        end

        -- Open some pages to give them frecency scores
        -- evict-10 gets highest score (opened 5 times)
        for _ = 1, 5 do
          pages_mod.update_open_stats('evict-10')
        end
        -- evict-09 gets medium score (opened 3 times)
        for _ = 1, 3 do
          pages_mod.update_open_stats('evict-09')
        end

        -- Evict with limit 5 (should remove 5 lowest frecency pages)
        local evicted = pages_mod.maybe_evict(5)
        assert.are.equal(5, evicted)

        -- High frecency pages should remain
        assert.is_true(pages_mod.has_page('evict-10'))
        assert.is_true(pages_mod.has_page('evict-09'))

        -- Check total remaining pages
        local all_results = pages_mod.search('', 100)
        assert.are.equal(5, #all_results)

        cache.close()
      end)
    end)
  end)

  describe('without cache initialized', function()
    before_each(function()
      -- Ensure cache is not initialized
      reset_cache_modules()
    end)

    it('save_page should return false', function()
      local pages = require('neotion.cache.pages')
      local result = pages.save_page('abc123', { properties = { title = { title = {} } } })
      assert.is_false(result)
    end)

    it('save_content should return false', function()
      local pages = require('neotion.cache.pages')
      local result = pages.save_content('abc123', {})
      assert.is_false(result)
    end)

    it('get_page should return nil', function()
      local pages = require('neotion.cache.pages')
      local result = pages.get_page('abc123')
      assert.is_nil(result)
    end)

    it('get_content should return nil', function()
      local pages = require('neotion.cache.pages')
      local result = pages.get_content('abc123')
      assert.is_nil(result)
    end)

    it('has_page should return false', function()
      local pages = require('neotion.cache.pages')
      local result = pages.has_page('abc123')
      assert.is_false(result)
    end)

    it('has_content should return false', function()
      local pages = require('neotion.cache.pages')
      local result = pages.has_content('abc123')
      assert.is_false(result)
    end)

    it('get_recent should return empty table', function()
      local pages = require('neotion.cache.pages')
      local result = pages.get_recent()
      assert.are.same({}, result)
    end)

    it('search should return empty table', function()
      local pages = require('neotion.cache.pages')
      local result = pages.search('test')
      assert.are.same({}, result)
    end)
  end)
end)
