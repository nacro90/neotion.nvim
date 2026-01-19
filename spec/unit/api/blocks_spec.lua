describe('neotion.api.blocks', function()
  local blocks

  before_each(function()
    package.loaded['neotion.api.blocks'] = nil
    blocks = require('neotion.api.blocks')
  end)

  describe('_fetch_nested_children', function()
    it('should skip fetching when at max_depth', function()
      local test_blocks = {
        { id = 'block1', has_children = true },
      }
      local called = false

      -- At max depth, should not fetch children
      blocks._fetch_nested_children(test_blocks, 3, 3, function(err)
        called = true
        assert.is_nil(err)
      end)

      -- Callback should be called immediately
      assert.is_true(called)
      -- _children should not be set (no fetch happened)
      assert.is_nil(test_blocks[1]._children)
    end)

    it('should call callback immediately when no blocks have children', function()
      local test_blocks = {
        { id = 'block1', has_children = false },
        { id = 'block2', has_children = false },
      }
      local called = false

      blocks._fetch_nested_children(test_blocks, 3, 0, function(err)
        called = true
        assert.is_nil(err)
      end)

      assert.is_true(called)
    end)

    it('should call callback immediately for empty blocks array', function()
      local called = false

      blocks._fetch_nested_children({}, 3, 0, function(err)
        called = true
        assert.is_nil(err)
      end)

      assert.is_true(called)
    end)

    it('should skip child_page blocks even if has_children is true', function()
      -- child_page blocks have has_children=true but their children are
      -- the page content, which should only be fetched when that page is opened
      local test_blocks = {
        { id = 'page1', type = 'child_page', has_children = true, child_page = { title = 'Sub Page' } },
      }
      local called = false

      blocks._fetch_nested_children(test_blocks, 3, 0, function(err)
        called = true
        assert.is_nil(err)
      end)

      -- Should complete immediately without fetching
      assert.is_true(called)
      -- _children should NOT be set for child_page
      assert.is_nil(test_blocks[1]._children)
    end)

    it('should skip child_database blocks even if has_children is true', function()
      -- child_database blocks are similar - their children are database rows
      local test_blocks = {
        { id = 'db1', type = 'child_database', has_children = true, child_database = { title = 'My DB' } },
      }
      local called = false

      blocks._fetch_nested_children(test_blocks, 3, 0, function(err)
        called = true
        assert.is_nil(err)
      end)

      -- Should complete immediately without fetching
      assert.is_true(called)
      -- _children should NOT be set for child_database
      assert.is_nil(test_blocks[1]._children)
    end)
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
