---@diagnostic disable: undefined-field
local extmarks = require('neotion.render.extmarks')
local types = require('neotion.format.types')

describe('neotion.render.extmarks', function()
  local bufnr

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'hello world',
      'second line',
      'third line',
    })
  end)

  after_each(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  describe('NAMESPACE', function()
    it('should have a namespace id', function()
      assert.is_number(extmarks.NAMESPACE)
      assert.is_true(extmarks.NAMESPACE > 0)
    end)
  end)

  describe('clear_line', function()
    it('should clear extmarks from a line', function()
      -- Add an extmark
      vim.api.nvim_buf_set_extmark(bufnr, extmarks.NAMESPACE, 0, 0, {
        end_col = 5,
        hl_group = 'NeotionBold',
      })

      extmarks.clear_line(bufnr, 0)

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, extmarks.NAMESPACE, { 0, 0 }, { 0, -1 }, {})
      assert.are.equal(0, #marks)
    end)

    it('should only clear marks on specified line', function()
      -- Add extmarks on different lines
      vim.api.nvim_buf_set_extmark(bufnr, extmarks.NAMESPACE, 0, 0, { hl_group = 'NeotionBold' })
      vim.api.nvim_buf_set_extmark(bufnr, extmarks.NAMESPACE, 1, 0, { hl_group = 'NeotionItalic' })

      extmarks.clear_line(bufnr, 0)

      local marks_line0 = vim.api.nvim_buf_get_extmarks(bufnr, extmarks.NAMESPACE, { 0, 0 }, { 0, -1 }, {})
      local marks_line1 = vim.api.nvim_buf_get_extmarks(bufnr, extmarks.NAMESPACE, { 1, 0 }, { 1, -1 }, {})

      assert.are.equal(0, #marks_line0)
      assert.are.equal(1, #marks_line1)
    end)
  end)

  describe('clear_buffer', function()
    it('should clear all extmarks from buffer', function()
      vim.api.nvim_buf_set_extmark(bufnr, extmarks.NAMESPACE, 0, 0, { hl_group = 'NeotionBold' })
      vim.api.nvim_buf_set_extmark(bufnr, extmarks.NAMESPACE, 1, 0, { hl_group = 'NeotionItalic' })
      vim.api.nvim_buf_set_extmark(bufnr, extmarks.NAMESPACE, 2, 0, { hl_group = 'NeotionCode' })

      extmarks.clear_buffer(bufnr)

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, extmarks.NAMESPACE, 0, -1, {})
      assert.are.equal(0, #marks)
    end)
  end)

  describe('apply_highlight', function()
    it('should apply highlight to range', function()
      extmarks.apply_highlight(bufnr, 0, 0, 5, 'NeotionBold')

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, extmarks.NAMESPACE, { 0, 0 }, { 0, -1 }, { details = true })
      assert.are.equal(1, #marks)
      assert.are.equal('NeotionBold', marks[1][4].hl_group)
    end)

    it('should apply multiple highlights to same line', function()
      extmarks.apply_highlight(bufnr, 0, 0, 5, 'NeotionBold')
      extmarks.apply_highlight(bufnr, 0, 6, 11, 'NeotionItalic')

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, extmarks.NAMESPACE, { 0, 0 }, { 0, -1 }, { details = true })
      assert.are.equal(2, #marks)
    end)

    it('should return extmark id', function()
      local id = extmarks.apply_highlight(bufnr, 0, 0, 5, 'NeotionBold')

      assert.is_number(id)
      assert.is_true(id > 0)
    end)
  end)

  describe('apply_virtual_text', function()
    it('should add virtual text at position', function()
      extmarks.apply_virtual_text(bufnr, 0, 0, '● ', 'NeotionBullet')

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, extmarks.NAMESPACE, { 0, 0 }, { 0, -1 }, { details = true })
      assert.are.equal(1, #marks)
      assert.is_table(marks[1][4].virt_text)
    end)

    it('should position virtual text inline by default', function()
      extmarks.apply_virtual_text(bufnr, 0, 0, '● ')

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, extmarks.NAMESPACE, { 0, 0 }, { 0, -1 }, { details = true })
      assert.are.equal('inline', marks[1][4].virt_text_pos)
    end)

    it('should support overlay position', function()
      extmarks.apply_virtual_text(bufnr, 0, 0, '●', nil, { position = 'overlay' })

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, extmarks.NAMESPACE, { 0, 0 }, { 0, -1 }, { details = true })
      assert.are.equal('overlay', marks[1][4].virt_text_pos)
    end)
  end)

  describe('apply_concealment', function()
    it('should conceal text range', function()
      extmarks.apply_concealment(bufnr, 0, 0, 2)

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, extmarks.NAMESPACE, { 0, 0 }, { 0, -1 }, { details = true })
      assert.are.equal(1, #marks)
      assert.are.equal('', marks[1][4].conceal)
    end)

    it('should conceal with replacement character', function()
      extmarks.apply_concealment(bufnr, 0, 0, 2, '…')

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, extmarks.NAMESPACE, { 0, 0 }, { 0, -1 }, { details = true })
      assert.are.equal('…', marks[1][4].conceal)
    end)
  end)

  describe('apply_segment_highlights', function()
    it('should apply highlights for formatted segment', function()
      local segment = types.RichTextSegment.new('bold', {
        annotations = types.Annotation.new({ bold = true }),
        start_col = 0,
      })

      extmarks.apply_segment_highlights(bufnr, 0, segment)

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, extmarks.NAMESPACE, { 0, 0 }, { 0, -1 }, { details = true })
      assert.are.equal(1, #marks)
      assert.are.equal('NeotionBold', marks[1][4].hl_group)
    end)

    it('should apply multiple highlights for combined formatting', function()
      local segment = types.RichTextSegment.new('both', {
        annotations = types.Annotation.new({ bold = true, italic = true }),
        start_col = 0,
      })

      extmarks.apply_segment_highlights(bufnr, 0, segment)

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, extmarks.NAMESPACE, { 0, 0 }, { 0, -1 }, { details = true })
      -- May be 1 or 2 marks depending on implementation
      assert.is_true(#marks >= 1)
    end)

    it('should not apply highlights for plain segment', function()
      local segment = types.RichTextSegment.new('plain', {
        start_col = 0,
      })

      extmarks.apply_segment_highlights(bufnr, 0, segment)

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, extmarks.NAMESPACE, { 0, 0 }, { 0, -1 }, { details = true })
      assert.are.equal(0, #marks)
    end)

    it('should apply color highlight', function()
      local segment = types.RichTextSegment.new('red', {
        annotations = types.Annotation.new({ color = 'red' }),
        start_col = 0,
      })

      extmarks.apply_segment_highlights(bufnr, 0, segment)

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, extmarks.NAMESPACE, { 0, 0 }, { 0, -1 }, { details = true })
      assert.are.equal(1, #marks)
      assert.are.equal('NeotionColorRed', marks[1][4].hl_group)
    end)
  end)

  describe('render_line_segments', function()
    it('should render multiple segments on a line', function()
      local segments = {
        types.RichTextSegment.new('hello ', { start_col = 0 }),
        types.RichTextSegment.new('world', {
          annotations = types.Annotation.new({ bold = true }),
          start_col = 6,
        }),
      }

      extmarks.render_line_segments(bufnr, 0, segments)

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, extmarks.NAMESPACE, { 0, 0 }, { 0, -1 }, { details = true })
      -- Should have 1 mark for bold "world"
      assert.are.equal(1, #marks)
      assert.are.equal('NeotionBold', marks[1][4].hl_group)
    end)

    it('should clear previous marks before rendering', function()
      -- Add existing mark
      vim.api.nvim_buf_set_extmark(bufnr, extmarks.NAMESPACE, 0, 0, { hl_group = 'NeotionItalic' })

      local segments = {
        types.RichTextSegment.new('bold', {
          annotations = types.Annotation.new({ bold = true }),
          start_col = 0,
        }),
      }

      extmarks.render_line_segments(bufnr, 0, segments)

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, extmarks.NAMESPACE, { 0, 0 }, { 0, -1 }, { details = true })
      assert.are.equal(1, #marks)
      assert.are.equal('NeotionBold', marks[1][4].hl_group)
    end)
  end)

  describe('get_line_marks', function()
    it('should return all marks on a line', function()
      extmarks.apply_highlight(bufnr, 0, 0, 5, 'NeotionBold')
      extmarks.apply_highlight(bufnr, 0, 6, 11, 'NeotionItalic')

      local marks = extmarks.get_line_marks(bufnr, 0)

      assert.are.equal(2, #marks)
    end)

    it('should return empty table for line without marks', function()
      local marks = extmarks.get_line_marks(bufnr, 0)

      assert.are.equal(0, #marks)
    end)
  end)
end)
