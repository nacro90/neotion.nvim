describe('neotion.model.blocks.heading', function()
  local heading_module

  before_each(function()
    package.loaded['neotion.model.blocks.heading'] = nil
    package.loaded['neotion.model.block'] = nil
    heading_module = require('neotion.model.blocks.heading')
  end)

  describe('HeadingBlock.new', function()
    it('should create heading_1 from raw JSON', function()
      local raw = {
        id = 'h1test',
        type = 'heading_1',
        heading_1 = {
          rich_text = { { plain_text = 'Main Title' } },
        },
      }

      local block = heading_module.new(raw)

      assert.are.equal('h1test', block:get_id())
      assert.are.equal('heading_1', block:get_type())
      assert.are.equal(1, block.level)
      assert.are.equal('Main Title', block:get_text())
    end)

    it('should create heading_2 from raw JSON', function()
      local raw = {
        id = 'h2test',
        type = 'heading_2',
        heading_2 = {
          rich_text = { { plain_text = 'Section' } },
        },
      }

      local block = heading_module.new(raw)

      assert.are.equal('heading_2', block:get_type())
      assert.are.equal(2, block.level)
      assert.are.equal('Section', block:get_text())
    end)

    it('should create heading_3 from raw JSON', function()
      local raw = {
        id = 'h3test',
        type = 'heading_3',
        heading_3 = {
          rich_text = { { plain_text = 'Subsection' } },
        },
      }

      local block = heading_module.new(raw)

      assert.are.equal('heading_3', block:get_type())
      assert.are.equal(3, block.level)
    end)

    it('should be marked as editable', function()
      local raw = {
        id = 'test',
        type = 'heading_1',
        heading_1 = { rich_text = {} },
      }

      local block = heading_module.new(raw)

      assert.is_true(block:is_editable())
    end)

    it('should extract plain text from multiple rich_text items', function()
      local raw = {
        id = 'test',
        type = 'heading_1',
        heading_1 = {
          rich_text = {
            { plain_text = 'Multi ' },
            { plain_text = 'word ' },
            { plain_text = 'title' },
          },
        },
      }

      local block = heading_module.new(raw)

      assert.are.equal('Multi word title', block:get_text())
    end)

    it('should preserve original rich_text for round-trip', function()
      local rich_text = {
        {
          type = 'text',
          plain_text = 'Styled Title',
          annotations = { bold = true, color = 'red' },
        },
      }
      local raw = {
        id = 'test',
        type = 'heading_1',
        heading_1 = { rich_text = rich_text },
      }

      local block = heading_module.new(raw)

      assert.are.same(rich_text, block.rich_text)
    end)
  end)

  describe('format', function()
    it('should format heading_1 with # prefix', function()
      local raw = {
        id = 'test',
        type = 'heading_1',
        heading_1 = { rich_text = { { plain_text = 'Title' } } },
      }
      local block = heading_module.new(raw)

      local lines = block:format()

      assert.are.equal(1, #lines)
      assert.are.equal('# Title', lines[1])
    end)

    it('should format heading_2 with ## prefix', function()
      local raw = {
        id = 'test',
        type = 'heading_2',
        heading_2 = { rich_text = { { plain_text = 'Section' } } },
      }
      local block = heading_module.new(raw)

      local lines = block:format()

      assert.are.equal('## Section', lines[1])
    end)

    it('should format heading_3 with ### prefix', function()
      local raw = {
        id = 'test',
        type = 'heading_3',
        heading_3 = { rich_text = { { plain_text = 'Subsection' } } },
      }
      local block = heading_module.new(raw)

      local lines = block:format()

      assert.are.equal('### Subsection', lines[1])
    end)

    it('should apply indent option', function()
      local raw = {
        id = 'test',
        type = 'heading_1',
        heading_1 = { rich_text = { { plain_text = 'Indented' } } },
      }
      local block = heading_module.new(raw)

      local lines = block:format({ indent = 1, indent_size = 2 })

      assert.are.equal('  # Indented', lines[1])
    end)
  end)

  describe('serialize', function()
    it('should preserve original rich_text when text unchanged', function()
      local original_rich_text = {
        {
          type = 'text',
          plain_text = 'Title',
          text = { content = 'Title' },
          annotations = { bold = true },
        },
      }
      local raw = {
        id = 'test',
        type = 'heading_1',
        heading_1 = { rich_text = original_rich_text },
      }
      local block = heading_module.new(raw)

      local serialized = block:serialize()

      assert.are.same(original_rich_text, serialized.heading_1.rich_text)
    end)

    it('should create plain rich_text when text changed', function()
      local raw = {
        id = 'test',
        type = 'heading_2',
        heading_2 = {
          rich_text = {
            {
              type = 'text',
              plain_text = 'Original',
              annotations = { bold = true },
            },
          },
        },
      }
      local block = heading_module.new(raw)

      block.text = 'Modified Title'

      local serialized = block:serialize()

      assert.are.equal('Modified Title', serialized.heading_2.rich_text[1].plain_text)
      assert.is_false(serialized.heading_2.rich_text[1].annotations.bold)
    end)

    it('should use correct heading key based on level', function()
      local raw = {
        id = 'test',
        type = 'heading_3',
        heading_3 = { rich_text = {} },
      }
      local block = heading_module.new(raw)
      block.text = 'New'

      local serialized = block:serialize()

      assert.is_not_nil(serialized.heading_3)
      assert.is_not_nil(serialized.heading_3.rich_text)
    end)

    it('should update type and key when level changes', function()
      local raw = {
        id = 'test',
        type = 'heading_1',
        heading_1 = { rich_text = { { plain_text = 'Title' } } },
      }
      local block = heading_module.new(raw)

      -- Change level from 1 to 2
      block:update_from_lines({ '## Title' })
      local serialized = block:serialize()

      -- Should have heading_2, not heading_1
      assert.are.equal('heading_2', serialized.type)
      assert.is_not_nil(serialized.heading_2)
      assert.is_nil(serialized.heading_1)
      assert.are.equal('Title', serialized.heading_2.rich_text[1].plain_text)
    end)

    it('should remove old heading key when level changes', function()
      local raw = {
        id = 'test',
        type = 'heading_3',
        heading_3 = { rich_text = { { plain_text = 'Subsection' } }, is_toggleable = false },
      }
      local block = heading_module.new(raw)

      -- Change level from 3 to 1
      block:update_from_lines({ '# Main Title' })
      local serialized = block:serialize()

      assert.are.equal('heading_1', serialized.type)
      assert.is_not_nil(serialized.heading_1)
      assert.is_nil(serialized.heading_3)
    end)
  end)

  describe('update_from_lines', function()
    it('should update text from heading line', function()
      local raw = {
        id = 'test',
        type = 'heading_1',
        heading_1 = { rich_text = { { plain_text = 'Original' } } },
      }
      local block = heading_module.new(raw)

      block:update_from_lines({ '# New Title' })

      assert.are.equal('New Title', block:get_text())
    end)

    it('should strip heading prefix when updating', function()
      local raw = {
        id = 'test',
        type = 'heading_2',
        heading_2 = { rich_text = {} },
      }
      local block = heading_module.new(raw)

      block:update_from_lines({ '## Section Name' })

      assert.are.equal('Section Name', block:get_text())
    end)

    it('should handle line without heading prefix', function()
      local raw = {
        id = 'test',
        type = 'heading_1',
        heading_1 = { rich_text = {} },
      }
      local block = heading_module.new(raw)

      block:update_from_lines({ 'Plain text without prefix' })

      assert.are.equal('Plain text without prefix', block:get_text())
    end)

    it('should mark block as dirty when content changes', function()
      local raw = {
        id = 'test',
        type = 'heading_1',
        heading_1 = { rich_text = { { plain_text = 'Original' } } },
      }
      local block = heading_module.new(raw)

      block:update_from_lines({ '# Changed' })

      assert.is_true(block:is_dirty())
    end)

    it('should not mark dirty when content unchanged', function()
      local raw = {
        id = 'test',
        type = 'heading_1',
        heading_1 = { rich_text = { { plain_text = 'Same' } } },
      }
      local block = heading_module.new(raw)

      block:update_from_lines({ '# Same' })

      assert.is_false(block:is_dirty())
    end)

    it('should do nothing with empty lines', function()
      local raw = {
        id = 'test',
        type = 'heading_1',
        heading_1 = { rich_text = { { plain_text = 'Original' } } },
      }
      local block = heading_module.new(raw)

      block:update_from_lines({})

      assert.are.equal('Original', block:get_text())
    end)

    it('should update level when hash count changes', function()
      local raw = {
        id = 'test',
        type = 'heading_1',
        heading_1 = { rich_text = { { plain_text = 'Title' } } },
      }
      local block = heading_module.new(raw)

      block:update_from_lines({ '## Title' })

      assert.are.equal(2, block.level)
      assert.are.equal('heading_2', block.type)
      assert.is_true(block:is_dirty())
    end)

    it('should cap level at 3', function()
      local raw = {
        id = 'test',
        type = 'heading_1',
        heading_1 = { rich_text = { { plain_text = 'Title' } } },
      }
      local block = heading_module.new(raw)

      block:update_from_lines({ '##### Title' })

      assert.are.equal(3, block.level)
      assert.are.equal('heading_3', block.type)
    end)

    it('should mark dirty when only level changes', function()
      local raw = {
        id = 'test',
        type = 'heading_1',
        heading_1 = { rich_text = { { plain_text = 'Same' } } },
      }
      local block = heading_module.new(raw)

      block:update_from_lines({ '### Same' })

      assert.is_true(block:is_dirty())
      assert.are.equal('Same', block:get_text())
      assert.are.equal(3, block.level)
    end)
  end)

  describe('matches_content', function()
    it('should match with heading prefix', function()
      local raw = {
        id = 'test',
        type = 'heading_1',
        heading_1 = { rich_text = { { plain_text = 'Title' } } },
      }
      local block = heading_module.new(raw)

      assert.is_true(block:matches_content({ '# Title' }))
    end)

    it('should match without heading prefix', function()
      local raw = {
        id = 'test',
        type = 'heading_1',
        heading_1 = { rich_text = { { plain_text = 'Title' } } },
      }
      local block = heading_module.new(raw)

      assert.is_true(block:matches_content({ 'Title' }))
    end)

    it('should return false for different content', function()
      local raw = {
        id = 'test',
        type = 'heading_1',
        heading_1 = { rich_text = { { plain_text = 'Title' } } },
      }
      local block = heading_module.new(raw)

      assert.is_false(block:matches_content({ '# Different' }))
    end)

    it('should handle empty lines', function()
      local raw = {
        id = 'test',
        type = 'heading_1',
        heading_1 = { rich_text = { { plain_text = 'Title' } } },
      }
      local block = heading_module.new(raw)

      assert.is_false(block:matches_content({}))
    end)
  end)

  describe('module interface', function()
    it('should expose is_editable function', function()
      assert.is_true(heading_module.is_editable())
    end)

    it('should expose new constructor', function()
      assert.is_function(heading_module.new)
    end)
  end)
end)
