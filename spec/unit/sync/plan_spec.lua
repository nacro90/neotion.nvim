describe('neotion.sync.plan', function()
  local plan_module

  before_each(function()
    -- Clear module cache
    package.loaded['neotion.sync.plan'] = nil
    package.loaded['neotion.model'] = nil
    package.loaded['neotion.model.mapping'] = nil
    plan_module = require('neotion.sync.plan')
  end)

  -- Helper to create mock block
  local function create_mock_block(id, block_type, text, dirty, type_changed)
    return {
      id = id,
      type = block_type,
      text = text or '',
      dirty = dirty or false,
      _type_changed = type_changed or false,
      raw = { type = block_type },
      get_id = function(self)
        return self.id
      end,
      get_type = function(self)
        return self.type
      end,
      get_text = function(self)
        return self.text
      end,
      is_dirty = function(self)
        return self.dirty
      end,
      set_dirty = function(self, value)
        self.dirty = value
      end,
      type_changed = function(self)
        return self._type_changed
      end,
    }
  end

  describe('get_summary', function()
    it('should return "No changes" for empty plan', function()
      local plan = {
        updates = {},
        creates = {},
        deletes = {},
        type_changes = {},
        unmatched = {},
        has_changes = false,
        needs_confirmation = false,
      }

      local summary = plan_module.get_summary(plan)

      assert.are.equal(1, #summary)
      assert.is_truthy(summary[1]:match('No changes'))
    end)

    it('should list update count', function()
      local plan = {
        updates = {
          { block = create_mock_block('b1', 'paragraph', 'Text 1'), block_id = 'b1', content = 'Text 1' },
          { block = create_mock_block('b2', 'paragraph', 'Text 2'), block_id = 'b2', content = 'Text 2' },
        },
        creates = {},
        deletes = {},
        type_changes = {},
        unmatched = {},
        has_changes = true,
        needs_confirmation = false,
      }

      local summary = plan_module.get_summary(plan)

      local found_updates = false
      for _, line in ipairs(summary) do
        if line:match('Updates: 2') then
          found_updates = true
        end
      end
      assert.is_true(found_updates)
    end)

    it('should list create count', function()
      local plan = {
        updates = {},
        creates = {
          { content = 'New block', block_type = 'paragraph', after_block_id = nil },
        },
        deletes = {},
        type_changes = {},
        unmatched = {},
        has_changes = true,
        needs_confirmation = false,
      }

      local summary = plan_module.get_summary(plan)

      local found_creates = false
      for _, line in ipairs(summary) do
        if line:match('Creates: 1') then
          found_creates = true
        end
      end
      assert.is_true(found_creates)
    end)

    it('should list delete count', function()
      local plan = {
        updates = {},
        creates = {},
        deletes = {
          { block_id = 'b1', original_content = 'Deleted text' },
        },
        type_changes = {},
        unmatched = {},
        has_changes = true,
        needs_confirmation = true,
      }

      local summary = plan_module.get_summary(plan)

      local found_deletes = false
      for _, line in ipairs(summary) do
        if line:match('Deletes: 1') then
          found_deletes = true
        end
      end
      assert.is_true(found_deletes)
    end)

    it('should list type change count', function()
      local plan = {
        updates = {},
        creates = {},
        deletes = {},
        type_changes = {
          {
            block = create_mock_block('b1', 'heading_2', 'Title'),
            block_id = 'b1',
            old_type = 'heading_1',
            new_type = 'heading_2',
            content = 'Title',
          },
        },
        unmatched = {},
        has_changes = true,
        needs_confirmation = false,
      }

      local summary = plan_module.get_summary(plan)

      local found_type_changes = false
      for _, line in ipairs(summary) do
        if line:match('Type changes: 1') then
          found_type_changes = true
        end
      end
      assert.is_true(found_type_changes)
    end)

    it('should note unmatched regions', function()
      local plan = {
        updates = {},
        creates = {},
        deletes = {},
        type_changes = {},
        unmatched = {
          { content = 'Unknown content', line_start = 5, line_end = 7, possible_matches = {} },
        },
        has_changes = false,
        needs_confirmation = true,
      }

      local summary = plan_module.get_summary(plan)

      local found_unmatched = false
      for _, line in ipairs(summary) do
        if line:match('Unmatched: 1') then
          found_unmatched = true
        end
      end
      assert.is_true(found_unmatched)
    end)

    it('should truncate long content in preview', function()
      local long_text = string.rep('a', 100)
      local plan = {
        updates = {
          { block = create_mock_block('b1', 'paragraph', long_text), block_id = 'b1', content = long_text },
        },
        creates = {},
        deletes = {},
        type_changes = {},
        unmatched = {},
        has_changes = true,
        needs_confirmation = false,
      }

      local summary = plan_module.get_summary(plan)

      -- Find the preview line
      for _, line in ipairs(summary) do
        if line:match('%[paragraph%]') then
          -- Should be truncated with ...
          assert.is_truthy(line:match('%.%.%.$') or #line < 60)
        end
      end
    end)
  end)

  describe('is_empty', function()
    it('should return true for empty plan', function()
      local plan = {
        updates = {},
        creates = {},
        deletes = {},
        type_changes = {},
        unmatched = {},
        has_changes = false,
        needs_confirmation = false,
      }

      assert.is_true(plan_module.is_empty(plan))
    end)

    it('should return false when has updates', function()
      local plan = {
        updates = { { block_id = 'b1' } },
        creates = {},
        deletes = {},
        type_changes = {},
        unmatched = {},
        has_changes = true,
        needs_confirmation = false,
      }

      assert.is_false(plan_module.is_empty(plan))
    end)

    it('should return false when has creates', function()
      local plan = {
        updates = {},
        creates = { { content = 'new' } },
        deletes = {},
        type_changes = {},
        unmatched = {},
        has_changes = true,
        needs_confirmation = false,
      }

      assert.is_false(plan_module.is_empty(plan))
    end)

    it('should return false when has deletes', function()
      local plan = {
        updates = {},
        creates = {},
        deletes = { { block_id = 'b1' } },
        type_changes = {},
        unmatched = {},
        has_changes = true,
        needs_confirmation = true,
      }

      assert.is_false(plan_module.is_empty(plan))
    end)

    it('should return false when has type_changes', function()
      local plan = {
        updates = {},
        creates = {},
        deletes = {},
        type_changes = { { block_id = 'b1' } },
        unmatched = {},
        has_changes = true,
        needs_confirmation = false,
      }

      assert.is_false(plan_module.is_empty(plan))
    end)
  end)

  describe('get_operation_count', function()
    it('should return 0 for empty plan', function()
      local plan = {
        updates = {},
        creates = {},
        deletes = {},
        type_changes = {},
        unmatched = {},
        has_changes = false,
        needs_confirmation = false,
      }

      assert.are.equal(0, plan_module.get_operation_count(plan))
    end)

    it('should count all operations', function()
      local plan = {
        updates = { {}, {} },
        creates = { {} },
        deletes = { {}, {}, {} },
        type_changes = {},
        unmatched = {},
        has_changes = true,
        needs_confirmation = true,
      }

      assert.are.equal(6, plan_module.get_operation_count(plan))
    end)

    it('should count type_changes as 2 operations each', function()
      local plan = {
        updates = { {} },
        creates = {},
        deletes = {},
        type_changes = { {}, {} }, -- 2 type changes = 4 operations (delete + create each)
        unmatched = {},
        has_changes = true,
        needs_confirmation = false,
      }

      -- 1 update + 2 type_changes * 2 = 1 + 4 = 5
      assert.are.equal(5, plan_module.get_operation_count(plan))
    end)
  end)
end)
