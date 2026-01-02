describe('neotion.model.blocks.paragraph', function()
  local paragraph_module

  before_each(function()
    package.loaded['neotion.model.blocks.paragraph'] = nil
    package.loaded['neotion.model.block'] = nil
    paragraph_module = require('neotion.model.blocks.paragraph')
  end)

  describe('ParagraphBlock.new', function()
    it('should create a paragraph from raw JSON', function()
      local raw = {
        id = 'para123',
        type = 'paragraph',
        paragraph = {
          rich_text = { { plain_text = 'Hello world' } },
        },
      }

      local block = paragraph_module.new(raw)

      assert.are.equal('para123', block:get_id())
      assert.are.equal('paragraph', block:get_type())
      assert.are.equal('Hello world', block:get_text())
    end)

    it('should be marked as editable', function()
      local raw = {
        id = 'test',
        type = 'paragraph',
        paragraph = { rich_text = {} },
      }

      local block = paragraph_module.new(raw)

      assert.is_true(block:is_editable())
    end)

    it('should extract plain text from multiple rich_text items', function()
      local raw = {
        id = 'test',
        type = 'paragraph',
        paragraph = {
          rich_text = {
            { plain_text = 'Hello ' },
            { plain_text = 'world' },
            { plain_text = '!' },
          },
        },
      }

      local block = paragraph_module.new(raw)

      assert.are.equal('Hello world!', block:get_text())
    end)

    it('should handle empty rich_text', function()
      local raw = {
        id = 'test',
        type = 'paragraph',
        paragraph = { rich_text = {} },
      }

      local block = paragraph_module.new(raw)

      assert.are.equal('', block:get_text())
    end)

    it('should handle missing paragraph field', function()
      local raw = {
        id = 'test',
        type = 'paragraph',
      }

      local block = paragraph_module.new(raw)

      assert.are.equal('', block:get_text())
    end)

    it('should preserve original rich_text for round-trip', function()
      local rich_text = {
        {
          type = 'text',
          plain_text = 'Bold text',
          annotations = { bold = true, italic = false },
        },
      }
      local raw = {
        id = 'test',
        type = 'paragraph',
        paragraph = { rich_text = rich_text },
      }

      local block = paragraph_module.new(raw)

      assert.are.same(rich_text, block.rich_text)
    end)

    it('should store original text for change detection', function()
      local raw = {
        id = 'test',
        type = 'paragraph',
        paragraph = { rich_text = { { plain_text = 'Original' } } },
      }

      local block = paragraph_module.new(raw)

      assert.are.equal('Original', block.original_text)
    end)
  end)

  describe('format', function()
    it('should return text as single line', function()
      local raw = {
        id = 'test',
        type = 'paragraph',
        paragraph = { rich_text = { { plain_text = 'Hello' } } },
      }
      local block = paragraph_module.new(raw)

      local lines = block:format()

      assert.are.equal(1, #lines)
      assert.are.equal('Hello', lines[1])
    end)

    it('should return empty string for empty paragraph', function()
      local raw = {
        id = 'test',
        type = 'paragraph',
        paragraph = { rich_text = {} },
      }
      local block = paragraph_module.new(raw)

      local lines = block:format()

      assert.are.equal(1, #lines)
      assert.are.equal('', lines[1])
    end)

    it('should handle multi-line paragraphs', function()
      local raw = {
        id = 'test',
        type = 'paragraph',
        paragraph = { rich_text = { { plain_text = 'Line 1\nLine 2' } } },
      }
      local block = paragraph_module.new(raw)

      local lines = block:format()

      assert.are.equal(2, #lines)
      assert.are.equal('Line 1', lines[1])
      assert.are.equal('Line 2', lines[2])
    end)

    it('should apply indent option', function()
      local raw = {
        id = 'test',
        type = 'paragraph',
        paragraph = { rich_text = { { plain_text = 'Indented' } } },
      }
      local block = paragraph_module.new(raw)

      local lines = block:format({ indent = 2, indent_size = 2 })

      assert.is_truthy(lines[1]:match('^    ')) -- 4 spaces
    end)
  end)

  describe('serialize', function()
    it('should preserve original rich_text when text unchanged', function()
      local original_rich_text = {
        {
          type = 'text',
          plain_text = 'Hello',
          text = { content = 'Hello' },
          annotations = { bold = true, italic = false },
        },
      }
      local raw = {
        id = 'test',
        type = 'paragraph',
        paragraph = { rich_text = original_rich_text },
      }
      local block = paragraph_module.new(raw)

      local serialized = block:serialize()

      assert.are.same(original_rich_text, serialized.paragraph.rich_text)
    end)

    it('should create plain rich_text when text changed', function()
      local raw = {
        id = 'test',
        type = 'paragraph',
        paragraph = {
          rich_text = {
            {
              type = 'text',
              plain_text = 'Original',
              annotations = { bold = true },
            },
          },
        },
      }
      local block = paragraph_module.new(raw)

      -- Modify text
      block.text = 'Modified'

      local serialized = block:serialize()

      -- Should have plain text without bold
      assert.are.equal(1, #serialized.paragraph.rich_text)
      assert.are.equal('Modified', serialized.paragraph.rich_text[1].plain_text)
      assert.are.equal('Modified', serialized.paragraph.rich_text[1].text.content)
      assert.is_false(serialized.paragraph.rich_text[1].annotations.bold)
    end)

    it('should preserve raw JSON metadata', function()
      local raw = {
        id = 'test123',
        type = 'paragraph',
        created_time = '2024-01-01T00:00:00Z',
        last_edited_time = '2024-01-02T00:00:00Z',
        paragraph = { rich_text = {} },
      }
      local block = paragraph_module.new(raw)

      local serialized = block:serialize()

      assert.are.equal('test123', serialized.id)
      assert.are.equal('2024-01-01T00:00:00Z', serialized.created_time)
    end)
  end)

  describe('update_from_lines', function()
    it('should update text from single line', function()
      local raw = {
        id = 'test',
        type = 'paragraph',
        paragraph = { rich_text = { { plain_text = 'Original' } } },
      }
      local block = paragraph_module.new(raw)

      block:update_from_lines({ 'New content' })

      assert.are.equal('New content', block:get_text())
    end)

    it('should mark block as dirty when content changes', function()
      local raw = {
        id = 'test',
        type = 'paragraph',
        paragraph = { rich_text = { { plain_text = 'Original' } } },
      }
      local block = paragraph_module.new(raw)

      assert.is_false(block:is_dirty())

      block:update_from_lines({ 'Changed' })

      assert.is_true(block:is_dirty())
    end)

    it('should not mark dirty when content unchanged', function()
      local raw = {
        id = 'test',
        type = 'paragraph',
        paragraph = { rich_text = { { plain_text = 'Same' } } },
      }
      local block = paragraph_module.new(raw)

      block:update_from_lines({ 'Same' })

      assert.is_false(block:is_dirty())
    end)

    it('should handle multi-line updates', function()
      local raw = {
        id = 'test',
        type = 'paragraph',
        paragraph = { rich_text = {} },
      }
      local block = paragraph_module.new(raw)

      block:update_from_lines({ 'Line 1', 'Line 2', 'Line 3' })

      assert.are.equal('Line 1\nLine 2\nLine 3', block:get_text())
    end)

    it('should trim whitespace from lines', function()
      local raw = {
        id = 'test',
        type = 'paragraph',
        paragraph = { rich_text = {} },
      }
      local block = paragraph_module.new(raw)

      block:update_from_lines({ '  Indented  ', '  Content  ' })

      assert.are.equal('Indented\nContent', block:get_text())
    end)

    it('should handle empty lines array', function()
      local raw = {
        id = 'test',
        type = 'paragraph',
        paragraph = { rich_text = { { plain_text = 'Original' } } },
      }
      local block = paragraph_module.new(raw)

      block:update_from_lines({})

      assert.are.equal('', block:get_text())
    end)
  end)

  describe('matches_content', function()
    it('should return true when content matches', function()
      local raw = {
        id = 'test',
        type = 'paragraph',
        paragraph = { rich_text = { { plain_text = 'Hello' } } },
      }
      local block = paragraph_module.new(raw)

      assert.is_true(block:matches_content({ 'Hello' }))
    end)

    it('should return false when content differs', function()
      local raw = {
        id = 'test',
        type = 'paragraph',
        paragraph = { rich_text = { { plain_text = 'Hello' } } },
      }
      local block = paragraph_module.new(raw)

      assert.is_false(block:matches_content({ 'Different' }))
    end)

    it('should ignore whitespace when matching', function()
      local raw = {
        id = 'test',
        type = 'paragraph',
        paragraph = { rich_text = { { plain_text = 'Hello' } } },
      }
      local block = paragraph_module.new(raw)

      assert.is_true(block:matches_content({ '  Hello  ' }))
    end)
  end)

  describe('module interface', function()
    it('should expose is_editable function', function()
      assert.is_true(paragraph_module.is_editable())
    end)

    it('should expose new constructor', function()
      assert.is_function(paragraph_module.new)
    end)
  end)
end)
