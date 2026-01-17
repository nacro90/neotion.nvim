describe('neotion.model.blocks.numbered_list', function()
  local numbered_list_module

  before_each(function()
    package.loaded['neotion.model.blocks.numbered_list'] = nil
    package.loaded['neotion.model.block'] = nil
    package.loaded['neotion.api.blocks'] = nil
    numbered_list_module = require('neotion.model.blocks.numbered_list')
  end)

  describe('NumberedListBlock.new', function()
    it('should create a numbered list item from raw JSON', function()
      local raw = {
        id = 'numbered123',
        type = 'numbered_list_item',
        numbered_list_item = {
          rich_text = { { plain_text = 'List item' } },
          color = 'default',
        },
      }

      local block = numbered_list_module.new(raw)

      assert.are.equal('numbered123', block:get_id())
      assert.are.equal('numbered_list_item', block:get_type())
    end)

    it('should be marked as editable', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = { rich_text = {} },
      }

      local block = numbered_list_module.new(raw)

      assert.is_true(block:is_editable())
    end)

    it('should extract plain text from rich_text', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = {
          rich_text = {
            { plain_text = 'First ' },
            { plain_text = 'Second' },
          },
        },
      }

      local block = numbered_list_module.new(raw)

      assert.are.equal('First Second', block:get_text())
    end)

    it('should handle empty rich_text', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = { rich_text = {} },
      }

      local block = numbered_list_module.new(raw)

      assert.are.equal('', block:get_text())
    end)

    it('should handle missing numbered_list_item field', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
      }

      local block = numbered_list_module.new(raw)

      assert.are.equal('', block:get_text())
    end)

    it('should preserve original rich_text for round-trip', function()
      local rich_text = {
        {
          type = 'text',
          plain_text = 'Bold item',
          annotations = { bold = true },
        },
      }
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = { rich_text = rich_text },
      }

      local block = numbered_list_module.new(raw)

      assert.are.same(rich_text, block.rich_text)
    end)

    it('should preserve color property', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = {
          rich_text = { { plain_text = 'Colored item' } },
          color = 'red',
        },
      }

      local block = numbered_list_module.new(raw)

      assert.are.equal('red', block.color)
    end)

    it('should default number to 1', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = { rich_text = { { plain_text = 'Item' } } },
      }

      local block = numbered_list_module.new(raw)

      assert.are.equal(1, block.number)
    end)
  end)

  describe('NumberedListBlock:format', function()
    it('should return line with number prefix', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = {
          rich_text = { { plain_text = 'List item' } },
        },
      }

      local block = numbered_list_module.new(raw)
      local lines = block:format()

      assert.are.equal(1, #lines)
      assert.are.equal('1. List item', lines[1])
    end)

    it('should use block number in prefix', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = {
          rich_text = { { plain_text = 'Third item' } },
        },
      }

      local block = numbered_list_module.new(raw)
      block.number = 3
      local lines = block:format()

      assert.are.equal('3. Third item', lines[1])
    end)

    it('should handle empty numbered item', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = { rich_text = {} },
      }

      local block = numbered_list_module.new(raw)
      local lines = block:format()

      assert.are.equal('1. ', lines[1])
    end)

    it('should handle multi-line content (soft breaks from Notion)', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = {
          rich_text = { { plain_text = 'First line\nContinuation\nMore content' } },
        },
      }

      local block = numbered_list_module.new(raw)
      local lines = block:format()

      -- First line gets number prefix, continuation lines are indented
      assert.are.equal(3, #lines)
      assert.are.equal('1. First line', lines[1])
      assert.are.equal('   Continuation', lines[2])
      assert.are.equal('   More content', lines[3])
    end)

    it('should adjust continuation indent for multi-digit numbers', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = {
          rich_text = { { plain_text = 'First line\nContinuation' } },
        },
      }

      local block = numbered_list_module.new(raw)
      block.number = 10
      local lines = block:format()

      -- "10. " is 4 chars, so continuation indent is 4 spaces
      assert.are.equal('10. First line', lines[1])
      assert.are.equal('    Continuation', lines[2])
    end)
  end)

  describe('NumberedListBlock:serialize', function()
    it('should return original raw when text unchanged', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = {
          rich_text = { { plain_text = 'Original', text = { content = 'Original' } } },
          color = 'default',
        },
      }

      local block = numbered_list_module.new(raw)
      local result = block:serialize()

      assert.are.equal('numbered_list_item', result.type)
      assert.is_not_nil(result.numbered_list_item)
    end)

    it('should update rich_text when text changed', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = {
          rich_text = { { plain_text = 'Original', text = { content = 'Original' } } },
        },
      }

      local block = numbered_list_module.new(raw)
      block:update_from_lines({ '1. Modified text' })
      local result = block:serialize()

      assert.is_not_nil(result.numbered_list_item.rich_text)
    end)

    it('should preserve color on serialization', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = {
          rich_text = { { plain_text = 'Text' } },
          color = 'blue',
        },
      }

      local block = numbered_list_module.new(raw)
      local result = block:serialize()

      assert.are.equal('blue', result.numbered_list_item.color)
    end)
  end)

  describe('NumberedListBlock:update_from_lines', function()
    it('should strip number prefix and update text', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = {
          rich_text = { { plain_text = 'Original' } },
        },
      }

      local block = numbered_list_module.new(raw)
      block:update_from_lines({ '1. New text' })

      assert.are.equal('New text', block:get_text())
      assert.is_true(block:is_dirty())
    end)

    it('should handle different numbers', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = {
          rich_text = { { plain_text = 'Original' } },
        },
      }

      local block = numbered_list_module.new(raw)
      block:update_from_lines({ '5. New text' })

      assert.are.equal('New text', block:get_text())
    end)

    it('should handle multi-digit numbers', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = {
          rich_text = { { plain_text = 'Original' } },
        },
      }

      local block = numbered_list_module.new(raw)
      block:update_from_lines({ '123. New text' })

      assert.are.equal('New text', block:get_text())
    end)

    it('should convert to paragraph when number has no space after dot', function()
      -- "1.No space" is not valid markdown numbered list format
      -- Valid format requires space: "1. text"
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = {
          rich_text = { { plain_text = 'Original' } },
        },
      }

      local block = numbered_list_module.new(raw)
      block:update_from_lines({ '1.No space' })

      -- Should trigger conversion to paragraph
      assert.is_true(block:type_changed())
      assert.are.equal('paragraph', block:get_type())
    end)

    it('should handle line without prefix', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = {
          rich_text = { { plain_text = 'Original' } },
        },
      }

      local block = numbered_list_module.new(raw)
      block:update_from_lines({ 'No prefix text' })

      assert.are.equal('No prefix text', block:get_text())
    end)

    it('should handle empty lines', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = {
          rich_text = { { plain_text = 'Original' } },
        },
      }

      local block = numbered_list_module.new(raw)
      block:update_from_lines({})

      assert.is_not_nil(block:get_text())
    end)

    it('should not mark dirty if text unchanged', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = {
          rich_text = { { plain_text = 'Same text' } },
        },
      }

      local block = numbered_list_module.new(raw)
      block:update_from_lines({ '1. Same text' })

      assert.is_false(block:is_dirty())
    end)

    it('should handle multi-line content', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = {
          rich_text = { { plain_text = 'Original' } },
        },
      }

      local block = numbered_list_module.new(raw)
      block:update_from_lines({ '1. First line', '   Continuation' })

      assert.are.equal('First line\nContinuation', block:get_text())
    end)
  end)

  describe('NumberedListBlock:get_text', function()
    it('should return text without prefix', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = {
          rich_text = { { plain_text = 'List content' } },
        },
      }

      local block = numbered_list_module.new(raw)

      assert.are.equal('List content', block:get_text())
    end)
  end)

  describe('NumberedListBlock:matches_content', function()
    it('should match when text is same (ignoring prefix)', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = {
          rich_text = { { plain_text = 'List text' } },
        },
      }

      local block = numbered_list_module.new(raw)

      assert.is_true(block:matches_content({ '1. List text' }))
    end)

    it('should match with different number prefix', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = {
          rich_text = { { plain_text = 'List text' } },
        },
      }

      local block = numbered_list_module.new(raw)

      assert.is_true(block:matches_content({ '5. List text' }))
    end)

    it('should not match when text differs', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = {
          rich_text = { { plain_text = 'Original' } },
        },
      }

      local block = numbered_list_module.new(raw)

      assert.is_false(block:matches_content({ '1. Different' }))
    end)
  end)

  describe('NumberedListBlock:render', function()
    it('should return false (use default text rendering)', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = {
          rich_text = { { plain_text = 'Item' } },
        },
      }

      local block = numbered_list_module.new(raw)
      local mock_ctx = {}

      local handled = block:render(mock_ctx)

      assert.is_false(handled)
    end)
  end)

  describe('NumberedListBlock:has_children', function()
    it('should return true when API says has_children', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = { rich_text = {} },
        has_children = true,
      }

      local block = numbered_list_module.new(raw)

      assert.is_true(block:has_children())
    end)

    it('should return false when no children', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = { rich_text = {} },
        has_children = false,
      }

      local block = numbered_list_module.new(raw)

      assert.is_false(block:has_children())
    end)

    it('should support children (nested lists)', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = { rich_text = {} },
      }

      local block = numbered_list_module.new(raw)

      assert.is_true(block:supports_children())
    end)
  end)

  describe('NumberedListBlock:get_rich_text_segments', function()
    it('should convert rich_text to RichTextSegment array', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = {
          rich_text = {
            {
              plain_text = 'Italic item',
              annotations = { bold = false, italic = true, strikethrough = false, underline = false, code = false },
              text = { content = 'Italic item' },
            },
          },
        },
      }

      local block = numbered_list_module.new(raw)
      local segments = block:get_rich_text_segments()

      assert.are.equal(1, #segments)
      assert.are.equal('Italic item', segments[1].text)
    end)
  end)

  describe('M.is_editable', function()
    it('should return true', function()
      assert.is_true(numbered_list_module.is_editable())
    end)
  end)

  -- Type conversion tests
  describe('type conversion', function()
    describe('type_changed', function()
      it('should return false when number prefix is preserved', function()
        local raw = {
          id = 'test',
          type = 'numbered_list_item',
          numbered_list_item = { rich_text = { { plain_text = 'Item' } } },
        }
        local block = numbered_list_module.new(raw)

        block:update_from_lines({ '1. Item' })

        assert.is_false(block:type_changed())
      end)

      it('should return true when prefix is removed (convert to paragraph)', function()
        local raw = {
          id = 'test',
          type = 'numbered_list_item',
          numbered_list_item = { rich_text = { { plain_text = 'Item' } } },
        }
        local block = numbered_list_module.new(raw)

        block:update_from_lines({ 'No prefix anymore' })

        assert.is_true(block:type_changed())
      end)

      it('should return true when changed to bullet prefix', function()
        local raw = {
          id = 'test',
          type = 'numbered_list_item',
          numbered_list_item = { rich_text = { { plain_text = 'Item' } } },
        }
        local block = numbered_list_module.new(raw)

        block:update_from_lines({ '- Now a bullet' })

        assert.is_true(block:type_changed())
      end)

      it('should return true when changed to quote prefix', function()
        local raw = {
          id = 'test',
          type = 'numbered_list_item',
          numbered_list_item = { rich_text = { { plain_text = 'Item' } } },
        }
        local block = numbered_list_module.new(raw)

        block:update_from_lines({ '| Now a quote' })

        assert.is_true(block:type_changed())
      end)
    end)

    describe('get_type', function()
      it('should return numbered_list_item when prefix preserved', function()
        local raw = {
          id = 'test',
          type = 'numbered_list_item',
          numbered_list_item = { rich_text = { { plain_text = 'Item' } } },
        }
        local block = numbered_list_module.new(raw)

        block:update_from_lines({ '1. Item' })

        assert.are.equal('numbered_list_item', block:get_type())
      end)

      it('should return paragraph when prefix removed', function()
        local raw = {
          id = 'test',
          type = 'numbered_list_item',
          numbered_list_item = { rich_text = { { plain_text = 'Item' } } },
        }
        local block = numbered_list_module.new(raw)

        block:update_from_lines({ 'Plain text now' })

        assert.are.equal('paragraph', block:get_type())
      end)

      it('should return bulleted_list_item when changed to bullet', function()
        local raw = {
          id = 'test',
          type = 'numbered_list_item',
          numbered_list_item = { rich_text = { { plain_text = 'Item' } } },
        }
        local block = numbered_list_module.new(raw)

        block:update_from_lines({ '- Bullet now' })

        assert.are.equal('bulleted_list_item', block:get_type())
      end)

      it('should return quote when changed to quote prefix', function()
        local raw = {
          id = 'test',
          type = 'numbered_list_item',
          numbered_list_item = { rich_text = { { plain_text = 'Item' } } },
        }
        local block = numbered_list_module.new(raw)

        block:update_from_lines({ '| Quoted now' })

        assert.are.equal('quote', block:get_type())
      end)
    end)

    describe('get_converted_content', function()
      it('should return text when not converting', function()
        local raw = {
          id = 'test',
          type = 'numbered_list_item',
          numbered_list_item = { rich_text = { { plain_text = 'Item' } } },
        }
        local block = numbered_list_module.new(raw)

        block:update_from_lines({ '1. Item' })

        assert.are.equal('Item', block:get_converted_content())
      end)

      it('should strip bullet prefix when converting to bullet', function()
        local raw = {
          id = 'test',
          type = 'numbered_list_item',
          numbered_list_item = { rich_text = { { plain_text = 'Item' } } },
        }
        local block = numbered_list_module.new(raw)

        block:update_from_lines({ '- Now a bullet' })

        assert.are.equal('Now a bullet', block:get_converted_content())
      end)

      it('should strip quote prefix when converting to quote', function()
        local raw = {
          id = 'test',
          type = 'numbered_list_item',
          numbered_list_item = { rich_text = { { plain_text = 'Item' } } },
        }
        local block = numbered_list_module.new(raw)

        block:update_from_lines({ '| Now a quote' })

        assert.are.equal('Now a quote', block:get_converted_content())
      end)

      it('should return full text when converting to paragraph', function()
        local raw = {
          id = 'test',
          type = 'numbered_list_item',
          numbered_list_item = { rich_text = { { plain_text = 'Item' } } },
        }
        local block = numbered_list_module.new(raw)

        block:update_from_lines({ 'Plain paragraph' })

        assert.are.equal('Plain paragraph', block:get_converted_content())
      end)
    end)
  end)

  describe('NumberedListBlock:set_number', function()
    it('should update the number field', function()
      local raw = {
        id = 'test',
        type = 'numbered_list_item',
        numbered_list_item = { rich_text = { { plain_text = 'Item' } } },
      }

      local block = numbered_list_module.new(raw)
      block:set_number(5)

      assert.are.equal(5, block.number)
    end)
  end)
end)
