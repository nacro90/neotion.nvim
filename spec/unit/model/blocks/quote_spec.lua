describe('neotion.model.blocks.quote', function()
  local quote_module

  before_each(function()
    package.loaded['neotion.model.blocks.quote'] = nil
    package.loaded['neotion.model.block'] = nil
    package.loaded['neotion.api.blocks'] = nil
    quote_module = require('neotion.model.blocks.quote')
  end)

  describe('QuoteBlock.new', function()
    it('should create a quote from raw JSON', function()
      local raw = {
        id = 'quote123',
        type = 'quote',
        quote = {
          rich_text = { { plain_text = 'A wise saying' } },
          color = 'default',
        },
      }

      local block = quote_module.new(raw)

      assert.are.equal('quote123', block:get_id())
      assert.are.equal('quote', block:get_type())
    end)

    it('should be marked as editable', function()
      local raw = {
        id = 'test',
        type = 'quote',
        quote = { rich_text = {} },
      }

      local block = quote_module.new(raw)

      assert.is_true(block:is_editable())
    end)

    it('should extract plain text from rich_text', function()
      local raw = {
        id = 'test',
        type = 'quote',
        quote = {
          rich_text = {
            { plain_text = 'First ' },
            { plain_text = 'Second' },
          },
        },
      }

      local block = quote_module.new(raw)

      assert.are.equal('First Second', block:get_text())
    end)

    it('should handle empty rich_text', function()
      local raw = {
        id = 'test',
        type = 'quote',
        quote = { rich_text = {} },
      }

      local block = quote_module.new(raw)

      assert.are.equal('', block:get_text())
    end)

    it('should handle missing quote field', function()
      local raw = {
        id = 'test',
        type = 'quote',
      }

      local block = quote_module.new(raw)

      assert.are.equal('', block:get_text())
    end)

    it('should preserve original rich_text for round-trip', function()
      local rich_text = {
        {
          type = 'text',
          plain_text = 'Bold quote',
          annotations = { bold = true },
        },
      }
      local raw = {
        id = 'test',
        type = 'quote',
        quote = { rich_text = rich_text },
      }

      local block = quote_module.new(raw)

      assert.are.same(rich_text, block.rich_text)
    end)

    it('should preserve color property', function()
      local raw = {
        id = 'test',
        type = 'quote',
        quote = {
          rich_text = { { plain_text = 'Colored quote' } },
          color = 'blue',
        },
      }

      local block = quote_module.new(raw)

      assert.are.equal('blue', block.color)
    end)
  end)

  describe('QuoteBlock:format', function()
    it('should return line with | prefix', function()
      local raw = {
        id = 'test',
        type = 'quote',
        quote = {
          rich_text = { { plain_text = 'Quote text' } },
        },
      }

      local block = quote_module.new(raw)
      local lines = block:format()

      assert.are.equal(1, #lines)
      assert.are.equal('| Quote text', lines[1])
    end)

    it('should handle empty quote', function()
      local raw = {
        id = 'test',
        type = 'quote',
        quote = { rich_text = {} },
      }

      local block = quote_module.new(raw)
      local lines = block:format()

      assert.are.equal('| ', lines[1])
    end)

    it('should include formatting markers in output', function()
      -- Mock rich_text_to_notion_syntax to return formatted text
      local raw = {
        id = 'test',
        type = 'quote',
        quote = {
          rich_text = {
            {
              plain_text = 'bold text',
              annotations = { bold = true },
              text = { content = 'bold text' },
            },
          },
        },
      }

      local block = quote_module.new(raw)
      local lines = block:format()

      -- Should have prefix and formatted content
      assert.truthy(lines[1]:match('^| '))
    end)
  end)

  describe('QuoteBlock:serialize', function()
    it('should return original raw when text unchanged', function()
      local raw = {
        id = 'test',
        type = 'quote',
        quote = {
          rich_text = { { plain_text = 'Original', text = { content = 'Original' } } },
          color = 'default',
        },
      }

      local block = quote_module.new(raw)
      local result = block:serialize()

      assert.are.equal('quote', result.type)
      assert.is_not_nil(result.quote)
    end)

    it('should update rich_text when text changed', function()
      local raw = {
        id = 'test',
        type = 'quote',
        quote = {
          rich_text = { { plain_text = 'Original', text = { content = 'Original' } } },
        },
      }

      local block = quote_module.new(raw)
      block:update_from_lines({ '| Modified text' })
      local result = block:serialize()

      -- rich_text should be updated
      assert.is_not_nil(result.quote.rich_text)
    end)

    it('should preserve color on serialization', function()
      local raw = {
        id = 'test',
        type = 'quote',
        quote = {
          rich_text = { { plain_text = 'Text' } },
          color = 'red',
        },
      }

      local block = quote_module.new(raw)
      local result = block:serialize()

      assert.are.equal('red', result.quote.color)
    end)
  end)

  describe('QuoteBlock:update_from_lines', function()
    it('should strip | prefix and update text', function()
      local raw = {
        id = 'test',
        type = 'quote',
        quote = {
          rich_text = { { plain_text = 'Original' } },
        },
      }

      local block = quote_module.new(raw)
      block:update_from_lines({ '| New text' })

      assert.are.equal('New text', block:get_text())
      assert.is_true(block:is_dirty())
    end)

    it('should handle > prefix as alternative', function()
      local raw = {
        id = 'test',
        type = 'quote',
        quote = {
          rich_text = { { plain_text = 'Original' } },
        },
      }

      local block = quote_module.new(raw)
      block:update_from_lines({ '> New text' })

      assert.are.equal('New text', block:get_text())
    end)

    it('should handle line without prefix', function()
      local raw = {
        id = 'test',
        type = 'quote',
        quote = {
          rich_text = { { plain_text = 'Original' } },
        },
      }

      local block = quote_module.new(raw)
      block:update_from_lines({ 'No prefix text' })

      assert.are.equal('No prefix text', block:get_text())
    end)

    it('should handle empty lines', function()
      local raw = {
        id = 'test',
        type = 'quote',
        quote = {
          rich_text = { { plain_text = 'Original' } },
        },
      }

      local block = quote_module.new(raw)
      block:update_from_lines({})

      -- Should not crash, text unchanged or empty
      assert.is_not_nil(block:get_text())
    end)

    it('should handle | prefix with no space', function()
      local raw = {
        id = 'test',
        type = 'quote',
        quote = {
          rich_text = { { plain_text = 'Original' } },
        },
      }

      local block = quote_module.new(raw)
      block:update_from_lines({ '|Text without space' })

      assert.are.equal('Text without space', block:get_text())
    end)

    it('should not mark dirty if text unchanged', function()
      local raw = {
        id = 'test',
        type = 'quote',
        quote = {
          rich_text = { { plain_text = 'Same text' } },
        },
      }

      local block = quote_module.new(raw)
      block:update_from_lines({ '| Same text' })

      assert.is_false(block:is_dirty())
    end)
  end)

  describe('QuoteBlock:get_text', function()
    it('should return text without prefix', function()
      local raw = {
        id = 'test',
        type = 'quote',
        quote = {
          rich_text = { { plain_text = 'Quote content' } },
        },
      }

      local block = quote_module.new(raw)

      assert.are.equal('Quote content', block:get_text())
    end)
  end)

  describe('QuoteBlock:matches_content', function()
    it('should match when text is same (ignoring prefix)', function()
      local raw = {
        id = 'test',
        type = 'quote',
        quote = {
          rich_text = { { plain_text = 'Quote text' } },
        },
      }

      local block = quote_module.new(raw)

      assert.is_true(block:matches_content({ '| Quote text' }))
    end)

    it('should match with > prefix too', function()
      local raw = {
        id = 'test',
        type = 'quote',
        quote = {
          rich_text = { { plain_text = 'Quote text' } },
        },
      }

      local block = quote_module.new(raw)

      assert.is_true(block:matches_content({ '> Quote text' }))
    end)

    it('should not match when text differs', function()
      local raw = {
        id = 'test',
        type = 'quote',
        quote = {
          rich_text = { { plain_text = 'Original' } },
        },
      }

      local block = quote_module.new(raw)

      assert.is_false(block:matches_content({ '| Different' }))
    end)
  end)

  describe('QuoteBlock:render', function()
    it('should return false (use default text rendering)', function()
      local raw = {
        id = 'test',
        type = 'quote',
        quote = {
          rich_text = { { plain_text = 'Quote' } },
        },
      }

      local block = quote_module.new(raw)
      local mock_ctx = {}

      local handled = block:render(mock_ctx)

      -- Quote uses default text rendering, not custom
      assert.is_false(handled)
    end)
  end)

  describe('QuoteBlock:has_children', function()
    it('should return false (children not supported in Phase 5.7)', function()
      local raw = {
        id = 'test',
        type = 'quote',
        quote = { rich_text = {} },
        has_children = true, -- API says it has children
      }

      local block = quote_module.new(raw)

      -- We ignore children for now
      assert.is_false(block:has_children())
    end)
  end)

  describe('QuoteBlock:get_rich_text_segments', function()
    it('should convert rich_text to RichTextSegment array', function()
      local raw = {
        id = 'test',
        type = 'quote',
        quote = {
          rich_text = {
            {
              plain_text = 'Bold text',
              annotations = { bold = true, italic = false, strikethrough = false, underline = false, code = false },
              text = { content = 'Bold text' },
            },
          },
        },
      }

      local block = quote_module.new(raw)
      local segments = block:get_rich_text_segments()

      assert.are.equal(1, #segments)
      assert.are.equal('Bold text', segments[1].text)
    end)
  end)

  describe('M.is_editable', function()
    it('should return true', function()
      assert.is_true(quote_module.is_editable())
    end)
  end)
end)
