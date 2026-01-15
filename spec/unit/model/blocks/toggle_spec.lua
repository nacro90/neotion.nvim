describe('neotion.model.blocks.toggle', function()
  local toggle_module

  before_each(function()
    package.loaded['neotion.model.blocks.toggle'] = nil
    package.loaded['neotion.model.block'] = nil
    package.loaded['neotion.api.blocks'] = nil
    toggle_module = require('neotion.model.blocks.toggle')
  end)

  describe('ToggleBlock.new', function()
    it('should create a toggle from raw JSON', function()
      local raw = {
        id = 'toggle123',
        type = 'toggle',
        toggle = {
          rich_text = { { plain_text = 'Toggle content' } },
          color = 'default',
        },
      }

      local block = toggle_module.new(raw)

      assert.are.equal('toggle123', block:get_id())
      assert.are.equal('toggle', block:get_type())
    end)

    it('should be marked as editable', function()
      local raw = {
        id = 'test',
        type = 'toggle',
        toggle = { rich_text = {} },
      }

      local block = toggle_module.new(raw)

      assert.is_true(block:is_editable())
    end)

    it('should extract plain text from rich_text', function()
      local raw = {
        id = 'test',
        type = 'toggle',
        toggle = {
          rich_text = {
            { plain_text = 'First ' },
            { plain_text = 'Second' },
          },
        },
      }

      local block = toggle_module.new(raw)

      assert.are.equal('First Second', block:get_text())
    end)

    it('should handle empty rich_text', function()
      local raw = {
        id = 'test',
        type = 'toggle',
        toggle = { rich_text = {} },
      }

      local block = toggle_module.new(raw)

      assert.are.equal('', block:get_text())
    end)

    it('should handle missing toggle field', function()
      local raw = {
        id = 'test',
        type = 'toggle',
      }

      local block = toggle_module.new(raw)

      assert.are.equal('', block:get_text())
    end)

    it('should preserve original rich_text for round-trip', function()
      local rich_text = {
        {
          type = 'text',
          plain_text = 'Bold toggle',
          annotations = { bold = true },
        },
      }
      local raw = {
        id = 'test',
        type = 'toggle',
        toggle = { rich_text = rich_text },
      }

      local block = toggle_module.new(raw)

      assert.are.same(rich_text, block.rich_text)
    end)

    it('should preserve color property', function()
      local raw = {
        id = 'test',
        type = 'toggle',
        toggle = {
          rich_text = { { plain_text = 'Colored toggle' } },
          color = 'blue',
        },
      }

      local block = toggle_module.new(raw)

      assert.are.equal('blue', block.color)
    end)
  end)

  describe('ToggleBlock:format', function()
    it('should return line with > prefix', function()
      local raw = {
        id = 'test',
        type = 'toggle',
        toggle = {
          rich_text = { { plain_text = 'Toggle text' } },
        },
      }

      local block = toggle_module.new(raw)
      local lines = block:format()

      assert.are.equal(1, #lines)
      assert.are.equal('> Toggle text', lines[1])
    end)

    it('should handle empty toggle', function()
      local raw = {
        id = 'test',
        type = 'toggle',
        toggle = { rich_text = {} },
      }

      local block = toggle_module.new(raw)
      local lines = block:format()

      assert.are.equal('> ', lines[1])
    end)

    it('should include formatting markers in output', function()
      local raw = {
        id = 'test',
        type = 'toggle',
        toggle = {
          rich_text = {
            {
              plain_text = 'bold text',
              annotations = { bold = true },
              text = { content = 'bold text' },
            },
          },
        },
      }

      local block = toggle_module.new(raw)
      local lines = block:format()

      -- Should have prefix and formatted content
      assert.truthy(lines[1]:match('^> '))
    end)
  end)

  describe('ToggleBlock:serialize', function()
    it('should return original raw when text unchanged', function()
      local raw = {
        id = 'test',
        type = 'toggle',
        toggle = {
          rich_text = { { plain_text = 'Original', text = { content = 'Original' } } },
          color = 'default',
        },
      }

      local block = toggle_module.new(raw)
      local result = block:serialize()

      assert.are.equal('toggle', result.type)
      assert.is_not_nil(result.toggle)
    end)

    it('should update rich_text when text changed', function()
      local raw = {
        id = 'test',
        type = 'toggle',
        toggle = {
          rich_text = { { plain_text = 'Original', text = { content = 'Original' } } },
        },
      }

      local block = toggle_module.new(raw)
      block:update_from_lines({ '> Modified text' })
      local result = block:serialize()

      -- rich_text should be updated
      assert.is_not_nil(result.toggle.rich_text)
    end)

    it('should preserve color on serialization', function()
      local raw = {
        id = 'test',
        type = 'toggle',
        toggle = {
          rich_text = { { plain_text = 'Text' } },
          color = 'red',
        },
      }

      local block = toggle_module.new(raw)
      local result = block:serialize()

      assert.are.equal('red', result.toggle.color)
    end)
  end)

  describe('ToggleBlock:update_from_lines', function()
    it('should strip > prefix and update text', function()
      local raw = {
        id = 'test',
        type = 'toggle',
        toggle = {
          rich_text = { { plain_text = 'Original' } },
        },
      }

      local block = toggle_module.new(raw)
      block:update_from_lines({ '> New text' })

      assert.are.equal('New text', block:get_text())
      assert.is_true(block:is_dirty())
    end)

    it('should handle line without prefix', function()
      local raw = {
        id = 'test',
        type = 'toggle',
        toggle = {
          rich_text = { { plain_text = 'Original' } },
        },
      }

      local block = toggle_module.new(raw)
      block:update_from_lines({ 'No prefix text' })

      assert.are.equal('No prefix text', block:get_text())
    end)

    it('should handle empty lines', function()
      local raw = {
        id = 'test',
        type = 'toggle',
        toggle = {
          rich_text = { { plain_text = 'Original' } },
        },
      }

      local block = toggle_module.new(raw)
      block:update_from_lines({})

      -- Should be empty
      assert.are.equal('', block:get_text())
    end)

    it('should not mark dirty if text unchanged', function()
      local raw = {
        id = 'test',
        type = 'toggle',
        toggle = {
          rich_text = { { plain_text = 'Same text' } },
        },
      }

      local block = toggle_module.new(raw)
      block:update_from_lines({ '> Same text' })

      assert.is_false(block:is_dirty())
    end)
  end)

  describe('ToggleBlock:get_text', function()
    it('should return text without prefix', function()
      local raw = {
        id = 'test',
        type = 'toggle',
        toggle = {
          rich_text = { { plain_text = 'Toggle content' } },
        },
      }

      local block = toggle_module.new(raw)

      assert.are.equal('Toggle content', block:get_text())
    end)
  end)

  describe('ToggleBlock:matches_content', function()
    it('should match when text is same (ignoring prefix)', function()
      local raw = {
        id = 'test',
        type = 'toggle',
        toggle = {
          rich_text = { { plain_text = 'Toggle text' } },
        },
      }

      local block = toggle_module.new(raw)

      assert.is_true(block:matches_content({ '> Toggle text' }))
    end)

    it('should not match when text differs', function()
      local raw = {
        id = 'test',
        type = 'toggle',
        toggle = {
          rich_text = { { plain_text = 'Original' } },
        },
      }

      local block = toggle_module.new(raw)

      assert.is_false(block:matches_content({ '> Different' }))
    end)
  end)

  describe('ToggleBlock:has_children', function()
    it('should return false (children not supported in MVP)', function()
      local raw = {
        id = 'test',
        type = 'toggle',
        toggle = { rich_text = {} },
        has_children = true, -- API says it has children
      }

      local block = toggle_module.new(raw)

      -- MVP ignores children
      assert.is_false(block:has_children())
    end)
  end)

  describe('ToggleBlock:get_gutter_icon', function()
    it('should return collapsed icon', function()
      local raw = {
        id = 'test',
        type = 'toggle',
        toggle = { rich_text = { { plain_text = 'Text' } } },
      }

      local block = toggle_module.new(raw)
      local icon = block:get_gutter_icon()

      -- Should be a non-nil icon string
      assert.is_not_nil(icon)
      assert.is_string(icon)
    end)
  end)

  describe('ToggleBlock:get_rich_text_segments', function()
    it('should convert rich_text to RichTextSegment array', function()
      local raw = {
        id = 'test',
        type = 'toggle',
        toggle = {
          rich_text = {
            {
              plain_text = 'Bold text',
              annotations = { bold = true, italic = false, strikethrough = false, underline = false, code = false },
              text = { content = 'Bold text' },
            },
          },
        },
      }

      local block = toggle_module.new(raw)
      local segments = block:get_rich_text_segments()

      assert.are.equal(1, #segments)
      assert.are.equal('Bold text', segments[1].text)
    end)
  end)

  describe('M.is_editable', function()
    it('should return true', function()
      assert.is_true(toggle_module.is_editable())
    end)
  end)

  -- Type conversion tests
  describe('type conversion', function()
    describe('type_changed', function()
      it('should return false when toggle prefix is preserved', function()
        local raw = {
          id = 'test',
          type = 'toggle',
          toggle = { rich_text = { { plain_text = 'Text' } } },
        }
        local block = toggle_module.new(raw)

        block:update_from_lines({ '> Text' })

        assert.is_false(block:type_changed())
      end)

      it('should return true when prefix is removed (convert to paragraph)', function()
        local raw = {
          id = 'test',
          type = 'toggle',
          toggle = { rich_text = { { plain_text = 'Text' } } },
        }
        local block = toggle_module.new(raw)

        block:update_from_lines({ 'No prefix anymore' })

        assert.is_true(block:type_changed())
      end)

      it('should return true when changed to bullet prefix', function()
        local raw = {
          id = 'test',
          type = 'toggle',
          toggle = { rich_text = { { plain_text = 'Text' } } },
        }
        local block = toggle_module.new(raw)

        block:update_from_lines({ '- Now a bullet' })

        assert.is_true(block:type_changed())
      end)
    end)

    describe('get_type', function()
      it('should return toggle when prefix preserved', function()
        local raw = {
          id = 'test',
          type = 'toggle',
          toggle = { rich_text = { { plain_text = 'Text' } } },
        }
        local block = toggle_module.new(raw)

        block:update_from_lines({ '> Text' })

        assert.are.equal('toggle', block:get_type())
      end)

      it('should return paragraph when prefix removed', function()
        local raw = {
          id = 'test',
          type = 'toggle',
          toggle = { rich_text = { { plain_text = 'Text' } } },
        }
        local block = toggle_module.new(raw)

        block:update_from_lines({ 'Plain text now' })

        assert.are.equal('paragraph', block:get_type())
      end)

      it('should return bulleted_list_item when changed to bullet prefix', function()
        local raw = {
          id = 'test',
          type = 'toggle',
          toggle = { rich_text = { { plain_text = 'Text' } } },
        }
        local block = toggle_module.new(raw)

        block:update_from_lines({ '- Bullet now' })

        assert.are.equal('bulleted_list_item', block:get_type())
      end)

      it('should return quote when changed to quote prefix', function()
        local raw = {
          id = 'test',
          type = 'toggle',
          toggle = { rich_text = { { plain_text = 'Text' } } },
        }
        local block = toggle_module.new(raw)

        block:update_from_lines({ '| Quote now' })

        assert.are.equal('quote', block:get_type())
      end)
    end)

    describe('get_converted_content', function()
      it('should return text when not converting', function()
        local raw = {
          id = 'test',
          type = 'toggle',
          toggle = { rich_text = { { plain_text = 'Toggle text' } } },
        }
        local block = toggle_module.new(raw)

        block:update_from_lines({ '> Toggle text' })

        assert.are.equal('Toggle text', block:get_converted_content())
      end)

      it('should strip bullet prefix when converting to bullet', function()
        local raw = {
          id = 'test',
          type = 'toggle',
          toggle = { rich_text = { { plain_text = 'Text' } } },
        }
        local block = toggle_module.new(raw)

        block:update_from_lines({ '- Now a bullet' })

        assert.are.equal('Now a bullet', block:get_converted_content())
      end)

      it('should return full text when converting to paragraph', function()
        local raw = {
          id = 'test',
          type = 'toggle',
          toggle = { rich_text = { { plain_text = 'Text' } } },
        }
        local block = toggle_module.new(raw)

        block:update_from_lines({ 'Plain paragraph' })

        -- No prefix to strip, return as-is
        assert.are.equal('Plain paragraph', block:get_converted_content())
      end)
    end)
  end)
end)
