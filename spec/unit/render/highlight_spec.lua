---@diagnostic disable: undefined-field
local highlight = require('neotion.render.highlight')

describe('neotion.render.highlight', function()
  describe('GROUPS', function()
    it('should define inline formatting groups', function()
      assert.is_table(highlight.GROUPS.NeotionBold)
      assert.is_table(highlight.GROUPS.NeotionItalic)
      assert.is_table(highlight.GROUPS.NeotionStrikethrough)
      assert.is_table(highlight.GROUPS.NeotionUnderline)
      assert.is_table(highlight.GROUPS.NeotionCode)
    end)

    it('should define foreground color groups', function()
      assert.is_table(highlight.GROUPS.NeotionColorRed)
      assert.is_table(highlight.GROUPS.NeotionColorBlue)
      assert.is_table(highlight.GROUPS.NeotionColorGreen)
      assert.is_table(highlight.GROUPS.NeotionColorYellow)
      assert.is_table(highlight.GROUPS.NeotionColorOrange)
      assert.is_table(highlight.GROUPS.NeotionColorPink)
      assert.is_table(highlight.GROUPS.NeotionColorPurple)
      assert.is_table(highlight.GROUPS.NeotionColorBrown)
      assert.is_table(highlight.GROUPS.NeotionColorGray)
    end)

    it('should define background color groups', function()
      assert.is_table(highlight.GROUPS.NeotionColorRedBg)
      assert.is_table(highlight.GROUPS.NeotionColorBlueBg)
      assert.is_table(highlight.GROUPS.NeotionColorGreenBg)
      assert.is_table(highlight.GROUPS.NeotionColorYellowBg)
      assert.is_table(highlight.GROUPS.NeotionColorOrangeBg)
      assert.is_table(highlight.GROUPS.NeotionColorPinkBg)
      assert.is_table(highlight.GROUPS.NeotionColorPurpleBg)
      assert.is_table(highlight.GROUPS.NeotionColorBrownBg)
      assert.is_table(highlight.GROUPS.NeotionColorGrayBg)
    end)

    it('should define heading groups', function()
      assert.is_table(highlight.GROUPS.NeotionH1)
      assert.is_table(highlight.GROUPS.NeotionH2)
      assert.is_table(highlight.GROUPS.NeotionH3)
    end)

    it('should use bold attribute for NeotionBold', function()
      assert.is_true(highlight.GROUPS.NeotionBold.bold)
    end)

    it('should use italic attribute for NeotionItalic', function()
      assert.is_true(highlight.GROUPS.NeotionItalic.italic)
    end)

    it('should use strikethrough attribute for NeotionStrikethrough', function()
      assert.is_true(highlight.GROUPS.NeotionStrikethrough.strikethrough)
    end)

    it('should use underline attribute for NeotionUnderline', function()
      assert.is_true(highlight.GROUPS.NeotionUnderline.underline)
    end)

    it('should have fg color for foreground color groups', function()
      assert.is_string(highlight.GROUPS.NeotionColorRed.fg)
      assert.is_true(highlight.GROUPS.NeotionColorRed.fg:match('^#') ~= nil)
    end)

    it('should have bg color for background color groups', function()
      assert.is_string(highlight.GROUPS.NeotionColorRedBg.bg)
      assert.is_true(highlight.GROUPS.NeotionColorRedBg.bg:match('^#') ~= nil)
    end)
  end)

  describe('get_annotation_highlights', function()
    it('should return empty table for default annotation', function()
      local types = require('neotion.format.types')
      local annotation = types.Annotation.new()

      local highlights = highlight.get_annotation_highlights(annotation)

      assert.are.equal(0, #highlights)
    end)

    it('should return NeotionBold for bold annotation', function()
      local types = require('neotion.format.types')
      local annotation = types.Annotation.new({ bold = true })

      local highlights = highlight.get_annotation_highlights(annotation)

      assert.are.equal(1, #highlights)
      assert.are.equal('NeotionBold', highlights[1])
    end)

    it('should return multiple highlights for combined formatting', function()
      local types = require('neotion.format.types')
      local annotation = types.Annotation.new({
        bold = true,
        italic = true,
      })

      local highlights = highlight.get_annotation_highlights(annotation)

      assert.are.equal(2, #highlights)
      assert.is_true(vim.tbl_contains(highlights, 'NeotionBold'))
      assert.is_true(vim.tbl_contains(highlights, 'NeotionItalic'))
    end)

    it('should include color highlight', function()
      local types = require('neotion.format.types')
      local annotation = types.Annotation.new({ color = 'red' })

      local highlights = highlight.get_annotation_highlights(annotation)

      assert.are.equal(1, #highlights)
      assert.are.equal('NeotionColorRed', highlights[1])
    end)

    it('should include background color highlight', function()
      local types = require('neotion.format.types')
      local annotation = types.Annotation.new({ color = 'blue_background' })

      local highlights = highlight.get_annotation_highlights(annotation)

      assert.are.equal(1, #highlights)
      assert.are.equal('NeotionColorBlueBg', highlights[1])
    end)

    it('should not include default color', function()
      local types = require('neotion.format.types')
      local annotation = types.Annotation.new({ color = 'default' })

      local highlights = highlight.get_annotation_highlights(annotation)

      assert.are.equal(0, #highlights)
    end)
  end)

  describe('get_heading_highlight', function()
    it('should return NeotionH1 for level 1', function()
      assert.are.equal('NeotionH1', highlight.get_heading_highlight(1))
    end)

    it('should return NeotionH2 for level 2', function()
      assert.are.equal('NeotionH2', highlight.get_heading_highlight(2))
    end)

    it('should return NeotionH3 for level 3', function()
      assert.are.equal('NeotionH3', highlight.get_heading_highlight(3))
    end)

    it('should clamp to NeotionH3 for levels > 3', function()
      assert.are.equal('NeotionH3', highlight.get_heading_highlight(4))
      assert.are.equal('NeotionH3', highlight.get_heading_highlight(6))
    end)

    it('should return NeotionH1 for invalid levels', function()
      assert.are.equal('NeotionH1', highlight.get_heading_highlight(0))
      assert.are.equal('NeotionH1', highlight.get_heading_highlight(-1))
    end)
  end)

  describe('setup', function()
    it('should create all highlight groups', function()
      -- Clear any existing highlights first
      for name, _ in pairs(highlight.GROUPS) do
        pcall(vim.api.nvim_set_hl, 0, name, {})
      end

      highlight.setup()

      -- Check that highlights were created
      local bold_hl = vim.api.nvim_get_hl(0, { name = 'NeotionBold' })
      assert.is_true(bold_hl.bold == true)

      local italic_hl = vim.api.nvim_get_hl(0, { name = 'NeotionItalic' })
      assert.is_true(italic_hl.italic == true)
    end)

    it('should be idempotent', function()
      highlight.setup()
      highlight.setup()

      -- Should not error and highlights should still exist
      local bold_hl = vim.api.nvim_get_hl(0, { name = 'NeotionBold' })
      assert.is_true(bold_hl.bold == true)
    end)
  end)

  describe('NOTION_COLORS', function()
    it('should define all Notion foreground colors', function()
      assert.is_string(highlight.NOTION_COLORS.red)
      assert.is_string(highlight.NOTION_COLORS.blue)
      assert.is_string(highlight.NOTION_COLORS.green)
      assert.is_string(highlight.NOTION_COLORS.yellow)
      assert.is_string(highlight.NOTION_COLORS.orange)
      assert.is_string(highlight.NOTION_COLORS.pink)
      assert.is_string(highlight.NOTION_COLORS.purple)
      assert.is_string(highlight.NOTION_COLORS.brown)
      assert.is_string(highlight.NOTION_COLORS.gray)
    end)

    it('should define all Notion background colors', function()
      assert.is_string(highlight.NOTION_COLORS.red_background)
      assert.is_string(highlight.NOTION_COLORS.blue_background)
      assert.is_string(highlight.NOTION_COLORS.green_background)
    end)

    it('should use hex color format', function()
      assert.is_true(highlight.NOTION_COLORS.red:match('^#%x%x%x%x%x%x$') ~= nil)
    end)
  end)
end)
