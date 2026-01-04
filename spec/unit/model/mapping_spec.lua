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

  describe('refresh_line_ranges with deletion detection', function()
    -- Helper to create typed mock block with proper format method
    local function create_typed_block(id, block_type, content)
      local block = {
        id = id,
        type = block_type,
        content = content or '',
        editable = block_type ~= 'divider' and block_type ~= 'toggle',
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
          if self.type == 'divider' then
            return { '---' }
          elseif self.type == 'heading_1' then
            return { '# ' .. (self.content or '') }
          elseif self.type == 'heading_2' then
            return { '## ' .. (self.content or '') }
          elseif self.type == 'heading_3' then
            return { '### ' .. (self.content or '') }
          elseif self.type == 'paragraph' then
            return { self.content or '' }
          elseif self.type == 'quote' then
            return { '| ' .. (self.content or '') }
          elseif self.type == 'bulleted_list_item' then
            return { '- ' .. (self.content or '') }
          elseif self.type == 'code' then
            return { '```lua', self.content or '', '```' }
          else
            return { self.content or '' }
          end
        end,
      }
      return block
    end

    it('should update line ranges from extmark positions', function()
      -- Setup: paragraph, divider, paragraph
      local blocks = {
        create_typed_block('para1', 'paragraph', 'First paragraph'),
        create_typed_block('div1', 'divider'),
        create_typed_block('para2', 'paragraph', 'Second paragraph'),
      }

      -- Set initial buffer content
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        'First paragraph',
        '---',
        'Second paragraph',
      })

      mapping.setup(bufnr, blocks)
      -- Setup extmarks (header_lines = 0)
      mapping.setup_extmarks(bufnr, 0)

      -- Verify initial line ranges
      local start1, end1 = blocks[1]:get_line_range()
      assert.are.equal(1, start1)
      assert.are.equal(1, end1)

      local start2, end2 = blocks[2]:get_line_range()
      assert.are.equal(2, start2)
      assert.are.equal(2, end2)

      local start3, end3 = blocks[3]:get_line_range()
      assert.are.equal(3, start3)
      assert.are.equal(3, end3)

      -- Simulate user editing: delete the divider line (line 2)
      vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, {})

      -- Refresh line ranges from extmarks
      mapping.refresh_line_ranges(bufnr)

      -- Check results - extmarks should have tracked the deletion
      start1, end1 = blocks[1]:get_line_range()
      start2, end2 = blocks[2]:get_line_range()
      start3, end3 = blocks[3]:get_line_range()

      -- First paragraph should still be at line 1
      assert.are.equal(1, start1)
      assert.are.equal(1, end1)

      -- Divider's extmark should have collapsed or moved
      -- The exact behavior depends on extmark gravity settings
      -- With end_right_gravity = false, the extmark may collapse

      -- Second paragraph should now be at line 2 (moved up)
      assert.are.equal(2, start3)
      assert.are.equal(2, end3)
    end)

    it('should track heading block position after edit', function()
      local blocks = {
        create_typed_block('h1', 'heading_1', 'Title'),
        create_typed_block('para1', 'paragraph', 'Content'),
      }

      -- Set initial content
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '# Title',
        'Content',
      })

      mapping.setup(bufnr, blocks)
      mapping.setup_extmarks(bufnr, 0)

      -- Verify initial state
      local start1, end1 = blocks[1]:get_line_range()
      assert.are.equal(1, start1)
      assert.are.equal(1, end1)

      local start2, end2 = blocks[2]:get_line_range()
      assert.are.equal(2, start2)
      assert.are.equal(2, end2)

      -- Delete the heading line
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, {})

      mapping.refresh_line_ranges(bufnr)

      start1, end1 = blocks[1]:get_line_range()
      start2, end2 = blocks[2]:get_line_range()

      -- Paragraph should now be at line 1
      assert.are.equal(1, start2)
      assert.are.equal(1, end2)
    end)

    it('should maintain correct ranges when all blocks present', function()
      local blocks = {
        create_typed_block('para1', 'paragraph', 'First'),
        create_typed_block('div1', 'divider'),
        create_typed_block('para2', 'paragraph', 'Second'),
      }

      -- All blocks present
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        'First',
        '---',
        'Second',
      })

      mapping.setup(bufnr, blocks)
      mapping.setup_extmarks(bufnr, 0)

      -- Refresh should maintain correct ranges
      mapping.refresh_line_ranges(bufnr)

      local start1, end1 = blocks[1]:get_line_range()
      local start2, end2 = blocks[2]:get_line_range()
      local start3, end3 = blocks[3]:get_line_range()

      -- All should have valid ranges
      assert.are.equal(1, start1)
      assert.are.equal(1, end1)
      assert.are.equal(2, start2)
      assert.are.equal(2, end2)
      assert.are.equal(3, start3)
      assert.are.equal(3, end3)
    end)

    it('should mark divider as deleted when line content is not ---', function()
      local blocks = {
        create_typed_block('para1', 'paragraph', 'First'),
        create_typed_block('div1', 'divider'),
        create_typed_block('para2', 'paragraph', 'Second'),
      }

      -- Initial content with divider
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        'First',
        '---',
        'Second',
      })

      mapping.setup(bufnr, blocks)
      mapping.setup_extmarks(bufnr, 0)

      -- Delete the divider line using dd simulation
      vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, {})

      -- Refresh line ranges
      mapping.refresh_line_ranges(bufnr)

      -- Divider should have nil line range (marked as deleted)
      local div_start, div_end = blocks[2]:get_line_range()
      assert.is_nil(div_start)
      assert.is_nil(div_end)

      -- Other blocks should have valid ranges
      local start1, end1 = blocks[1]:get_line_range()
      local start3, end3 = blocks[3]:get_line_range()

      assert.are.equal(1, start1)
      assert.are.equal(1, end1)
      assert.are.equal(2, start3)
      assert.are.equal(2, end3)
    end)

    it('should not mark empty paragraphs as deleted when originally empty', function()
      -- Helper to create block with original_text tracking
      local function create_block_with_original(id, block_type, content)
        local block = create_typed_block(id, block_type, content)
        block.original_text = content or ''
        block.get_text = function(self)
          return self.content or ''
        end
        return block
      end

      local blocks = {
        create_block_with_original('para1', 'paragraph', 'Content'),
        create_block_with_original('para2', 'paragraph', ''), -- Empty paragraph
        create_block_with_original('para3', 'paragraph', 'More content'),
      }

      -- Buffer with empty line for empty paragraph
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        'Content',
        '',
        'More content',
      })

      mapping.setup(bufnr, blocks)
      mapping.setup_extmarks(bufnr, 0)

      -- Refresh - empty paragraph should NOT be marked as deleted
      mapping.refresh_line_ranges(bufnr)

      local start1, end1 = blocks[1]:get_line_range()
      local start2, end2 = blocks[2]:get_line_range()
      local start3, end3 = blocks[3]:get_line_range()

      -- All should have valid ranges (including empty paragraph)
      assert.are.equal(1, start1)
      assert.are.equal(1, end1)
      assert.are.equal(2, start2) -- Empty paragraph still has valid range
      assert.are.equal(2, end2)
      assert.are.equal(3, start3)
      assert.are.equal(3, end3)
    end)

    it('should detect divider deletion when extmarks overlap on same row', function()
      -- This tests the specific bug where divider and paragraph end up on same row
      local blocks = {
        create_typed_block('para1', 'paragraph', 'Before'),
        create_typed_block('div1', 'divider'),
        create_typed_block('para2', 'paragraph', 'After'),
      }

      -- Initial content
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        'Before',
        '---',
        'After',
      })

      mapping.setup(bufnr, blocks)
      mapping.setup_extmarks(bufnr, 0)

      -- Verify initial state
      local div_start_before, div_end_before = blocks[2]:get_line_range()
      assert.are.equal(2, div_start_before)

      -- Delete divider line - this causes extmarks to collapse
      vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, {})

      -- Now buffer is: "Before", "After" (2 lines)
      -- Both divider and para2 extmarks may point to row 1 (0-indexed)

      mapping.refresh_line_ranges(bufnr)

      -- Divider should be marked as deleted (line content is 'After', not '---')
      local div_start, div_end = blocks[2]:get_line_range()
      assert.is_nil(div_start, 'Divider should have nil start line after deletion')
      assert.is_nil(div_end, 'Divider should have nil end line after deletion')

      -- Para2 should have valid range at line 2
      local para2_start, para2_end = blocks[3]:get_line_range()
      assert.are.equal(2, para2_start)
      assert.are.equal(2, para2_end)
    end)
  end)
end)
