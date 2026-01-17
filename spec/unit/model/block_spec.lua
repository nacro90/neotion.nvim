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
    it('should return true when raw.has_children is true', function()
      local block = block_module.Block.new({
        id = 'test',
        type = 'toggle',
        has_children = true,
      })

      assert.is_true(block:has_children())
    end)

    it('should return false when has_children is false and no children', function()
      local block = block_module.Block.new({
        id = 'test',
        type = 'paragraph',
        has_children = false,
      })

      assert.is_false(block:has_children())
    end)

    it('should return false when has_children is not set and no children', function()
      local block = block_module.Block.new({
        id = 'test',
        type = 'paragraph',
      })

      assert.is_false(block:has_children())
    end)

    it('should return true when children are added locally', function()
      local parent = block_module.Block.new({ id = 'parent', type = 'toggle' })
      local child = block_module.Block.new({ id = 'child', type = 'paragraph' })

      parent:add_child(child)

      assert.is_true(parent:has_children())
    end)
  end)

  describe('children management', function()
    it('should initialize with empty children array', function()
      local block = block_module.Block.new({ id = 'test', type = 'toggle' })

      assert.are.same({}, block:get_children())
    end)

    it('should add child and set parent reference', function()
      local parent = block_module.Block.new({ id = 'parent', type = 'toggle' })
      local child = block_module.Block.new({ id = 'child', type = 'paragraph' })

      parent:add_child(child)

      assert.are.equal(1, #parent:get_children())
      assert.are.equal(child, parent:get_children()[1])
      assert.are.equal(parent, child.parent)
      assert.are.equal('parent', child.parent_id)
    end)

    it('should set child depth based on parent depth', function()
      local parent = block_module.Block.new({ id = 'parent', type = 'toggle' })
      parent.depth = 1
      local child = block_module.Block.new({ id = 'child', type = 'paragraph' })

      parent:add_child(child)

      assert.are.equal(2, child.depth)
    end)

    it('should add child at specific index', function()
      local parent = block_module.Block.new({ id = 'parent', type = 'toggle' })
      local child1 = block_module.Block.new({ id = 'child1', type = 'paragraph' })
      local child2 = block_module.Block.new({ id = 'child2', type = 'paragraph' })
      local child3 = block_module.Block.new({ id = 'child3', type = 'paragraph' })

      parent:add_child(child1)
      parent:add_child(child3)
      parent:add_child(child2, 2)

      assert.are.equal(child1, parent:get_children()[1])
      assert.are.equal(child2, parent:get_children()[2])
      assert.are.equal(child3, parent:get_children()[3])
    end)

    it('should remove child and clear parent reference', function()
      local parent = block_module.Block.new({ id = 'parent', type = 'toggle' })
      local child = block_module.Block.new({ id = 'child', type = 'paragraph' })
      parent:add_child(child)

      local result = parent:remove_child(child)

      assert.is_true(result)
      assert.are.equal(0, #parent:get_children())
      assert.is_nil(child.parent)
      assert.is_nil(child.parent_id)
    end)

    it('should return false when removing non-existent child', function()
      local parent = block_module.Block.new({ id = 'parent', type = 'toggle' })
      local other = block_module.Block.new({ id = 'other', type = 'paragraph' })

      local result = parent:remove_child(other)

      assert.is_false(result)
    end)
  end)

  describe('set_parent', function()
    it('should set parent reference and update parent_id', function()
      local parent = block_module.Block.new({ id = 'parent', type = 'toggle' })
      local child = block_module.Block.new({ id = 'child', type = 'paragraph' })

      child:set_parent(parent)

      assert.are.equal(parent, child.parent)
      assert.are.equal('parent', child.parent_id)
    end)

    it('should update depth based on parent', function()
      local parent = block_module.Block.new({ id = 'parent', type = 'toggle' })
      parent.depth = 2
      local child = block_module.Block.new({ id = 'child', type = 'paragraph' })

      child:set_parent(parent)

      assert.are.equal(3, child.depth)
    end)

    it('should reset depth to 0 when parent is nil', function()
      local parent = block_module.Block.new({ id = 'parent', type = 'toggle' })
      local child = block_module.Block.new({ id = 'child', type = 'paragraph' })
      child:set_parent(parent)

      child:set_parent(nil)

      assert.are.equal(0, child.depth)
    end)
  end)

  describe('supports_children', function()
    it('should return false for base block', function()
      local block = block_module.Block.new({ id = 'test', type = 'paragraph' })

      assert.is_false(block:supports_children())
    end)
  end)

  -- Phase 7: Block deletion with children tests
  describe('block deletion with children', function()
    it('should clear all children references when parent is conceptually deleted', function()
      local parent = block_module.Block.new({ id = 'parent', type = 'toggle' })
      local child1 = block_module.Block.new({ id = 'child1', type = 'paragraph' })
      local child2 = block_module.Block.new({ id = 'child2', type = 'paragraph' })
      parent:add_child(child1)
      parent:add_child(child2)

      -- Simulate deletion by removing all children
      while #parent:get_children() > 0 do
        parent:remove_child(parent:get_children()[1])
      end

      assert.are.equal(0, #parent:get_children())
      assert.is_nil(child1.parent)
      assert.is_nil(child2.parent)
    end)

    it('should handle nested children deletion (grandchildren)', function()
      local grandparent = block_module.Block.new({ id = 'grandparent', type = 'toggle' })
      local parent = block_module.Block.new({ id = 'parent', type = 'toggle' })
      local child = block_module.Block.new({ id = 'child', type = 'paragraph' })

      grandparent:add_child(parent)
      parent:add_child(child)

      -- Remove parent from grandparent
      grandparent:remove_child(parent)

      -- Parent's children should still be intact (Notion API handles recursive delete)
      assert.are.equal(1, #parent:get_children())
      assert.are.equal(child, parent:get_children()[1])
      -- But parent reference to grandparent should be cleared
      assert.is_nil(parent.parent)
    end)

    it('should preserve sibling children when one child is removed', function()
      local parent = block_module.Block.new({ id = 'parent', type = 'toggle' })
      local child1 = block_module.Block.new({ id = 'child1', type = 'paragraph' })
      local child2 = block_module.Block.new({ id = 'child2', type = 'paragraph' })
      local child3 = block_module.Block.new({ id = 'child3', type = 'paragraph' })

      parent:add_child(child1)
      parent:add_child(child2)
      parent:add_child(child3)

      -- Remove middle child
      parent:remove_child(child2)

      assert.are.equal(2, #parent:get_children())
      assert.are.equal(child1, parent:get_children()[1])
      assert.are.equal(child3, parent:get_children()[2])
      assert.is_nil(child2.parent)
      -- Siblings should still have parent reference
      assert.are.equal(parent, child1.parent)
      assert.are.equal(parent, child3.parent)
    end)
  end)

  -- Phase 7: Moving children between parents tests
  describe('moving children between parents', function()
    it('should move child from one parent to another', function()
      local parent1 = block_module.Block.new({ id = 'parent1', type = 'toggle' })
      local parent2 = block_module.Block.new({ id = 'parent2', type = 'toggle' })
      local child = block_module.Block.new({ id = 'child', type = 'paragraph' })

      parent1:add_child(child)
      assert.are.equal(parent1, child.parent)
      assert.are.equal(1, #parent1:get_children())

      -- Move to new parent
      parent1:remove_child(child)
      parent2:add_child(child)

      assert.are.equal(0, #parent1:get_children())
      assert.are.equal(1, #parent2:get_children())
      assert.are.equal(parent2, child.parent)
      assert.are.equal('parent2', child.parent_id)
    end)

    it('should update depth when moving to different level parent', function()
      local root = block_module.Block.new({ id = 'root', type = 'toggle' })
      root.depth = 0
      local level1 = block_module.Block.new({ id = 'level1', type = 'toggle' })
      local level2 = block_module.Block.new({ id = 'level2', type = 'toggle' })
      local child = block_module.Block.new({ id = 'child', type = 'paragraph' })

      root:add_child(level1)
      level1:add_child(level2)
      level2:add_child(child)

      assert.are.equal(3, child.depth) -- depth 3 (root=0, level1=1, level2=2, child=3)

      -- Move child from level2 to level1 (shallower)
      level2:remove_child(child)
      level1:add_child(child)

      assert.are.equal(2, child.depth) -- Now at depth 2
    end)

    it('should handle moving child to become top-level (no parent)', function()
      local parent = block_module.Block.new({ id = 'parent', type = 'toggle' })
      parent.depth = 1
      local child = block_module.Block.new({ id = 'child', type = 'paragraph' })

      parent:add_child(child)
      assert.are.equal(2, child.depth)

      -- Remove from parent but don't add to new parent (becomes top-level)
      parent:remove_child(child)
      child:set_parent(nil)

      assert.is_nil(child.parent)
      assert.are.equal(0, child.depth)
    end)

    it('should correctly reorder children when inserting at specific index', function()
      local parent = block_module.Block.new({ id = 'parent', type = 'toggle' })
      local child1 = block_module.Block.new({ id = 'child1', type = 'paragraph' })
      local child2 = block_module.Block.new({ id = 'child2', type = 'paragraph' })
      local child3 = block_module.Block.new({ id = 'child3', type = 'paragraph' })

      parent:add_child(child1)
      parent:add_child(child3)
      -- Insert child2 at index 2 (between child1 and child3)
      parent:add_child(child2, 2)

      local children = parent:get_children()
      assert.are.equal(3, #children)
      assert.are.equal(child1, children[1])
      assert.are.equal(child2, children[2])
      assert.are.equal(child3, children[3])
    end)
  end)
end)
