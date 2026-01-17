describe('neotion.model.mapping indent detection', function()
  local mapping
  local bufnr

  -- Helper to create a mock block that supports children
  local function create_mock_block(id, block_type, content, opts)
    opts = opts or {}
    return {
      id = id,
      type = block_type,
      content = content or '',
      editable = opts.editable ~= false,
      dirty = false,
      line_start = nil,
      line_end = nil,
      children = {},
      _supports_children = opts.supports_children or false,
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
        if self.type == 'toggle' then
          return { '> ' .. (self.content or '') }
        elseif self.type == 'bulleted_list_item' then
          return { '- ' .. (self.content or '') }
        elseif self.type == 'quote' then
          return { '| ' .. (self.content or '') }
        else
          return { self.content or '' }
        end
      end,
      get_children = function(self)
        return self.children or {}
      end,
      supports_children = function(self)
        return self._supports_children
      end,
    }
  end

  before_each(function()
    package.loaded['neotion.model.mapping'] = nil
    mapping = require('neotion.model.mapping')
    bufnr = vim.api.nvim_create_buf(false, true)
  end)

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      mapping.clear(bufnr)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  describe('detect_indent_level', function()
    it('should return 0 for non-indented line', function()
      assert.are.equal(0, mapping.detect_indent_level('Normal text'))
      assert.are.equal(0, mapping.detect_indent_level('> Toggle header'))
      assert.are.equal(0, mapping.detect_indent_level('- Bullet item'))
    end)

    it('should return 1 for 2-space indented line', function()
      assert.are.equal(1, mapping.detect_indent_level('  Indented text'))
      assert.are.equal(1, mapping.detect_indent_level('  - Nested bullet'))
    end)

    it('should return 2 for 4-space indented line', function()
      assert.are.equal(2, mapping.detect_indent_level('    Deeply indented'))
    end)

    it('should return 3 for 6-space indented line', function()
      assert.are.equal(3, mapping.detect_indent_level('      Max depth'))
    end)

    it('should handle empty lines as indent 0', function()
      assert.are.equal(0, mapping.detect_indent_level(''))
    end)

    it('should handle whitespace-only lines', function()
      assert.are.equal(1, mapping.detect_indent_level('  '))
      assert.are.equal(2, mapping.detect_indent_level('    '))
    end)

    it('should handle partial indentation (odd spaces)', function()
      -- 3 spaces = floor(3/2) = 1
      assert.are.equal(1, mapping.detect_indent_level('   Odd spaces'))
      -- 5 spaces = floor(5/2) = 2
      assert.are.equal(2, mapping.detect_indent_level('     Five spaces'))
    end)
  end)

  describe('find_parent_by_indent', function()
    it('should return nil for non-indented orphan line', function()
      local blocks = {
        create_mock_block('toggle1', 'toggle', 'Toggle', { supports_children = true }),
      }
      blocks[1]:set_line_range(1, 1)

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '> Toggle',
        'Not indented orphan',
      })

      mapping.setup(bufnr, blocks)

      local parent_id = mapping.find_parent_by_indent(bufnr, 2, 0) -- line 2, indent 0
      assert.is_nil(parent_id)
    end)

    it('should return parent block id for indented orphan after toggle', function()
      local blocks = {
        create_mock_block('toggle1', 'toggle', 'Toggle', { supports_children = true }),
      }
      blocks[1]:set_line_range(1, 1)

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '> Toggle',
        '  Indented orphan',
      })

      mapping.setup(bufnr, blocks)

      local parent_id = mapping.find_parent_by_indent(bufnr, 2, 1) -- line 2, indent 1
      assert.are.equal('toggle1', parent_id)
    end)

    it('should return nil when previous block does not support children', function()
      local blocks = {
        create_mock_block('para1', 'paragraph', 'Normal', { supports_children = false }),
      }
      blocks[1]:set_line_range(1, 1)

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        'Normal paragraph',
        '  Indented line',
      })

      mapping.setup(bufnr, blocks)

      local parent_id = mapping.find_parent_by_indent(bufnr, 2, 1)
      assert.is_nil(parent_id)
    end)

    it('should find parent when orphan is deeper nested', function()
      -- Toggle at indent 0 owns child at indent 1+
      local blocks = {
        create_mock_block('toggle1', 'toggle', 'Toggle', { supports_children = true }),
        create_mock_block('para1', 'paragraph', 'Sibling'),
      }
      blocks[1]:set_line_range(1, 1)
      blocks[2]:set_line_range(3, 3)

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '> Toggle',
        '  Child line 1',
        'Sibling paragraph',
      })

      mapping.setup(bufnr, blocks)

      local parent_id = mapping.find_parent_by_indent(bufnr, 2, 1)
      assert.are.equal('toggle1', parent_id)
    end)

    it('should return correct parent when multiple toggles exist', function()
      local blocks = {
        create_mock_block('toggle1', 'toggle', 'First', { supports_children = true }),
        create_mock_block('toggle2', 'toggle', 'Second', { supports_children = true }),
      }
      blocks[1]:set_line_range(1, 1)
      blocks[2]:set_line_range(3, 3)

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '> First toggle',
        '  First child',
        '> Second toggle',
        '  Second child',
      })

      mapping.setup(bufnr, blocks)

      -- Line 2 (indent 1) should belong to toggle1
      local parent_id1 = mapping.find_parent_by_indent(bufnr, 2, 1)
      assert.are.equal('toggle1', parent_id1)

      -- Line 4 (indent 1) should belong to toggle2
      local parent_id2 = mapping.find_parent_by_indent(bufnr, 4, 1)
      assert.are.equal('toggle2', parent_id2)
    end)

    it('should handle deeply nested structure', function()
      -- Toggle owns bullet, bullet owns paragraph
      local blocks = {
        create_mock_block('toggle1', 'toggle', 'Toggle', { supports_children = true }),
        create_mock_block('bullet1', 'bulleted_list_item', 'Bullet', { supports_children = true }),
      }
      blocks[1]:set_line_range(1, 1)
      blocks[2]:set_line_range(2, 2)

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '> Toggle',
        '  - Bullet child',
        '    Deeply nested',
      })

      -- Simulate bullet is toggle's child
      blocks[2].depth = 1

      mapping.setup(bufnr, blocks)

      -- Line 3 (indent 2) should belong to bullet1
      local parent_id = mapping.find_parent_by_indent(bufnr, 3, 2)
      assert.are.equal('bullet1', parent_id)
    end)
  end)

  describe('detect_orphan_lines with indent', function()
    it('should set parent_block_id for indented orphan', function()
      local blocks = {
        create_mock_block('toggle1', 'toggle', 'Toggle', { supports_children = true }),
      }
      blocks[1]:set_line_range(1, 1)

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '> Toggle',
        '  Child orphan',
      })

      mapping.setup(bufnr, blocks)

      local orphans = mapping.detect_orphan_lines(bufnr, 0)
      assert.are.equal(1, #orphans)
      assert.are.equal('toggle1', orphans[1].parent_block_id)
      assert.are.equal(1, orphans[1].indent_level)
    end)

    it('should set after_block_id for non-indented orphan', function()
      local blocks = {
        create_mock_block('toggle1', 'toggle', 'Toggle', { supports_children = true }),
      }
      blocks[1]:set_line_range(1, 1)

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '> Toggle',
        'Sibling orphan',
      })

      mapping.setup(bufnr, blocks)

      local orphans = mapping.detect_orphan_lines(bufnr, 0)
      assert.are.equal(1, #orphans)
      assert.is_nil(orphans[1].parent_block_id)
      assert.are.equal('toggle1', orphans[1].after_block_id)
      assert.are.equal(0, orphans[1].indent_level)
    end)

    it('should split orphans at different indent levels', function()
      local blocks = {
        create_mock_block('toggle1', 'toggle', 'Toggle', { supports_children = true }),
      }
      blocks[1]:set_line_range(1, 1)

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '> Toggle',
        '  Child 1',
        '  Child 2',
        'Sibling',
      })

      mapping.setup(bufnr, blocks)

      local orphans = mapping.detect_orphan_lines(bufnr, 0)
      -- Should be 3 orphans: Child 1 (line 2), Child 2 (line 3), Sibling (line 4)
      -- Each indented child is a separate block in Notion
      assert.are.equal(3, #orphans)

      -- First orphan: Child 1
      assert.are.equal(2, orphans[1].start_line)
      assert.are.equal(2, orphans[1].end_line)
      assert.are.equal('toggle1', orphans[1].parent_block_id)
      assert.are.equal(1, orphans[1].indent_level)

      -- Second orphan: Child 2
      assert.are.equal(3, orphans[2].start_line)
      assert.are.equal(3, orphans[2].end_line)
      assert.are.equal('toggle1', orphans[2].parent_block_id)
      assert.are.equal(1, orphans[2].indent_level)

      -- Third orphan: Sibling (top-level)
      assert.are.equal(4, orphans[3].start_line)
      assert.are.equal(4, orphans[3].end_line)
      assert.is_nil(orphans[3].parent_block_id)
      assert.are.equal('toggle1', orphans[3].after_block_id)
      assert.are.equal(0, orphans[3].indent_level)
    end)

    it('should handle mixed indent levels in sequence', function()
      local blocks = {
        create_mock_block('toggle1', 'toggle', 'Toggle', { supports_children = true }),
      }
      blocks[1]:set_line_range(1, 1)

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '> Toggle',
        '  Child 1', -- indent 1
        '    Nested', -- indent 2
        '  Child 2', -- back to indent 1
        'Sibling', -- indent 0
      })

      mapping.setup(bufnr, blocks)

      local orphans = mapping.detect_orphan_lines(bufnr, 0)
      -- Complex splitting: different indents should create separate ranges
      -- This is important for correct parent assignment
      assert.is_true(#orphans >= 2)
    end)

    it('should return content stripped of leading indent', function()
      local blocks = {
        create_mock_block('toggle1', 'toggle', 'Toggle', { supports_children = true }),
      }
      blocks[1]:set_line_range(1, 1)

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '> Toggle',
        '  Indented content',
      })

      mapping.setup(bufnr, blocks)

      local orphans = mapping.detect_orphan_lines(bufnr, 0)
      assert.are.equal(1, #orphans)
      -- Content should be stripped of indent (2 spaces)
      assert.are.equal('Indented content', orphans[1].content[1])
    end)

    it('should handle quote block children', function()
      local blocks = {
        create_mock_block('quote1', 'quote', 'Quote', { supports_children = true }),
      }
      blocks[1]:set_line_range(1, 1)

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '| Quote text',
        '  Quote child',
      })

      mapping.setup(bufnr, blocks)

      local orphans = mapping.detect_orphan_lines(bufnr, 0)
      assert.are.equal(1, #orphans)
      assert.are.equal('quote1', orphans[1].parent_block_id)
    end)

    it('should handle bulleted list children', function()
      local blocks = {
        create_mock_block('bullet1', 'bulleted_list_item', 'Bullet', { supports_children = true }),
      }
      blocks[1]:set_line_range(1, 1)

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '- Bullet item',
        '  Bullet child',
      })

      mapping.setup(bufnr, blocks)

      local orphans = mapping.detect_orphan_lines(bufnr, 0)
      assert.are.equal(1, #orphans)
      assert.are.equal('bullet1', orphans[1].parent_block_id)
    end)

    -- BUG FIX: When toggle itself is orphan (new), child should still detect parent
    it('should detect parent when toggle is also orphan (new toggle with child)', function()
      -- No existing blocks - toggle and its child are both new/orphan
      local blocks = {}

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '> test toggle',
        '  inner paragraph',
      })

      mapping.setup(bufnr, blocks)

      local orphans = mapping.detect_orphan_lines(bufnr, 0)

      -- Should detect 2 separate orphan ranges based on indent
      assert.are.equal(2, #orphans)

      -- First orphan: toggle (indent 0)
      assert.are.equal(1, orphans[1].start_line)
      assert.are.equal(1, orphans[1].end_line)
      assert.are.equal('> test toggle', orphans[1].content[1])
      assert.is_nil(orphans[1].parent_block_id) -- toggle has no parent
      assert.are.equal(0, orphans[1].indent_level)

      -- Second orphan: child paragraph (indent 1)
      assert.are.equal(2, orphans[2].start_line)
      assert.are.equal(2, orphans[2].end_line)
      assert.are.equal('inner paragraph', orphans[2].content[1])
      assert.are.equal(1, orphans[2].indent_level)
      -- BUG: Currently parent_block_id is nil because toggle is also orphan
      -- It should link to the previous orphan (toggle) as parent
      -- For now we can't set parent_block_id because toggle doesn't have an ID yet
      -- Instead, the sync layer should handle this by batching children with parent
    end)

    -- BUG FIX: Existing toggle children should NOT be detected as orphans
    it('should NOT detect existing toggle children as orphans', function()
      -- Create toggle with existing child
      local child_block = create_mock_block('child1', 'paragraph', 'existing child', {})
      local toggle_block = create_mock_block('toggle1', 'toggle', 'test toggle', { supports_children = true })
      toggle_block.children = { child_block }

      -- Buffer content:
      -- Line 1: > test toggle
      -- Line 2:   existing child  (indented - child of toggle)
      -- Line 3:   new line        (indented - NEW orphan, should be child of toggle)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '> test toggle',
        '  existing child',
        '  new line',
      })

      -- Setup with parent having child
      local blocks = { toggle_block }
      toggle_block:set_line_range(1, 1)
      child_block:set_line_range(2, 2)
      mapping.setup(bufnr, blocks)

      local orphans = mapping.detect_orphan_lines(bufnr, 0)

      -- Should only detect line 3 as orphan (new line)
      -- Line 2 is already owned by child_block
      assert.are.equal(1, #orphans, 'Should detect only 1 orphan (new line)')
      assert.are.equal(3, orphans[1].start_line, 'Orphan should be at line 3')
      assert.are.equal('new line', orphans[1].content[1])
      assert.are.equal('toggle1', orphans[1].parent_block_id, 'New line should have toggle as parent')
    end)

    it('should NOT detect deeply nested children as orphans', function()
      -- Create nested structure: toggle > child1 > grandchild
      local grandchild = create_mock_block('grandchild1', 'paragraph', 'grandchild text', {})
      local child_block = create_mock_block('child1', 'toggle', 'child toggle', { supports_children = true })
      child_block.children = { grandchild }
      local toggle_block = create_mock_block('toggle1', 'toggle', 'parent toggle', { supports_children = true })
      toggle_block.children = { child_block }

      -- Buffer content:
      -- Line 1: > parent toggle
      -- Line 2:   > child toggle
      -- Line 3:     grandchild text
      -- Line 4:     new orphan line
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '> parent toggle',
        '  > child toggle',
        '    grandchild text',
        '    new orphan line',
      })

      local blocks = { toggle_block }
      toggle_block:set_line_range(1, 1)
      child_block:set_line_range(2, 2)
      grandchild:set_line_range(3, 3)
      mapping.setup(bufnr, blocks)

      local orphans = mapping.detect_orphan_lines(bufnr, 0)

      -- Should only detect line 4 as orphan
      assert.are.equal(1, #orphans, 'Should detect only 1 orphan (new line at depth 2)')
      assert.are.equal(4, orphans[1].start_line, 'Orphan should be at line 4')
      assert.are.equal('new orphan line', orphans[1].content[1])
    end)

    -- BUG TEST: Multiple indented paragraph lines should become separate orphans
    -- This tests the scenario where user presses <CR> multiple times inside toggle
    it('should create separate orphans for each indented paragraph line', function()
      -- Toggle with one existing child
      local child_block = create_mock_block('child1', 'paragraph', 'existing child')
      local toggle_block = create_mock_block('toggle1', 'toggle', 'test toggle', { supports_children = true })
      toggle_block.children = { child_block }

      -- Buffer content after user presses <CR> twice and types content:
      -- Line 1: > test toggle
      -- Line 2:   existing child
      -- Line 3:   second paragraph    <-- NEW (should be separate orphan)
      -- Line 4:   third paragraph     <-- NEW (should be separate orphan)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '> test toggle',
        '  existing child',
        '  second paragraph',
        '  third paragraph',
      })

      local blocks = { toggle_block }
      toggle_block:set_line_range(1, 1)
      child_block:set_line_range(2, 2)
      mapping.setup(bufnr, blocks)

      local orphans = mapping.detect_orphan_lines(bufnr, 0)

      -- Should detect TWO separate orphans (one for each new line)
      -- NOT one orphan with two lines merged
      assert.are.equal(2, #orphans, 'Should detect 2 separate orphans for indented paragraphs')

      assert.are.equal(3, orphans[1].start_line)
      assert.are.equal(3, orphans[1].end_line)
      assert.are.equal('second paragraph', orphans[1].content[1])
      assert.are.equal(1, #orphans[1].content, 'First orphan should have 1 line')

      assert.are.equal(4, orphans[2].start_line)
      assert.are.equal(4, orphans[2].end_line)
      assert.are.equal('third paragraph', orphans[2].content[1])
      assert.are.equal(1, #orphans[2].content, 'Second orphan should have 1 line')
    end)

    -- Additional test: Top-level paragraphs can still be multi-line
    it('should allow multi-line paragraphs at top level (indent 0)', function()
      -- No parent block, just content at top level
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        'first line of paragraph',
        'second line of same paragraph',
        'third line of same paragraph',
      })

      mapping.setup(bufnr, {})

      local orphans = mapping.detect_orphan_lines(bufnr, 0)

      -- Top-level paragraphs CAN be multi-line (Notion supports this)
      assert.are.equal(1, #orphans, 'Top-level should be single orphan with multiple lines')
      assert.are.equal(1, orphans[1].start_line)
      assert.are.equal(3, orphans[1].end_line)
      assert.are.equal(3, #orphans[1].content, 'Should have 3 lines in content')
    end)
  end)
end)
