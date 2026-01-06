describe('neotion.input.completion.colors', function()
  local colors

  before_each(function()
    package.loaded['neotion.input.completion.colors'] = nil
    colors = require('neotion.input.completion.colors')
  end)

  describe('TEXT_COLORS', function()
    it('includes all Notion API text colors', function()
      local expected = {
        'default',
        'gray',
        'brown',
        'orange',
        'yellow',
        'green',
        'blue',
        'purple',
        'pink',
        'red',
      }

      for _, color in ipairs(expected) do
        assert.is_true(vim.tbl_contains(colors.TEXT_COLORS, color), 'Missing text color: ' .. color)
      end
    end)
  end)

  describe('BACKGROUND_COLORS', function()
    it('includes all Notion API background colors', function()
      local expected = {
        'gray_background',
        'brown_background',
        'orange_background',
        'yellow_background',
        'green_background',
        'blue_background',
        'purple_background',
        'pink_background',
        'red_background',
      }

      for _, color in ipairs(expected) do
        assert.is_true(vim.tbl_contains(colors.BACKGROUND_COLORS, color), 'Missing background color: ' .. color)
      end
    end)
  end)

  describe('get_items', function()
    it('returns items for all colors with empty query', function()
      local items
      colors.get_items('', function(result)
        items = result
      end)

      -- Should have both text and background colors
      -- 10 text colors + 9 background colors = 19
      assert.is_true(#items >= 19)
    end)

    it('filters items by query', function()
      local items
      colors.get_items('red', function(result)
        items = result
      end)

      -- Should include 'Red' and 'Red background'
      assert.are.equal(2, #items)
      for _, item in ipairs(items) do
        assert.is_true(item.label:lower():find('red') ~= nil, 'Item "' .. item.label .. '" should match "red"')
      end
    end)

    it('filters background colors specifically', function()
      local items
      colors.get_items('background', function(result)
        items = result
      end)

      -- Should only return background colors
      for _, item in ipairs(items) do
        assert.is_true(
          item.value.color:find('_background') ~= nil,
          'Item should be a background color: ' .. item.value.color
        )
      end
    end)

    it('returns items with correct value structure', function()
      local items
      colors.get_items('blue', function(result)
        items = result
      end)

      for _, item in ipairs(items) do
        assert.is_table(item.value)
        assert.are.equal('color', item.value.type)
        assert.is_string(item.value.color)
      end
    end)

    it('items have required fields', function()
      local items
      colors.get_items('', function(result)
        items = result
      end)

      for _, item in ipairs(items) do
        assert.is_string(item.label)
        assert.is_table(item.value)
        assert.is_string(item.icon)
        if item.description then
          assert.is_string(item.description)
        end
      end
    end)
  end)

  describe('format_color_syntax', function()
    it('formats text color syntax', function()
      local result = colors.format_color_syntax('red')
      assert.are.equal('<c:red></c>', result)
    end)

    it('formats background color syntax', function()
      local result = colors.format_color_syntax('blue_background')
      assert.are.equal('<c:blue_background></c>', result)
    end)

    it('returns empty string for default color', function()
      local result = colors.format_color_syntax('default')
      assert.are.equal('', result)
    end)
  end)

  describe('is_background_color', function()
    it('returns true for background colors', function()
      assert.is_true(colors.is_background_color('red_background'))
      assert.is_true(colors.is_background_color('blue_background'))
    end)

    it('returns false for text colors', function()
      assert.is_false(colors.is_background_color('red'))
      assert.is_false(colors.is_background_color('blue'))
      assert.is_false(colors.is_background_color('default'))
    end)
  end)
end)
