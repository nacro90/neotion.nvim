--- Unit tests for neotion.sync module
--- Phase 10: Block creation tests

describe('neotion.sync', function()
  local sync
  local mock_blocks_api
  local mock_buffer
  local mock_model

  -- Helper to create mock block
  local function create_mock_block(opts)
    opts = opts or {}
    return {
      id = opts.id or nil,
      temp_id = opts.temp_id or 'temp_123',
      is_new = opts.is_new ~= false,
      after_block_id = opts.after_block_id,
      type = opts.type or 'paragraph',
      text = opts.text or 'Test content',
      raw = { type = opts.type or 'paragraph', id = opts.id },
      get_id = function(self)
        return self.id
      end,
      get_type = function(self)
        return self.type
      end,
      get_text = function(self)
        return self.text
      end,
      is_dirty = function()
        return false
      end,
      set_dirty = function() end,
      type_changed = function()
        return false
      end,
      serialize = function(self)
        return {
          type = self.type,
          [self.type] = {
            rich_text = {
              { type = 'text', text = { content = self.text } },
            },
          },
        }
      end,
    }
  end

  -- Helper to create mock plan
  local function create_mock_plan(opts)
    opts = opts or {}
    return {
      updates = opts.updates or {},
      creates = opts.creates or {},
      deletes = opts.deletes or {},
      type_changes = opts.type_changes or {},
      unmatched = {},
      has_changes = opts.has_changes ~= false,
      needs_confirmation = false,
    }
  end

  before_each(function()
    -- Clear module caches
    package.loaded['neotion.sync'] = nil
    package.loaded['neotion.api.blocks'] = nil
    package.loaded['neotion.buffer'] = nil
    package.loaded['neotion.model'] = nil

    -- Create mock blocks API
    mock_blocks_api = {
      append_calls = {},
      append_result = { error = nil, blocks = {} },
      append = function(parent_id, children, callback, after_block_id)
        table.insert(mock_blocks_api.append_calls, {
          parent_id = parent_id,
          children = children,
          after_block_id = after_block_id,
        })
        vim.schedule(function()
          callback(mock_blocks_api.append_result)
        end)
      end,
      update = function(block_id, block_data, callback)
        vim.schedule(function()
          callback({ error = nil, block = block_data })
        end)
      end,
      delete = function(block_id, callback)
        vim.schedule(function()
          callback({ error = nil })
        end)
      end,
    }

    -- Create mock buffer module
    mock_buffer = {
      status = 'ready',
      data = { page_id = 'test-page-id-00000000000000000' },
      is_neotion_buffer = function()
        return true
      end,
      get_data = function()
        return mock_buffer.data
      end,
      set_status = function(_, status)
        mock_buffer.status = status
      end,
      get_status = function()
        return mock_buffer.status
      end,
      update_data = function() end,
    }

    -- Create mock model module
    mock_model = {
      mark_all_clean = function() end,
      serialize_block = function(block)
        return block:serialize()
      end,
    }

    -- Install mocks
    package.loaded['neotion.api.blocks'] = mock_blocks_api
    package.loaded['neotion.buffer'] = mock_buffer
    package.loaded['neotion.model'] = mock_model

    sync = require('neotion.sync')
  end)

  describe('execute creates', function()
    it('should call blocks_api.append for new blocks', function()
      local block = create_mock_block({
        temp_id = 'temp_456',
        text = 'New paragraph',
      })

      local plan = create_mock_plan({
        creates = {
          {
            block = block,
            content = 'New paragraph',
            block_type = 'paragraph',
            after_block_id = nil,
            temp_id = 'temp_456',
          },
        },
      })

      -- Set up successful API response
      mock_blocks_api.append_result = {
        error = nil,
        blocks = {
          { id = 'notion-new-block-id-000000000000' },
        },
      }

      local completed = false
      local success = false

      sync.execute(1, plan, function(ok, errors)
        completed = true
        success = ok
      end)

      -- Wait for async completion
      vim.wait(1000, function()
        return completed
      end)

      assert.is_true(completed, 'Callback should be called')
      assert.is_true(success, 'Should succeed')
      assert.are.equal(1, #mock_blocks_api.append_calls, 'Should call append once')

      local call = mock_blocks_api.append_calls[1]
      assert.are.equal('test-page-id-00000000000000000', call.parent_id)
      assert.are.equal(1, #call.children)
    end)

    it('should update block ID from API response', function()
      local block = create_mock_block({
        temp_id = 'temp_789',
        text = 'Content',
      })

      local plan = create_mock_plan({
        creates = {
          {
            block = block,
            content = 'Content',
            block_type = 'paragraph',
            after_block_id = nil,
            temp_id = 'temp_789',
          },
        },
      })

      -- Set up successful API response with new ID
      mock_blocks_api.append_result = {
        error = nil,
        blocks = {
          { id = 'new-notion-id-from-api-00000000' },
        },
      }

      local completed = false

      sync.execute(1, plan, function()
        completed = true
      end)

      vim.wait(1000, function()
        return completed
      end)

      assert.are.equal('new-notion-id-from-api-00000000', block.id, 'Block ID should be updated')
      assert.are.equal('new-notion-id-from-api-00000000', block.raw.id, 'Raw ID should be updated')
      assert.is_false(block.is_new, 'is_new should be false')
      assert.is_nil(block.temp_id, 'temp_id should be cleared')
    end)

    it('should pass after_block_id to append', function()
      local block = create_mock_block({
        temp_id = 'temp_after',
        after_block_id = 'previous-block-id-0000000000000',
      })

      local plan = create_mock_plan({
        creates = {
          {
            block = block,
            content = 'After content',
            block_type = 'paragraph',
            after_block_id = 'previous-block-id-0000000000000',
            temp_id = 'temp_after',
          },
        },
      })

      mock_blocks_api.append_result = {
        error = nil,
        blocks = { { id = 'new-id-0000000000000000000000000' } },
      }

      local completed = false

      sync.execute(1, plan, function()
        completed = true
      end)

      vim.wait(1000, function()
        return completed
      end)

      local call = mock_blocks_api.append_calls[1]
      assert.are.equal('previous-block-id-0000000000000', call.after_block_id)
    end)

    it('should handle API failure gracefully', function()
      local block = create_mock_block({ temp_id = 'temp_fail' })

      local plan = create_mock_plan({
        creates = {
          {
            block = block,
            content = 'Will fail',
            block_type = 'paragraph',
            after_block_id = nil,
            temp_id = 'temp_fail',
          },
        },
      })

      -- Set up failure response
      mock_blocks_api.append_result = {
        error = 'API rate limit exceeded',
        blocks = {},
      }

      local completed = false
      local success = false
      local returned_errors = {}

      sync.execute(1, plan, function(ok, errors)
        completed = true
        success = ok
        returned_errors = errors
      end)

      vim.wait(1000, function()
        return completed
      end)

      assert.is_false(success, 'Should fail')
      assert.is_true(#returned_errors > 0, 'Should have errors')
      assert.is_truthy(returned_errors[1]:match('Create failed'), 'Error should mention create failure')

      -- Block should retain its temp state
      assert.is_true(block.is_new, 'is_new should remain true on failure')
      assert.are.equal('temp_fail', block.temp_id, 'temp_id should remain on failure')
    end)

    it('should create multiple blocks', function()
      local block1 = create_mock_block({ temp_id = 'temp_1', text = 'First' })
      local block2 = create_mock_block({ temp_id = 'temp_2', text = 'Second' })

      local plan = create_mock_plan({
        creates = {
          { block = block1, content = 'First', block_type = 'paragraph', temp_id = 'temp_1' },
          { block = block2, content = 'Second', block_type = 'paragraph', temp_id = 'temp_2' },
        },
      })

      local call_count = 0
      mock_blocks_api.append = function(parent_id, children, callback, after_block_id)
        call_count = call_count + 1
        local new_id = 'new-id-' .. call_count .. '-0000000000000000000'
        vim.schedule(function()
          callback({ error = nil, blocks = { { id = new_id } } })
        end)
      end

      local completed = false
      local success = false

      sync.execute(1, plan, function(ok)
        completed = true
        success = ok
      end)

      vim.wait(1000, function()
        return completed
      end)

      assert.is_true(success, 'Should succeed')
      assert.are.equal(2, call_count, 'Should call append twice')
    end)

    it('should handle divider block creation', function()
      local block = create_mock_block({
        temp_id = 'temp_divider',
        type = 'divider',
        text = '',
      })
      block.serialize = function()
        return { type = 'divider', divider = {} }
      end

      local plan = create_mock_plan({
        creates = {
          {
            block = block,
            content = '',
            block_type = 'divider',
            temp_id = 'temp_divider',
          },
        },
      })

      mock_blocks_api.append_result = {
        error = nil,
        blocks = { { id = 'divider-id-000000000000000000000' } },
      }

      local completed = false

      sync.execute(1, plan, function()
        completed = true
      end)

      vim.wait(1000, function()
        return completed
      end)

      local call = mock_blocks_api.append_calls[1]
      assert.are.equal('divider', call.children[1].type)
    end)
  end)

  describe('execute creates edge cases', function()
    it('should fail gracefully when page_id is missing', function()
      -- Clear page_id from mock buffer
      mock_buffer.data = { page_id = nil }

      local block = create_mock_block({ temp_id = 'temp_no_page' })

      local plan = create_mock_plan({
        creates = {
          {
            block = block,
            content = 'Content',
            block_type = 'paragraph',
            temp_id = 'temp_no_page',
          },
        },
      })

      local completed = false
      local success = false
      local returned_errors = {}

      sync.execute(1, plan, function(ok, errors)
        completed = true
        success = ok
        returned_errors = errors
      end)

      vim.wait(1000, function()
        return completed
      end)

      assert.is_false(success, 'Should fail when page_id is missing')
      assert.is_true(#returned_errors > 0, 'Should have errors')
      assert.is_truthy(returned_errors[1]:match('page_id'), 'Error should mention page_id')

      -- Block should retain its new state
      assert.is_true(block.is_new, 'is_new should remain true')
    end)
  end)

  describe('execute with mixed operations', function()
    it('should handle creates alongside updates', function()
      local existing_block = create_mock_block({
        id = 'existing-block-id-000000000000000',
        is_new = false,
        temp_id = nil,
        text = 'Updated text',
      })

      local new_block = create_mock_block({
        temp_id = 'temp_new',
        text = 'New block',
      })

      local plan = create_mock_plan({
        updates = {
          {
            block = existing_block,
            block_id = 'existing-block-id-000000000000000',
            content = 'Updated text',
          },
        },
        creates = {
          {
            block = new_block,
            content = 'New block',
            block_type = 'paragraph',
            temp_id = 'temp_new',
          },
        },
      })

      mock_blocks_api.append_result = {
        error = nil,
        blocks = { { id = 'created-block-id-00000000000000' } },
      }

      local completed = false
      local success = false

      sync.execute(1, plan, function(ok)
        completed = true
        success = ok
      end)

      vim.wait(1000, function()
        return completed
      end)

      assert.is_true(success, 'Should succeed with mixed operations')
    end)
  end)
end)
