describe('neotion.model.mapping', function()
  local mapping
  local bufnr

  -- Helper to create a mock block
  local function create_mock_block(id, block_type, text, editable)
    return {
      id = id,
      type = block_type,
      text = text or '',
      editable = editable ~= false,
      dirty = false,
      line_start = nil,
      line_end = nil,
      get_id = function(self)
        return self.id
      end,
      get_type = function(self)
        return self.type
      end,
      is_editable = function(self)
        return self.editable
      end,
      is_dirty = function(self)
        return self.dirty
      end,
      set_dirty = function(self, value)
        self.dirty = value
      end,
      set_line_range = function(self, start_line, end_line)
        self.line_start = start_line
        self.line_end = end_line
      end,
      get_line_range = function(self)
        return self.line_start, self.line_end
      end,
      contains_line = function(self, line)
        if not self.line_start or not self.line_end then
          return false
        end
        return line >= self.line_start and line <= self.line_end
      end,
      format = function(self)
        if self.text == '' then
          return { '' }
        end
        local lines = {}
        for line in (self.text .. '\n'):gmatch('([^\n]*)\n') do
          table.insert(lines, line)
        end
        return #lines > 0 and lines or { self.text }
      end,
    }
  end

  before_each(function()
    -- Clear module cache
    package.loaded['neotion.model.mapping'] = nil
    mapping = require('neotion.model.mapping')

    -- Create a test buffer
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'Header line 1',
      'Header line 2',
      '',
      'Paragraph 1',
      '',
      '# Heading 1',
      '',
      'Paragraph 2',
    })
  end)

  after_each(function()
    -- Clean up
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      mapping.clear(bufnr)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  describe('setup', function()
    it('should store blocks for buffer', function()
      local blocks = {
        create_mock_block('block1', 'paragraph', 'Paragraph 1'),
      }

      mapping.setup(bufnr, blocks)

      assert.is_true(mapping.has_blocks(bufnr))
    end)

    it('should clear previous blocks', function()
      local blocks1 = {
        create_mock_block('block1', 'paragraph', 'Text 1'),
        create_mock_block('block2', 'paragraph', 'Text 2'),
      }
      local blocks2 = {
        create_mock_block('block3', 'paragraph', 'Text 3'),
      }

      mapping.setup(bufnr, blocks1)
      mapping.setup(bufnr, blocks2)

      assert.are.equal(1, mapping.get_block_count(bufnr))
    end)
  end)

  describe('setup_extmarks', function()
    it('should set line ranges on blocks', function()
      local blocks = {
        create_mock_block('block1', 'paragraph', 'Paragraph 1'),
        create_mock_block('block2', 'heading_1', '# Heading 1'),
        create_mock_block('block3', 'paragraph', 'Paragraph 2'),
      }

      mapping.setup(bufnr, blocks)
      mapping.setup_extmarks(bufnr, 3) -- 3 header lines

      -- First block starts at line 4 (after 3 header lines)
      local start1, end1 = blocks[1]:get_line_range()
      assert.are.equal(4, start1)
      assert.are.equal(4, end1)
    end)

    it('should create extmarks for blocks', function()
      local blocks = {
        create_mock_block('block1', 'paragraph', 'Test'),
      }

      mapping.setup(bufnr, blocks)
      mapping.setup_extmarks(bufnr, 0)

      local ns_id = mapping.get_namespace()
      local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, {})

      assert.is_true(#extmarks > 0)
    end)
  end)

  describe('get_block_at_line', function()
    it('should return block at specific line', function()
      local blocks = {
        create_mock_block('block1', 'paragraph', 'First'),
        create_mock_block('block2', 'paragraph', 'Second'),
      }
      blocks[1]:set_line_range(1, 1)
      blocks[2]:set_line_range(2, 2)

      mapping.setup(bufnr, blocks)

      local block1 = mapping.get_block_at_line(bufnr, 1)
      local block2 = mapping.get_block_at_line(bufnr, 2)

      assert.are.equal('block1', block1:get_id())
      assert.are.equal('block2', block2:get_id())
    end)

    it('should return nil for line without block', function()
      local blocks = {
        create_mock_block('block1', 'paragraph', 'Test'),
      }
      blocks[1]:set_line_range(5, 5)

      mapping.setup(bufnr, blocks)

      local block = mapping.get_block_at_line(bufnr, 1)

      assert.is_nil(block)
    end)

    it('should return nil for buffer without blocks', function()
      local block = mapping.get_block_at_line(bufnr, 1)

      assert.is_nil(block)
    end)
  end)

  describe('get_block_by_id', function()
    it('should return block by ID', function()
      local blocks = {
        create_mock_block('block1', 'paragraph', 'First'),
        create_mock_block('block2', 'heading_1', 'Second'),
        create_mock_block('block3', 'paragraph', 'Third'),
      }

      mapping.setup(bufnr, blocks)

      local block = mapping.get_block_by_id(bufnr, 'block2')

      assert.are.equal('block2', block:get_id())
      assert.are.equal('heading_1', block:get_type())
    end)

    it('should return nil for unknown ID', function()
      local blocks = {
        create_mock_block('block1', 'paragraph', 'Test'),
      }

      mapping.setup(bufnr, blocks)

      local block = mapping.get_block_by_id(bufnr, 'nonexistent')

      assert.is_nil(block)
    end)
  end)

  describe('get_blocks', function()
    it('should return all blocks for buffer', function()
      local blocks = {
        create_mock_block('block1', 'paragraph'),
        create_mock_block('block2', 'paragraph'),
        create_mock_block('block3', 'paragraph'),
      }

      mapping.setup(bufnr, blocks)

      local result = mapping.get_blocks(bufnr)

      assert.are.equal(3, #result)
    end)

    it('should return empty array for buffer without blocks', function()
      local result = mapping.get_blocks(bufnr)

      assert.are.equal(0, #result)
    end)
  end)

  describe('get_dirty_blocks', function()
    it('should return only dirty blocks', function()
      local blocks = {
        create_mock_block('block1', 'paragraph'),
        create_mock_block('block2', 'paragraph'),
        create_mock_block('block3', 'paragraph'),
      }
      blocks[1]:set_dirty(true)
      blocks[3]:set_dirty(true)

      mapping.setup(bufnr, blocks)

      local dirty = mapping.get_dirty_blocks(bufnr)

      assert.are.equal(2, #dirty)
    end)

    it('should return empty array when no dirty blocks', function()
      local blocks = {
        create_mock_block('block1', 'paragraph'),
        create_mock_block('block2', 'paragraph'),
      }

      mapping.setup(bufnr, blocks)

      local dirty = mapping.get_dirty_blocks(bufnr)

      assert.are.equal(0, #dirty)
    end)
  end)

  describe('get_editable_blocks', function()
    it('should return only editable blocks', function()
      local blocks = {
        create_mock_block('block1', 'paragraph', '', true),
        create_mock_block('block2', 'toggle', '', false),
        create_mock_block('block3', 'heading_1', '', true),
      }

      mapping.setup(bufnr, blocks)

      local editable = mapping.get_editable_blocks(bufnr)

      assert.are.equal(2, #editable)
    end)

    it('should return empty array when no editable blocks', function()
      local blocks = {
        create_mock_block('block1', 'toggle', '', false),
        create_mock_block('block2', 'code', '', false),
      }

      mapping.setup(bufnr, blocks)

      local editable = mapping.get_editable_blocks(bufnr)

      assert.are.equal(0, #editable)
    end)
  end)

  describe('has_blocks', function()
    it('should return true when buffer has blocks', function()
      local blocks = { create_mock_block('block1', 'paragraph') }

      mapping.setup(bufnr, blocks)

      assert.is_true(mapping.has_blocks(bufnr))
    end)

    it('should return false when buffer has no blocks', function()
      assert.is_false(mapping.has_blocks(bufnr))
    end)

    it('should return false after clear', function()
      local blocks = { create_mock_block('block1', 'paragraph') }

      mapping.setup(bufnr, blocks)
      mapping.clear(bufnr)

      assert.is_false(mapping.has_blocks(bufnr))
    end)
  end)

  describe('get_block_count', function()
    it('should return correct block count', function()
      local blocks = {
        create_mock_block('block1', 'paragraph'),
        create_mock_block('block2', 'paragraph'),
        create_mock_block('block3', 'paragraph'),
      }

      mapping.setup(bufnr, blocks)

      assert.are.equal(3, mapping.get_block_count(bufnr))
    end)

    it('should return 0 for buffer without blocks', function()
      assert.are.equal(0, mapping.get_block_count(bufnr))
    end)
  end)

  describe('clear', function()
    it('should remove all blocks for buffer', function()
      local blocks = { create_mock_block('block1', 'paragraph') }

      mapping.setup(bufnr, blocks)
      mapping.clear(bufnr)

      assert.is_false(mapping.has_blocks(bufnr))
      assert.are.equal(0, mapping.get_block_count(bufnr))
    end)

    it('should clear extmarks', function()
      local blocks = { create_mock_block('block1', 'paragraph', 'Test') }

      mapping.setup(bufnr, blocks)
      mapping.setup_extmarks(bufnr, 0)
      mapping.clear(bufnr)

      local ns_id = mapping.get_namespace()
      local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, {})

      assert.are.equal(0, #extmarks)
    end)

    it('should not fail for buffer without blocks', function()
      -- Should not throw
      mapping.clear(bufnr)
    end)
  end)

  describe('get_namespace', function()
    it('should return a valid namespace ID', function()
      local ns_id = mapping.get_namespace()

      assert.is_number(ns_id)
      assert.is_true(ns_id > 0)
    end)

    it('should return consistent namespace', function()
      local ns1 = mapping.get_namespace()
      local ns2 = mapping.get_namespace()

      assert.are.equal(ns1, ns2)
    end)
  end)

  describe('get_readonly_namespace', function()
    it('should return a valid namespace ID', function()
      local ns_id = mapping.get_readonly_namespace()

      assert.is_number(ns_id)
      assert.is_true(ns_id > 0)
    end)

    it('should be different from main namespace', function()
      local main_ns = mapping.get_namespace()
      local readonly_ns = mapping.get_readonly_namespace()

      assert.are_not.equal(main_ns, readonly_ns)
    end)
  end)
end)
