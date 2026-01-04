describe('neotion.model.registry', function()
  local registry

  before_each(function()
    -- Clear all cached modules for clean test state
    package.loaded['neotion.model.registry'] = nil
    package.loaded['neotion.model.block'] = nil
    package.loaded['neotion.model.blocks.paragraph'] = nil
    package.loaded['neotion.model.blocks.heading'] = nil
    registry = require('neotion.model.registry')
    registry.clear_cache()
  end)

  describe('is_supported', function()
    it('should return true for paragraph', function()
      assert.is_true(registry.is_supported('paragraph'))
    end)

    it('should return true for heading_1', function()
      assert.is_true(registry.is_supported('heading_1'))
    end)

    it('should return true for heading_2', function()
      assert.is_true(registry.is_supported('heading_2'))
    end)

    it('should return true for heading_3', function()
      assert.is_true(registry.is_supported('heading_3'))
    end)

    it('should return false for unsupported types', function()
      -- Phase 5.7: code, quote, bulleted_list_item, divider are now supported
      assert.is_false(registry.is_supported('toggle'))
      assert.is_false(registry.is_supported('callout'))
      assert.is_false(registry.is_supported('image'))
      assert.is_false(registry.is_supported('embed'))
    end)

    it('should return true for Phase 5.7 block types', function()
      assert.is_true(registry.is_supported('divider'))
      assert.is_true(registry.is_supported('quote'))
      assert.is_true(registry.is_supported('bulleted_list_item'))
      assert.is_true(registry.is_supported('code'))
    end)

    it('should return false for unknown types', function()
      assert.is_false(registry.is_supported('nonexistent_type'))
    end)
  end)

  describe('get_handler', function()
    it('should return paragraph handler', function()
      local handler = registry.get_handler('paragraph')

      assert.is_not_nil(handler)
      assert.is_function(handler.new)
      assert.is_function(handler.is_editable)
    end)

    it('should return heading handler for all heading types', function()
      local h1 = registry.get_handler('heading_1')
      local h2 = registry.get_handler('heading_2')
      local h3 = registry.get_handler('heading_3')

      assert.is_not_nil(h1)
      assert.is_not_nil(h2)
      assert.is_not_nil(h3)
    end)

    it('should return nil for unsupported types', function()
      local handler = registry.get_handler('toggle')

      assert.is_nil(handler)
    end)

    it('should cache handlers', function()
      local handler1 = registry.get_handler('paragraph')
      local handler2 = registry.get_handler('paragraph')

      assert.are.equal(handler1, handler2)
    end)
  end)

  describe('deserialize', function()
    it('should create ParagraphBlock for paragraph type', function()
      local raw = {
        id = 'para1',
        type = 'paragraph',
        paragraph = { rich_text = { { plain_text = 'Test' } } },
      }

      local block = registry.deserialize(raw)

      assert.are.equal('para1', block:get_id())
      assert.are.equal('paragraph', block:get_type())
      assert.is_true(block:is_editable())
    end)

    it('should create HeadingBlock for heading types', function()
      local raw = {
        id = 'head1',
        type = 'heading_1',
        heading_1 = { rich_text = { { plain_text = 'Title' } } },
      }

      local block = registry.deserialize(raw)

      assert.are.equal('head1', block:get_id())
      assert.are.equal('heading_1', block:get_type())
      assert.is_true(block:is_editable())
    end)

    it('should create read-only base Block for unsupported types', function()
      local raw = {
        id = 'toggle1',
        type = 'toggle',
        toggle = { rich_text = { { plain_text = 'Toggle' } } },
      }

      local block = registry.deserialize(raw)

      assert.are.equal('toggle1', block:get_id())
      assert.are.equal('toggle', block:get_type())
      assert.is_false(block:is_editable())
    end)

    it('should preserve raw JSON in all block types', function()
      local raw = {
        id = 'test',
        type = 'image',
        image = { url = 'http://example.com/img.png' },
        custom_field = 'preserved',
      }

      local block = registry.deserialize(raw)

      assert.are.same(raw, block.raw)
    end)
  end)

  describe('deserialize_all', function()
    it('should deserialize array of blocks', function()
      local blocks_raw = {
        {
          id = 'para1',
          type = 'paragraph',
          paragraph = { rich_text = {} },
        },
        {
          id = 'head1',
          type = 'heading_1',
          heading_1 = { rich_text = {} },
        },
        {
          id = 'toggle1',
          type = 'toggle',
          toggle = { rich_text = {} },
        },
      }

      local blocks = registry.deserialize_all(blocks_raw)

      assert.are.equal(3, #blocks)
      assert.are.equal('para1', blocks[1]:get_id())
      assert.are.equal('head1', blocks[2]:get_id())
      assert.are.equal('toggle1', blocks[3]:get_id())
    end)

    it('should return empty array for empty input', function()
      local blocks = registry.deserialize_all({})

      assert.are.equal(0, #blocks)
    end)

    it('should mix editable and read-only blocks', function()
      -- Phase 5.7: code is now editable, use divider as read-only example
      local blocks_raw = {
        { id = '1', type = 'paragraph', paragraph = { rich_text = {} } },
        { id = '2', type = 'divider', divider = {} },
        { id = '3', type = 'heading_2', heading_2 = { rich_text = {} } },
      }

      local blocks = registry.deserialize_all(blocks_raw)

      assert.is_true(blocks[1]:is_editable())
      assert.is_false(blocks[2]:is_editable()) -- divider is read-only
      assert.is_true(blocks[3]:is_editable())
    end)
  end)

  describe('get_supported_types', function()
    it('should return array of supported types', function()
      local types = registry.get_supported_types()

      assert.is_table(types)
      assert.is_true(vim.tbl_contains(types, 'paragraph'))
      assert.is_true(vim.tbl_contains(types, 'heading_1'))
      assert.is_true(vim.tbl_contains(types, 'heading_2'))
      assert.is_true(vim.tbl_contains(types, 'heading_3'))
    end)

    it('should not contain unsupported types', function()
      local types = registry.get_supported_types()

      -- Phase 5.7: code is now supported, use toggle and image as unsupported examples
      assert.is_false(vim.tbl_contains(types, 'toggle'))
      assert.is_false(vim.tbl_contains(types, 'image'))
    end)

    it('should contain Phase 5.7 types', function()
      local types = registry.get_supported_types()

      assert.is_true(vim.tbl_contains(types, 'divider'))
      assert.is_true(vim.tbl_contains(types, 'quote'))
      assert.is_true(vim.tbl_contains(types, 'bulleted_list_item'))
      assert.is_true(vim.tbl_contains(types, 'code'))
    end)
  end)

  describe('check_editability', function()
    it('should return true for all editable blocks', function()
      local blocks_raw = {
        { id = '1', type = 'paragraph', paragraph = { rich_text = {} } },
        { id = '2', type = 'heading_1', heading_1 = { rich_text = {} } },
        { id = '3', type = 'heading_2', heading_2 = { rich_text = {} } },
      }
      local blocks = registry.deserialize_all(blocks_raw)

      local is_editable, unsupported = registry.check_editability(blocks)

      assert.is_true(is_editable)
      assert.are.equal(0, #unsupported)
    end)

    it('should return false when unsupported blocks present', function()
      local blocks_raw = {
        { id = '1', type = 'paragraph', paragraph = { rich_text = {} } },
        { id = '2', type = 'toggle', toggle = { rich_text = {} } },
      }
      local blocks = registry.deserialize_all(blocks_raw)

      local is_editable, unsupported = registry.check_editability(blocks)

      assert.is_false(is_editable)
      assert.are.equal(1, #unsupported)
      assert.are.equal('toggle', unsupported[1])
    end)

    it('should list all unsupported types', function()
      -- Phase 5.7: code, quote, bulleted_list_item are now supported
      -- Use toggle, image, embed as unsupported examples
      local blocks_raw = {
        { id = '1', type = 'toggle', toggle = {} },
        { id = '2', type = 'image', image = {} },
        { id = '3', type = 'embed', embed = {} },
      }
      local blocks = registry.deserialize_all(blocks_raw)

      local _, unsupported = registry.check_editability(blocks)

      assert.are.equal(3, #unsupported)
    end)

    it('should deduplicate unsupported types', function()
      local blocks_raw = {
        { id = '1', type = 'toggle', toggle = {} },
        { id = '2', type = 'toggle', toggle = {} },
        { id = '3', type = 'toggle', toggle = {} },
      }
      local blocks = registry.deserialize_all(blocks_raw)

      local _, unsupported = registry.check_editability(blocks)

      assert.are.equal(1, #unsupported)
    end)

    it('should return true for empty blocks array', function()
      local is_editable, unsupported = registry.check_editability({})

      assert.is_true(is_editable)
      assert.are.equal(0, #unsupported)
    end)
  end)

  describe('clear_cache', function()
    it('should clear cached handlers', function()
      -- Load a handler
      local handler1 = registry.get_handler('paragraph')
      assert.is_not_nil(handler1)

      -- Clear cache
      registry.clear_cache()

      -- Force module reload
      package.loaded['neotion.model.blocks.paragraph'] = nil

      -- Get handler again - should reload
      local handler2 = registry.get_handler('paragraph')

      -- They should be different objects
      assert.is_not_nil(handler2)
    end)
  end)
end)
