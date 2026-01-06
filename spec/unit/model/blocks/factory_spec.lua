describe('neotion.model.blocks.factory', function()
  local factory

  before_each(function()
    -- Clear module caches
    package.loaded['neotion.model.blocks.factory'] = nil
    package.loaded['neotion.model.blocks.detection'] = nil
    package.loaded['neotion.model.registry'] = nil

    factory = require('neotion.model.blocks.factory')
  end)

  describe('create_from_lines', function()
    it('should create paragraph block from plain text', function()
      local block = factory.create_from_lines({ 'Hello world' }, nil)

      assert.is_not_nil(block)
      assert.are.equal('paragraph', block:get_type())
      assert.are.equal('Hello world', block:get_text())
      assert.is_true(block.is_new)
    end)

    it('should create heading_1 block from # prefix', function()
      local block = factory.create_from_lines({ '# My Heading' }, nil)

      assert.is_not_nil(block)
      assert.are.equal('heading_1', block:get_type())
      assert.are.equal('My Heading', block:get_text())
    end)

    it('should create heading_2 block from ## prefix', function()
      local block = factory.create_from_lines({ '## Second Level' }, nil)

      assert.is_not_nil(block)
      assert.are.equal('heading_2', block:get_type())
      assert.are.equal('Second Level', block:get_text())
    end)

    it('should create heading_3 block from ### prefix', function()
      local block = factory.create_from_lines({ '### Third Level' }, nil)

      assert.is_not_nil(block)
      assert.are.equal('heading_3', block:get_type())
      assert.are.equal('Third Level', block:get_text())
    end)

    it('should create bulleted_list_item from - prefix', function()
      local block = factory.create_from_lines({ '- List item' }, nil)

      assert.is_not_nil(block)
      assert.are.equal('bulleted_list_item', block:get_type())
      assert.are.equal('List item', block:get_text())
    end)

    it('should create quote block from | prefix', function()
      local block = factory.create_from_lines({ '| Quote text' }, nil)

      assert.is_not_nil(block)
      assert.are.equal('quote', block:get_type())
      assert.are.equal('Quote text', block:get_text())
    end)

    it('should create divider block from ---', function()
      local block = factory.create_from_lines({ '---' }, nil)

      assert.is_not_nil(block)
      assert.are.equal('divider', block:get_type())
    end)

    it('should return nil for empty lines', function()
      local block = factory.create_from_lines({ '' }, nil)

      assert.is_nil(block)
    end)

    it('should return nil for all empty lines', function()
      local block = factory.create_from_lines({ '', '', '' }, nil)

      assert.is_nil(block)
    end)

    it('should set after_block_id for positioning', function()
      local block = factory.create_from_lines({ 'Content' }, 'block123')

      assert.is_not_nil(block)
      assert.are.equal('block123', block.after_block_id)
    end)

    it('should generate temp_id for new blocks', function()
      local block = factory.create_from_lines({ 'Content' }, nil)

      assert.is_not_nil(block)
      assert.is_not_nil(block.temp_id)
      assert.is_true(block.temp_id:match('^temp_') ~= nil)
    end)

    it('should handle multi-line content', function()
      local block = factory.create_from_lines({ 'Line 1', 'Line 2', 'Line 3' }, nil)

      assert.is_not_nil(block)
      assert.are.equal('paragraph', block:get_type())
      -- Content should be joined with newlines
      local text = block:get_text()
      assert.is_true(text:find('Line 1') ~= nil)
    end)
  end)

  describe('create_raw_block', function()
    it('should create paragraph raw structure', function()
      local raw = factory.create_raw_block('paragraph', 'Test content')

      assert.are.equal('paragraph', raw.type)
      assert.is_nil(raw.id)
      assert.is_not_nil(raw.paragraph)
      assert.is_not_nil(raw.paragraph.rich_text)
      assert.are.equal(1, #raw.paragraph.rich_text)
      assert.are.equal('Test content', raw.paragraph.rich_text[1].plain_text)
    end)

    it('should create heading_1 raw structure', function()
      local raw = factory.create_raw_block('heading_1', 'Heading Text')

      assert.are.equal('heading_1', raw.type)
      assert.is_not_nil(raw.heading_1)
      assert.are.equal(false, raw.heading_1.is_toggleable)
    end)

    it('should create divider raw structure', function()
      local raw = factory.create_raw_block('divider', '')

      assert.are.equal('divider', raw.type)
      assert.is_not_nil(raw.divider)
      assert.is_nil(raw.divider.rich_text) -- Divider has no rich_text
    end)

    it('should create bulleted_list_item raw structure', function()
      local raw = factory.create_raw_block('bulleted_list_item', 'Item text')

      assert.are.equal('bulleted_list_item', raw.type)
      assert.is_not_nil(raw.bulleted_list_item)
      assert.is_not_nil(raw.bulleted_list_item.rich_text)
    end)
  end)

  describe('create_from_orphans', function()
    it('should create blocks from orphan ranges', function()
      local orphans = {
        {
          start_line = 5,
          end_line = 5,
          content = { '# New Heading' },
          after_block_id = 'block1',
        },
        {
          start_line = 7,
          end_line = 7,
          content = { 'New paragraph' },
          after_block_id = 'block2',
        },
      }

      local blocks = factory.create_from_orphans(orphans)

      assert.are.equal(2, #blocks)
      assert.are.equal('heading_1', blocks[1]:get_type())
      assert.are.equal('paragraph', blocks[2]:get_type())
    end)

    it('should skip empty orphan ranges', function()
      local orphans = {
        {
          start_line = 5,
          end_line = 5,
          content = { '' },
          after_block_id = 'block1',
        },
      }

      local blocks = factory.create_from_orphans(orphans)

      assert.are.equal(0, #blocks)
    end)

    it('should store orphan line info on blocks', function()
      local orphans = {
        {
          start_line = 10,
          end_line = 12,
          content = { 'Line 1', 'Line 2', 'Line 3' },
          after_block_id = 'block1',
        },
      }

      local blocks = factory.create_from_orphans(orphans)

      assert.are.equal(1, #blocks)
      assert.are.equal(10, blocks[1].orphan_start_line)
      assert.are.equal(12, blocks[1].orphan_end_line)
    end)
  end)
end)
