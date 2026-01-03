---@diagnostic disable: undefined-field
local rich_text = require('neotion.model.rich_text')
local types = require('neotion.format.types')

describe('neotion.model.rich_text', function()
  describe('from_api', function()
    it('should convert empty rich_text array to empty segments', function()
      local segments = rich_text.from_api({})

      assert.are.equal(0, #segments)
    end)

    it('should convert single plain text item', function()
      local api_rich_text = {
        {
          type = 'text',
          text = { content = 'Hello World', link = nil },
          plain_text = 'Hello World',
          annotations = {
            bold = false,
            italic = false,
            strikethrough = false,
            underline = false,
            code = false,
            color = 'default',
          },
          href = nil,
        },
      }

      local segments = rich_text.from_api(api_rich_text)

      assert.are.equal(1, #segments)
      assert.are.equal('Hello World', segments[1].text)
      assert.is_true(segments[1]:is_plain())
      assert.are.equal(0, segments[1].start_col)
      assert.are.equal(11, segments[1].end_col)
    end)

    it('should convert multiple segments with correct positions', function()
      local api_rich_text = {
        {
          type = 'text',
          plain_text = 'Hello ',
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
          type = 'text',
          plain_text = 'bold',
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
          plain_text = ' text',
          annotations = {
            bold = false,
            italic = false,
            strikethrough = false,
            underline = false,
            code = false,
            color = 'default',
          },
        },
      }

      local segments = rich_text.from_api(api_rich_text)

      assert.are.equal(3, #segments)

      -- First segment: "Hello "
      assert.are.equal('Hello ', segments[1].text)
      assert.are.equal(0, segments[1].start_col)
      assert.are.equal(6, segments[1].end_col)

      -- Second segment: "bold"
      assert.are.equal('bold', segments[2].text)
      assert.is_true(segments[2].annotations.bold)
      assert.are.equal(6, segments[2].start_col)
      assert.are.equal(10, segments[2].end_col)

      -- Third segment: " text"
      assert.are.equal(' text', segments[3].text)
      assert.are.equal(10, segments[3].start_col)
      assert.are.equal(15, segments[3].end_col)
    end)

    it('should handle nil input', function()
      local segments = rich_text.from_api(nil)

      assert.are.equal(0, #segments)
    end)
  end)

  describe('to_api', function()
    it('should convert empty segments to empty array', function()
      local result = rich_text.to_api({})

      assert.are.same({}, result)
    end)

    it('should convert single segment to API format', function()
      local segment = types.RichTextSegment.new('Hello', {
        annotations = types.Annotation.new({ bold = true }),
      })

      local result = rich_text.to_api({ segment })

      assert.are.equal(1, #result)
      assert.are.equal('text', result[1].type)
      assert.are.equal('Hello', result[1].text.content)
      assert.is_true(result[1].annotations.bold)
    end)

    it('should convert multiple segments', function()
      local segments = {
        types.RichTextSegment.new('Plain '),
        types.RichTextSegment.new('bold', {
          annotations = types.Annotation.new({ bold = true }),
        }),
      }

      local result = rich_text.to_api(segments)

      assert.are.equal(2, #result)
      assert.are.equal('Plain ', result[1].text.content)
      assert.are.equal('bold', result[2].text.content)
    end)
  end)

  describe('to_plain', function()
    it('should return empty string for empty segments', function()
      local result = rich_text.to_plain({})

      assert.are.equal('', result)
    end)

    it('should concatenate all segment text', function()
      local segments = {
        types.RichTextSegment.new('Hello '),
        types.RichTextSegment.new('World'),
        types.RichTextSegment.new('!'),
      }

      local result = rich_text.to_plain(segments)

      assert.are.equal('Hello World!', result)
    end)
  end)

  describe('from_plain', function()
    it('should create single plain segment from text', function()
      local segments = rich_text.from_plain('Hello World')

      assert.are.equal(1, #segments)
      assert.are.equal('Hello World', segments[1].text)
      assert.is_true(segments[1]:is_plain())
    end)

    it('should handle empty string', function()
      local segments = rich_text.from_plain('')

      assert.are.equal(0, #segments)
    end)

    it('should handle nil input', function()
      local segments = rich_text.from_plain(nil)

      assert.are.equal(0, #segments)
    end)
  end)

  describe('equals', function()
    it('should return true for identical segments', function()
      local a = {
        types.RichTextSegment.new('Hello', {
          annotations = types.Annotation.new({ bold = true }),
        }),
      }
      local b = {
        types.RichTextSegment.new('Hello', {
          annotations = types.Annotation.new({ bold = true }),
        }),
      }

      assert.is_true(rich_text.equals(a, b))
    end)

    it('should return false for different text', function()
      local a = { types.RichTextSegment.new('Hello') }
      local b = { types.RichTextSegment.new('World') }

      assert.is_false(rich_text.equals(a, b))
    end)

    it('should return false for different annotations', function()
      local a = {
        types.RichTextSegment.new('Hello', {
          annotations = types.Annotation.new({ bold = true }),
        }),
      }
      local b = {
        types.RichTextSegment.new('Hello', {
          annotations = types.Annotation.new({ italic = true }),
        }),
      }

      assert.is_false(rich_text.equals(a, b))
    end)

    it('should return false for different segment count', function()
      local a = { types.RichTextSegment.new('Hello') }
      local b = {
        types.RichTextSegment.new('Hel'),
        types.RichTextSegment.new('lo'),
      }

      assert.is_false(rich_text.equals(a, b))
    end)

    it('should return true for empty arrays', function()
      assert.is_true(rich_text.equals({}, {}))
    end)
  end)

  describe('merge_adjacent', function()
    it('should merge adjacent segments with same formatting', function()
      local segments = {
        types.RichTextSegment.new('Hel', {
          annotations = types.Annotation.new({ bold = true }),
        }),
        types.RichTextSegment.new('lo', {
          annotations = types.Annotation.new({ bold = true }),
          start_col = 3,
        }),
      }

      local merged = rich_text.merge_adjacent(segments)

      assert.are.equal(1, #merged)
      assert.are.equal('Hello', merged[1].text)
      assert.is_true(merged[1].annotations.bold)
    end)

    it('should not merge segments with different formatting', function()
      local segments = {
        types.RichTextSegment.new('Hello '),
        types.RichTextSegment.new('World', {
          annotations = types.Annotation.new({ bold = true }),
          start_col = 6,
        }),
      }

      local merged = rich_text.merge_adjacent(segments)

      assert.are.equal(2, #merged)
    end)

    it('should handle empty input', function()
      local merged = rich_text.merge_adjacent({})

      assert.are.equal(0, #merged)
    end)

    it('should handle single segment', function()
      local segments = { types.RichTextSegment.new('Hello') }

      local merged = rich_text.merge_adjacent(segments)

      assert.are.equal(1, #merged)
      assert.are.equal('Hello', merged[1].text)
    end)

    it('should update positions after merge', function()
      local segments = {
        types.RichTextSegment.new('A'),
        types.RichTextSegment.new('B', { start_col = 1 }),
        types.RichTextSegment.new('C', {
          annotations = types.Annotation.new({ bold = true }),
          start_col = 2,
        }),
      }

      local merged = rich_text.merge_adjacent(segments)

      assert.are.equal(2, #merged)
      assert.are.equal('AB', merged[1].text)
      assert.are.equal(0, merged[1].start_col)
      assert.are.equal(2, merged[1].end_col)
      assert.are.equal('C', merged[2].text)
      assert.are.equal(2, merged[2].start_col)
      assert.are.equal(3, merged[2].end_col)
    end)
  end)

  describe('get_segment_at', function()
    it('should return segment at given column', function()
      local segments = {
        types.RichTextSegment.new('Hello ', { start_col = 0 }),
        types.RichTextSegment.new('World', { start_col = 6 }),
      }

      local segment, index = rich_text.get_segment_at(segments, 7)

      assert.are.equal('World', segment.text)
      assert.are.equal(2, index)
    end)

    it('should return first segment at column 0', function()
      local segments = {
        types.RichTextSegment.new('Hello'),
      }

      local segment, index = rich_text.get_segment_at(segments, 0)

      assert.are.equal('Hello', segment.text)
      assert.are.equal(1, index)
    end)

    it('should return nil for column beyond segments', function()
      local segments = {
        types.RichTextSegment.new('Hello'),
      }

      local segment, index = rich_text.get_segment_at(segments, 10)

      assert.is_nil(segment)
      assert.is_nil(index)
    end)

    it('should return nil for empty segments', function()
      local segment, index = rich_text.get_segment_at({}, 0)

      assert.is_nil(segment)
      assert.is_nil(index)
    end)
  end)

  describe('total_length', function()
    it('should return 0 for empty segments', function()
      assert.are.equal(0, rich_text.total_length({}))
    end)

    it('should return sum of all segment lengths', function()
      local segments = {
        types.RichTextSegment.new('Hello '),
        types.RichTextSegment.new('World'),
      }

      assert.are.equal(11, rich_text.total_length(segments))
    end)
  end)
end)
