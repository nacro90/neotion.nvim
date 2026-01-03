---@diagnostic disable: undefined-field
local notion = require('neotion.format.notion')
local types = require('neotion.format.types')

describe('neotion.format.notion', function()
  describe('provider interface', function()
    it('should have name "notion"', function()
      assert.are.equal('notion', notion.name)
    end)

    it('should have parse function', function()
      assert.is_function(notion.parse)
    end)

    it('should have render function', function()
      assert.is_function(notion.render)
    end)

    it('should have render_segment function', function()
      assert.is_function(notion.render_segment)
    end)
  end)

  describe('parse', function()
    describe('plain text', function()
      it('should parse plain text as single segment', function()
        local segments = notion.parse('hello world')

        assert.are.equal(1, #segments)
        assert.are.equal('hello world', segments[1].text)
      end)

      it('should return empty array for empty string', function()
        local segments = notion.parse('')

        assert.are.equal(0, #segments)
      end)

      it('should have default annotations for plain text', function()
        local segments = notion.parse('plain')

        assert.is_false(segments[1].annotations.bold)
        assert.is_false(segments[1].annotations.italic)
      end)
    end)

    describe('bold', function()
      it('should parse **bold** text', function()
        local segments = notion.parse('**bold**')

        assert.are.equal(1, #segments)
        assert.are.equal('bold', segments[1].text)
        assert.is_true(segments[1].annotations.bold)
      end)

      it('should parse text with bold in middle', function()
        local segments = notion.parse('hello **world** there')

        assert.are.equal(3, #segments)
        assert.are.equal('hello ', segments[1].text)
        assert.is_false(segments[1].annotations.bold)
        assert.are.equal('world', segments[2].text)
        assert.is_true(segments[2].annotations.bold)
        assert.are.equal(' there', segments[3].text)
        assert.is_false(segments[3].annotations.bold)
      end)

      it('should handle multiple bold sections', function()
        local segments = notion.parse('**one** and **two**')

        assert.are.equal(3, #segments)
        assert.is_true(segments[1].annotations.bold)
        assert.is_false(segments[2].annotations.bold)
        assert.is_true(segments[3].annotations.bold)
      end)
    end)

    describe('italic', function()
      it('should parse *italic* text', function()
        local segments = notion.parse('*italic*')

        assert.are.equal(1, #segments)
        assert.are.equal('italic', segments[1].text)
        assert.is_true(segments[1].annotations.italic)
      end)

      it('should parse text with italic in middle', function()
        local segments = notion.parse('hello *world* there')

        assert.are.equal(3, #segments)
        assert.are.equal('world', segments[2].text)
        assert.is_true(segments[2].annotations.italic)
      end)
    end)

    describe('strikethrough', function()
      it('should parse ~strikethrough~ text', function()
        local segments = notion.parse('~strikethrough~')

        assert.are.equal(1, #segments)
        assert.are.equal('strikethrough', segments[1].text)
        assert.is_true(segments[1].annotations.strikethrough)
      end)
    end)

    describe('code', function()
      it('should parse `code` text', function()
        local segments = notion.parse('`code`')

        assert.are.equal(1, #segments)
        assert.are.equal('code', segments[1].text)
        assert.is_true(segments[1].annotations.code)
      end)

      it('should preserve spaces in code', function()
        local segments = notion.parse('`code with spaces`')

        assert.are.equal(1, #segments)
        assert.are.equal('code with spaces', segments[1].text)
        assert.is_true(segments[1].annotations.code)
      end)
    end)

    describe('underline', function()
      it('should parse <u>underline</u> text', function()
        local segments = notion.parse('<u>underline</u>')

        assert.are.equal(1, #segments)
        assert.are.equal('underline', segments[1].text)
        assert.is_true(segments[1].annotations.underline)
      end)
    end)

    describe('color', function()
      it('should parse <c:red>colored</c> text', function()
        local segments = notion.parse('<c:red>colored</c>')

        assert.are.equal(1, #segments)
        assert.are.equal('colored', segments[1].text)
        assert.are.equal('red', segments[1].annotations.color)
      end)

      it('should parse background colors', function()
        local segments = notion.parse('<c:blue_background>text</c>')

        assert.are.equal(1, #segments)
        assert.are.equal('text', segments[1].text)
        assert.are.equal('blue_background', segments[1].annotations.color)
      end)

      it('should handle all Notion colors', function()
        local colors = { 'red', 'blue', 'green', 'yellow', 'orange', 'pink', 'purple', 'brown', 'gray' }

        for _, color in ipairs(colors) do
          local segments = notion.parse('<c:' .. color .. '>text</c>')
          assert.are.equal(color, segments[1].annotations.color)
        end
      end)
    end)

    describe('nested formatting', function()
      it('should parse bold italic', function()
        local segments = notion.parse('***bold italic***')

        assert.are.equal(1, #segments)
        assert.are.equal('bold italic', segments[1].text)
        assert.is_true(segments[1].annotations.bold)
        assert.is_true(segments[1].annotations.italic)
      end)

      it('should parse bold with color', function()
        local segments = notion.parse('**<c:red>bold red</c>**')

        assert.are.equal(1, #segments)
        assert.are.equal('bold red', segments[1].text)
        assert.is_true(segments[1].annotations.bold)
        assert.are.equal('red', segments[1].annotations.color)
      end)

      -- This is the key test case: italic starting inside bold
      it('should parse italic inside bold: **bold *italicbold***', function()
        local segments = notion.parse('**bold *italicbold***')

        assert.are.equal(2, #segments)
        -- First segment: "bold " with only bold
        assert.are.equal('bold ', segments[1].text)
        assert.is_true(segments[1].annotations.bold)
        assert.is_false(segments[1].annotations.italic)
        -- Second segment: "italicbold" with bold+italic
        assert.are.equal('italicbold', segments[2].text)
        assert.is_true(segments[2].annotations.bold)
        assert.is_true(segments[2].annotations.italic)
      end)

      it('should parse italic with text after it inside bold: **bold *italic* more**', function()
        local segments = notion.parse('**bold *italic* more**')

        assert.are.equal(3, #segments)
        -- First segment: "bold " with only bold
        assert.are.equal('bold ', segments[1].text)
        assert.is_true(segments[1].annotations.bold)
        assert.is_false(segments[1].annotations.italic)
        -- Second segment: "italic" with bold+italic
        assert.are.equal('italic', segments[2].text)
        assert.is_true(segments[2].annotations.bold)
        assert.is_true(segments[2].annotations.italic)
        -- Third segment: " more" with only bold
        assert.are.equal(' more', segments[3].text)
        assert.is_true(segments[3].annotations.bold)
        assert.is_false(segments[3].annotations.italic)
      end)

      it('should parse bold inside italic: *italic **bolditalic***', function()
        local segments = notion.parse('*italic **bolditalic***')

        assert.are.equal(2, #segments)
        -- First segment: "italic " with only italic
        assert.are.equal('italic ', segments[1].text)
        assert.is_false(segments[1].annotations.bold)
        assert.is_true(segments[1].annotations.italic)
        -- Second segment: "bolditalic" with bold+italic
        assert.are.equal('bolditalic', segments[2].text)
        assert.is_true(segments[2].annotations.bold)
        assert.is_true(segments[2].annotations.italic)
      end)

      it('should handle bold inside italic with text after: *italic **bold** more*', function()
        local segments = notion.parse('*italic **bold** more*')

        assert.are.equal(3, #segments)
        -- First segment: "italic " with only italic
        assert.are.equal('italic ', segments[1].text)
        assert.is_false(segments[1].annotations.bold)
        assert.is_true(segments[1].annotations.italic)
        -- Second segment: "bold" with bold+italic
        assert.are.equal('bold', segments[2].text)
        assert.is_true(segments[2].annotations.bold)
        assert.is_true(segments[2].annotations.italic)
        -- Third segment: " more" with only italic
        assert.are.equal(' more', segments[3].text)
        assert.is_false(segments[3].annotations.bold)
        assert.is_true(segments[3].annotations.italic)
      end)
    end)

    describe('column positions', function()
      it('should track start_col and end_col', function()
        local segments = notion.parse('ab**cd**ef')

        -- 'ab' at 0-2, 'cd' at 2-4, 'ef' at 4-6
        assert.are.equal(0, segments[1].start_col)
        assert.are.equal(2, segments[1].end_col)
        assert.are.equal(2, segments[2].start_col)
        assert.are.equal(4, segments[2].end_col)
        assert.are.equal(4, segments[3].start_col)
        assert.are.equal(6, segments[3].end_col)
      end)
    end)

    describe('escape sequences', function()
      it('should handle escaped asterisks', function()
        local segments = notion.parse('\\*not italic\\*')

        assert.are.equal(1, #segments)
        assert.are.equal('*not italic*', segments[1].text)
        assert.is_false(segments[1].annotations.italic)
      end)

      it('should handle escaped backticks', function()
        local segments = notion.parse('\\`not code\\`')

        assert.are.equal(1, #segments)
        assert.are.equal('`not code`', segments[1].text)
        assert.is_false(segments[1].annotations.code)
      end)
    end)
  end)

  describe('render', function()
    it('should render plain text segment', function()
      local segments = { types.RichTextSegment.new('hello') }

      local result = notion.render(segments)

      assert.are.equal('hello', result)
    end)

    it('should render bold segment', function()
      local segments = {
        types.RichTextSegment.new('bold', {
          annotations = types.Annotation.new({ bold = true }),
        }),
      }

      local result = notion.render(segments)

      assert.are.equal('**bold**', result)
    end)

    it('should render italic segment', function()
      local segments = {
        types.RichTextSegment.new('italic', {
          annotations = types.Annotation.new({ italic = true }),
        }),
      }

      local result = notion.render(segments)

      assert.are.equal('*italic*', result)
    end)

    it('should render strikethrough segment', function()
      local segments = {
        types.RichTextSegment.new('strike', {
          annotations = types.Annotation.new({ strikethrough = true }),
        }),
      }

      local result = notion.render(segments)

      assert.are.equal('~strike~', result)
    end)

    it('should render code segment', function()
      local segments = {
        types.RichTextSegment.new('code', {
          annotations = types.Annotation.new({ code = true }),
        }),
      }

      local result = notion.render(segments)

      assert.are.equal('`code`', result)
    end)

    it('should render underline segment', function()
      local segments = {
        types.RichTextSegment.new('underline', {
          annotations = types.Annotation.new({ underline = true }),
        }),
      }

      local result = notion.render(segments)

      assert.are.equal('<u>underline</u>', result)
    end)

    it('should render colored segment', function()
      local segments = {
        types.RichTextSegment.new('colored', {
          annotations = types.Annotation.new({ color = 'red' }),
        }),
      }

      local result = notion.render(segments)

      assert.are.equal('<c:red>colored</c>', result)
    end)

    it('should render multiple segments', function()
      local segments = {
        types.RichTextSegment.new('plain '),
        types.RichTextSegment.new('bold', {
          annotations = types.Annotation.new({ bold = true }),
        }),
        types.RichTextSegment.new(' text'),
      }

      local result = notion.render(segments)

      assert.are.equal('plain **bold** text', result)
    end)

    it('should render bold italic together', function()
      local segments = {
        types.RichTextSegment.new('both', {
          annotations = types.Annotation.new({ bold = true, italic = true }),
        }),
      }

      local result = notion.render(segments)

      assert.are.equal('***both***', result)
    end)

    it('should not add color markers for default color', function()
      local segments = {
        types.RichTextSegment.new('text', {
          annotations = types.Annotation.new({ color = 'default' }),
        }),
      }

      local result = notion.render(segments)

      assert.are.equal('text', result)
    end)

    it('should escape special characters in text', function()
      local segments = { types.RichTextSegment.new('*not italic*') }

      local result = notion.render(segments)

      assert.are.equal('\\*not italic\\*', result)
    end)

    describe('adjacent segment rendering', function()
      it('should render bold then bold+italic correctly (italic inside bold ending)', function()
        local segments = {
          types.RichTextSegment.new('bold ', {
            annotations = types.Annotation.new({ bold = true }),
          }),
          types.RichTextSegment.new('italicbold', {
            annotations = types.Annotation.new({ bold = true, italic = true }),
          }),
        }

        local result = notion.render(segments)

        assert.are.equal('**bold *italicbold***', result)
      end)

      it('should render bold then bold+italic then bold correctly', function()
        local segments = {
          types.RichTextSegment.new('bold ', {
            annotations = types.Annotation.new({ bold = true }),
          }),
          types.RichTextSegment.new('italic', {
            annotations = types.Annotation.new({ bold = true, italic = true }),
          }),
          types.RichTextSegment.new(' more', {
            annotations = types.Annotation.new({ bold = true }),
          }),
        }

        local result = notion.render(segments)

        assert.are.equal('**bold *italic* more**', result)
      end)

      it('should render italic then bold+italic correctly (bold inside italic ending)', function()
        local segments = {
          types.RichTextSegment.new('italic ', {
            annotations = types.Annotation.new({ italic = true }),
          }),
          types.RichTextSegment.new('bolditalic', {
            annotations = types.Annotation.new({ bold = true, italic = true }),
          }),
        }

        local result = notion.render(segments)

        assert.are.equal('*italic **bolditalic***', result)
      end)

      it('should render italic then bold+italic then italic correctly', function()
        local segments = {
          types.RichTextSegment.new('italic ', {
            annotations = types.Annotation.new({ italic = true }),
          }),
          types.RichTextSegment.new('bold', {
            annotations = types.Annotation.new({ bold = true, italic = true }),
          }),
          types.RichTextSegment.new(' more', {
            annotations = types.Annotation.new({ italic = true }),
          }),
        }

        local result = notion.render(segments)

        assert.are.equal('*italic **bold** more*', result)
      end)
    end)
  end)

  describe('render_segment', function()
    it('should render single segment', function()
      local segment = types.RichTextSegment.new('test', {
        annotations = types.Annotation.new({ bold = true }),
      })

      local result = notion.render_segment(segment)

      assert.are.equal('**test**', result)
    end)

    it('should handle vim.NIL href gracefully (defensive)', function()
      -- This tests defensive handling in case vim.NIL bypasses from_api normalization
      local segment = types.RichTextSegment.new('test', {
        annotations = types.Annotation.new(),
      })
      -- Manually set href to vim.NIL to simulate edge case
      segment.href = vim.NIL

      -- Should not throw an error, should treat vim.NIL as no link
      local result = notion.render_segment(segment)

      assert.are.equal('test', result)
    end)

    it('should render segment with valid href', function()
      local segment = types.RichTextSegment.new('click me', {
        annotations = types.Annotation.new(),
        href = 'https://example.com',
      })

      local result = notion.render_segment(segment)

      assert.are.equal('[click me](https://example.com)', result)
    end)
  end)

  describe('roundtrip', function()
    it('should parse and render plain text identically', function()
      local original = 'hello world'
      local segments = notion.parse(original)
      local result = notion.render(segments)

      assert.are.equal(original, result)
    end)

    it('should parse and render formatted text identically', function()
      local original = 'hello **bold** and *italic* world'
      local segments = notion.parse(original)
      local result = notion.render(segments)

      assert.are.equal(original, result)
    end)

    it('should parse and render colored text identically', function()
      local original = '<c:red>red text</c>'
      local segments = notion.parse(original)
      local result = notion.render(segments)

      assert.are.equal(original, result)
    end)

    it('should roundtrip italic inside bold ending together', function()
      local original = '**bold *italicbold***'
      local segments = notion.parse(original)
      local result = notion.render(segments)

      assert.are.equal(original, result)
    end)

    it('should roundtrip italic inside bold with text after', function()
      local original = '**bold *italic* more**'
      local segments = notion.parse(original)
      local result = notion.render(segments)

      assert.are.equal(original, result)
    end)

    it('should roundtrip bold inside italic ending together', function()
      local original = '*italic **bolditalic***'
      local segments = notion.parse(original)
      local result = notion.render(segments)

      assert.are.equal(original, result)
    end)

    it('should roundtrip bold inside italic with text after', function()
      local original = '*italic **bold** more*'
      local segments = notion.parse(original)
      local result = notion.render(segments)

      assert.are.equal(original, result)
    end)
  end)

  describe('MARKERS', function()
    it('should expose marker constants', function()
      assert.is_table(notion.MARKERS)
      assert.are.equal('**', notion.MARKERS.bold)
      assert.are.equal('*', notion.MARKERS.italic)
      assert.are.equal('~', notion.MARKERS.strikethrough)
      assert.are.equal('`', notion.MARKERS.code)
    end)
  end)

  describe('parse_with_concealment', function()
    it('should return empty result for empty string', function()
      local result = notion.parse_with_concealment('')

      assert.are.equal(0, #result.segments)
      assert.are.equal(0, #result.conceal_regions)
    end)

    it('should return no conceal regions for plain text', function()
      local result = notion.parse_with_concealment('hello world')

      assert.are.equal(1, #result.segments)
      assert.are.equal('hello world', result.segments[1].text)
      assert.are.equal(0, #result.conceal_regions)
    end)

    describe('bold concealment', function()
      it('should return conceal regions for ** markers', function()
        local result = notion.parse_with_concealment('**bold**')

        -- Should have 1 segment for "bold"
        assert.are.equal(1, #result.segments)
        assert.are.equal('bold', result.segments[1].text)
        assert.is_true(result.segments[1].annotations.bold)

        -- Should have 2 conceal regions (opening and closing **)
        assert.are.equal(2, #result.conceal_regions)
        -- Opening ** at columns 0-2
        assert.are.equal(0, result.conceal_regions[1].start_col)
        assert.are.equal(2, result.conceal_regions[1].end_col)
        -- Closing ** at columns 6-8
        assert.are.equal(6, result.conceal_regions[2].start_col)
        assert.are.equal(8, result.conceal_regions[2].end_col)
      end)

      it('should have correct segment positions for bold', function()
        local result = notion.parse_with_concealment('**bold**')

        -- Segment starts after ** (col 2) and ends before ** (col 6)
        assert.are.equal(2, result.segments[1].start_col)
        assert.are.equal(6, result.segments[1].end_col)
      end)
    end)

    describe('italic concealment', function()
      it('should return conceal regions for * markers', function()
        local result = notion.parse_with_concealment('*italic*')

        assert.are.equal(1, #result.segments)
        assert.are.equal('italic', result.segments[1].text)
        assert.is_true(result.segments[1].annotations.italic)

        assert.are.equal(2, #result.conceal_regions)
        assert.are.equal(0, result.conceal_regions[1].start_col)
        assert.are.equal(1, result.conceal_regions[1].end_col)
        assert.are.equal(7, result.conceal_regions[2].start_col)
        assert.are.equal(8, result.conceal_regions[2].end_col)
      end)
    end)

    describe('mixed content', function()
      it('should handle text before and after formatted content', function()
        local result = notion.parse_with_concealment('hello **bold** world')

        -- Should have 3 segments: "hello ", "bold", " world"
        assert.are.equal(3, #result.segments)
        assert.are.equal('hello ', result.segments[1].text)
        assert.are.equal('bold', result.segments[2].text)
        assert.are.equal(' world', result.segments[3].text)

        -- Should have 2 conceal regions for **
        assert.are.equal(2, #result.conceal_regions)
      end)

      it('should calculate correct positions for text before formatting', function()
        local result = notion.parse_with_concealment('hi **x**')
        -- "hi " is at 0-3, ** at 3-5, "x" at 5-6, ** at 6-8

        assert.are.equal(0, result.segments[1].start_col)
        assert.are.equal(3, result.segments[1].end_col)
        assert.are.equal(5, result.segments[2].start_col)
        assert.are.equal(6, result.segments[2].end_col)
      end)
    end)

    describe('code concealment', function()
      it('should return conceal regions for ` markers', function()
        local result = notion.parse_with_concealment('`code`')

        assert.are.equal(1, #result.segments)
        assert.are.equal('code', result.segments[1].text)
        assert.is_true(result.segments[1].annotations.code)

        assert.are.equal(2, #result.conceal_regions)
      end)
    end)

    describe('strikethrough concealment', function()
      it('should return conceal regions for ~ markers', function()
        local result = notion.parse_with_concealment('~strike~')

        assert.are.equal(1, #result.segments)
        assert.are.equal('strike', result.segments[1].text)
        assert.is_true(result.segments[1].annotations.strikethrough)

        assert.are.equal(2, #result.conceal_regions)
      end)
    end)

    describe('underline concealment', function()
      it('should return conceal regions for <u></u> markers', function()
        local result = notion.parse_with_concealment('<u>underline</u>')

        assert.are.equal(1, #result.segments)
        assert.are.equal('underline', result.segments[1].text)
        assert.is_true(result.segments[1].annotations.underline)

        -- <u> = 3 chars, </u> = 4 chars
        assert.are.equal(2, #result.conceal_regions)
        assert.are.equal(0, result.conceal_regions[1].start_col)
        assert.are.equal(3, result.conceal_regions[1].end_col)
      end)
    end)

    describe('color concealment', function()
      it('should return conceal regions for <c:color></c> markers', function()
        local result = notion.parse_with_concealment('<c:red>text</c>')

        assert.are.equal(1, #result.segments)
        assert.are.equal('text', result.segments[1].text)
        assert.are.equal('red', result.segments[1].annotations.color)

        -- <c:red> = 7 chars, </c> = 4 chars
        assert.are.equal(2, #result.conceal_regions)
        assert.are.equal(0, result.conceal_regions[1].start_col)
        assert.are.equal(7, result.conceal_regions[1].end_col)
      end)
    end)

    describe('escape concealment', function()
      it('should conceal backslash in escape sequences', function()
        local result = notion.parse_with_concealment('\\*')

        -- Should have segment with literal * char
        assert.are.equal(1, #result.segments)
        assert.are.equal('*', result.segments[1].text)

        -- Should conceal the backslash
        assert.are.equal(1, #result.conceal_regions)
        assert.are.equal(0, result.conceal_regions[1].start_col)
        assert.are.equal(1, result.conceal_regions[1].end_col)
      end)

      it('should handle multiple escapes', function()
        local result = notion.parse_with_concealment('\\*text\\*')

        -- All plain text with same annotations - should be merged to 1 segment
        assert.are.equal(1, #result.segments)
        assert.are.equal('*text*', result.segments[1].text)

        -- Should conceal both backslashes
        assert.are.equal(2, #result.conceal_regions)
      end)
    end)

    describe('bold italic concealment', function()
      it('should return conceal regions for *** markers', function()
        local result = notion.parse_with_concealment('***bold italic***')

        assert.are.equal(1, #result.segments)
        assert.are.equal('bold italic', result.segments[1].text)
        assert.is_true(result.segments[1].annotations.bold)
        assert.is_true(result.segments[1].annotations.italic)

        assert.are.equal(2, #result.conceal_regions)
        -- Opening *** at 0-3
        assert.are.equal(0, result.conceal_regions[1].start_col)
        assert.are.equal(3, result.conceal_regions[1].end_col)
      end)
    end)
  end)

  describe('parse_to_api', function()
    it('should have parse_to_api function', function()
      assert.is_function(notion.parse_to_api)
    end)

    it('should return empty array for empty string', function()
      local result = notion.parse_to_api('')

      assert.are.equal(0, #result)
    end)

    it('should convert plain text to API format', function()
      local result = notion.parse_to_api('hello world')

      assert.are.equal(1, #result)
      assert.are.equal('text', result[1].type)
      assert.are.equal('hello world', result[1].text.content)
      assert.are.equal('hello world', result[1].plain_text)
      assert.is_false(result[1].annotations.bold)
    end)

    it('should convert bold text to API format', function()
      local result = notion.parse_to_api('**bold**')

      assert.are.equal(1, #result)
      assert.are.equal('bold', result[1].text.content)
      assert.is_true(result[1].annotations.bold)
      assert.is_false(result[1].annotations.italic)
    end)

    it('should convert mixed formatting to API format', function()
      local result = notion.parse_to_api('hello **bold** world')

      assert.are.equal(3, #result)
      assert.are.equal('hello ', result[1].text.content)
      assert.is_false(result[1].annotations.bold)
      assert.are.equal('bold', result[2].text.content)
      assert.is_true(result[2].annotations.bold)
      assert.are.equal(' world', result[3].text.content)
      assert.is_false(result[3].annotations.bold)
    end)

    it('should convert italic text to API format', function()
      local result = notion.parse_to_api('*italic*')

      assert.are.equal(1, #result)
      assert.are.equal('italic', result[1].text.content)
      assert.is_true(result[1].annotations.italic)
    end)

    it('should convert strikethrough to API format', function()
      local result = notion.parse_to_api('~strike~')

      assert.are.equal(1, #result)
      assert.are.equal('strike', result[1].text.content)
      assert.is_true(result[1].annotations.strikethrough)
    end)

    it('should convert code to API format', function()
      local result = notion.parse_to_api('`code`')

      assert.are.equal(1, #result)
      assert.are.equal('code', result[1].text.content)
      assert.is_true(result[1].annotations.code)
    end)

    it('should convert underline to API format', function()
      local result = notion.parse_to_api('<u>underline</u>')

      assert.are.equal(1, #result)
      assert.are.equal('underline', result[1].text.content)
      assert.is_true(result[1].annotations.underline)
    end)

    it('should convert color to API format', function()
      local result = notion.parse_to_api('<c:red>colored</c>')

      assert.are.equal(1, #result)
      assert.are.equal('colored', result[1].text.content)
      assert.are.equal('red', result[1].annotations.color)
    end)

    it('should convert nested formatting to API format', function()
      local result = notion.parse_to_api('***bold italic***')

      assert.are.equal(1, #result)
      assert.are.equal('bold italic', result[1].text.content)
      assert.is_true(result[1].annotations.bold)
      assert.is_true(result[1].annotations.italic)
    end)

    it('should handle complex mixed formatting', function()
      local result = notion.parse_to_api('**bold** and *italic* and `code`')

      assert.are.equal(5, #result)
      assert.is_true(result[1].annotations.bold)
      assert.is_false(result[2].annotations.bold)
      assert.is_true(result[3].annotations.italic)
      assert.is_false(result[4].annotations.italic)
      assert.is_true(result[5].annotations.code)
    end)

    describe('round-trip', function()
      it('should preserve formatting in parse -> render -> parse cycle', function()
        local original = '**bold** *italic* ~strike~ `code`'
        local parsed1 = notion.parse(original)
        local rendered = notion.render(parsed1)
        local parsed2 = notion.parse(rendered)

        assert.are.equal(#parsed1, #parsed2)
        for i, seg in ipairs(parsed1) do
          assert.are.equal(seg.text, parsed2[i].text)
          assert.are.equal(seg.annotations.bold, parsed2[i].annotations.bold)
          assert.are.equal(seg.annotations.italic, parsed2[i].annotations.italic)
          assert.are.equal(seg.annotations.strikethrough, parsed2[i].annotations.strikethrough)
          assert.are.equal(seg.annotations.code, parsed2[i].annotations.code)
        end
      end)
    end)
  end)

  describe('link syntax', function()
    describe('parse', function()
      it('should parse markdown link [text](url)', function()
        local segments = notion.parse('[link text](https://example.com)')

        assert.are.equal(1, #segments)
        assert.are.equal('link text', segments[1].text)
        assert.are.equal('https://example.com', segments[1].href)
      end)

      it('should parse link with surrounding text', function()
        local segments = notion.parse('click [here](https://example.com) now')

        assert.are.equal(3, #segments)
        assert.are.equal('click ', segments[1].text)
        assert.is_nil(segments[1].href)
        assert.are.equal('here', segments[2].text)
        assert.are.equal('https://example.com', segments[2].href)
        assert.are.equal(' now', segments[3].text)
        assert.is_nil(segments[3].href)
      end)

      it('should parse multiple links', function()
        local segments = notion.parse('[one](http://1.com) and [two](http://2.com)')

        assert.are.equal(3, #segments)
        assert.are.equal('one', segments[1].text)
        assert.are.equal('http://1.com', segments[1].href)
        assert.are.equal(' and ', segments[2].text)
        assert.is_nil(segments[2].href)
        assert.are.equal('two', segments[3].text)
        assert.are.equal('http://2.com', segments[3].href)
      end)

      it('should parse link with formatting', function()
        local segments = notion.parse('**[bold link](https://example.com)**')

        assert.are.equal(1, #segments)
        assert.are.equal('bold link', segments[1].text)
        assert.are.equal('https://example.com', segments[1].href)
        assert.is_true(segments[1].annotations.bold)
      end)

      it('should parse link inside formatted text', function()
        local segments = notion.parse('**click [here](https://example.com) now**')

        assert.are.equal(3, #segments)
        assert.are.equal('click ', segments[1].text)
        assert.is_true(segments[1].annotations.bold)
        assert.is_nil(segments[1].href)
        assert.are.equal('here', segments[2].text)
        assert.are.equal('https://example.com', segments[2].href)
        assert.is_true(segments[2].annotations.bold)
        assert.are.equal(' now', segments[3].text)
        assert.is_true(segments[3].annotations.bold)
        assert.is_nil(segments[3].href)
      end)

      it('should handle empty link text', function()
        local segments = notion.parse('[](https://example.com)')

        assert.are.equal(1, #segments)
        assert.are.equal('', segments[1].text)
        assert.are.equal('https://example.com', segments[1].href)
      end)

      it('should handle link with special characters in url', function()
        local segments = notion.parse('[search](https://google.com/search?q=hello+world)')

        assert.are.equal(1, #segments)
        assert.are.equal('search', segments[1].text)
        assert.are.equal('https://google.com/search?q=hello+world', segments[1].href)
      end)

      it('should not parse incomplete link syntax [text](', function()
        local segments = notion.parse('[incomplete](')

        -- Should be treated as literal text
        assert.are.equal(1, #segments)
        assert.are.equal('[incomplete](', segments[1].text)
        assert.is_nil(segments[1].href)
      end)

      it('should not parse malformed link [text]url)', function()
        local segments = notion.parse('[text]url)')

        assert.are.equal(1, #segments)
        assert.are.equal('[text]url)', segments[1].text)
        assert.is_nil(segments[1].href)
      end)
    end)

    describe('render', function()
      it('should render link as [text](url)', function()
        local segment = types.RichTextSegment.new('link text', {
          href = 'https://example.com',
        })
        local rendered = notion.render({ segment })

        assert.are.equal('[link text](https://example.com)', rendered)
      end)

      it('should render link with formatting', function()
        local segment = types.RichTextSegment.new('bold link', {
          href = 'https://example.com',
          annotations = types.Annotation.new({ bold = true }),
        })
        local rendered = notion.render({ segment })

        assert.are.equal('**[bold link](https://example.com)**', rendered)
      end)

      it('should render multiple links with text between', function()
        local segments = {
          types.RichTextSegment.new('one', { href = 'http://1.com' }),
          types.RichTextSegment.new(' and '),
          types.RichTextSegment.new('two', { href = 'http://2.com' }),
        }
        local rendered = notion.render(segments)

        assert.are.equal('[one](http://1.com) and [two](http://2.com)', rendered)
      end)
    end)

    describe('parse_to_api', function()
      it('should convert link to API format', function()
        local result = notion.parse_to_api('[click me](https://example.com)')

        assert.are.equal(1, #result)
        assert.are.equal('click me', result[1].text.content)
        assert.are.equal('https://example.com', result[1].text.link.url)
        assert.are.equal('https://example.com', result[1].href)
      end)

      it('should convert formatted link to API format', function()
        local result = notion.parse_to_api('**[bold link](https://example.com)**')

        assert.are.equal(1, #result)
        assert.are.equal('bold link', result[1].text.content)
        assert.are.equal('https://example.com', result[1].text.link.url)
        assert.is_true(result[1].annotations.bold)
      end)

      it('should handle text without link having nil link field', function()
        local result = notion.parse_to_api('plain text')

        assert.are.equal(1, #result)
        assert.is_nil(result[1].text.link)
        assert.is_nil(result[1].href)
      end)
    end)

    describe('concealment', function()
      it('should return conceal regions for link markers', function()
        local result = notion.parse_with_concealment('[link](https://example.com)')

        assert.are.equal(1, #result.segments)
        assert.are.equal('link', result.segments[1].text)
        assert.are.equal('https://example.com', result.segments[1].href)

        -- Should have conceal regions for [ and ](url)
        assert.is_true(#result.conceal_regions >= 2)
      end)
    end)

    describe('round-trip', function()
      it('should preserve links in parse -> render -> parse cycle', function()
        local original = '[click here](https://example.com)'
        local parsed1 = notion.parse(original)
        local rendered = notion.render(parsed1)
        local parsed2 = notion.parse(rendered)

        assert.are.equal(#parsed1, #parsed2)
        assert.are.equal(parsed1[1].text, parsed2[1].text)
        assert.are.equal(parsed1[1].href, parsed2[1].href)
      end)

      it('should preserve formatted links in cycle', function()
        local original = '**[bold link](https://example.com)**'
        local parsed1 = notion.parse(original)
        local rendered = notion.render(parsed1)
        local parsed2 = notion.parse(rendered)

        assert.are.equal(#parsed1, #parsed2)
        assert.are.equal(parsed1[1].text, parsed2[1].text)
        assert.are.equal(parsed1[1].href, parsed2[1].href)
        assert.are.equal(parsed1[1].annotations.bold, parsed2[1].annotations.bold)
      end)
    end)
  end)
end)
