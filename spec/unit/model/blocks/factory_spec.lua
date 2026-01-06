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

    -- Bug #10.1: Type detection should use first non-empty line
    -- Scenario: User presses 'o', then '<CR>', then types '## heading'
    -- Content becomes: ['', '## heading', '']
    describe('first non-empty line detection', function()
      it('should detect heading_2 from first non-empty line with leading empty', function()
        local block = factory.create_from_lines({ '', '## heading', '' }, nil)

        assert.is_not_nil(block)
        assert.are.equal('heading_2', block:get_type())
        assert.are.equal('heading', block:get_text())
      end)

      it('should detect heading_1 from first non-empty line', function()
        local block = factory.create_from_lines({ '', '', '# Big Heading' }, nil)

        assert.is_not_nil(block)
        assert.are.equal('heading_1', block:get_type())
        assert.are.equal('Big Heading', block:get_text())
      end)

      it('should detect bulleted_list_item from first non-empty line', function()
        local block = factory.create_from_lines({ '', '- list item', '' }, nil)

        assert.is_not_nil(block)
        assert.are.equal('bulleted_list_item', block:get_type())
        assert.are.equal('list item', block:get_text())
      end)

      it('should detect divider from first non-empty line', function()
        local block = factory.create_from_lines({ '', '---', '' }, nil)

        assert.is_not_nil(block)
        assert.are.equal('divider', block:get_type())
      end)

      it('should detect quote from first non-empty line', function()
        local block = factory.create_from_lines({ '', '| quote text', '' }, nil)

        assert.is_not_nil(block)
        assert.are.equal('quote', block:get_type())
        assert.are.equal('quote text', block:get_text())
      end)

      it('should trim leading empty lines from content', function()
        local block = factory.create_from_lines({ '', '', '## heading' }, nil)

        assert.is_not_nil(block)
        -- Content should NOT have leading newlines
        local text = block:get_text()
        assert.are.equal('heading', text)
      end)
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

    -- Bug #10.2: Multi-line orphan splitting by type boundaries
    -- Scenario: quote block + empty + heading in same orphan range
    describe('type boundary splitting', function()
      it('should split quote and heading into separate blocks', function()
        -- This is the exact bug scenario: quote absorbed heading
        local orphans = {
          {
            start_line = 22,
            end_line = 25,
            content = { '| queteruhe -somanu', '', '### heading 3' },
            after_block_id = 'block1',
          },
        }

        local blocks = factory.create_from_orphans(orphans)

        assert.are.equal(2, #blocks)
        assert.are.equal('quote', blocks[1]:get_type())
        assert.are.equal('queteruhe -somanu', blocks[1]:get_text())
        assert.are.equal('heading_3', blocks[2]:get_type())
        assert.are.equal('heading 3', blocks[2]:get_text())
      end)

      it('should split different heading levels', function()
        local orphans = {
          {
            start_line = 1,
            end_line = 3,
            content = { '# Heading 1', '', '## Heading 2' },
            after_block_id = 'block1',
          },
        }

        local blocks = factory.create_from_orphans(orphans)

        assert.are.equal(2, #blocks)
        assert.are.equal('heading_1', blocks[1]:get_type())
        assert.are.equal('heading_2', blocks[2]:get_type())
      end)

      it('should split bullet and paragraph', function()
        local orphans = {
          {
            start_line = 1,
            end_line = 3,
            content = { '- list item', '', 'paragraph text' },
            after_block_id = 'block1',
          },
        }

        local blocks = factory.create_from_orphans(orphans)

        assert.are.equal(2, #blocks)
        assert.are.equal('bulleted_list_item', blocks[1]:get_type())
        assert.are.equal('paragraph', blocks[2]:get_type())
      end)

      it('should keep divider as single block', function()
        local orphans = {
          {
            start_line = 1,
            end_line = 3,
            content = { 'paragraph', '---', 'more text' },
            after_block_id = 'block1',
          },
        }

        local blocks = factory.create_from_orphans(orphans)

        assert.are.equal(3, #blocks)
        assert.are.equal('paragraph', blocks[1]:get_type())
        assert.are.equal('divider', blocks[2]:get_type())
        assert.are.equal('paragraph', blocks[3]:get_type())
      end)

      it('should handle empty lines with heading prefix', function()
        -- User scenario: o + Enter + ## heading
        local orphans = {
          {
            start_line = 1,
            end_line = 3,
            content = { '', '## My Heading', '' },
            after_block_id = 'block1',
          },
        }

        local blocks = factory.create_from_orphans(orphans)

        assert.are.equal(1, #blocks)
        assert.are.equal('heading_2', blocks[1]:get_type())
        assert.are.equal('My Heading', blocks[1]:get_text())
      end)

      it('should chain after_block_id for multiple blocks', function()
        local orphans = {
          {
            start_line = 1,
            end_line = 3,
            content = { '# First', '', '## Second' },
            after_block_id = 'original_block',
          },
        }

        local blocks = factory.create_from_orphans(orphans)

        assert.are.equal(2, #blocks)
        -- First block uses original after_block_id
        assert.are.equal('original_block', blocks[1].after_block_id)
        -- Second block uses first block's temp_id
        assert.are.equal(blocks[1].temp_id, blocks[2].after_block_id)
      end)

      it('should handle consecutive bullets as separate blocks', function()
        local orphans = {
          {
            start_line = 1,
            end_line = 2,
            content = { '- item 1', '- item 2' },
            after_block_id = 'block1',
          },
        }

        local blocks = factory.create_from_orphans(orphans)

        -- Each list item is a separate Notion block
        assert.are.equal(2, #blocks)
        assert.are.equal('bulleted_list_item', blocks[1]:get_type())
        assert.are.equal('bulleted_list_item', blocks[2]:get_type())
        assert.are.equal('item 1', blocks[1]:get_text())
        assert.are.equal('item 2', blocks[2]:get_text())
      end)

      it('should handle consecutive numbered items as separate blocks', function()
        local orphans = {
          {
            start_line = 1,
            end_line = 2,
            content = { '1. first', '2. second' },
            after_block_id = 'block1',
          },
        }

        local blocks = factory.create_from_orphans(orphans)

        -- Each numbered item is a separate Notion block
        assert.are.equal(2, #blocks)
        assert.are.equal('numbered_list_item', blocks[1]:get_type())
        assert.are.equal('numbered_list_item', blocks[2]:get_type())
        assert.are.equal('first', blocks[1]:get_text())
        assert.are.equal('second', blocks[2]:get_text())
      end)
    end)
  end)
end)
