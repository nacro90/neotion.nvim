---@diagnostic disable: undefined-field
local anti_conceal = require('neotion.render.anti_conceal')

describe('neotion.render.anti_conceal', function()
  local bufnr

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'hello **world** there',
      'second *line* here',
      'third ~line~ text',
    })
    -- Clear any state
    anti_conceal.reset()
  end)

  after_each(function()
    anti_conceal.detach(bufnr)
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  describe('attach', function()
    it('should attach to buffer', function()
      anti_conceal.attach(bufnr)

      assert.is_true(anti_conceal.is_attached(bufnr))
    end)

    it('should not attach twice to same buffer', function()
      anti_conceal.attach(bufnr)
      anti_conceal.attach(bufnr)

      assert.is_true(anti_conceal.is_attached(bufnr))
    end)

    it('should track cursor line on attach', function()
      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_win_set_cursor(0, { 2, 0 })

      anti_conceal.attach(bufnr)

      assert.are.equal(1, anti_conceal.get_cursor_line(bufnr)) -- 0-indexed
    end)
  end)

  describe('detach', function()
    it('should detach from buffer', function()
      anti_conceal.attach(bufnr)

      anti_conceal.detach(bufnr)

      assert.is_false(anti_conceal.is_attached(bufnr))
    end)

    it('should not error when detaching unattached buffer', function()
      assert.has_no_error(function()
        anti_conceal.detach(bufnr)
      end)
    end)
  end)

  describe('is_attached', function()
    it('should return false for unattached buffer', function()
      assert.is_false(anti_conceal.is_attached(bufnr))
    end)

    it('should return true for attached buffer', function()
      anti_conceal.attach(bufnr)

      assert.is_true(anti_conceal.is_attached(bufnr))
    end)
  end)

  describe('get_cursor_line', function()
    it('should return nil for unattached buffer', function()
      assert.is_nil(anti_conceal.get_cursor_line(bufnr))
    end)

    it('should return current cursor line', function()
      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      anti_conceal.attach(bufnr)

      assert.are.equal(0, anti_conceal.get_cursor_line(bufnr))
    end)
  end)

  describe('update_cursor_line', function()
    it('should update tracked cursor line', function()
      vim.api.nvim_set_current_buf(bufnr)
      anti_conceal.attach(bufnr)

      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      local old_line, new_line = anti_conceal.update_cursor_line(bufnr)

      assert.are.equal(0, old_line)
      assert.are.equal(1, new_line)
    end)

    it('should return nil for unattached buffer', function()
      local old_line, new_line = anti_conceal.update_cursor_line(bufnr)

      assert.is_nil(old_line)
      assert.is_nil(new_line)
    end)

    it('should return same line when cursor did not move', function()
      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      anti_conceal.attach(bufnr)

      local old_line, new_line = anti_conceal.update_cursor_line(bufnr)

      assert.are.equal(0, old_line)
      assert.are.equal(0, new_line)
    end)
  end)

  describe('should_show_raw', function()
    it('should return true for cursor line', function()
      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      anti_conceal.attach(bufnr)

      assert.is_true(anti_conceal.should_show_raw(bufnr, 0))
    end)

    it('should return false for non-cursor lines', function()
      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      anti_conceal.attach(bufnr)

      assert.is_false(anti_conceal.should_show_raw(bufnr, 1))
      assert.is_false(anti_conceal.should_show_raw(bufnr, 2))
    end)

    it('should return false for unattached buffer', function()
      assert.is_false(anti_conceal.should_show_raw(bufnr, 0))
    end)
  end)

  describe('set_render_callback', function()
    it('should store render callback', function()
      anti_conceal.attach(bufnr)
      local callback = function() end

      anti_conceal.set_render_callback(bufnr, callback)

      assert.is_function(anti_conceal.get_render_callback(bufnr))
    end)

    it('should return nil when no callback set', function()
      assert.is_nil(anti_conceal.get_render_callback(bufnr))
    end)

    it('should return nil for unattached buffer', function()
      local callback = function() end
      anti_conceal.set_render_callback(bufnr, callback)

      assert.is_nil(anti_conceal.get_render_callback(bufnr))
    end)
  end)

  describe('on_cursor_moved', function()
    it('should call render callback for old and new lines', function()
      local rendered_lines = {}
      local callback = function(buf, line)
        table.insert(rendered_lines, { buf = buf, line = line })
      end

      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      anti_conceal.attach(bufnr)
      anti_conceal.set_render_callback(bufnr, callback)

      -- Move cursor to line 2
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      anti_conceal.on_cursor_moved(bufnr)

      -- Should have rendered both old line (0) and new line (1)
      assert.are.equal(2, #rendered_lines)
    end)

    it('should not call callback when cursor stays on same line', function()
      local call_count = 0
      local callback = function()
        call_count = call_count + 1
      end

      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      anti_conceal.attach(bufnr)
      anti_conceal.set_render_callback(bufnr, callback)

      -- Move cursor within same line
      vim.api.nvim_win_set_cursor(0, { 1, 5 })
      anti_conceal.on_cursor_moved(bufnr)

      assert.are.equal(0, call_count)
    end)
  end)

  describe('reset', function()
    it('should clear all state', function()
      anti_conceal.attach(bufnr)
      anti_conceal.set_render_callback(bufnr, function() end)

      anti_conceal.reset()

      assert.is_false(anti_conceal.is_attached(bufnr))
      assert.is_nil(anti_conceal.get_render_callback(bufnr))
    end)
  end)

  describe('list_attached', function()
    it('should return empty table when nothing attached', function()
      local attached = anti_conceal.list_attached()

      assert.are.equal(0, #attached)
    end)

    it('should return list of attached buffers', function()
      local bufnr2 = vim.api.nvim_create_buf(false, true)
      anti_conceal.attach(bufnr)
      anti_conceal.attach(bufnr2)

      local attached = anti_conceal.list_attached()

      assert.are.equal(2, #attached)
      vim.api.nvim_buf_delete(bufnr2, { force = true })
    end)
  end)
end)
