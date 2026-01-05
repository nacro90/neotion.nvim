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
package.loaded['neotion.cache.query_cache'] = nil

local db_module = require('neotion.cache.db')

-- Skip all tests if SQLite is not available
if not db_module.is_sqlite_available() then
  describe('cache.query_cache', function()
    it('SKIPPED: sqlite.lua not available', function()
      pending('sqlite.lua not installed')
    end)
  end)
  return
end

-- Helper: reset neotion cache modules
local function reset_cache_modules()
  package.loaded['neotion.cache'] = nil
  package.loaded['neotion.cache.db'] = nil
  package.loaded['neotion.cache.pages'] = nil
  package.loaded['neotion.cache.schema'] = nil
  package.loaded['neotion.cache.query_cache'] = nil
end

-- Helper: setup fresh cache for each test
local function setup_cache()
  reset_cache_modules()
  local cache = require('neotion.cache')
  cache.init(':memory:')
  local query_cache_mod = require('neotion.cache.query_cache')
  return cache, query_cache_mod
end

describe('cache.query_cache', function()
  local cache, query_cache

  before_each(function()
    cache, query_cache = setup_cache()
  end)

  after_each(function()
    if cache then
      cache.close()
    end
  end)

  describe('normalize_query', function()
    it('should lowercase query', function()
      assert.are.equal('test', query_cache.normalize_query('TEST'))
      assert.are.equal('test', query_cache.normalize_query('Test'))
      assert.are.equal('test', query_cache.normalize_query('TeSt'))
    end)

    it('should trim whitespace', function()
      assert.are.equal('test', query_cache.normalize_query('  test  '))
      assert.are.equal('test', query_cache.normalize_query('\ttest\n'))
    end)

    it('should handle empty string', function()
      assert.are.equal('', query_cache.normalize_query(''))
      assert.are.equal('', query_cache.normalize_query('   '))
    end)

    it('should handle nil', function()
      assert.are.equal('', query_cache.normalize_query(nil))
    end)

    it('should preserve internal spaces', function()
      assert.are.equal('hello world', query_cache.normalize_query('  Hello World  '))
    end)
  end)

  describe('set', function()
    it('should store query with page_ids', function()
      local page_ids = { 'id1', 'id2', 'id3' }
      local ok = query_cache.set('test', page_ids)
      assert.is_true(ok)
    end)

    it('should normalize query before storing', function()
      query_cache.set('  TEST  ', { 'id1' })
      local result = query_cache.get('test')
      assert.is_not_nil(result)
      assert.are.same({ 'id1' }, result.page_ids)
    end)

    it('should store empty page_ids', function()
      local ok = query_cache.set('empty', {})
      assert.is_true(ok)
      local result = query_cache.get('empty')
      assert.are.same({}, result.page_ids)
    end)

    it('should update existing query', function()
      query_cache.set('test', { 'id1', 'id2' })
      query_cache.set('test', { 'id3', 'id4', 'id5' })
      local result = query_cache.get('test')
      assert.are.same({ 'id3', 'id4', 'id5' }, result.page_ids)
    end)

    it('should preserve page order (Notion relevance)', function()
      -- Notion returns pages in relevance order, we must preserve it
      local page_ids = { 'most_relevant', 'second', 'third', 'least_relevant' }
      query_cache.set('test', page_ids)
      local result = query_cache.get('test')
      assert.are.same(page_ids, result.page_ids)
    end)
  end)

  describe('get', function()
    it('should return nil for unknown query', function()
      local result = query_cache.get('unknown')
      assert.is_nil(result)
    end)

    it('should return cached result with metadata', function()
      query_cache.set('test', { 'id1', 'id2' })
      local result = query_cache.get('test')

      assert.is_not_nil(result)
      assert.are.same({ 'id1', 'id2' }, result.page_ids)
      assert.is_number(result.cached_at)
      assert.is_number(result.result_count)
      assert.are.equal(2, result.result_count)
    end)

    it('should normalize query before lookup', function()
      query_cache.set('hello', { 'id1' })
      local result = query_cache.get('  HELLO  ')
      assert.is_not_nil(result)
    end)

    it('should return nil for empty query', function()
      -- Empty query should use frecency, not query cache
      query_cache.set('', { 'id1' })
      local result = query_cache.get('')
      -- We don't cache empty queries - use frecency instead
      assert.is_nil(result)
    end)
  end)

  describe('get_with_prefix_fallback', function()
    before_each(function()
      -- Setup test data
      query_cache.set('t', { 'id_t1', 'id_t2', 'id_t3' })
      query_cache.set('te', { 'id_te1', 'id_te2' })
      query_cache.set('test', { 'id_test1' })
    end)

    it('should return exact match if available', function()
      local result = query_cache.get_with_prefix_fallback('test')
      assert.is_not_nil(result)
      assert.are.same({ 'id_test1' }, result.page_ids)
      assert.is_false(result.is_fallback)
    end)

    it('should fallback to shorter prefix on miss', function()
      local result = query_cache.get_with_prefix_fallback('testing')
      assert.is_not_nil(result)
      assert.are.same({ 'id_test1' }, result.page_ids)
      assert.is_true(result.is_fallback)
      assert.are.equal('test', result.matched_query)
    end)

    it('should try progressively shorter prefixes', function()
      local result = query_cache.get_with_prefix_fallback('tex')
      assert.is_not_nil(result)
      assert.are.same({ 'id_te1', 'id_te2' }, result.page_ids)
      assert.is_true(result.is_fallback)
      assert.are.equal('te', result.matched_query)
    end)

    it('should return nil if no prefix matches', function()
      local result = query_cache.get_with_prefix_fallback('xyz')
      assert.is_nil(result)
    end)

    it('should handle single character query', function()
      local result = query_cache.get_with_prefix_fallback('t')
      assert.is_not_nil(result)
      assert.are.same({ 'id_t1', 'id_t2', 'id_t3' }, result.page_ids)
      assert.is_false(result.is_fallback)
    end)

    it('should return nil for empty query', function()
      local result = query_cache.get_with_prefix_fallback('')
      assert.is_nil(result)
    end)
  end)

  describe('delete', function()
    it('should delete cached query', function()
      query_cache.set('test', { 'id1' })
      query_cache.delete('test')
      assert.is_nil(query_cache.get('test'))
    end)

    it('should normalize query before deleting', function()
      query_cache.set('test', { 'id1' })
      query_cache.delete('  TEST  ')
      assert.is_nil(query_cache.get('test'))
    end)

    it('should not error on non-existent query', function()
      assert.has_no.errors(function()
        query_cache.delete('nonexistent')
      end)
    end)
  end)

  describe('clear', function()
    it('should remove all cached queries', function()
      query_cache.set('q1', { 'id1' })
      query_cache.set('q2', { 'id2' })
      query_cache.set('q3', { 'id3' })

      query_cache.clear()

      assert.is_nil(query_cache.get('q1'))
      assert.is_nil(query_cache.get('q2'))
      assert.is_nil(query_cache.get('q3'))
    end)
  end)

  describe('count', function()
    it('should return 0 for empty cache', function()
      assert.are.equal(0, query_cache.count())
    end)

    it('should return correct count', function()
      query_cache.set('q1', { 'id1' })
      query_cache.set('q2', { 'id2' })
      query_cache.set('q3', { 'id3' })
      assert.are.equal(3, query_cache.count())
    end)
  end)

  describe('evict', function()
    it('should evict oldest entries when limit exceeded', function()
      -- Set a low limit for testing
      local limit = 3

      -- Add entries with increasing timestamps
      query_cache.set('old1', { 'id1' })
      query_cache.set('old2', { 'id2' })
      query_cache.set('old3', { 'id3' })

      -- Should have 3 entries
      assert.are.equal(3, query_cache.count())

      -- Evict to limit of 2
      query_cache.evict(2)
      assert.are.equal(2, query_cache.count())

      -- Oldest entry should be gone (old1)
      assert.is_nil(query_cache.get('old1'))
      -- Newer entries should remain
      assert.is_not_nil(query_cache.get('old2'))
      assert.is_not_nil(query_cache.get('old3'))
    end)

    it('should not evict if under limit', function()
      query_cache.set('q1', { 'id1' })
      query_cache.set('q2', { 'id2' })

      query_cache.evict(10)
      assert.are.equal(2, query_cache.count())
    end)
  end)

  describe('get_stats', function()
    it('should return cache statistics', function()
      query_cache.set('q1', { 'id1', 'id2' })
      query_cache.set('q2', { 'id3' })

      local stats = query_cache.get_stats()

      assert.are.equal(2, stats.query_count)
      assert.are.equal(3, stats.total_page_ids)
      assert.is_number(stats.oldest_cached_at)
      assert.is_number(stats.newest_cached_at)
    end)

    it('should return zeros for empty cache', function()
      local stats = query_cache.get_stats()

      assert.are.equal(0, stats.query_count)
      assert.are.equal(0, stats.total_page_ids)
    end)
  end)

  describe('integration with pages table', function()
    it('should work with page metadata lookup', function()
      -- First, setup a page in the pages table using Notion API format
      local pages_cache = require('neotion.cache.pages')
      local notion_page = {
        id = 'page123',
        properties = {
          Name = {
            type = 'title',
            title = { { plain_text = 'Test Page' } },
          },
        },
        parent = { type = 'workspace' },
        icon = { type = 'emoji', emoji = '📄' },
        last_edited_time = '2024-01-01T00:00:00.000Z',
        created_time = '2024-01-01T00:00:00.000Z',
      }
      pages_cache.save_page('page123', notion_page)

      -- Cache a query result
      query_cache.set('test', { 'page123' })

      -- Get the cached query
      local result = query_cache.get('test')
      assert.is_not_nil(result)
      assert.are.same({ 'page123' }, result.page_ids)

      -- The page_ids should be usable to lookup actual page data
      local page = pages_cache.get_page('page123')
      assert.is_not_nil(page)
      assert.are.equal('Test Page', page.title)
    end)
  end)
end)
