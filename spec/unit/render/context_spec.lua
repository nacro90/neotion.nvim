describe('neotion.render.context', function()
  local context_module
  local extmarks

  -- Mock extmarks module
  local mock_extmarks
  local extmark_calls

  before_each(function()
    extmark_calls = {}

    mock_extmarks = {
      NAMESPACE = 999,
      apply_highlight = function(bufnr, line, start_col, end_col, hl_group)
        table.insert(extmark_calls, {
          type = 'highlight',
          bufnr = bufnr,
          line = line,
          start_col = start_col,
          end_col = end_col,
          hl_group = hl_group,
        })
        return 1
      end,
      apply_virtual_text = function(bufnr, line, col, text, hl_group, opts)
        table.insert(extmark_calls, {
          type = 'virtual_text',
          bufnr = bufnr,
          line = line,
          col = col,
          text = text,
          hl_group = hl_group,
          opts = opts,
        })
        return 2
      end,
      apply_concealment = function(bufnr, line, start_col, end_col, replacement)
        table.insert(extmark_calls, {
          type = 'concealment',
          bufnr = bufnr,
          line = line,
          start_col = start_col,
          end_col = end_col,
          replacement = replacement,
        })
        return 3
      end,
      clear_line = function(bufnr, line)
        table.insert(extmark_calls, {
          type = 'clear_line',
          bufnr = bufnr,
          line = line,
        })
      end,
    }

    -- Inject mock
    package.loaded['neotion.render.extmarks'] = mock_extmarks
    package.loaded['neotion.render.context'] = nil
    context_module = require('neotion.render.context')
  end)

  after_each(function()
    package.loaded['neotion.render.extmarks'] = nil
    package.loaded['neotion.render.context'] = nil
  end)

  describe('RenderContext.new', function()
    it('should create context with required fields', function()
      local ctx = context_module.RenderContext.new(1, 5, {})

      assert.are.equal(1, ctx.bufnr)
      assert.are.equal(5, ctx.line)
    end)

    it('should set is_cursor_line from opts', function()
      local ctx = context_module.RenderContext.new(1, 5, { is_cursor_line = true })

      assert.is_true(ctx.is_cursor_line)
    end)

    it('should default is_cursor_line to false', function()
      local ctx = context_module.RenderContext.new(1, 5, {})

      assert.is_false(ctx.is_cursor_line)
    end)

    it('should set window_width from opts', function()
      local ctx = context_module.RenderContext.new(1, 5, { window_width = 120 })

      assert.are.equal(120, ctx.window_width)
    end)

    it('should default window_width to 80', function()
      local ctx = context_module.RenderContext.new(1, 5, {})

      assert.are.equal(80, ctx.window_width)
    end)

    it('should set text_width from opts', function()
      local ctx = context_module.RenderContext.new(1, 5, { text_width = 76 })

      assert.are.equal(76, ctx.text_width)
    end)

    it('should default text_width to window_width', function()
      local ctx = context_module.RenderContext.new(1, 5, { window_width = 100 })

      assert.are.equal(100, ctx.text_width)
    end)
  end)

  describe('RenderContext:overlay_line', function()
    it('should create full-width virtual text overlay', function()
      local ctx = context_module.RenderContext.new(1, 5, { text_width = 40 })

      ctx:overlay_line('─', 'NeotionDivider')

      assert.are.equal(1, #extmark_calls)
      local call = extmark_calls[1]
      assert.are.equal('virtual_text', call.type)
      assert.are.equal(1, call.bufnr)
      assert.are.equal(5, call.line)
      assert.are.equal(0, call.col)
      assert.are.equal(string.rep('─', 40), call.text)
      assert.are.equal('NeotionDivider', call.hl_group)
      assert.are.equal('overlay', call.opts.position)
    end)

    it('should use custom width when provided', function()
      local ctx = context_module.RenderContext.new(1, 5, { text_width = 80 })

      ctx:overlay_line('━', 'TestHL', { width = 20 })

      local call = extmark_calls[1]
      assert.are.equal(string.rep('━', 20), call.text)
    end)

    it('should use text_width by default', function()
      local ctx = context_module.RenderContext.new(1, 5, { text_width = 50 })

      ctx:overlay_line('─', 'NeotionDivider')

      local call = extmark_calls[1]
      -- ─ is 3 bytes in UTF-8, so 50 chars = 150 bytes
      assert.are.equal(string.rep('─', 50), call.text)
    end)
  end)

  describe('RenderContext:highlight', function()
    it('should delegate to extmarks.apply_highlight', function()
      local ctx = context_module.RenderContext.new(1, 5, {})

      ctx:highlight(10, 20, 'NeotionBold')

      assert.are.equal(1, #extmark_calls)
      local call = extmark_calls[1]
      assert.are.equal('highlight', call.type)
      assert.are.equal(1, call.bufnr)
      assert.are.equal(5, call.line)
      assert.are.equal(10, call.start_col)
      assert.are.equal(20, call.end_col)
      assert.are.equal('NeotionBold', call.hl_group)
    end)
  end)

  describe('RenderContext:conceal', function()
    it('should apply concealment when not on cursor line', function()
      local ctx = context_module.RenderContext.new(1, 5, { is_cursor_line = false })

      ctx:conceal(0, 2, '')

      assert.are.equal(1, #extmark_calls)
      local call = extmark_calls[1]
      assert.are.equal('concealment', call.type)
      assert.are.equal(0, call.start_col)
      assert.are.equal(2, call.end_col)
      assert.are.equal('', call.replacement)
    end)

    it('should skip concealment on cursor line (anti-conceal)', function()
      local ctx = context_module.RenderContext.new(1, 5, { is_cursor_line = true })

      ctx:conceal(0, 2, '')

      assert.are.equal(0, #extmark_calls)
    end)

    it('should use replacement character', function()
      local ctx = context_module.RenderContext.new(1, 5, { is_cursor_line = false })

      ctx:conceal(5, 10, '│')

      local call = extmark_calls[1]
      assert.are.equal('│', call.replacement)
    end)
  end)

  describe('RenderContext:virtual_text', function()
    it('should delegate to extmarks.apply_virtual_text', function()
      local ctx = context_module.RenderContext.new(1, 5, {})

      ctx:virtual_text(10, '│ ', 'NeotionQuote')

      assert.are.equal(1, #extmark_calls)
      local call = extmark_calls[1]
      assert.are.equal('virtual_text', call.type)
      assert.are.equal(1, call.bufnr)
      assert.are.equal(5, call.line)
      assert.are.equal(10, call.col)
      assert.are.equal('│ ', call.text)
      assert.are.equal('NeotionQuote', call.hl_group)
    end)

    it('should pass position option', function()
      local ctx = context_module.RenderContext.new(1, 5, {})

      ctx:virtual_text(0, 'prefix', 'TestHL', { position = 'inline' })

      local call = extmark_calls[1]
      assert.are.equal('inline', call.opts.position)
    end)

    it('should default position to inline', function()
      local ctx = context_module.RenderContext.new(1, 5, {})

      ctx:virtual_text(0, 'text', 'TestHL')

      local call = extmark_calls[1]
      assert.are.equal('inline', call.opts.position)
    end)
  end)

  describe('RenderContext:clear', function()
    it('should delegate to extmarks.clear_line', function()
      local ctx = context_module.RenderContext.new(1, 5, {})

      ctx:clear()

      assert.are.equal(1, #extmark_calls)
      local call = extmark_calls[1]
      assert.are.equal('clear_line', call.type)
      assert.are.equal(1, call.bufnr)
      assert.are.equal(5, call.line)
    end)
  end)

  describe('Block rendering context properties', function()
    it('should provide block_start_line when set', function()
      local ctx = context_module.RenderContext.new(1, 7, {
        block_start_line = 5,
        block_end_line = 10,
      })

      assert.are.equal(5, ctx.block_start_line)
      assert.are.equal(10, ctx.block_end_line)
    end)

    it('should calculate is_block_start correctly', function()
      local ctx = context_module.RenderContext.new(1, 5, {
        block_start_line = 5,
        block_end_line = 10,
      })

      assert.is_true(ctx:is_block_start())
    end)

    it('should calculate is_block_end correctly', function()
      local ctx = context_module.RenderContext.new(1, 10, {
        block_start_line = 5,
        block_end_line = 10,
      })

      assert.is_true(ctx:is_block_end())
    end)

    it('should return false for is_block_start when not at start', function()
      local ctx = context_module.RenderContext.new(1, 7, {
        block_start_line = 5,
        block_end_line = 10,
      })

      assert.is_false(ctx:is_block_start())
    end)

    it('should return false for is_block_end when not at end', function()
      local ctx = context_module.RenderContext.new(1, 7, {
        block_start_line = 5,
        block_end_line = 10,
      })

      assert.is_false(ctx:is_block_end())
    end)

    it('should handle single-line blocks', function()
      local ctx = context_module.RenderContext.new(1, 5, {
        block_start_line = 5,
        block_end_line = 5,
      })

      assert.is_true(ctx:is_block_start())
      assert.is_true(ctx:is_block_end())
    end)
  end)
end)
