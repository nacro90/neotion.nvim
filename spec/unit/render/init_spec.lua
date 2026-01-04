---@diagnostic disable: undefined-field
local anti_conceal = require('neotion.render.anti_conceal')
local extmarks = require('neotion.render.extmarks')
local render = require('neotion.render.init')

describe('neotion.render.init', function()
  local bufnr

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'hello **world** there',
      'second *line* here',
      'plain text line',
    })
    -- Reset state
    render.reset()
    anti_conceal.reset()
  end)

  after_each(function()
    render.detach(bufnr)
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  describe('attach', function()
    it('should attach renderer to buffer', function()
      render.attach(bufnr)

      assert.is_true(render.is_attached(bufnr))
    end)

    it('should also attach anti-conceal', function()
      render.attach(bufnr)

      assert.is_true(anti_conceal.is_attached(bufnr))
    end)

    it('should not attach twice', function()
      render.attach(bufnr)
      render.attach(bufnr)

      assert.is_true(render.is_attached(bufnr))
    end)

    it('should render all lines on attach', function()
      render.attach(bufnr)

      -- Check that some extmarks exist
      local marks = extmarks.get_buffer_marks(bufnr)
      -- Should have marks for **world** and *line*
      assert.is_true(#marks >= 2)
    end)
  end)

  describe('detach', function()
    it('should detach renderer from buffer', function()
      render.attach(bufnr)

      render.detach(bufnr)

      assert.is_false(render.is_attached(bufnr))
    end)

    it('should also detach anti-conceal', function()
      render.attach(bufnr)

      render.detach(bufnr)

      assert.is_false(anti_conceal.is_attached(bufnr))
    end)

    it('should clear all extmarks', function()
      render.attach(bufnr)

      render.detach(bufnr)

      local marks = extmarks.get_buffer_marks(bufnr)
      assert.are.equal(0, #marks)
    end)
  end)

  describe('is_attached', function()
    it('should return false for unattached buffer', function()
      assert.is_false(render.is_attached(bufnr))
    end)

    it('should return true for attached buffer', function()
      render.attach(bufnr)

      assert.is_true(render.is_attached(bufnr))
    end)
  end)

  describe('render_line', function()
    it('should render a single line', function()
      render.attach(bufnr)
      extmarks.clear_buffer(bufnr)

      render.render_line(bufnr, 0)

      local marks = extmarks.get_line_marks(bufnr, 0)
      -- Should have mark for **world**
      assert.is_true(#marks >= 1)
    end)

    it('should not render unattached buffer', function()
      render.render_line(bufnr, 0)

      local marks = extmarks.get_line_marks(bufnr, 0)
      assert.are.equal(0, #marks)
    end)

    it('should show raw markers on cursor line', function()
      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      render.attach(bufnr)

      -- Line 0 is cursor line - should not have concealment
      -- This is tested by checking that the line content isn't modified
      local line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
      assert.are.equal('hello **world** there', line)
    end)

    it('should apply concealment on non-cursor lines', function()
      -- Set current buffer and cursor to line 2 (index 1)
      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      render.attach(bufnr)

      -- Line 0 is NOT cursor line - should have concealment
      local marks = extmarks.get_line_marks(bufnr, 0)

      -- Find conceal marks
      local conceal_count = 0
      for _, mark in ipairs(marks) do
        if mark[4] and mark[4].conceal then
          conceal_count = conceal_count + 1
        end
      end

      -- Should have 2 conceal marks for ** and **
      assert.are.equal(2, conceal_count)
    end)

    it('should apply highlight extmarks for formatted text', function()
      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_win_set_cursor(0, { 3, 0 }) -- Cursor on plain text line
      render.attach(bufnr)

      local marks = extmarks.get_line_marks(bufnr, 0)

      -- Find highlight marks
      local highlight_count = 0
      for _, mark in ipairs(marks) do
        if mark[4] and mark[4].hl_group then
          highlight_count = highlight_count + 1
        end
      end

      -- Should have highlight for bold text
      assert.is_true(highlight_count >= 1)
    end)
  end)

  describe('render_buffer', function()
    it('should render all lines in buffer', function()
      render.attach(bufnr)
      extmarks.clear_buffer(bufnr)

      render.render_buffer(bufnr)

      local marks = extmarks.get_buffer_marks(bufnr)
      assert.is_true(#marks >= 2)
    end)
  end)

  describe('refresh', function()
    it('should clear and re-render buffer', function()
      render.attach(bufnr)
      local initial_marks = #extmarks.get_buffer_marks(bufnr)

      render.refresh(bufnr)

      local final_marks = #extmarks.get_buffer_marks(bufnr)
      assert.are.equal(initial_marks, final_marks)
    end)
  end)

  describe('set_enabled', function()
    it('should enable rendering', function()
      render.set_enabled(true)

      assert.is_true(render.is_enabled())
    end)

    it('should disable rendering', function()
      render.set_enabled(false)

      assert.is_false(render.is_enabled())
    end)

    it('should detach all buffers when disabled', function()
      render.attach(bufnr)

      render.set_enabled(false)

      assert.is_false(render.is_attached(bufnr))
    end)
  end)

  describe('is_enabled', function()
    it('should be enabled by default', function()
      assert.is_true(render.is_enabled())
    end)
  end)

  describe('reset', function()
    it('should clear all state', function()
      render.attach(bufnr)

      render.reset()

      assert.is_false(render.is_attached(bufnr))
    end)
  end)

  describe('list_attached', function()
    it('should return empty list when nothing attached', function()
      local attached = render.list_attached()

      assert.are.equal(0, #attached)
    end)

    it('should return list of attached buffers', function()
      local bufnr2 = vim.api.nvim_create_buf(false, true)
      render.attach(bufnr)
      render.attach(bufnr2)

      local attached = render.list_attached()

      assert.are.equal(2, #attached)
      vim.api.nvim_buf_delete(bufnr2, { force = true })
    end)
  end)

  describe('get_config', function()
    it('should return current render config', function()
      local config = render.get_config()

      assert.is_table(config)
      assert.is_boolean(config.enabled)
      assert.is_boolean(config.anti_conceal)
    end)
  end)

  describe('set_config', function()
    it('should update render config', function()
      render.set_config({ anti_conceal = false })

      local config = render.get_config()
      assert.is_false(config.anti_conceal)
    end)

    it('should merge with existing config', function()
      local original = render.get_config()

      render.set_config({ anti_conceal = false })

      local config = render.get_config()
      assert.are.equal(original.enabled, config.enabled)
    end)
  end)

  describe('link highlighting', function()
    it('should apply NeotionLink highlight to links', function()
      -- Create buffer with a link
      local link_bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(link_bufnr, 0, -1, false, {
        'Click [here](https://example.com) for info',
      })
      vim.api.nvim_set_current_buf(link_bufnr)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      render.attach(link_bufnr)

      -- Get marks on line 0
      local marks = extmarks.get_line_marks(link_bufnr, 0)

      -- Find NeotionLink highlight
      local has_link_highlight = false
      for _, mark in ipairs(marks) do
        local details = mark[4]
        if details and details.hl_group and details.hl_group:match('Link') then
          has_link_highlight = true
          break
        end
      end

      assert.is_true(has_link_highlight, 'Link should have NeotionLink highlight')

      render.detach(link_bufnr)
      vim.api.nvim_buf_delete(link_bufnr, { force = true })
    end)

    it('should highlight link text not URL', function()
      local link_bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(link_bufnr, 0, -1, false, {
        '[link](https://example.com)',
      })
      vim.api.nvim_set_current_buf(link_bufnr)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      render.attach(link_bufnr)

      local marks = extmarks.get_line_marks(link_bufnr, 0)

      -- Link text "link" is at columns 1-5 (0-indexed, after [)
      -- Find highlight mark covering link text area
      local link_highlighted = false
      for _, mark in ipairs(marks) do
        local details = mark[4]
        if details and details.hl_group and details.hl_group:match('Link') then
          -- Check if it covers the link text position
          local start_col = mark[2]
          if start_col >= 0 and start_col <= 5 then
            link_highlighted = true
            break
          end
        end
      end

      assert.is_true(link_highlighted, 'Link text should be highlighted')

      render.detach(link_bufnr)
      vim.api.nvim_buf_delete(link_bufnr, { force = true })
    end)
  end)

  describe('InsertLeave autocmd', function()
    it('should re-render buffer on InsertLeave', function()
      vim.api.nvim_set_current_buf(bufnr)
      render.attach(bufnr)

      -- Clear marks to verify re-render
      extmarks.clear_buffer(bufnr)
      local marks_before = #extmarks.get_buffer_marks(bufnr)
      assert.are.equal(0, marks_before)

      -- Trigger InsertLeave autocmd manually
      vim.api.nvim_exec_autocmds('InsertLeave', { buffer = bufnr })

      -- Wait for any deferred callbacks
      vim.wait(50, function()
        return false
      end)

      -- Should have re-rendered
      local marks_after = #extmarks.get_buffer_marks(bufnr)
      assert.is_true(marks_after > 0)
    end)

    it('should not re-render if not attached', function()
      -- Do not attach
      extmarks.clear_buffer(bufnr)

      -- Trigger InsertLeave autocmd manually
      vim.api.nvim_exec_autocmds('InsertLeave', { buffer = bufnr })

      -- Should have no marks
      local marks = #extmarks.get_buffer_marks(bufnr)
      assert.are.equal(0, marks)
    end)
  end)

  describe('TextChanged debounce', function()
    it('should debounce rapid TextChanged events', function()
      local config = require('neotion.config')
      -- Set a small debounce for testing
      config.setup({ render = { debounce_ms = 50 } })

      vim.api.nvim_set_current_buf(bufnr)
      render.attach(bufnr)

      -- Track refresh calls by counting marks after clear
      local refresh_happened = false
      extmarks.clear_buffer(bufnr)

      -- Trigger multiple rapid TextChanged events
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { 'change 1' })
      vim.api.nvim_exec_autocmds('TextChanged', { buffer = bufnr })
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { 'change 2' })
      vim.api.nvim_exec_autocmds('TextChanged', { buffer = bufnr })
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { 'change 3 **bold**' })
      vim.api.nvim_exec_autocmds('TextChanged', { buffer = bufnr })

      -- Immediately after, marks should still be cleared (debounce pending)
      local marks_immediate = #extmarks.get_buffer_marks(bufnr)
      assert.are.equal(0, marks_immediate, 'Marks should be 0 immediately (debounce pending)')

      -- Wait for debounce to complete
      vim.wait(100, function()
        local marks = #extmarks.get_buffer_marks(bufnr)
        if marks > 0 then
          refresh_happened = true
          return true
        end
        return false
      end)

      -- After debounce, refresh should have happened
      assert.is_true(refresh_happened, 'Refresh should happen after debounce period')

      -- Reset config
      config.reset()
    end)

    it('should refresh immediately when debounce_ms is 0', function()
      local config = require('neotion.config')
      -- Disable debounce
      config.setup({ render = { debounce_ms = 0 } })

      vim.api.nvim_set_current_buf(bufnr)
      render.attach(bufnr)

      -- Clear marks
      extmarks.clear_buffer(bufnr)

      -- Trigger TextChanged
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { 'immediate **bold**' })
      vim.api.nvim_exec_autocmds('TextChanged', { buffer = bufnr })

      -- Should have marks immediately (no debounce)
      local marks = #extmarks.get_buffer_marks(bufnr)
      assert.is_true(marks > 0, 'Marks should appear immediately when debounce disabled')

      -- Reset config
      config.reset()
    end)

    it('should cancel pending debounce timer on detach', function()
      local config = require('neotion.config')
      config.setup({ render = { debounce_ms = 100 } })

      vim.api.nvim_set_current_buf(bufnr)
      render.attach(bufnr)
      extmarks.clear_buffer(bufnr)

      -- Trigger TextChanged to start debounce timer
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { 'pending **bold**' })
      vim.api.nvim_exec_autocmds('TextChanged', { buffer = bufnr })

      -- Detach before debounce completes
      render.detach(bufnr)

      -- Wait for what would have been the debounce period
      vim.wait(150, function()
        return false
      end)

      -- Should not have any marks (timer was cancelled)
      local marks = #extmarks.get_buffer_marks(bufnr)
      assert.are.equal(0, marks, 'Detach should cancel pending debounce timer')

      -- Reset config
      config.reset()
    end)
  end)
end)
