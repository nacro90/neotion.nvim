---@diagnostic disable: undefined-field
local icons = require('neotion.render.icons')

describe('neotion.render.icons', function()
  describe('PRESETS', function()
    it('should define nerd preset', function()
      assert.is_table(icons.PRESETS.nerd)
    end)

    it('should define ascii preset', function()
      assert.is_table(icons.PRESETS.ascii)
    end)

    describe('nerd preset', function()
      local nerd = icons.PRESETS.nerd

      it('should have heading icons', function()
        assert.is_table(nerd.heading)
        assert.are.equal(3, #nerd.heading)
      end)

      it('should have bullet icons', function()
        assert.is_table(nerd.bullet)
        assert.is_true(#nerd.bullet >= 2)
      end)

      it('should have checkbox icons', function()
        assert.is_string(nerd.checkbox_unchecked)
        assert.is_string(nerd.checkbox_checked)
      end)

      it('should have quote icon', function()
        assert.is_string(nerd.quote)
      end)

      it('should have toggle icons', function()
        assert.is_string(nerd.toggle_collapsed)
        assert.is_string(nerd.toggle_expanded)
      end)

      it('should use nerd font characters for headings', function()
        -- Nerd font icons are typically multi-byte
        for _, icon in ipairs(nerd.heading) do
          assert.is_true(#icon > 1, 'Heading icon should be multi-byte: ' .. icon)
        end
      end)
    end)

    describe('ascii preset', function()
      local ascii = icons.PRESETS.ascii

      it('should have heading markers', function()
        assert.is_table(ascii.heading)
        assert.are.equal(3, #ascii.heading)
        assert.are.equal('# ', ascii.heading[1])
        assert.are.equal('## ', ascii.heading[2])
        assert.are.equal('### ', ascii.heading[3])
      end)

      it('should have bullet markers', function()
        assert.is_table(ascii.bullet)
        assert.is_true(vim.tbl_contains(ascii.bullet, '-'))
      end)

      it('should have checkbox markers', function()
        assert.are.equal('[ ]', ascii.checkbox_unchecked)
        assert.are.equal('[x]', ascii.checkbox_checked)
      end)

      it('should have quote marker', function()
        assert.are.equal('|', ascii.quote)
      end)

      it('should have toggle markers', function()
        assert.are.equal('>', ascii.toggle_collapsed)
        assert.are.equal('v', ascii.toggle_expanded)
      end)
    end)
  end)

  describe('get_icons', function()
    it('should return nerd preset for "nerd"', function()
      local result = icons.get_icons('nerd')

      assert.are.same(icons.PRESETS.nerd, result)
    end)

    it('should return ascii preset for "ascii"', function()
      local result = icons.get_icons('ascii')

      assert.are.same(icons.PRESETS.ascii, result)
    end)

    it('should return nerd preset for nil', function()
      local result = icons.get_icons(nil)

      assert.are.same(icons.PRESETS.nerd, result)
    end)

    it('should return empty icons for false', function()
      local result = icons.get_icons(false)

      assert.is_table(result)
      assert.are.equal(0, #result.heading)
      assert.are.equal(0, #result.bullet)
    end)

    it('should return custom table if provided', function()
      local custom = {
        heading = { 'H1 ', 'H2 ', 'H3 ' },
        bullet = { '*' },
        checkbox_unchecked = '( )',
        checkbox_checked = '(x)',
        quote = '>',
        toggle_collapsed = '+',
        toggle_expanded = '-',
      }

      local result = icons.get_icons(custom)

      assert.are.same(custom, result)
    end)

    it('should merge custom with defaults for partial custom', function()
      local partial = {
        heading = { 'A ', 'B ', 'C ' },
      }

      local result = icons.get_icons(partial)

      assert.are.equal('A ', result.heading[1])
      -- Should have defaults for other fields
      assert.is_string(result.checkbox_unchecked)
    end)
  end)

  describe('get_heading_icon', function()
    it('should return icon for level 1', function()
      local icon = icons.get_heading_icon(1, 'nerd')

      assert.is_string(icon)
      assert.are.equal(icons.PRESETS.nerd.heading[1], icon)
    end)

    it('should return icon for level 2', function()
      local icon = icons.get_heading_icon(2, 'nerd')

      assert.are.equal(icons.PRESETS.nerd.heading[2], icon)
    end)

    it('should return icon for level 3', function()
      local icon = icons.get_heading_icon(3, 'nerd')

      assert.are.equal(icons.PRESETS.nerd.heading[3], icon)
    end)

    it('should clamp to level 3 for higher levels', function()
      local icon = icons.get_heading_icon(5, 'nerd')

      assert.are.equal(icons.PRESETS.nerd.heading[3], icon)
    end)

    it('should return empty string for level 0 or negative', function()
      assert.are.equal('', icons.get_heading_icon(0, 'nerd'))
      assert.are.equal('', icons.get_heading_icon(-1, 'nerd'))
    end)

    it('should use ascii preset when specified', function()
      local icon = icons.get_heading_icon(1, 'ascii')

      assert.are.equal('# ', icon)
    end)
  end)

  describe('get_bullet_icon', function()
    it('should return icon for level 1', function()
      local icon = icons.get_bullet_icon(1, 'nerd')

      assert.is_string(icon)
      assert.are.equal(icons.PRESETS.nerd.bullet[1], icon)
    end)

    it('should cycle through bullet icons', function()
      local preset = icons.PRESETS.nerd
      local num_bullets = #preset.bullet

      -- Level beyond available icons should cycle
      local icon = icons.get_bullet_icon(num_bullets + 1, 'nerd')
      assert.are.equal(preset.bullet[1], icon)
    end)

    it('should use ascii preset when specified', function()
      local icon = icons.get_bullet_icon(1, 'ascii')

      assert.are.equal(icons.PRESETS.ascii.bullet[1], icon)
    end)
  end)

  describe('get_checkbox_icon', function()
    it('should return unchecked icon for false', function()
      local icon = icons.get_checkbox_icon(false, 'nerd')

      assert.are.equal(icons.PRESETS.nerd.checkbox_unchecked, icon)
    end)

    it('should return checked icon for true', function()
      local icon = icons.get_checkbox_icon(true, 'nerd')

      assert.are.equal(icons.PRESETS.nerd.checkbox_checked, icon)
    end)

    it('should use ascii preset when specified', function()
      local unchecked = icons.get_checkbox_icon(false, 'ascii')
      local checked = icons.get_checkbox_icon(true, 'ascii')

      assert.are.equal('[ ]', unchecked)
      assert.are.equal('[x]', checked)
    end)
  end)

  describe('get_toggle_icon', function()
    it('should return collapsed icon for false', function()
      local icon = icons.get_toggle_icon(false, 'nerd')

      assert.are.equal(icons.PRESETS.nerd.toggle_collapsed, icon)
    end)

    it('should return expanded icon for true', function()
      local icon = icons.get_toggle_icon(true, 'nerd')

      assert.are.equal(icons.PRESETS.nerd.toggle_expanded, icon)
    end)

    it('should use ascii preset when specified', function()
      local collapsed = icons.get_toggle_icon(false, 'ascii')
      local expanded = icons.get_toggle_icon(true, 'ascii')

      assert.are.equal('>', collapsed)
      assert.are.equal('v', expanded)
    end)
  end)

  describe('get_quote_icon', function()
    it('should return quote icon', function()
      local icon = icons.get_quote_icon('nerd')

      assert.are.equal(icons.PRESETS.nerd.quote, icon)
    end)

    it('should use ascii preset when specified', function()
      local icon = icons.get_quote_icon('ascii')

      assert.are.equal('|', icon)
    end)
  end)
end)
