describe('neotion.api.blocks', function()
  local blocks

  before_each(function()
    package.loaded['neotion.api.blocks'] = nil
    blocks = require('neotion.api.blocks')
  end)

  describe('rich_text_to_plain', function()
    it('should extract plain text from rich text array', function()
      local rich_text = {
        { plain_text = 'Hello ' },
        { plain_text = 'World' },
      }

      local result = blocks.rich_text_to_plain(rich_text)

      assert.are.equal('Hello World', result)
    end)

    it('should return empty string for empty array', function()
      local result = blocks.rich_text_to_plain({})

      assert.are.equal('', result)
    end)

    it('should return empty string for nil', function()
      local result = blocks.rich_text_to_plain(nil)

      assert.are.equal('', result)
    end)

    it('should handle mixed content with annotations', function()
      local rich_text = {
        { plain_text = 'Normal ', annotations = { bold = false } },
        { plain_text = 'bold', annotations = { bold = true } },
        { plain_text = ' text', annotations = { bold = false } },
      }

      local result = blocks.rich_text_to_plain(rich_text)

      assert.are.equal('Normal bold text', result)
    end)

    it('should skip items without plain_text', function()
      local rich_text = {
        { plain_text = 'Hello' },
        { type = 'mention' }, -- no plain_text
        { plain_text = ' World' },
      }

      local result = blocks.rich_text_to_plain(rich_text)

      assert.are.equal('Hello World', result)
    end)
  end)

  describe('get_block_text', function()
    it('should extract text from paragraph block', function()
      local block = {
        type = 'paragraph',
        paragraph = {
          rich_text = {
            { plain_text = 'Hello World' },
          },
        },
      }

      local result = blocks.get_block_text(block)

      assert.are.equal('Hello World', result)
    end)

    it('should extract text from heading_1 block', function()
      local block = {
        type = 'heading_1',
        heading_1 = {
          rich_text = {
            { plain_text = 'Main Title' },
          },
        },
      }

      local result = blocks.get_block_text(block)

      assert.are.equal('Main Title', result)
    end)

    it('should extract title from child_page block', function()
      local block = {
        type = 'child_page',
        child_page = {
          title = 'Sub Page',
        },
      }

      local result = blocks.get_block_text(block)

      assert.are.equal('Sub Page', result)
    end)

    it('should return empty string for nil block', function()
      local result = blocks.get_block_text(nil)

      assert.are.equal('', result)
    end)

    it('should return empty string for block without type', function()
      local block = {}

      local result = blocks.get_block_text(block)

      assert.are.equal('', result)
    end)

    it('should return empty string for divider block', function()
      local block = {
        type = 'divider',
        divider = {},
      }

      local result = blocks.get_block_text(block)

      assert.are.equal('', result)
    end)

    it('should extract text from bulleted_list_item', function()
      local block = {
        type = 'bulleted_list_item',
        bulleted_list_item = {
          rich_text = {
            { plain_text = 'List item' },
          },
        },
      }

      local result = blocks.get_block_text(block)

      assert.are.equal('List item', result)
    end)

    it('should extract text from to_do block', function()
      local block = {
        type = 'to_do',
        to_do = {
          rich_text = {
            { plain_text = 'Task to complete' },
          },
          checked = false,
        },
      }

      local result = blocks.get_block_text(block)

      assert.are.equal('Task to complete', result)
    end)
  end)
end)
