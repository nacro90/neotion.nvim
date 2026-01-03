describe('neotion.input.shortcuts', function()
  local shortcuts

  before_each(function()
    package.loaded['neotion.input.shortcuts'] = nil
    shortcuts = require('neotion.input.shortcuts')
  end)

  describe('get_marker_pair', function()
    it('should return ** for bold', function()
      local start_marker, end_marker = shortcuts.get_marker_pair('bold')
      assert.are.equal('**', start_marker)
      assert.are.equal('**', end_marker)
    end)

    it('should return * for italic', function()
      local start_marker, end_marker = shortcuts.get_marker_pair('italic')
      assert.are.equal('*', start_marker)
      assert.are.equal('*', end_marker)
    end)

    it('should return ~ for strikethrough', function()
      local start_marker, end_marker = shortcuts.get_marker_pair('strikethrough')
      assert.are.equal('~', start_marker)
      assert.are.equal('~', end_marker)
    end)

    it('should return ` for code', function()
      local start_marker, end_marker = shortcuts.get_marker_pair('code')
      assert.are.equal('`', start_marker)
      assert.are.equal('`', end_marker)
    end)

    it('should return <u> and </u> for underline', function()
      local start_marker, end_marker = shortcuts.get_marker_pair('underline')
      assert.are.equal('<u>', start_marker)
      assert.are.equal('</u>', end_marker)
    end)

    it('should return <c:color> and </c> for color', function()
      local start_marker, end_marker = shortcuts.get_marker_pair('color', 'red')
      assert.are.equal('<c:red>', start_marker)
      assert.are.equal('</c>', end_marker)
    end)

    it('should return <c:blue> for blue color', function()
      local start_marker, end_marker = shortcuts.get_marker_pair('color', 'blue')
      assert.are.equal('<c:blue>', start_marker)
      assert.are.equal('</c>', end_marker)
    end)

    it('should return nil for unknown format', function()
      local start_marker, end_marker = shortcuts.get_marker_pair('unknown')
      assert.is_nil(start_marker)
      assert.is_nil(end_marker)
    end)
  end)

  describe('wrap_text', function()
    it('should wrap text with bold markers', function()
      local result = shortcuts.wrap_text('hello', 'bold')
      assert.are.equal('**hello**', result)
    end)

    it('should wrap text with italic markers', function()
      local result = shortcuts.wrap_text('hello', 'italic')
      assert.are.equal('*hello*', result)
    end)

    it('should wrap text with strikethrough markers', function()
      local result = shortcuts.wrap_text('hello', 'strikethrough')
      assert.are.equal('~hello~', result)
    end)

    it('should wrap text with code markers', function()
      local result = shortcuts.wrap_text('hello', 'code')
      assert.are.equal('`hello`', result)
    end)

    it('should wrap text with underline markers', function()
      local result = shortcuts.wrap_text('hello', 'underline')
      assert.are.equal('<u>hello</u>', result)
    end)

    it('should wrap text with color markers', function()
      local result = shortcuts.wrap_text('hello', 'color', 'red')
      assert.are.equal('<c:red>hello</c>', result)
    end)

    it('should return original text for unknown format', function()
      local result = shortcuts.wrap_text('hello', 'unknown')
      assert.are.equal('hello', result)
    end)

    it('should handle empty text', function()
      local result = shortcuts.wrap_text('', 'bold')
      assert.are.equal('****', result)
    end)
  end)

  describe('unwrap_text', function()
    it('should unwrap bold markers', function()
      local result = shortcuts.unwrap_text('**hello**', 'bold')
      assert.are.equal('hello', result)
    end)

    it('should unwrap italic markers', function()
      local result = shortcuts.unwrap_text('*hello*', 'italic')
      assert.are.equal('hello', result)
    end)

    it('should unwrap strikethrough markers', function()
      local result = shortcuts.unwrap_text('~hello~', 'strikethrough')
      assert.are.equal('hello', result)
    end)

    it('should unwrap code markers', function()
      local result = shortcuts.unwrap_text('`hello`', 'code')
      assert.are.equal('hello', result)
    end)

    it('should unwrap underline markers', function()
      local result = shortcuts.unwrap_text('<u>hello</u>', 'underline')
      assert.are.equal('hello', result)
    end)

    it('should unwrap color markers', function()
      local result = shortcuts.unwrap_text('<c:red>hello</c>', 'color')
      assert.are.equal('hello', result)
    end)

    it('should unwrap any color', function()
      local result = shortcuts.unwrap_text('<c:blue_background>hello</c>', 'color')
      assert.are.equal('hello', result)
    end)

    it('should return original text if not wrapped', function()
      local result = shortcuts.unwrap_text('hello', 'bold')
      assert.are.equal('hello', result)
    end)

    it('should return original text for unknown format', function()
      local result = shortcuts.unwrap_text('**hello**', 'unknown')
      assert.are.equal('**hello**', result)
    end)
  end)

  describe('is_wrapped', function()
    it('should detect bold wrapped text', function()
      assert.is_true(shortcuts.is_wrapped('**hello**', 'bold'))
    end)

    it('should detect italic wrapped text', function()
      assert.is_true(shortcuts.is_wrapped('*hello*', 'italic'))
    end)

    it('should detect strikethrough wrapped text', function()
      assert.is_true(shortcuts.is_wrapped('~hello~', 'strikethrough'))
    end)

    it('should detect code wrapped text', function()
      assert.is_true(shortcuts.is_wrapped('`hello`', 'code'))
    end)

    it('should detect underline wrapped text', function()
      assert.is_true(shortcuts.is_wrapped('<u>hello</u>', 'underline'))
    end)

    it('should detect color wrapped text', function()
      assert.is_true(shortcuts.is_wrapped('<c:red>hello</c>', 'color'))
    end)

    it('should detect any color', function()
      assert.is_true(shortcuts.is_wrapped('<c:blue_background>hello</c>', 'color'))
    end)

    it('should return false for unwrapped text', function()
      assert.is_false(shortcuts.is_wrapped('hello', 'bold'))
    end)

    it('should return false for partial wrap', function()
      assert.is_false(shortcuts.is_wrapped('**hello', 'bold'))
    end)

    it('should return false for unknown format', function()
      assert.is_false(shortcuts.is_wrapped('**hello**', 'unknown'))
    end)
  end)

  describe('toggle_text', function()
    it('should wrap unwrapped text', function()
      local result = shortcuts.toggle_text('hello', 'bold')
      assert.are.equal('**hello**', result)
    end)

    it('should unwrap wrapped text', function()
      local result = shortcuts.toggle_text('**hello**', 'bold')
      assert.are.equal('hello', result)
    end)

    it('should toggle italic', function()
      assert.are.equal('*hello*', shortcuts.toggle_text('hello', 'italic'))
      assert.are.equal('hello', shortcuts.toggle_text('*hello*', 'italic'))
    end)

    it('should toggle strikethrough', function()
      assert.are.equal('~hello~', shortcuts.toggle_text('hello', 'strikethrough'))
      assert.are.equal('hello', shortcuts.toggle_text('~hello~', 'strikethrough'))
    end)

    it('should toggle code', function()
      assert.are.equal('`hello`', shortcuts.toggle_text('hello', 'code'))
      assert.are.equal('hello', shortcuts.toggle_text('`hello`', 'code'))
    end)

    it('should toggle underline', function()
      assert.are.equal('<u>hello</u>', shortcuts.toggle_text('hello', 'underline'))
      assert.are.equal('hello', shortcuts.toggle_text('<u>hello</u>', 'underline'))
    end)

    it('should toggle color', function()
      local result = shortcuts.toggle_text('hello', 'color', 'red')
      assert.are.equal('<c:red>hello</c>', result)

      local unwrapped = shortcuts.toggle_text('<c:red>hello</c>', 'color')
      assert.are.equal('hello', unwrapped)
    end)
  end)

  describe('insert_pair_string', function()
    it('should return bold pair with cursor placeholder', function()
      local result = shortcuts.insert_pair_string('bold')
      assert.are.equal('****', result)
    end)

    it('should return italic pair', function()
      local result = shortcuts.insert_pair_string('italic')
      assert.are.equal('**', result)
    end)

    it('should return strikethrough pair', function()
      local result = shortcuts.insert_pair_string('strikethrough')
      assert.are.equal('~~', result)
    end)

    it('should return code pair', function()
      local result = shortcuts.insert_pair_string('code')
      assert.are.equal('``', result)
    end)

    it('should return underline pair', function()
      local result = shortcuts.insert_pair_string('underline')
      assert.are.equal('<u></u>', result)
    end)

    it('should return color pair', function()
      local result = shortcuts.insert_pair_string('color', 'red')
      assert.are.equal('<c:red></c>', result)
    end)

    it('should return empty string for unknown format', function()
      local result = shortcuts.insert_pair_string('unknown')
      assert.are.equal('', result)
    end)
  end)

  describe('cursor_offset_in_pair', function()
    it('should return 2 for bold', function()
      local offset = shortcuts.cursor_offset_in_pair('bold')
      assert.are.equal(2, offset)
    end)

    it('should return 1 for italic', function()
      local offset = shortcuts.cursor_offset_in_pair('italic')
      assert.are.equal(1, offset)
    end)

    it('should return 1 for strikethrough', function()
      local offset = shortcuts.cursor_offset_in_pair('strikethrough')
      assert.are.equal(1, offset)
    end)

    it('should return 1 for code', function()
      local offset = shortcuts.cursor_offset_in_pair('code')
      assert.are.equal(1, offset)
    end)

    it('should return 3 for underline', function()
      local offset = shortcuts.cursor_offset_in_pair('underline')
      assert.are.equal(3, offset)
    end)

    it('should return length of start marker for color', function()
      local offset = shortcuts.cursor_offset_in_pair('color', 'red')
      assert.are.equal(7, offset) -- <c:red>
    end)

    it('should return 0 for unknown format', function()
      local offset = shortcuts.cursor_offset_in_pair('unknown')
      assert.are.equal(0, offset)
    end)
  end)

  describe('module interface', function()
    it('should expose setup function', function()
      assert.is_function(shortcuts.setup)
    end)

    it('should expose format types', function()
      assert.is_table(shortcuts.FORMAT_TYPES)
      assert.is_true(vim.tbl_contains(shortcuts.FORMAT_TYPES, 'bold'))
      assert.is_true(vim.tbl_contains(shortcuts.FORMAT_TYPES, 'italic'))
      assert.is_true(vim.tbl_contains(shortcuts.FORMAT_TYPES, 'strikethrough'))
      assert.is_true(vim.tbl_contains(shortcuts.FORMAT_TYPES, 'code'))
      assert.is_true(vim.tbl_contains(shortcuts.FORMAT_TYPES, 'underline'))
      assert.is_true(vim.tbl_contains(shortcuts.FORMAT_TYPES, 'color'))
    end)
  end)
end)
