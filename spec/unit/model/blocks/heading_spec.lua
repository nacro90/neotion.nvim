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

    it('should handle multi-line content (soft breaks from Notion)', function()
      local raw = {
        id = 'test',
        type = 'heading_1',
        heading_1 = { rich_text = { { plain_text = 'Main Title\nSubtitle line' } } },
      }
      local block = heading_module.new(raw)

      local lines = block:format()

      -- First line gets heading prefix, continuation lines are indented
      assert.are.equal(2, #lines)
      assert.are.equal('# Main Title', lines[1])
      assert.are.equal('  Subtitle line', lines[2])
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

    it('should parse markers when text changed with formatting', function()
      local raw = {
        id = 'test',
        type = 'heading_1',
        heading_1 = { rich_text = { { plain_text = 'Original' } } },
      }
      local block = heading_module.new(raw)

      block.text = '**Bold Title**'

      local serialized = block:serialize()

      assert.are.equal(1, #serialized.heading_1.rich_text)
      assert.are.equal('Bold Title', serialized.heading_1.rich_text[1].plain_text)
      assert.is_true(serialized.heading_1.rich_text[1].annotations.bold)
    end)

    it('should parse mixed formatting markers', function()
      local raw = {
        id = 'test',
        type = 'heading_2',
        heading_2 = { rich_text = { { plain_text = 'Original' } } },
      }
      local block = heading_module.new(raw)

      block.text = 'Hello **bold** and *italic*'

      local serialized = block:serialize()

      assert.are.equal(4, #serialized.heading_2.rich_text)
      assert.are.equal('Hello ', serialized.heading_2.rich_text[1].plain_text)
      assert.are.equal('bold', serialized.heading_2.rich_text[2].plain_text)
      assert.is_true(serialized.heading_2.rich_text[2].annotations.bold)
      assert.are.equal(' and ', serialized.heading_2.rich_text[3].plain_text)
      assert.are.equal('italic', serialized.heading_2.rich_text[4].plain_text)
      assert.is_true(serialized.heading_2.rich_text[4].annotations.italic)
    end)

    it('should parse link markers to href', function()
      local raw = {
        id = 'test',
        type = 'heading_1',
        heading_1 = { rich_text = { { plain_text = 'Original' } } },
      }
      local block = heading_module.new(raw)

      block.text = '[click here](https://example.com)'

      local serialized = block:serialize()

      assert.are.equal(1, #serialized.heading_1.rich_text)
      assert.are.equal('click here', serialized.heading_1.rich_text[1].plain_text)
      assert.are.equal('https://example.com', serialized.heading_1.rich_text[1].href)
    end)

    it('should parse color markers', function()
      local raw = {
        id = 'test',
        type = 'heading_3',
        heading_3 = { rich_text = { { plain_text = 'Original' } } },
      }
      local block = heading_module.new(raw)

      block.text = '<c:red>colored title</c>'

      local serialized = block:serialize()

      assert.are.equal(1, #serialized.heading_3.rich_text)
      assert.are.equal('colored title', serialized.heading_3.rich_text[1].plain_text)
      assert.are.equal('red', serialized.heading_3.rich_text[1].annotations.color)
    end)

    it('should create plain rich_text when text changed without markers', function()
      local raw = {
        id = 'test',
        type = 'heading_1',
        heading_1 = {
          rich_text = {
            { plain_text = 'Original', annotations = { bold = true } },
          },
        },
      }
      local block = heading_module.new(raw)

      block.text = 'Plain new title'

      local serialized = block:serialize()

      assert.are.equal(1, #serialized.heading_1.rich_text)
      assert.are.equal('Plain new title', serialized.heading_1.rich_text[1].plain_text)
      assert.is_false(serialized.heading_1.rich_text[1].annotations.bold)
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

  describe('rich text integration', function()
    local types

    before_each(function()
      types = require('neotion.format.types')
    end)

    describe('get_rich_text_segments', function()
      it('should convert API rich_text to RichTextSegment array', function()
        local raw = {
          id = 'test',
          type = 'heading_1',
          heading_1 = {
            rich_text = {
              {
                type = 'text',
                plain_text = 'Bold ',
                annotations = {
                  bold = true,
                  italic = false,
                  strikethrough = false,
                  underline = false,
                  code = false,
                  color = 'default',
                },
              },
              {
                type = 'text',
                plain_text = 'Title',
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
        local block = heading_module.new(raw)

        local segments = block:get_rich_text_segments()

        assert.are.equal(2, #segments)
        assert.are.equal('Bold ', segments[1].text)
        assert.is_true(segments[1].annotations.bold)
        assert.are.equal('Title', segments[2].text)
        assert.is_false(segments[2].annotations.bold)
      end)

      it('should return empty array for empty rich_text', function()
        local raw = {
          id = 'test',
          type = 'heading_2',
          heading_2 = { rich_text = {} },
        }
        local block = heading_module.new(raw)

        local segments = block:get_rich_text_segments()

        assert.are.equal(0, #segments)
      end)

      it('should handle colored heading text', function()
        local raw = {
          id = 'test',
          type = 'heading_1',
          heading_1 = {
            rich_text = {
              {
                plain_text = 'Colored Title',
                annotations = {
                  bold = false,
                  italic = false,
                  strikethrough = false,
                  underline = false,
                  code = false,
                  color = 'blue',
                },
              },
            },
          },
        }
        local block = heading_module.new(raw)

        local segments = block:get_rich_text_segments()

        assert.are.equal('blue', segments[1].annotations.color)
      end)

      it('should calculate correct column positions', function()
        local raw = {
          id = 'test',
          type = 'heading_1',
          heading_1 = {
            rich_text = {
              { plain_text = 'AB', annotations = {} },
              { plain_text = 'CDE', annotations = {} },
            },
          },
        }
        local block = heading_module.new(raw)

        local segments = block:get_rich_text_segments()

        assert.are.equal(0, segments[1].start_col)
        assert.are.equal(2, segments[1].end_col)
        assert.are.equal(2, segments[2].start_col)
        assert.are.equal(5, segments[2].end_col)
      end)
    end)

    describe('format_with_markers', function()
      it('should format plain heading text without markers', function()
        local raw = {
          id = 'test',
          type = 'heading_1',
          heading_1 = {
            rich_text = {
              {
                plain_text = 'Plain Title',
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
        local block = heading_module.new(raw)

        local text = block:format_with_markers()

        assert.are.equal('Plain Title', text)
      end)

      it('should format bold heading text with ** markers', function()
        local raw = {
          id = 'test',
          type = 'heading_2',
          heading_2 = {
            rich_text = {
              {
                plain_text = 'Bold Title',
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
        local block = heading_module.new(raw)

        local text = block:format_with_markers()

        assert.are.equal('**Bold Title**', text)
      end)

      it('should format mixed heading formatting', function()
        local raw = {
          id = 'test',
          type = 'heading_1',
          heading_1 = {
            rich_text = {
              {
                plain_text = 'Main ',
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
                plain_text = 'Title',
                annotations = {
                  bold = false,
                  italic = true,
                  strikethrough = false,
                  underline = false,
                  code = false,
                  color = 'default',
                },
              },
            },
          },
        }
        local block = heading_module.new(raw)

        local text = block:format_with_markers()

        assert.are.equal('Main *Title*', text)
      end)

      it('should format colored heading text with <c:color> markers', function()
        local raw = {
          id = 'test',
          type = 'heading_3',
          heading_3 = {
            rich_text = {
              {
                plain_text = 'Blue Title',
                annotations = {
                  bold = false,
                  italic = false,
                  strikethrough = false,
                  underline = false,
                  code = false,
                  color = 'blue',
                },
              },
            },
          },
        }
        local block = heading_module.new(raw)

        local text = block:format_with_markers()

        assert.are.equal('<c:blue>Blue Title</c>', text)
      end)
    end)
  end)
end)
