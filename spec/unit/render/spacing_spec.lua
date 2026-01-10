---Unit tests for block spacing (virtual lines)
describe('neotion.render spacing', function()
  local extmarks
  local mock_extmarks
  local extmark_calls

  before_each(function()
    extmark_calls = {}

    -- Mock extmarks module
    mock_extmarks = {
      NAMESPACE = 999,
      apply_virtual_lines = function(bufnr, line, count)
        table.insert(extmark_calls, {
          type = 'virtual_lines',
          bufnr = bufnr,
          line = line,
          count = count,
        })
        return 1
      end,
      clear_line = function() end,
      clear_buffer = function() end,
    }

    package.loaded['neotion.render.extmarks'] = mock_extmarks
  end)

  after_each(function()
    package.loaded['neotion.render.extmarks'] = nil
    package.loaded['neotion.render.context'] = nil
    package.loaded['neotion.model.block'] = nil
    package.loaded['neotion.model.blocks.bulleted_list'] = nil
    package.loaded['neotion.model.blocks.numbered_list'] = nil
    package.loaded['neotion.model.blocks.heading'] = nil
  end)

  describe('extmarks.apply_virtual_lines', function()
    it('should return -1 for zero count', function()
      package.loaded['neotion.render.extmarks'] = nil
      extmarks = require('neotion.render.extmarks')

      local result = extmarks.apply_virtual_lines(1, 0, 0)
      assert.equals(-1, result)
    end)

    it('should return -1 for negative count', function()
      package.loaded['neotion.render.extmarks'] = nil
      extmarks = require('neotion.render.extmarks')

      local result = extmarks.apply_virtual_lines(1, 0, -1)
      assert.equals(-1, result)
    end)
  end)

  describe('extmarks namespaces', function()
    it('should have separate namespace for virtual lines', function()
      package.loaded['neotion.render.extmarks'] = nil
      extmarks = require('neotion.render.extmarks')

      assert.is_not_nil(extmarks.NAMESPACE)
      assert.is_not_nil(extmarks.VIRT_LINES_NAMESPACE)
      assert.are_not.equal(extmarks.NAMESPACE, extmarks.VIRT_LINES_NAMESPACE)
    end)

    it('should have clear_virtual_lines function', function()
      package.loaded['neotion.render.extmarks'] = nil
      extmarks = require('neotion.render.extmarks')

      assert.is_function(extmarks.clear_virtual_lines)
    end)
  end)

  describe('RenderContext:virtual_lines', function()
    it('should call apply_virtual_lines with correct args', function()
      local context = require('neotion.render.context')
      local ctx = context.RenderContext.new(1, 5, {})

      ctx:virtual_lines(2)

      assert.equals(1, #extmark_calls)
      local call = extmark_calls[1]
      assert.equals('virtual_lines', call.type)
      assert.equals(1, call.bufnr)
      assert.equals(5, call.line)
      assert.equals(2, call.count)
    end)

    it('should not call for zero count', function()
      local context = require('neotion.render.context')
      local ctx = context.RenderContext.new(1, 5, {})

      ctx:virtual_lines(0)

      assert.equals(0, #extmark_calls)
    end)

    it('should not call for negative count', function()
      local context = require('neotion.render.context')
      local ctx = context.RenderContext.new(1, 5, {})

      ctx:virtual_lines(-1)

      assert.equals(0, #extmark_calls)
    end)
  end)

  describe('Block:spacing_after', function()
    it('should return 1 for base Block', function()
      package.loaded['neotion.model.block'] = nil
      local block_mod = require('neotion.model.block')
      local block = block_mod.Block.new({ id = 'test', type = 'unsupported' })

      assert.equals(1, block:spacing_after())
    end)
  end)

  describe('Block:spacing_before', function()
    it('should return 0 for base Block', function()
      package.loaded['neotion.model.block'] = nil
      local block_mod = require('neotion.model.block')
      local block = block_mod.Block.new({ id = 'test', type = 'unsupported' })

      assert.equals(0, block:spacing_before())
    end)
  end)

  describe('Block:is_list_item', function()
    it('should return true for bulleted_list_item', function()
      package.loaded['neotion.model.block'] = nil
      local block_mod = require('neotion.model.block')
      local block = block_mod.Block.new({ id = 'test', type = 'bulleted_list_item' })

      assert.is_true(block:is_list_item())
    end)

    it('should return true for numbered_list_item', function()
      package.loaded['neotion.model.block'] = nil
      local block_mod = require('neotion.model.block')
      local block = block_mod.Block.new({ id = 'test', type = 'numbered_list_item' })

      assert.is_true(block:is_list_item())
    end)

    it('should return false for paragraph', function()
      package.loaded['neotion.model.block'] = nil
      local block_mod = require('neotion.model.block')
      local block = block_mod.Block.new({ id = 'test', type = 'paragraph' })

      assert.is_false(block:is_list_item())
    end)

    it('should return false for heading', function()
      package.loaded['neotion.model.block'] = nil
      local block_mod = require('neotion.model.block')
      local block = block_mod.Block.new({ id = 'test', type = 'heading_1' })

      assert.is_false(block:is_list_item())
    end)
  end)

  describe('BulletedListBlock:spacing_after', function()
    it('should return 0 (grouped with other list items)', function()
      package.loaded['neotion.model.blocks.bulleted_list'] = nil
      local bulleted = require('neotion.model.blocks.bulleted_list')
      local block = bulleted.new({
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = { rich_text = {} },
      })

      assert.equals(0, block:spacing_after())
    end)
  end)

  describe('NumberedListBlock:spacing_after', function()
    it('should return 0 (grouped with other list items)', function()
      package.loaded['neotion.model.blocks.numbered_list'] = nil
      local numbered = require('neotion.model.blocks.numbered_list')
      local block = numbered.new({
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = { rich_text = {} },
      })

      assert.equals(0, block:spacing_after())
    end)
  end)

  describe('HeadingBlock:spacing_before', function()
    it('should return 1 for heading_1', function()
      package.loaded['neotion.model.blocks.heading'] = nil
      local heading = require('neotion.model.blocks.heading')
      local block = heading.new({
        id = 'test',
        type = 'heading_1',
        heading_1 = { rich_text = {} },
      })

      assert.equals(1, block:spacing_before())
    end)

    it('should return 0 for heading_2', function()
      package.loaded['neotion.model.blocks.heading'] = nil
      local heading = require('neotion.model.blocks.heading')
      local block = heading.new({
        id = 'test',
        type = 'heading_2',
        heading_2 = { rich_text = {} },
      })

      assert.equals(0, block:spacing_before())
    end)

    it('should return 0 for heading_3', function()
      package.loaded['neotion.model.blocks.heading'] = nil
      local heading = require('neotion.model.blocks.heading')
      local block = heading.new({
        id = 'test',
        type = 'heading_3',
        heading_3 = { rich_text = {} },
      })

      assert.equals(0, block:spacing_before())
    end)
  end)

  describe('Block:is_empty_paragraph', function()
    it('should return false for base Block (not a paragraph)', function()
      package.loaded['neotion.model.block'] = nil
      local block_mod = require('neotion.model.block')
      local block = block_mod.Block.new({ id = 'test', type = 'heading_1' })

      assert.is_false(block:is_empty_paragraph())
    end)

    it('should return false for paragraph type with text (base Block)', function()
      package.loaded['neotion.model.block'] = nil
      local block_mod = require('neotion.model.block')
      local block = block_mod.Block.new({ id = 'test', type = 'paragraph' })

      -- Base Block:get_text() returns '', but type is paragraph
      -- So this checks type but doesn't have access to actual text
      -- The base implementation should be: type == 'paragraph' AND get_text() == ''
      assert.is_false(block:is_empty_paragraph()) -- Base Block's get_text() returns ''
    end)
  end)

  describe('ParagraphBlock:is_empty_paragraph', function()
    it('should return true when text is empty', function()
      package.loaded['neotion.model.blocks.paragraph'] = nil
      local paragraph = require('neotion.model.blocks.paragraph')
      local block = paragraph.new({
        id = 'test',
        type = 'paragraph',
        paragraph = { rich_text = {} },
      })

      assert.is_true(block:is_empty_paragraph())
    end)

    it('should return false when text is non-empty', function()
      package.loaded['neotion.model.blocks.paragraph'] = nil
      local paragraph = require('neotion.model.blocks.paragraph')
      local block = paragraph.new({
        id = 'test',
        type = 'paragraph',
        paragraph = {
          rich_text = {
            { plain_text = 'Hello world' },
          },
        },
      })

      assert.is_false(block:is_empty_paragraph())
    end)

    it('should return false when text is whitespace only', function()
      package.loaded['neotion.model.blocks.paragraph'] = nil
      local paragraph = require('neotion.model.blocks.paragraph')
      local block = paragraph.new({
        id = 'test',
        type = 'paragraph',
        paragraph = {
          rich_text = {
            { plain_text = '   ' },
          },
        },
      })

      -- Whitespace-only is not considered empty (could be intentional spacing)
      assert.is_false(block:is_empty_paragraph())
    end)
  end)

  describe('Empty paragraph spacing optimization', function()
    -- Mock modules for spacing tests
    local function setup_spacing_mocks()
      -- Mock mapping module
      local mock_blocks = {}
      package.loaded['neotion.model.mapping'] = {
        get_blocks = function()
          return mock_blocks
        end,
        detect_orphan_lines = function()
          return {}
        end,
      }

      -- Mock buffer module
      package.loaded['neotion.buffer'] = {
        get_data = function()
          return { header_line_count = 6 }
        end,
      }

      return mock_blocks
    end

    after_each(function()
      package.loaded['neotion.model.mapping'] = nil
      package.loaded['neotion.buffer'] = nil
      package.loaded['neotion.model.blocks.paragraph'] = nil
      package.loaded['neotion.render.init'] = nil
    end)

    it('should not add spacing before empty paragraph', function()
      local mock_blocks = setup_spacing_mocks()

      -- Create blocks: paragraph -> empty paragraph
      local paragraph = require('neotion.model.blocks.paragraph')
      local block1 = paragraph.new({
        id = 'block1',
        type = 'paragraph',
        paragraph = { rich_text = { { plain_text = 'First block' } } },
      })
      block1:set_line_range(1, 1)

      local block2 = paragraph.new({
        id = 'block2',
        type = 'paragraph',
        paragraph = { rich_text = {} }, -- Empty
      })
      block2:set_line_range(2, 2)

      mock_blocks[1] = block1
      mock_blocks[2] = block2

      -- Apply spacing
      local render = require('neotion.render.init')
      render.apply_block_spacing(1)

      -- Check: block1 should have spacing = 0 (because next is empty paragraph)
      -- Find the virtual_lines call for line 0 (block1 end, 0-indexed)
      local found_block1_spacing = false
      for _, call in ipairs(extmark_calls) do
        if call.type == 'virtual_lines' and call.line == 0 then
          found_block1_spacing = true
          -- Should NOT have spacing (call shouldn't exist)
          assert.fail('Block before empty paragraph should have NO spacing')
        end
      end

      -- Ensure we checked (if no call found, that's correct behavior)
      assert.is_false(found_block1_spacing)
    end)

    it('should add spacing after empty paragraph', function()
      local mock_blocks = setup_spacing_mocks()

      local paragraph = require('neotion.model.blocks.paragraph')

      -- Create blocks: empty paragraph -> normal paragraph
      local block1 = paragraph.new({
        id = 'block1',
        type = 'paragraph',
        paragraph = { rich_text = {} }, -- Empty
      })
      block1:set_line_range(1, 1)

      local block2 = paragraph.new({
        id = 'block2',
        type = 'paragraph',
        paragraph = { rich_text = { { plain_text = 'Second block' } } },
      })
      block2:set_line_range(2, 2)

      mock_blocks[1] = block1
      mock_blocks[2] = block2

      -- Apply spacing
      local render = require('neotion.render.init')
      render.apply_block_spacing(1)

      -- Check: block1 (empty paragraph) should have spacing = 1 after
      local found = false
      for _, call in ipairs(extmark_calls) do
        if call.type == 'virtual_lines' and call.line == 0 then -- block1 end (0-indexed)
          found = true
          assert.equals(1, call.count)
        end
      end
      assert.is_true(found, 'Empty paragraph should have spacing after')
    end)

    it('should handle consecutive empty paragraphs', function()
      local mock_blocks = setup_spacing_mocks()

      local paragraph = require('neotion.model.blocks.paragraph')

      -- paragraph -> empty1 -> empty2 -> paragraph
      local block1 = paragraph.new({
        id = 'block1',
        type = 'paragraph',
        paragraph = { rich_text = { { plain_text = 'First' } } },
      })
      block1:set_line_range(1, 1)

      local block2 = paragraph.new({
        id = 'block2',
        type = 'paragraph',
        paragraph = { rich_text = {} },
      })
      block2:set_line_range(2, 2)

      local block3 = paragraph.new({
        id = 'block3',
        type = 'paragraph',
        paragraph = { rich_text = {} },
      })
      block3:set_line_range(3, 3)

      local block4 = paragraph.new({
        id = 'block4',
        type = 'paragraph',
        paragraph = { rich_text = { { plain_text = 'Last' } } },
      })
      block4:set_line_range(4, 4)

      mock_blocks[1] = block1
      mock_blocks[2] = block2
      mock_blocks[3] = block3
      mock_blocks[4] = block4

      local render = require('neotion.render.init')
      render.apply_block_spacing(1)

      -- block1 -> empty1: no spacing (0)
      -- empty1 -> empty2: no spacing (0)
      -- empty2 -> paragraph: spacing (1)
      local spacing_map = {}
      for _, call in ipairs(extmark_calls) do
        if call.type == 'virtual_lines' then
          spacing_map[call.line] = call.count
        end
      end

      -- Line 0 (block1): no spacing
      assert.is_nil(spacing_map[0])
      -- Line 1 (block2/empty1): no spacing
      assert.is_nil(spacing_map[1])
      -- Line 2 (block3/empty2): spacing = 1
      assert.equals(1, spacing_map[2])
    end)

    it('should handle empty paragraph at buffer start', function()
      local mock_blocks = setup_spacing_mocks()

      local paragraph = require('neotion.model.blocks.paragraph')

      -- empty paragraph -> normal paragraph
      local block1 = paragraph.new({
        id = 'block1',
        type = 'paragraph',
        paragraph = { rich_text = {} },
      })
      block1:set_line_range(1, 1)

      local block2 = paragraph.new({
        id = 'block2',
        type = 'paragraph',
        paragraph = { rich_text = { { plain_text = 'Second' } } },
      })
      block2:set_line_range(2, 2)

      mock_blocks[1] = block1
      mock_blocks[2] = block2

      local render = require('neotion.render.init')
      render.apply_block_spacing(1)

      -- Empty paragraph at start should have spacing after
      local found = false
      for _, call in ipairs(extmark_calls) do
        if call.type == 'virtual_lines' and call.line == 0 then
          found = true
          assert.equals(1, call.count)
        end
      end
      assert.is_true(found)
    end)

    it('should handle empty paragraph at buffer end', function()
      local mock_blocks = setup_spacing_mocks()

      local paragraph = require('neotion.model.blocks.paragraph')

      -- normal paragraph -> empty paragraph (end)
      local block1 = paragraph.new({
        id = 'block1',
        type = 'paragraph',
        paragraph = { rich_text = { { plain_text = 'First' } } },
      })
      block1:set_line_range(1, 1)

      local block2 = paragraph.new({
        id = 'block2',
        type = 'paragraph',
        paragraph = { rich_text = {} },
      })
      block2:set_line_range(2, 2)

      mock_blocks[1] = block1
      mock_blocks[2] = block2

      local render = require('neotion.render.init')
      render.apply_block_spacing(1)

      -- block1 should have NO spacing (next is empty paragraph)
      local found_block1 = false
      for _, call in ipairs(extmark_calls) do
        if call.type == 'virtual_lines' and call.line == 0 then
          found_block1 = true
        end
      end
      assert.is_false(found_block1)

      -- block2 (empty at end) should have spacing = 1
      local found_block2 = false
      for _, call in ipairs(extmark_calls) do
        if call.type == 'virtual_lines' and call.line == 1 then
          found_block2 = true
          assert.equals(1, call.count)
        end
      end
      assert.is_true(found_block2)
    end)

    it('should handle empty orphan line after last block', function()
      local mock_blocks = setup_spacing_mocks()

      -- Override mapping to return empty orphan line
      package.loaded['neotion.model.mapping'] = {
        get_blocks = function()
          return mock_blocks
        end,
        detect_orphan_lines = function()
          return { { start_line = 2, end_line = 2 } }
        end,
      }

      -- Mock buffer module with header
      package.loaded['neotion.buffer'] = {
        get_data = function()
          return { header_line_count = 6 }
        end,
      }

      -- Mock vim.api functions
      local original_get_lines = vim.api.nvim_buf_get_lines
      local original_line_count = vim.api.nvim_buf_line_count

      vim.api.nvim_buf_get_lines = function(bufnr, start, end_line, strict)
        if start == 1 and end_line == 2 then
          return { '' } -- Empty orphan line
        end
        return original_get_lines(bufnr, start, end_line, strict)
      end

      vim.api.nvim_buf_line_count = function(bufnr)
        return 2 -- Block at line 1, empty orphan at line 2
      end

      local paragraph = require('neotion.model.blocks.paragraph')

      -- Last block with empty orphan after
      local block1 = paragraph.new({
        id = 'block1',
        type = 'paragraph',
        paragraph = { rich_text = { { plain_text = 'Last block' } } },
      })
      block1:set_line_range(1, 1)

      mock_blocks[1] = block1

      local render = require('neotion.render.init')
      render.apply_block_spacing(1)

      -- block1 should have NO spacing (next is empty orphan)
      local found_block1 = false
      for _, call in ipairs(extmark_calls) do
        if call.type == 'virtual_lines' and call.line == 0 then
          found_block1 = true
        end
      end
      assert.is_false(found_block1, 'Block before empty orphan should have NO spacing')

      -- orphan line should have spacing = 1
      local found_orphan = false
      for _, call in ipairs(extmark_calls) do
        if call.type == 'virtual_lines' and call.line == 1 then
          found_orphan = true
          assert.equals(1, call.count)
        end
      end
      assert.is_true(found_orphan, 'Empty orphan should have spacing after')

      -- Restore original functions
      vim.api.nvim_buf_get_lines = original_get_lines
      vim.api.nvim_buf_line_count = original_line_count
    end)

    it('should handle empty orphan line between two blocks', function()
      local mock_blocks = setup_spacing_mocks()

      -- Override mapping to return two blocks with orphan between
      package.loaded['neotion.model.mapping'] = {
        get_blocks = function()
          return mock_blocks
        end,
        detect_orphan_lines = function()
          return { { start_line = 2, end_line = 2 } }
        end,
      }

      -- Mock buffer module with header
      package.loaded['neotion.buffer'] = {
        get_data = function()
          return { header_line_count = 6 }
        end,
      }

      -- Mock vim.api functions
      local original_get_lines = vim.api.nvim_buf_get_lines
      local original_line_count = vim.api.nvim_buf_line_count

      vim.api.nvim_buf_get_lines = function(bufnr, start, end_line, strict)
        if start == 1 and end_line == 2 then
          return { '' } -- Empty orphan line at line 2
        end
        return original_get_lines(bufnr, start, end_line, strict)
      end

      vim.api.nvim_buf_line_count = function(bufnr)
        return 3 -- Block1 at line 1, orphan at line 2, block2 at line 3
      end

      local paragraph = require('neotion.model.blocks.paragraph')

      -- First block
      local block1 = paragraph.new({
        id = 'block1',
        type = 'paragraph',
        paragraph = { rich_text = { { plain_text = 'First block' } } },
      })
      block1:set_line_range(1, 1)

      -- Second block (after orphan)
      local block2 = paragraph.new({
        id = 'block2',
        type = 'paragraph',
        paragraph = { rich_text = { { plain_text = 'Second block' } } },
      })
      block2:set_line_range(3, 3)

      mock_blocks[1] = block1
      mock_blocks[2] = block2

      local render = require('neotion.render.init')
      render.apply_block_spacing(1)

      -- block1 should have NO spacing (next is empty orphan at line 2)
      local found_block1 = false
      for _, call in ipairs(extmark_calls) do
        if call.type == 'virtual_lines' and call.line == 0 then
          found_block1 = true
        end
      end
      assert.is_false(found_block1, 'Block before empty orphan should have NO spacing')

      -- Empty orphan should have NO spacing (we don't know what block type it will become)
      local found_orphan = false
      for _, call in ipairs(extmark_calls) do
        if call.type == 'virtual_lines' and call.line == 1 then
          found_orphan = true
        end
      end
      assert.is_false(found_orphan, 'Empty orphan should have NO spacing')

      -- block2 should have spacing = 1 (normal spacing after empty orphan)
      local found_block2 = false
      for _, call in ipairs(extmark_calls) do
        if call.type == 'virtual_lines' and call.line == 2 then
          found_block2 = true
          assert.equals(1, call.count)
        end
      end
      assert.is_true(found_block2, 'Block after orphan should have normal spacing')

      -- Restore original functions
      vim.api.nvim_buf_get_lines = original_get_lines
      vim.api.nvim_buf_line_count = original_line_count
    end)
  end)
end)
