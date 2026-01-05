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
package.loaded['neotion.cache.sync_state'] = nil

local db_module = require('neotion.cache.db')

-- Skip all tests if SQLite is not available
if not db_module.is_sqlite_available() then
  describe('neotion.cache.sync_state', function()
    it('SKIPPED: sqlite.lua not available', function()
      pending('sqlite.lua not installed')
    end)
  end)
  return
end

local cache = require('neotion.cache')
local sync_state = require('neotion.cache.sync_state')

describe('neotion.cache.sync_state', function()
  local test_page_id = 'abc123def456abc123def456abc12345'

  before_each(function()
    -- Reset and initialize cache with in-memory DB
    cache._reset()
    cache.init(':memory:')

    -- Insert a test page first (sync_state has FK to pages)
    local db = cache.get_db()
    db:execute(
      [[
      INSERT INTO pages (id, title, last_edited_time, cached_at)
      VALUES (?, 'Test Page', 1704067200, 1704067200)
    ]],
      { test_page_id }
    )
  end)

  after_each(function()
    cache.close()
  end)

  describe('get_state', function()
    it('should return nil for non-existent page', function()
      local state = sync_state.get_state('nonexistent123456789012345678901')
      assert.is_nil(state)
    end)

    it('should return state after update_after_pull', function()
      sync_state.update_after_pull(test_page_id, 'hash123')

      local state = sync_state.get_state(test_page_id)
      assert.is_not_nil(state)
      assert.are.equal(test_page_id, state.page_id)
      assert.are.equal('hash123', state.remote_hash)
      assert.is_number(state.last_pull_time)
      assert.are.equal('synced', state.sync_status)
    end)

    it('should return state after update_after_push', function()
      sync_state.update_after_push(test_page_id, 'pushhash456')

      local state = sync_state.get_state(test_page_id)
      assert.is_not_nil(state)
      assert.are.equal('pushhash456', state.local_hash)
      assert.is_number(state.last_push_time)
      assert.are.equal('synced', state.sync_status)
    end)
  end)

  describe('update_after_pull', function()
    it('should create new state if not exists', function()
      local ok = sync_state.update_after_pull(test_page_id, 'newhash')
      assert.is_true(ok)

      local state = sync_state.get_state(test_page_id)
      assert.are.equal('newhash', state.remote_hash)
    end)

    it('should update existing state', function()
      sync_state.update_after_pull(test_page_id, 'hash1')
      sync_state.update_after_pull(test_page_id, 'hash2')

      local state = sync_state.get_state(test_page_id)
      assert.are.equal('hash2', state.remote_hash)
    end)

    it('should set sync_status to synced', function()
      sync_state.update_after_pull(test_page_id, 'hash')

      local state = sync_state.get_state(test_page_id)
      assert.are.equal('synced', state.sync_status)
    end)

    it('should update last_pull_time to current timestamp', function()
      local before = os.time()
      sync_state.update_after_pull(test_page_id, 'hash')
      local after = os.time()

      local state = sync_state.get_state(test_page_id)
      assert.is_true(state.last_pull_time >= before)
      assert.is_true(state.last_pull_time <= after)
    end)
  end)

  describe('update_after_push', function()
    it('should create new state if not exists', function()
      local ok = sync_state.update_after_push(test_page_id, 'pushhash')
      assert.is_true(ok)

      local state = sync_state.get_state(test_page_id)
      assert.are.equal('pushhash', state.local_hash)
    end)

    it('should update existing state', function()
      sync_state.update_after_push(test_page_id, 'hash1')
      sync_state.update_after_push(test_page_id, 'hash2')

      local state = sync_state.get_state(test_page_id)
      assert.are.equal('hash2', state.local_hash)
    end)

    it('should set sync_status to synced', function()
      sync_state.update_after_push(test_page_id, 'hash')

      local state = sync_state.get_state(test_page_id)
      assert.are.equal('synced', state.sync_status)
    end)

    it('should update last_push_time to current timestamp', function()
      local before = os.time()
      sync_state.update_after_push(test_page_id, 'hash')
      local after = os.time()

      local state = sync_state.get_state(test_page_id)
      assert.is_true(state.last_push_time >= before)
      assert.is_true(state.last_push_time <= after)
    end)

    it('should also set remote_hash to match local after push', function()
      sync_state.update_after_push(test_page_id, 'syncedhash')

      local state = sync_state.get_state(test_page_id)
      assert.are.equal('syncedhash', state.local_hash)
      assert.are.equal('syncedhash', state.remote_hash)
    end)
  end)

  describe('has_changed', function()
    it('should return true if no state exists', function()
      local changed = sync_state.has_changed(test_page_id, 'anyhash')
      assert.is_true(changed)
    end)

    it('should return false if hash matches remote_hash', function()
      sync_state.update_after_pull(test_page_id, 'samehash')

      local changed = sync_state.has_changed(test_page_id, 'samehash')
      assert.is_false(changed)
    end)

    it('should return true if hash differs from remote_hash', function()
      sync_state.update_after_pull(test_page_id, 'oldhash')

      local changed = sync_state.has_changed(test_page_id, 'newhash')
      assert.is_true(changed)
    end)

    it('should return false if hash matches local_hash', function()
      sync_state.update_after_push(test_page_id, 'localhash')

      local changed = sync_state.has_changed(test_page_id, 'localhash')
      assert.is_false(changed)
    end)
  end)

  describe('mark_modified', function()
    it('should set sync_status to modified', function()
      sync_state.update_after_pull(test_page_id, 'hash')
      sync_state.mark_modified(test_page_id, 'newhash')

      local state = sync_state.get_state(test_page_id)
      assert.are.equal('modified', state.sync_status)
      assert.are.equal('newhash', state.local_hash)
    end)

    it('should create state if not exists', function()
      sync_state.mark_modified(test_page_id, 'modifiedhash')

      local state = sync_state.get_state(test_page_id)
      assert.is_not_nil(state)
      assert.are.equal('modified', state.sync_status)
    end)

    it('should return false if page not in cache', function()
      -- page_id that doesn't exist in pages table
      local non_existent_page = 'ffffffffffffffffffffffffffffffff'
      local result = sync_state.mark_modified(non_existent_page, 'hash')
      assert.is_false(result)
    end)
  end)

  describe('delete_state', function()
    it('should remove state for page', function()
      sync_state.update_after_pull(test_page_id, 'hash')
      assert.is_not_nil(sync_state.get_state(test_page_id))

      sync_state.delete_state(test_page_id)
      assert.is_nil(sync_state.get_state(test_page_id))
    end)

    it('should return true even if state did not exist', function()
      local ok = sync_state.delete_state('nonexistent12345678901234567890123')
      assert.is_true(ok)
    end)
  end)

  describe('get_all_states', function()
    it('should return empty table if no states', function()
      local states = sync_state.get_all_states()
      assert.are.same({}, states)
    end)

    it('should return all states', function()
      -- Insert another page
      local db = cache.get_db()
      local page2 = 'def456abc123def456abc123def45678'
      db:execute(
        [[
        INSERT INTO pages (id, title, last_edited_time, cached_at)
        VALUES (?, 'Page 2', 1704067200, 1704067200)
      ]],
        { page2 }
      )

      sync_state.update_after_pull(test_page_id, 'hash1')
      sync_state.update_after_pull(page2, 'hash2')

      local states = sync_state.get_all_states()
      assert.are.equal(2, #states)
    end)
  end)
end)
