---@diagnostic disable: undefined-field
local schema = require('neotion.cache.schema')

describe('neotion.cache.schema', function()
  describe('VERSION', function()
    it('should be a positive integer', function()
      assert.is_number(schema.VERSION)
      assert.is_true(schema.VERSION >= 1)
      assert.are.equal(math.floor(schema.VERSION), schema.VERSION)
    end)
  end)

  describe('TABLES', function()
    it('should contain schema_version table', function()
      assert.is_not_nil(schema.TABLES.schema_version)
      assert.is_string(schema.TABLES.schema_version)
      assert.matches('CREATE TABLE', schema.TABLES.schema_version)
    end)

    it('should contain pages table', function()
      assert.is_not_nil(schema.TABLES.pages)
      assert.is_string(schema.TABLES.pages)
      assert.matches('CREATE TABLE', schema.TABLES.pages)
      assert.matches('id TEXT PRIMARY KEY', schema.TABLES.pages)
      assert.matches('title TEXT', schema.TABLES.pages)
      assert.matches('cached_at INTEGER', schema.TABLES.pages)
    end)

    it('should contain page_content table', function()
      assert.is_not_nil(schema.TABLES.page_content)
      assert.is_string(schema.TABLES.page_content)
      assert.matches('CREATE TABLE', schema.TABLES.page_content)
      assert.matches('page_id TEXT PRIMARY KEY', schema.TABLES.page_content)
      assert.matches('blocks_json TEXT', schema.TABLES.page_content)
      assert.matches('content_hash TEXT', schema.TABLES.page_content)
    end)

    it('should contain block_hashes table', function()
      assert.is_not_nil(schema.TABLES.block_hashes)
      assert.is_string(schema.TABLES.block_hashes)
      assert.matches('CREATE TABLE', schema.TABLES.block_hashes)
      assert.matches('block_id TEXT PRIMARY KEY', schema.TABLES.block_hashes)
      assert.matches('page_id TEXT', schema.TABLES.block_hashes)
    end)

    it('should contain sync_state table', function()
      assert.is_not_nil(schema.TABLES.sync_state)
      assert.is_string(schema.TABLES.sync_state)
      assert.matches('CREATE TABLE', schema.TABLES.sync_state)
      assert.matches('page_id TEXT PRIMARY KEY', schema.TABLES.sync_state)
      assert.matches('local_hash TEXT', schema.TABLES.sync_state)
      assert.matches('remote_hash TEXT', schema.TABLES.sync_state)
    end)

    it('should contain sync_queue table', function()
      assert.is_not_nil(schema.TABLES.sync_queue)
      assert.is_string(schema.TABLES.sync_queue)
      assert.matches('CREATE TABLE', schema.TABLES.sync_queue)
      assert.matches('operation TEXT', schema.TABLES.sync_queue)
      assert.matches('payload TEXT', schema.TABLES.sync_queue)
    end)
  end)

  describe('INDEXES', function()
    it('should be a table of index definitions', function()
      assert.is_table(schema.INDEXES)
      assert.is_true(#schema.INDEXES > 0)
    end)

    it('should contain valid CREATE INDEX statements', function()
      for _, idx in ipairs(schema.INDEXES) do
        assert.is_string(idx)
        assert.matches('CREATE INDEX', idx)
      end
    end)

    it('should have index on pages.title', function()
      local found = false
      for _, idx in ipairs(schema.INDEXES) do
        if idx:match('pages') and idx:match('title') then
          found = true
          break
        end
      end
      assert.is_true(found, 'Should have index on pages.title')
    end)

    it('should have index on pages frecency', function()
      local found = false
      for _, idx in ipairs(schema.INDEXES) do
        if idx:match('frecency') then
          found = true
          break
        end
      end
      assert.is_true(found, 'Should have index for frecency')
    end)

    it('should have index on block_hashes.page_id', function()
      local found = false
      for _, idx in ipairs(schema.INDEXES) do
        if idx:match('block_hashes') and idx:match('page_id') then
          found = true
          break
        end
      end
      assert.is_true(found, 'Should have index on block_hashes.page_id')
    end)

    it('should have index on sync_queue priority', function()
      local found = false
      for _, idx in ipairs(schema.INDEXES) do
        if idx:match('sync_queue') and idx:match('priority') then
          found = true
          break
        end
      end
      assert.is_true(found, 'Should have index on sync_queue priority')
    end)
  end)

  describe('get_all_statements', function()
    it('should return table creation statements in order', function()
      local stmts = schema.get_all_statements()
      assert.is_table(stmts)
      assert.is_true(#stmts > 0)
    end)

    it('should include all tables and indexes', function()
      local stmts = schema.get_all_statements()
      -- 6 tables + indexes
      assert.is_true(#stmts >= 6)
    end)

    it('should have schema_version as first table', function()
      local stmts = schema.get_all_statements()
      assert.matches('schema_version', stmts[1])
    end)
  end)

  describe('get_migration', function()
    it('should return nil for version 0', function()
      local migration = schema.get_migration(0)
      assert.is_nil(migration)
    end)

    it('should return nil for future versions', function()
      local migration = schema.get_migration(999)
      assert.is_nil(migration)
    end)

    it('should return migration for version 1 if exists', function()
      -- Version 1 is initial schema, may not need migration
      local migration = schema.get_migration(1)
      -- Can be nil (initial) or table (migration statements)
      if migration then
        assert.is_table(migration)
      end
    end)
  end)
end)
