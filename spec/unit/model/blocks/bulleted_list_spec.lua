describe('neotion.model.blocks.bulleted_list', function()
  local bulleted_list_module

  before_each(function()
    package.loaded['neotion.model.blocks.bulleted_list'] = nil
    package.loaded['neotion.model.block'] = nil
    package.loaded['neotion.api.blocks'] = nil
    bulleted_list_module = require('neotion.model.blocks.bulleted_list')
  end)

  describe('BulletedListBlock.new', function()
    it('should create a bulleted list item from raw JSON', function()
      local raw = {
        id = 'bullet123',
        type = 'bulleted_list_item',
        bulleted_list_item = {
          rich_text = { { plain_text = 'List item' } },
          color = 'default',
        },
      }

      local block = bulleted_list_module.new(raw)

      assert.are.equal('bullet123', block:get_id())
      assert.are.equal('bulleted_list_item', block:get_type())
    end)

    it('should be marked as editable', function()
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = { rich_text = {} },
      }

      local block = bulleted_list_module.new(raw)

      assert.is_true(block:is_editable())
    end)

    it('should extract plain text from rich_text', function()
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = {
          rich_text = {
            { plain_text = 'First ' },
            { plain_text = 'Second' },
          },
        },
      }

      local block = bulleted_list_module.new(raw)

      assert.are.equal('First Second', block:get_text())
    end)

    it('should handle empty rich_text', function()
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = { rich_text = {} },
      }

      local block = bulleted_list_module.new(raw)

      assert.are.equal('', block:get_text())
    end)

    it('should handle missing bulleted_list_item field', function()
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
      }

      local block = bulleted_list_module.new(raw)

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
        type = 'bulleted_list_item',
        bulleted_list_item = { rich_text = rich_text },
      }

      local block = bulleted_list_module.new(raw)

      assert.are.same(rich_text, block.rich_text)
    end)

    it('should preserve color property', function()
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = {
          rich_text = { { plain_text = 'Colored item' } },
          color = 'red',
        },
      }

      local block = bulleted_list_module.new(raw)

      assert.are.equal('red', block.color)
    end)
  end)

  describe('BulletedListBlock:format', function()
    it('should return line with - prefix', function()
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = {
          rich_text = { { plain_text = 'List item' } },
        },
      }

      local block = bulleted_list_module.new(raw)
      local lines = block:format()

      assert.are.equal(1, #lines)
      assert.are.equal('- List item', lines[1])
    end)

    it('should handle empty bullet', function()
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = { rich_text = {} },
      }

      local block = bulleted_list_module.new(raw)
      local lines = block:format()

      assert.are.equal('- ', lines[1])
    end)

    it('should handle multi-line content (soft breaks from Notion)', function()
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = {
          rich_text = { { plain_text = 'First line\nContinuation\nMore content' } },
        },
      }

      local block = bulleted_list_module.new(raw)
      local lines = block:format()

      -- First line gets bullet prefix, continuation lines are indented
      assert.are.equal(3, #lines)
      assert.are.equal('- First line', lines[1])
      assert.are.equal('  Continuation', lines[2])
      assert.are.equal('  More content', lines[3])
    end)
  end)

  describe('BulletedListBlock:serialize', function()
    it('should return original raw when text unchanged', function()
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = {
          rich_text = { { plain_text = 'Original', text = { content = 'Original' } } },
          color = 'default',
        },
      }

      local block = bulleted_list_module.new(raw)
      local result = block:serialize()

      assert.are.equal('bulleted_list_item', result.type)
      assert.is_not_nil(result.bulleted_list_item)
    end)

    it('should update rich_text when text changed', function()
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = {
          rich_text = { { plain_text = 'Original', text = { content = 'Original' } } },
        },
      }

      local block = bulleted_list_module.new(raw)
      block:update_from_lines({ '- Modified text' })
      local result = block:serialize()

      assert.is_not_nil(result.bulleted_list_item.rich_text)
    end)

    it('should preserve color on serialization', function()
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = {
          rich_text = { { plain_text = 'Text' } },
          color = 'blue',
        },
      }

      local block = bulleted_list_module.new(raw)
      local result = block:serialize()

      assert.are.equal('blue', result.bulleted_list_item.color)
    end)
  end)

  describe('BulletedListBlock:update_from_lines', function()
    it('should strip - prefix and update text', function()
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = {
          rich_text = { { plain_text = 'Original' } },
        },
      }

      local block = bulleted_list_module.new(raw)
      block:update_from_lines({ '- New text' })

      assert.are.equal('New text', block:get_text())
      assert.is_true(block:is_dirty())
    end)

    it('should handle * prefix', function()
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = {
          rich_text = { { plain_text = 'Original' } },
        },
      }

      local block = bulleted_list_module.new(raw)
      block:update_from_lines({ '* New text' })

      assert.are.equal('New text', block:get_text())
    end)

    it('should handle + prefix', function()
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = {
          rich_text = { { plain_text = 'Original' } },
        },
      }

      local block = bulleted_list_module.new(raw)
      block:update_from_lines({ '+ New text' })

      assert.are.equal('New text', block:get_text())
    end)

    it('should handle line without prefix', function()
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = {
          rich_text = { { plain_text = 'Original' } },
        },
      }

      local block = bulleted_list_module.new(raw)
      block:update_from_lines({ 'No prefix text' })

      assert.are.equal('No prefix text', block:get_text())
    end)

    it('should handle empty lines', function()
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = {
          rich_text = { { plain_text = 'Original' } },
        },
      }

      local block = bulleted_list_module.new(raw)
      block:update_from_lines({})

      assert.is_not_nil(block:get_text())
    end)

    it('should handle content starting with dash', function()
      -- e.g., "- -5 degrees" should become "-5 degrees" not "5 degrees"
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = {
          rich_text = { { plain_text = 'Original' } },
        },
      }

      local block = bulleted_list_module.new(raw)
      block:update_from_lines({ '- -5 degrees' })

      assert.are.equal('-5 degrees', block:get_text())
    end)

    it('should not mark dirty if text unchanged', function()
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = {
          rich_text = { { plain_text = 'Same text' } },
        },
      }

      local block = bulleted_list_module.new(raw)
      block:update_from_lines({ '- Same text' })

      assert.is_false(block:is_dirty())
    end)
  end)

  describe('BulletedListBlock:get_text', function()
    it('should return text without prefix', function()
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = {
          rich_text = { { plain_text = 'List content' } },
        },
      }

      local block = bulleted_list_module.new(raw)

      assert.are.equal('List content', block:get_text())
    end)
  end)

  describe('BulletedListBlock:matches_content', function()
    it('should match when text is same (ignoring prefix)', function()
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = {
          rich_text = { { plain_text = 'List text' } },
        },
      }

      local block = bulleted_list_module.new(raw)

      assert.is_true(block:matches_content({ '- List text' }))
    end)

    it('should match with * prefix too', function()
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = {
          rich_text = { { plain_text = 'List text' } },
        },
      }

      local block = bulleted_list_module.new(raw)

      assert.is_true(block:matches_content({ '* List text' }))
    end)

    it('should match with + prefix too', function()
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = {
          rich_text = { { plain_text = 'List text' } },
        },
      }

      local block = bulleted_list_module.new(raw)

      assert.is_true(block:matches_content({ '+ List text' }))
    end)

    it('should not match when text differs', function()
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = {
          rich_text = { { plain_text = 'Original' } },
        },
      }

      local block = bulleted_list_module.new(raw)

      assert.is_false(block:matches_content({ '- Different' }))
    end)
  end)

  describe('BulletedListBlock:render', function()
    it('should return false (use default text rendering)', function()
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = {
          rich_text = { { plain_text = 'Item' } },
        },
      }

      local block = bulleted_list_module.new(raw)
      local mock_ctx = {}

      local handled = block:render(mock_ctx)

      assert.is_false(handled)
    end)
  end)

  describe('BulletedListBlock:has_children', function()
    it('should return false (nesting not supported in Phase 5.7)', function()
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = { rich_text = {} },
        has_children = true,
      }

      local block = bulleted_list_module.new(raw)

      assert.is_false(block:has_children())
    end)
  end)

  describe('BulletedListBlock:get_rich_text_segments', function()
    it('should convert rich_text to RichTextSegment array', function()
      local raw = {
        id = 'test',
        type = 'bulleted_list_item',
        bulleted_list_item = {
          rich_text = {
            {
              plain_text = 'Italic item',
              annotations = { bold = false, italic = true, strikethrough = false, underline = false, code = false },
              text = { content = 'Italic item' },
            },
          },
        },
      }

      local block = bulleted_list_module.new(raw)
      local segments = block:get_rich_text_segments()

      assert.are.equal(1, #segments)
      assert.are.equal('Italic item', segments[1].text)
    end)
  end)

  describe('M.is_editable', function()
    it('should return true', function()
      assert.is_true(bulleted_list_module.is_editable())
    end)
  end)

  -- Phase 5.8: Block Type Conversion
  describe('type conversion', function()
    describe('type_changed', function()
      it('should return false when bullet prefix is preserved', function()
        local raw = {
          id = 'test',
          type = 'bulleted_list_item',
          bulleted_list_item = { rich_text = { { plain_text = 'Item' } } },
        }
        local block = bulleted_list_module.new(raw)

        block:update_from_lines({ '- Item' })

        assert.is_false(block:type_changed())
      end)

      it('should return true when prefix is removed (convert to paragraph)', function()
        local raw = {
          id = 'test',
          type = 'bulleted_list_item',
          bulleted_list_item = { rich_text = { { plain_text = 'Item' } } },
        }
        local block = bulleted_list_module.new(raw)

        block:update_from_lines({ 'No prefix anymore' })

        assert.is_true(block:type_changed())
      end)

      it('should return true when changed to quote prefix', function()
        local raw = {
          id = 'test',
          type = 'bulleted_list_item',
          bulleted_list_item = { rich_text = { { plain_text = 'Item' } } },
        }
        local block = bulleted_list_module.new(raw)

        block:update_from_lines({ '| Now a quote' })

        assert.is_true(block:type_changed())
      end)
    end)

    describe('get_type', function()
      it('should return bulleted_list_item when prefix preserved', function()
        local raw = {
          id = 'test',
          type = 'bulleted_list_item',
          bulleted_list_item = { rich_text = { { plain_text = 'Item' } } },
        }
        local block = bulleted_list_module.new(raw)

        block:update_from_lines({ '- Item' })

        assert.are.equal('bulleted_list_item', block:get_type())
      end)

      it('should return paragraph when prefix removed', function()
        local raw = {
          id = 'test',
          type = 'bulleted_list_item',
          bulleted_list_item = { rich_text = { { plain_text = 'Item' } } },
        }
        local block = bulleted_list_module.new(raw)

        block:update_from_lines({ 'Plain text now' })

        assert.are.equal('paragraph', block:get_type())
      end)

      it('should return quote when changed to quote prefix', function()
        local raw = {
          id = 'test',
          type = 'bulleted_list_item',
          bulleted_list_item = { rich_text = { { plain_text = 'Item' } } },
        }
        local block = bulleted_list_module.new(raw)

        block:update_from_lines({ '| Quoted now' })

        assert.are.equal('quote', block:get_type())
      end)
    end)

    describe('get_text for conversion', function()
      it('should return content without prefix when converting to paragraph', function()
        local raw = {
          id = 'test',
          type = 'bulleted_list_item',
          bulleted_list_item = { rich_text = { { plain_text = 'Item' } } },
        }
        local block = bulleted_list_module.new(raw)

        block:update_from_lines({ 'Plain text' })

        -- Text should be the full content for paragraph conversion
        assert.are.equal('Plain text', block:get_text())
      end)
    end)

    describe('get_converted_content', function()
      it('should return text when not converting', function()
        local raw = {
          id = 'test',
          type = 'bulleted_list_item',
          bulleted_list_item = { rich_text = { { plain_text = 'Item' } } },
        }
        local block = bulleted_list_module.new(raw)

        block:update_from_lines({ '- Item' })

        assert.are.equal('Item', block:get_converted_content())
      end)

      it('should strip quote prefix when converting to quote', function()
        local raw = {
          id = 'test',
          type = 'bulleted_list_item',
          bulleted_list_item = { rich_text = { { plain_text = 'Item' } } },
        }
        local block = bulleted_list_module.new(raw)

        block:update_from_lines({ '| Now a quote' })

        assert.are.equal('Now a quote', block:get_converted_content())
      end)

      it('should return full text when converting to paragraph', function()
        local raw = {
          id = 'test',
          type = 'bulleted_list_item',
          bulleted_list_item = { rich_text = { { plain_text = 'Item' } } },
        }
        local block = bulleted_list_module.new(raw)

        block:update_from_lines({ 'Plain paragraph' })

        -- No prefix to strip, return as-is
        assert.are.equal('Plain paragraph', block:get_converted_content())
      end)
    end)
  end)
end)
