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

    it('should parse markers when text changed with formatting', function()
      local raw = {
        id = 'test',
        type = 'paragraph',
        paragraph = {
          rich_text = {
            {
              type = 'text',
              plain_text = 'Original',
              annotations = { bold = false },
            },
          },
        },
      }
      local block = paragraph_module.new(raw)

      -- Modify text with bold markers
      block.text = '**Bold text**'

      local serialized = block:serialize()

      -- Should have parsed bold formatting
      assert.are.equal(1, #serialized.paragraph.rich_text)
      assert.are.equal('Bold text', serialized.paragraph.rich_text[1].plain_text)
      assert.are.equal('Bold text', serialized.paragraph.rich_text[1].text.content)
      assert.is_true(serialized.paragraph.rich_text[1].annotations.bold)
    end)

    it('should parse mixed formatting markers', function()
      local raw = {
        id = 'test',
        type = 'paragraph',
        paragraph = { rich_text = {} },
      }
      local block = paragraph_module.new(raw)

      block.text = 'Hello **bold** and *italic*'

      local serialized = block:serialize()

      assert.are.equal(4, #serialized.paragraph.rich_text)
      assert.are.equal('Hello ', serialized.paragraph.rich_text[1].text.content)
      assert.is_false(serialized.paragraph.rich_text[1].annotations.bold)
      assert.are.equal('bold', serialized.paragraph.rich_text[2].text.content)
      assert.is_true(serialized.paragraph.rich_text[2].annotations.bold)
      assert.are.equal(' and ', serialized.paragraph.rich_text[3].text.content)
      assert.are.equal('italic', serialized.paragraph.rich_text[4].text.content)
      assert.is_true(serialized.paragraph.rich_text[4].annotations.italic)
    end)

    it('should parse link markers to href', function()
      local raw = {
        id = 'test',
        type = 'paragraph',
        paragraph = { rich_text = {} },
      }
      local block = paragraph_module.new(raw)

      block.text = '[click here](https://example.com)'

      local serialized = block:serialize()

      assert.are.equal(1, #serialized.paragraph.rich_text)
      assert.are.equal('click here', serialized.paragraph.rich_text[1].text.content)
      assert.are.equal('https://example.com', serialized.paragraph.rich_text[1].text.link.url)
      assert.are.equal('https://example.com', serialized.paragraph.rich_text[1].href)
    end)

    it('should parse formatted link markers', function()
      local raw = {
        id = 'test',
        type = 'paragraph',
        paragraph = { rich_text = {} },
      }
      local block = paragraph_module.new(raw)

      block.text = '**[bold link](https://example.com)**'

      local serialized = block:serialize()

      assert.are.equal(1, #serialized.paragraph.rich_text)
      assert.are.equal('bold link', serialized.paragraph.rich_text[1].text.content)
      assert.are.equal('https://example.com', serialized.paragraph.rich_text[1].text.link.url)
      assert.is_true(serialized.paragraph.rich_text[1].annotations.bold)
    end)

    it('should parse color markers', function()
      local raw = {
        id = 'test',
        type = 'paragraph',
        paragraph = { rich_text = {} },
      }
      local block = paragraph_module.new(raw)

      block.text = '<c:red>colored text</c>'

      local serialized = block:serialize()

      assert.are.equal(1, #serialized.paragraph.rich_text)
      assert.are.equal('colored text', serialized.paragraph.rich_text[1].text.content)
      assert.are.equal('red', serialized.paragraph.rich_text[1].annotations.color)
    end)

    it('should create plain rich_text when text changed without markers', function()
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

      -- Modify text without any markers
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

  describe('rich text integration', function()
    local types

    before_each(function()
      types = require('neotion.format.types')
    end)

    describe('get_rich_text_segments', function()
      it('should convert API rich_text to RichTextSegment array', function()
        local raw = {
          id = 'test',
          type = 'paragraph',
          paragraph = {
            rich_text = {
              {
                type = 'text',
                plain_text = 'Hello ',
                annotations = {
                  bold = false,
                  italic = false,
                  strikethrough = false,
                  underline = false,
                  code = false,
                  color = 'default',
                },
              },
              {
                type = 'text',
                plain_text = 'world',
                annotations = {
                  bold = true,
                  italic = false,
                  strikethrough = false,
                  underline = false,
                  code = false,
                  color = 'default',
                },
              },
            },
          },
        }
        local block = paragraph_module.new(raw)

        local segments = block:get_rich_text_segments()

        assert.are.equal(2, #segments)
        assert.are.equal('Hello ', segments[1].text)
        assert.is_false(segments[1].annotations.bold)
        assert.are.equal('world', segments[2].text)
        assert.is_true(segments[2].annotations.bold)
      end)

      it('should return empty array for empty rich_text', function()
        local raw = {
          id = 'test',
          type = 'paragraph',
          paragraph = { rich_text = {} },
        }
        local block = paragraph_module.new(raw)

        local segments = block:get_rich_text_segments()

        assert.are.equal(0, #segments)
      end)

      it('should handle colored text', function()
        local raw = {
          id = 'test',
          type = 'paragraph',
          paragraph = {
            rich_text = {
              {
                plain_text = 'Red text',
                annotations = {
                  bold = false,
                  italic = false,
                  strikethrough = false,
                  underline = false,
                  code = false,
                  color = 'red',
                },
              },
            },
          },
        }
        local block = paragraph_module.new(raw)

        local segments = block:get_rich_text_segments()

        assert.are.equal('red', segments[1].annotations.color)
      end)

      it('should calculate correct column positions', function()
        local raw = {
          id = 'test',
          type = 'paragraph',
          paragraph = {
            rich_text = {
              { plain_text = 'AB', annotations = {} },
              { plain_text = 'CD', annotations = {} },
            },
          },
        }
        local block = paragraph_module.new(raw)

        local segments = block:get_rich_text_segments()

        assert.are.equal(0, segments[1].start_col)
        assert.are.equal(2, segments[1].end_col)
        assert.are.equal(2, segments[2].start_col)
        assert.are.equal(4, segments[2].end_col)
      end)
    end)

    describe('format_with_markers', function()
      it('should format plain text without markers', function()
        local raw = {
          id = 'test',
          type = 'paragraph',
          paragraph = {
            rich_text = {
              {
                plain_text = 'Hello world',
                annotations = {
                  bold = false,
                  italic = false,
                  strikethrough = false,
                  underline = false,
                  code = false,
                  color = 'default',
                },
              },
            },
          },
        }
        local block = paragraph_module.new(raw)

        local text = block:format_with_markers()

        assert.are.equal('Hello world', text)
      end)

      it('should format bold text with ** markers', function()
        local raw = {
          id = 'test',
          type = 'paragraph',
          paragraph = {
            rich_text = {
              {
                plain_text = 'bold',
                annotations = {
                  bold = true,
                  italic = false,
                  strikethrough = false,
                  underline = false,
                  code = false,
                  color = 'default',
                },
              },
            },
          },
        }
        local block = paragraph_module.new(raw)

        local text = block:format_with_markers()

        assert.are.equal('**bold**', text)
      end)

      it('should format mixed formatting', function()
        local raw = {
          id = 'test',
          type = 'paragraph',
          paragraph = {
            rich_text = {
              {
                plain_text = 'Hello ',
                annotations = {
                  bold = false,
                  italic = false,
                  strikethrough = false,
                  underline = false,
                  code = false,
                  color = 'default',
                },
              },
              {
                plain_text = 'world',
                annotations = {
                  bold = true,
                  italic = false,
                  strikethrough = false,
                  underline = false,
                  code = false,
                  color = 'default',
                },
              },
            },
          },
        }
        local block = paragraph_module.new(raw)

        local text = block:format_with_markers()

        assert.are.equal('Hello **world**', text)
      end)

      it('should format colored text with <c:color> markers', function()
        local raw = {
          id = 'test',
          type = 'paragraph',
          paragraph = {
            rich_text = {
              {
                plain_text = 'red text',
                annotations = {
                  bold = false,
                  italic = false,
                  strikethrough = false,
                  underline = false,
                  code = false,
                  color = 'red',
                },
              },
            },
          },
        }
        local block = paragraph_module.new(raw)

        local text = block:format_with_markers()

        assert.are.equal('<c:red>red text</c>', text)
      end)
    end)
  end)

  -- Phase 5.8: Block Type Conversion
  describe('type conversion', function()
    describe('type_changed', function()
      it('should return false for normal paragraph', function()
        local raw = {
          id = 'test',
          type = 'paragraph',
          paragraph = { rich_text = { { plain_text = 'Normal text' } } },
        }
        local block = paragraph_module.new(raw)

        block:update_from_lines({ 'Normal text' })

        assert.is_false(block:type_changed())
      end)

      it('should return true when content has bullet prefix', function()
        local raw = {
          id = 'test',
          type = 'paragraph',
          paragraph = { rich_text = { { plain_text = 'Original' } } },
        }
        local block = paragraph_module.new(raw)

        block:update_from_lines({ '- bullet item' })

        assert.is_true(block:type_changed())
      end)

      it('should return true when content has quote prefix', function()
        local raw = {
          id = 'test',
          type = 'paragraph',
          paragraph = { rich_text = { { plain_text = 'Original' } } },
        }
        local block = paragraph_module.new(raw)

        block:update_from_lines({ '| quoted text' })

        assert.is_true(block:type_changed())
      end)

      it('should return false for multi-line content with prefix', function()
        -- Multi-line paragraphs don't convert
        local raw = {
          id = 'test',
          type = 'paragraph',
          paragraph = { rich_text = {} },
        }
        local block = paragraph_module.new(raw)

        block:update_from_lines({ '- line one', 'line two' })

        assert.is_false(block:type_changed())
      end)
    end)

    describe('get_type', function()
      it('should return paragraph for normal content', function()
        local raw = {
          id = 'test',
          type = 'paragraph',
          paragraph = { rich_text = { { plain_text = 'Normal' } } },
        }
        local block = paragraph_module.new(raw)

        block:update_from_lines({ 'Normal' })

        assert.are.equal('paragraph', block:get_type())
      end)

      it('should return bulleted_list_item when bullet prefix detected', function()
        local raw = {
          id = 'test',
          type = 'paragraph',
          paragraph = { rich_text = {} },
        }
        local block = paragraph_module.new(raw)

        block:update_from_lines({ '- bullet item' })

        assert.are.equal('bulleted_list_item', block:get_type())
      end)

      it('should return quote when quote prefix detected', function()
        local raw = {
          id = 'test',
          type = 'paragraph',
          paragraph = { rich_text = {} },
        }
        local block = paragraph_module.new(raw)

        block:update_from_lines({ '| quoted' })

        assert.are.equal('quote', block:get_type())
      end)

      it('should detect asterisk bullet prefix', function()
        local raw = {
          id = 'test',
          type = 'paragraph',
          paragraph = { rich_text = {} },
        }
        local block = paragraph_module.new(raw)

        block:update_from_lines({ '* bullet' })

        assert.are.equal('bulleted_list_item', block:get_type())
      end)

      it('should detect plus bullet prefix', function()
        local raw = {
          id = 'test',
          type = 'paragraph',
          paragraph = { rich_text = {} },
        }
        local block = paragraph_module.new(raw)

        block:update_from_lines({ '+ bullet' })

        assert.are.equal('bulleted_list_item', block:get_type())
      end)
    end)

    describe('get_converted_content', function()
      it('should return text without prefix for bullet', function()
        local raw = {
          id = 'test',
          type = 'paragraph',
          paragraph = { rich_text = {} },
        }
        local block = paragraph_module.new(raw)

        block:update_from_lines({ '- item text' })

        assert.are.equal('item text', block:get_converted_content())
      end)

      it('should return text without prefix for quote', function()
        local raw = {
          id = 'test',
          type = 'paragraph',
          paragraph = { rich_text = {} },
        }
        local block = paragraph_module.new(raw)

        block:update_from_lines({ '| quoted text' })

        assert.are.equal('quoted text', block:get_converted_content())
      end)

      it('should return original text when no conversion', function()
        local raw = {
          id = 'test',
          type = 'paragraph',
          paragraph = { rich_text = { { plain_text = 'Normal' } } },
        }
        local block = paragraph_module.new(raw)

        block:update_from_lines({ 'Normal' })

        assert.are.equal('Normal', block:get_converted_content())
      end)
    end)

    describe('dirty state with type conversion', function()
      it('should mark dirty when type changes', function()
        local raw = {
          id = 'test',
          type = 'paragraph',
          paragraph = { rich_text = { { plain_text = '- item' } } },
        }
        local block = paragraph_module.new(raw)
        block.dirty = false

        block:update_from_lines({ '- new item' })

        assert.is_true(block:is_dirty())
      end)
    end)
  end)
end)
