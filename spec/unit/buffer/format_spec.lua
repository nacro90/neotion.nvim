describe('neotion.buffer.format', function()
  local format

  before_each(function()
    package.loaded['neotion.buffer.format'] = nil
    package.loaded['neotion.api.blocks'] = nil
    format = require('neotion.buffer.format')
  end)

  describe('format_block', function()
    it('should format paragraph block', function()
      local block = {
        type = 'paragraph',
        paragraph = {
          rich_text = {
            { plain_text = 'Hello World' },
          },
        },
      }

      local lines = format.format_block(block, 0)

      assert.are.equal(1, #lines)
      assert.are.equal('Hello World', lines[1])
    end)

    it('should format empty paragraph as empty line', function()
      local block = {
        type = 'paragraph',
        paragraph = {
          rich_text = {},
        },
      }

      local lines = format.format_block(block, 0)

      assert.are.equal(1, #lines)
      assert.are.equal('', lines[1])
    end)

    it('should format heading_1 with # prefix', function()
      local block = {
        type = 'heading_1',
        heading_1 = {
          rich_text = {
            { plain_text = 'Main Title' },
          },
        },
      }

      local lines = format.format_block(block, 0)

      assert.are.equal('# Main Title', lines[1])
    end)

    it('should format heading_2 with ## prefix', function()
      local block = {
        type = 'heading_2',
        heading_2 = {
          rich_text = {
            { plain_text = 'Sub Title' },
          },
        },
      }

      local lines = format.format_block(block, 0)

      assert.are.equal('## Sub Title', lines[1])
    end)

    it('should format heading_3 with ### prefix', function()
      local block = {
        type = 'heading_3',
        heading_3 = {
          rich_text = {
            { plain_text = 'Small Title' },
          },
        },
      }

      local lines = format.format_block(block, 0)

      assert.are.equal('### Small Title', lines[1])
    end)

    it('should format bulleted_list_item with - prefix', function()
      local block = {
        type = 'bulleted_list_item',
        bulleted_list_item = {
          rich_text = {
            { plain_text = 'List item' },
          },
        },
      }

      local lines = format.format_block(block, 0)

      assert.are.equal('- List item', lines[1])
    end)

    it('should format numbered_list_item with 1. prefix', function()
      local block = {
        type = 'numbered_list_item',
        numbered_list_item = {
          rich_text = {
            { plain_text = 'First item' },
          },
        },
      }

      local lines = format.format_block(block, 0)

      assert.are.equal('1. First item', lines[1])
    end)

    it('should format unchecked to_do with [ ]', function()
      local block = {
        type = 'to_do',
        to_do = {
          rich_text = {
            { plain_text = 'Unchecked task' },
          },
          checked = false,
        },
      }

      local lines = format.format_block(block, 0)

      assert.are.equal('- [ ] Unchecked task', lines[1])
    end)

    it('should format checked to_do with [x]', function()
      local block = {
        type = 'to_do',
        to_do = {
          rich_text = {
            { plain_text = 'Done task' },
          },
          checked = true,
        },
      }

      local lines = format.format_block(block, 0)

      assert.are.equal('- [x] Done task', lines[1])
    end)

    it('should format quote with > prefix', function()
      local block = {
        type = 'quote',
        quote = {
          rich_text = {
            { plain_text = 'A wise quote' },
          },
        },
      }

      local lines = format.format_block(block, 0)

      assert.are.equal('> A wise quote', lines[1])
    end)

    it('should format divider as ---', function()
      local block = {
        type = 'divider',
        divider = {},
      }

      local lines = format.format_block(block, 0)

      assert.are.equal('---', lines[1])
    end)

    it('should format toggle with triangle prefix', function()
      local block = {
        type = 'toggle',
        toggle = {
          rich_text = {
            { plain_text = 'Toggle title' },
          },
        },
      }

      local lines = format.format_block(block, 0)

      assert.is_truthy(lines[1]:match('Toggle title'))
    end)

    it('should format code block with fences', function()
      local block = {
        type = 'code',
        code = {
          rich_text = {
            { plain_text = 'print("hello")' },
          },
          language = 'python',
        },
      }

      local lines = format.format_block(block, 0)

      assert.are.equal('```python', lines[1])
      assert.are.equal('print("hello")', lines[2])
      assert.are.equal('```', lines[3])
    end)

    it('should apply indent to block', function()
      local block = {
        type = 'paragraph',
        paragraph = {
          rich_text = {
            { plain_text = 'Indented text' },
          },
        },
      }

      local lines = format.format_block(block, 2)

      assert.are.equal('    Indented text', lines[1])
    end)

    it('should format child_page with icon', function()
      local block = {
        type = 'child_page',
        child_page = {
          title = 'Sub Page',
        },
      }

      local lines = format.format_block(block, 0)

      assert.is_truthy(lines[1]:match('Sub Page'))
    end)
  end)

  describe('format_blocks', function()
    it('should format multiple blocks', function()
      local page_blocks = {
        {
          type = 'heading_1',
          heading_1 = {
            rich_text = { { plain_text = 'Title' } },
          },
        },
        {
          type = 'paragraph',
          paragraph = {
            rich_text = { { plain_text = 'Content' } },
          },
        },
      }

      local lines = format.format_blocks(page_blocks)

      assert.are.equal(2, #lines)
      assert.are.equal('# Title', lines[1])
      assert.are.equal('Content', lines[2])
    end)

    it('should return empty array for empty blocks', function()
      local lines = format.format_blocks({})

      assert.are.equal(0, #lines)
    end)

    it('should number consecutive numbered_list_items sequentially', function()
      local page_blocks = {
        {
          type = 'numbered_list_item',
          numbered_list_item = {
            rich_text = { { plain_text = 'First' } },
          },
        },
        {
          type = 'numbered_list_item',
          numbered_list_item = {
            rich_text = { { plain_text = 'Second' } },
          },
        },
        {
          type = 'numbered_list_item',
          numbered_list_item = {
            rich_text = { { plain_text = 'Third' } },
          },
        },
      }

      local lines = format.format_blocks(page_blocks)

      assert.are.equal(3, #lines)
      assert.are.equal('1. First', lines[1])
      assert.are.equal('2. Second', lines[2])
      assert.are.equal('3. Third', lines[3])
    end)

    it('should restart numbering after non-list block', function()
      local page_blocks = {
        {
          type = 'numbered_list_item',
          numbered_list_item = {
            rich_text = { { plain_text = 'First' } },
          },
        },
        {
          type = 'numbered_list_item',
          numbered_list_item = {
            rich_text = { { plain_text = 'Second' } },
          },
        },
        {
          type = 'paragraph',
          paragraph = {
            rich_text = { { plain_text = 'Break' } },
          },
        },
        {
          type = 'numbered_list_item',
          numbered_list_item = {
            rich_text = { { plain_text = 'New first' } },
          },
        },
        {
          type = 'numbered_list_item',
          numbered_list_item = {
            rich_text = { { plain_text = 'New second' } },
          },
        },
      }

      local lines = format.format_blocks(page_blocks)

      assert.are.equal(5, #lines)
      assert.are.equal('1. First', lines[1])
      assert.are.equal('2. Second', lines[2])
      assert.are.equal('Break', lines[3])
      assert.are.equal('1. New first', lines[4])
      assert.are.equal('2. New second', lines[5])
    end)
  end)
end)
