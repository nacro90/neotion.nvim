describe('neotion.model.block', function()
  local block_module

  before_each(function()
    package.loaded['neotion.model.block'] = nil
    block_module = require('neotion.model.block')
  end)

  describe('Block.new', function()
    it('should create a block from raw JSON', function()
      local raw = {
        id = 'abc123',
        type = 'paragraph',
        paragraph = {
          rich_text = { { plain_text = 'Hello' } },
        },
      }

      local block = block_module.Block.new(raw)

      assert.are.equal('abc123', block:get_id())
      assert.are.equal('paragraph', block:get_type())
    end)

    it('should preserve raw JSON for round-trip', function()
      local raw = {
        id = 'test123',
        type = 'code',
        code = {
          language = 'lua',
          rich_text = { { plain_text = 'print("hello")' } },
        },
        created_time = '2024-01-01T00:00:00Z',
      }

      local block = block_module.Block.new(raw)

      assert.are.same(raw, block.raw)
    end)

    it('should extract parent_id from parent.block_id', function()
      local raw = {
        id = 'child',
        type = 'paragraph',
        parent = {
          type = 'block_id',
          block_id = 'parent123',
        },
      }

      local block = block_module.Block.new(raw)

      assert.are.equal('parent123', block.parent_id)
    end)

    it('should default to not editable', function()
      local raw = { id = 'test', type = 'unsupported' }

      local block = block_module.Block.new(raw)

      assert.is_false(block:is_editable())
    end)

    it('should default to not dirty', function()
      local raw = { id = 'test', type = 'paragraph' }

      local block = block_module.Block.new(raw)

      assert.is_false(block:is_dirty())
    end)
  end)

  describe('line range', function()
    it('should set and get line range', function()
      local block = block_module.Block.new({ id = 'test', type = 'paragraph' })

      block:set_line_range(5, 10)
      local start_line, end_line = block:get_line_range()

      assert.are.equal(5, start_line)
      assert.are.equal(10, end_line)
    end)

    it('should check if line is within range', function()
      local block = block_module.Block.new({ id = 'test', type = 'paragraph' })
      block:set_line_range(5, 10)

      assert.is_true(block:contains_line(5))
      assert.is_true(block:contains_line(7))
      assert.is_true(block:contains_line(10))
      assert.is_false(block:contains_line(4))
      assert.is_false(block:contains_line(11))
    end)

    it('should return false for contains_line when no range set', function()
      local block = block_module.Block.new({ id = 'test', type = 'paragraph' })

      assert.is_false(block:contains_line(5))
    end)
  end)

  describe('dirty tracking', function()
    it('should set dirty flag', function()
      local block = block_module.Block.new({ id = 'test', type = 'paragraph' })

      block:set_dirty(true)

      assert.is_true(block:is_dirty())
    end)

    it('should clear dirty flag', function()
      local block = block_module.Block.new({ id = 'test', type = 'paragraph' })
      block:set_dirty(true)

      block:set_dirty(false)

      assert.is_false(block:is_dirty())
    end)
  end)

  describe('format', function()
    it('should return placeholder for unsupported block', function()
      local block = block_module.Block.new({ id = 'test', type = 'unsupported' })

      local lines = block:format()

      assert.are.equal(1, #lines)
      assert.is_truthy(lines[1]:match('%[unsupported %- read only%]'))
    end)

    it('should respect indent option', function()
      local block = block_module.Block.new({ id = 'test', type = 'unsupported' })

      local lines = block:format({ indent = 2, indent_size = 2 })

      assert.is_truthy(lines[1]:match('^    ')) -- 4 spaces indent
    end)
  end)

  describe('serialize', function()
    it('should return original raw JSON for unsupported block', function()
      local raw = {
        id = 'test',
        type = 'unsupported',
        unsupported = { data = 'preserved' },
      }

      local block = block_module.Block.new(raw)
      local serialized = block:serialize()

      assert.are.same(raw, serialized)
    end)
  end)

  describe('has_children', function()
    it('should return true when has_children is true', function()
      local block = block_module.Block.new({
        id = 'test',
        type = 'toggle',
        has_children = true,
      })

      assert.is_true(block:has_children())
    end)

    it('should return false when has_children is false', function()
      local block = block_module.Block.new({
        id = 'test',
        type = 'paragraph',
        has_children = false,
      })

      assert.is_false(block:has_children())
    end)

    it('should return false when has_children is not set', function()
      local block = block_module.Block.new({
        id = 'test',
        type = 'paragraph',
      })

      assert.is_false(block:has_children())
    end)
  end)
end)
