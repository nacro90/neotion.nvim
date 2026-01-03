---@diagnostic disable: undefined-field
local types = require('neotion.format.types')

describe('neotion.format.types', function()
  describe('Annotation', function()
    describe('new', function()
      it('should create annotation with default values', function()
        local annotation = types.Annotation.new()

        assert.is_false(annotation.bold)
        assert.is_false(annotation.italic)
        assert.is_false(annotation.strikethrough)
        assert.is_false(annotation.underline)
        assert.is_false(annotation.code)
        assert.are.equal('default', annotation.color)
      end)

      it('should create annotation with provided values', function()
        local annotation = types.Annotation.new({
          bold = true,
          italic = true,
          color = 'red',
        })

        assert.is_true(annotation.bold)
        assert.is_true(annotation.italic)
        assert.is_false(annotation.strikethrough)
        assert.is_false(annotation.underline)
        assert.is_false(annotation.code)
        assert.are.equal('red', annotation.color)
      end)
    end)

    describe('from_api', function()
      it('should parse Notion API annotation format', function()
        local api_annotation = {
          bold = true,
          italic = false,
          strikethrough = true,
          underline = false,
          code = false,
          color = 'blue',
        }

        local annotation = types.Annotation.from_api(api_annotation)

        assert.is_true(annotation.bold)
        assert.is_false(annotation.italic)
        assert.is_true(annotation.strikethrough)
        assert.is_false(annotation.underline)
        assert.is_false(annotation.code)
        assert.are.equal('blue', annotation.color)
      end)

      it('should handle nil api annotation', function()
        local annotation = types.Annotation.from_api(nil)

        assert.is_false(annotation.bold)
        assert.are.equal('default', annotation.color)
      end)

      it('should handle empty api annotation', function()
        local annotation = types.Annotation.from_api({})

        assert.is_false(annotation.bold)
        assert.are.equal('default', annotation.color)
      end)
    end)

    describe('to_api', function()
      it('should convert to Notion API format', function()
        local annotation = types.Annotation.new({
          bold = true,
          italic = true,
          color = 'red',
        })

        local api = annotation:to_api()

        assert.is_true(api.bold)
        assert.is_true(api.italic)
        assert.is_false(api.strikethrough)
        assert.is_false(api.underline)
        assert.is_false(api.code)
        assert.are.equal('red', api.color)
      end)
    end)

    describe('is_default', function()
      it('should return true for default annotation', function()
        local annotation = types.Annotation.new()

        assert.is_true(annotation:is_default())
      end)

      it('should return false when any formatting is applied', function()
        local bold = types.Annotation.new({ bold = true })
        local colored = types.Annotation.new({ color = 'red' })

        assert.is_false(bold:is_default())
        assert.is_false(colored:is_default())
      end)
    end)

    describe('equals', function()
      it('should return true for identical annotations', function()
        local a = types.Annotation.new({ bold = true, color = 'red' })
        local b = types.Annotation.new({ bold = true, color = 'red' })

        assert.is_true(a:equals(b))
      end)

      it('should return false for different annotations', function()
        local a = types.Annotation.new({ bold = true })
        local b = types.Annotation.new({ italic = true })

        assert.is_false(a:equals(b))
      end)
    end)

    describe('clone', function()
      it('should create a copy with same values', function()
        local original = types.Annotation.new({
          bold = true,
          italic = true,
          color = 'red',
        })

        local cloned = original:clone()

        assert.is_true(cloned.bold)
        assert.is_true(cloned.italic)
        assert.are.equal('red', cloned.color)
      end)

      it('should create independent copy', function()
        local original = types.Annotation.new({ bold = true })

        local cloned = original:clone()
        cloned.bold = false

        assert.is_true(original.bold)
        assert.is_false(cloned.bold)
      end)

      it('should be equal to original', function()
        local original = types.Annotation.new({
          bold = true,
          strikethrough = true,
        })

        local cloned = original:clone()

        assert.is_true(original:equals(cloned))
      end)
    end)

    describe('has_formatting', function()
      it('should return false when no formatting', function()
        local annotation = types.Annotation.new()

        assert.is_false(annotation:has_formatting())
      end)

      it('should return true when bold', function()
        local annotation = types.Annotation.new({ bold = true })

        assert.is_true(annotation:has_formatting())
      end)

      it('should return true when colored (non-default)', function()
        local annotation = types.Annotation.new({ color = 'red' })

        assert.is_true(annotation:has_formatting())
      end)

      it('should return false when color is default', function()
        local annotation = types.Annotation.new({ color = 'default' })

        assert.is_false(annotation:has_formatting())
      end)
    end)
  end)

  describe('ColorValue', function()
    describe('is_valid', function()
      it('should return true for valid foreground colors', function()
        assert.is_true(types.ColorValue.is_valid('default'))
        assert.is_true(types.ColorValue.is_valid('red'))
        assert.is_true(types.ColorValue.is_valid('blue'))
        assert.is_true(types.ColorValue.is_valid('green'))
        assert.is_true(types.ColorValue.is_valid('yellow'))
        assert.is_true(types.ColorValue.is_valid('orange'))
        assert.is_true(types.ColorValue.is_valid('pink'))
        assert.is_true(types.ColorValue.is_valid('purple'))
        assert.is_true(types.ColorValue.is_valid('brown'))
        assert.is_true(types.ColorValue.is_valid('gray'))
      end)

      it('should return true for valid background colors', function()
        assert.is_true(types.ColorValue.is_valid('red_background'))
        assert.is_true(types.ColorValue.is_valid('blue_background'))
        assert.is_true(types.ColorValue.is_valid('green_background'))
        assert.is_true(types.ColorValue.is_valid('gray_background'))
      end)

      it('should return false for invalid colors', function()
        assert.is_false(types.ColorValue.is_valid('invalid'))
        assert.is_false(types.ColorValue.is_valid(''))
        assert.is_false(types.ColorValue.is_valid(nil))
      end)
    end)

    describe('is_background', function()
      it('should return true for background colors', function()
        assert.is_true(types.ColorValue.is_background('red_background'))
        assert.is_true(types.ColorValue.is_background('blue_background'))
      end)

      it('should return false for foreground colors', function()
        assert.is_false(types.ColorValue.is_background('red'))
        assert.is_false(types.ColorValue.is_background('default'))
      end)
    end)

    describe('to_highlight_name', function()
      it('should convert foreground color to highlight name', function()
        assert.are.equal('NeotionColorRed', types.ColorValue.to_highlight_name('red'))
        assert.are.equal('NeotionColorBlue', types.ColorValue.to_highlight_name('blue'))
      end)

      it('should convert background color to highlight name', function()
        assert.are.equal('NeotionColorRedBg', types.ColorValue.to_highlight_name('red_background'))
        assert.are.equal('NeotionColorBlueBg', types.ColorValue.to_highlight_name('blue_background'))
      end)

      it('should return nil for default color', function()
        assert.is_nil(types.ColorValue.to_highlight_name('default'))
      end)
    end)

    describe('all', function()
      it('should return list of all valid colors', function()
        local colors = types.ColorValue.all()

        assert.is_table(colors)
        assert.is_true(#colors > 0)
        assert.is_true(vim.tbl_contains(colors, 'red'))
        assert.is_true(vim.tbl_contains(colors, 'red_background'))
      end)
    end)
  end)

  describe('RichTextSegment', function()
    describe('new', function()
      it('should create segment with text and default annotation', function()
        local segment = types.RichTextSegment.new('Hello')

        assert.are.equal('Hello', segment.text)
        assert.is_true(segment.annotations:is_default())
        assert.is_nil(segment.href)
        assert.are.equal(0, segment.start_col)
        assert.are.equal(5, segment.end_col)
      end)

      it('should create segment with custom annotation', function()
        local segment = types.RichTextSegment.new('Bold', {
          annotations = types.Annotation.new({ bold = true }),
        })

        assert.are.equal('Bold', segment.text)
        assert.is_true(segment.annotations.bold)
      end)

      it('should create segment with href', function()
        local segment = types.RichTextSegment.new('Link', {
          href = 'https://example.com',
        })

        assert.are.equal('https://example.com', segment.href)
      end)

      it('should create segment with custom start_col', function()
        local segment = types.RichTextSegment.new('World', {
          start_col = 6,
        })

        assert.are.equal(6, segment.start_col)
        assert.are.equal(11, segment.end_col)
      end)
    end)

    describe('from_api', function()
      it('should parse Notion API rich_text item', function()
        local api_item = {
          type = 'text',
          text = { content = 'Hello World', link = nil },
          plain_text = 'Hello World',
          annotations = {
            bold = true,
            italic = false,
            strikethrough = false,
            underline = false,
            code = false,
            color = 'default',
          },
          href = nil,
        }

        local segment = types.RichTextSegment.from_api(api_item)

        assert.are.equal('Hello World', segment.text)
        assert.is_true(segment.annotations.bold)
        assert.is_nil(segment.href)
      end)

      it('should parse rich_text item with link', function()
        local api_item = {
          type = 'text',
          text = { content = 'Click here', link = { url = 'https://example.com' } },
          plain_text = 'Click here',
          annotations = {
            bold = false,
            italic = false,
            strikethrough = false,
            underline = false,
            code = false,
            color = 'default',
          },
          href = 'https://example.com',
        }

        local segment = types.RichTextSegment.from_api(api_item)

        assert.are.equal('Click here', segment.text)
        assert.are.equal('https://example.com', segment.href)
      end)

      it('should handle mention type', function()
        local api_item = {
          type = 'mention',
          mention = { type = 'user', user = { id = 'user-123' } },
          plain_text = '@John',
          annotations = {
            bold = false,
            italic = false,
            strikethrough = false,
            underline = false,
            code = false,
            color = 'default',
          },
          href = nil,
        }

        local segment = types.RichTextSegment.from_api(api_item)

        assert.are.equal('@John', segment.text)
      end)

      it('should handle vim.NIL href (userdata from JSON decode)', function()
        -- vim.NIL is returned by vim.json.decode for null values
        local api_item = {
          type = 'text',
          text = { content = 'Hello', link = vim.NIL },
          plain_text = 'Hello',
          annotations = {
            bold = false,
            italic = false,
            strikethrough = false,
            underline = false,
            code = false,
            color = 'default',
          },
          href = vim.NIL, -- This is userdata, not nil!
        }

        local segment = types.RichTextSegment.from_api(api_item)

        assert.are.equal('Hello', segment.text)
        -- href should be nil, not vim.NIL (userdata)
        assert.is_nil(segment.href)
      end)

      it('should handle vim.NIL in text.link field', function()
        local api_item = {
          type = 'text',
          text = { content = 'Hello', link = vim.NIL },
          plain_text = 'Hello',
          annotations = {
            bold = false,
            italic = false,
            strikethrough = false,
            underline = false,
            code = false,
            color = 'default',
          },
          href = nil,
        }

        local segment = types.RichTextSegment.from_api(api_item)

        assert.are.equal('Hello', segment.text)
        assert.is_nil(segment.href)
      end)
    end)

    describe('to_api', function()
      it('should convert to Notion API format', function()
        local segment = types.RichTextSegment.new('Hello', {
          annotations = types.Annotation.new({ bold = true }),
        })

        local api = segment:to_api()

        assert.are.equal('text', api.type)
        assert.are.equal('Hello', api.text.content)
        assert.is_nil(api.text.link)
        assert.are.equal('Hello', api.plain_text)
        assert.is_true(api.annotations.bold)
      end)

      it('should include link when href is present', function()
        local segment = types.RichTextSegment.new('Link', {
          href = 'https://example.com',
        })

        local api = segment:to_api()

        assert.are.equal('https://example.com', api.text.link.url)
        assert.are.equal('https://example.com', api.href)
      end)
    end)

    describe('length', function()
      it('should return text length', function()
        local segment = types.RichTextSegment.new('Hello')

        assert.are.equal(5, segment:length())
      end)

      it('should handle unicode correctly', function()
        local segment = types.RichTextSegment.new('Merhaba')

        assert.are.equal(7, segment:length())
      end)
    end)

    describe('is_plain', function()
      it('should return true for plain text', function()
        local segment = types.RichTextSegment.new('Plain text')

        assert.is_true(segment:is_plain())
      end)

      it('should return false for formatted text', function()
        local segment = types.RichTextSegment.new('Bold', {
          annotations = types.Annotation.new({ bold = true }),
        })

        assert.is_false(segment:is_plain())
      end)

      it('should return false for linked text', function()
        local segment = types.RichTextSegment.new('Link', {
          href = 'https://example.com',
        })

        assert.is_false(segment:is_plain())
      end)
    end)
  end)
end)
