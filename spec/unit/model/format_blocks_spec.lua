describe('neotion.model.format_blocks', function()
  local model

  before_each(function()
    -- Clear module caches
    for k in pairs(package.loaded) do
      if k:match('^neotion%.') then
        package.loaded[k] = nil
      end
    end
    model = require('neotion.model')
  end)

  -- Helper to create a mock numbered list block
  local function make_numbered_block(text)
    local block = {
      type = 'numbered_list_item',
      number = 1,
    }

    function block:format()
      return { tostring(self.number) .. '. ' .. text }
    end

    function block:set_number(n)
      self.number = n
    end

    return block
  end

  -- Helper to create a mock paragraph block
  local function make_paragraph_block(text)
    local block = {
      type = 'paragraph',
    }

    function block:format()
      return { text }
    end

    return block
  end

  -- Helper to create a mock bulleted list block
  local function make_bulleted_block(text)
    local block = {
      type = 'bulleted_list_item',
    }

    function block:format()
      return { '- ' .. text }
    end

    return block
  end

  describe('numbered list sequencing', function()
    it('should number consecutive numbered_list_items sequentially', function()
      local blocks = {
        make_numbered_block('First'),
        make_numbered_block('Second'),
        make_numbered_block('Third'),
      }

      local lines = model.format_blocks(blocks)

      assert.are.equal(3, #lines)
      assert.are.equal('1. First', lines[1])
      assert.are.equal('2. Second', lines[2])
      assert.are.equal('3. Third', lines[3])
    end)

    it('should restart numbering after paragraph block', function()
      local blocks = {
        make_numbered_block('First'),
        make_numbered_block('Second'),
        make_paragraph_block('Break paragraph'),
        make_numbered_block('New first'),
        make_numbered_block('New second'),
      }

      local lines = model.format_blocks(blocks)

      assert.are.equal(5, #lines)
      assert.are.equal('1. First', lines[1])
      assert.are.equal('2. Second', lines[2])
      assert.are.equal('Break paragraph', lines[3])
      assert.are.equal('1. New first', lines[4])
      assert.are.equal('2. New second', lines[5])
    end)

    it('should restart numbering after bulleted list', function()
      local blocks = {
        make_numbered_block('First'),
        make_numbered_block('Second'),
        make_bulleted_block('Bullet'),
        make_numbered_block('New first'),
      }

      local lines = model.format_blocks(blocks)

      assert.are.equal(4, #lines)
      assert.are.equal('1. First', lines[1])
      assert.are.equal('2. Second', lines[2])
      assert.are.equal('- Bullet', lines[3])
      assert.are.equal('1. New first', lines[4])
    end)

    it('should handle single numbered item', function()
      local blocks = {
        make_numbered_block('Only one'),
      }

      local lines = model.format_blocks(blocks)

      assert.are.equal(1, #lines)
      assert.are.equal('1. Only one', lines[1])
    end)

    it('should handle multiple separate numbered lists', function()
      local blocks = {
        make_numbered_block('List 1 Item 1'),
        make_numbered_block('List 1 Item 2'),
        make_paragraph_block('Separator'),
        make_numbered_block('List 2 Item 1'),
        make_numbered_block('List 2 Item 2'),
        make_numbered_block('List 2 Item 3'),
        make_paragraph_block('Another separator'),
        make_numbered_block('List 3 Item 1'),
      }

      local lines = model.format_blocks(blocks)

      assert.are.equal(8, #lines)
      assert.are.equal('1. List 1 Item 1', lines[1])
      assert.are.equal('2. List 1 Item 2', lines[2])
      assert.are.equal('Separator', lines[3])
      assert.are.equal('1. List 2 Item 1', lines[4])
      assert.are.equal('2. List 2 Item 2', lines[5])
      assert.are.equal('3. List 2 Item 3', lines[6])
      assert.are.equal('Another separator', lines[7])
      assert.are.equal('1. List 3 Item 1', lines[8])
    end)
  end)
end)
