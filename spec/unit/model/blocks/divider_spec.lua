describe('neotion.model.blocks.divider', function()
  local divider_module

  before_each(function()
    package.loaded['neotion.model.blocks.divider'] = nil
    package.loaded['neotion.model.block'] = nil
    divider_module = require('neotion.model.blocks.divider')
  end)

  describe('DividerBlock.new', function()
    it('should create a divider from raw JSON', function()
      local raw = {
        id = 'div123',
        type = 'divider',
        divider = {},
      }

      local block = divider_module.new(raw)

      assert.are.equal('div123', block:get_id())
      assert.are.equal('divider', block:get_type())
    end)

    it('should be marked as NOT editable', function()
      local raw = {
        id = 'test',
        type = 'divider',
        divider = {},
      }

      local block = divider_module.new(raw)

      assert.is_false(block:is_editable())
    end)

    it('should handle missing divider field', function()
      local raw = {
        id = 'test',
        type = 'divider',
      }

      local block = divider_module.new(raw)

      assert.are.equal('divider', block:get_type())
    end)
  end)

  describe('DividerBlock:format', function()
    it('should return single line with ---', function()
      local raw = {
        id = 'test',
        type = 'divider',
        divider = {},
      }

      local block = divider_module.new(raw)
      local lines = block:format()

      assert.are.equal(1, #lines)
      assert.are.equal('---', lines[1])
    end)

    it('should ignore indent options', function()
      local raw = {
        id = 'test',
        type = 'divider',
        divider = {},
      }

      local block = divider_module.new(raw)
      local lines = block:format({ indent = 2, indent_size = 4 })

      -- Divider doesn't support indentation
      assert.are.equal('---', lines[1])
    end)
  end)

  describe('DividerBlock:serialize', function()
    it('should return original raw JSON unchanged', function()
      local raw = {
        id = 'test',
        type = 'divider',
        divider = {},
        created_time = '2024-01-01',
        last_edited_time = '2024-01-02',
      }

      local block = divider_module.new(raw)
      local result = block:serialize()

      assert.are.same(raw, result)
    end)
  end)

  describe('DividerBlock:update_from_lines', function()
    it('should be a no-op (divider is not editable)', function()
      local raw = {
        id = 'test',
        type = 'divider',
        divider = {},
      }

      local block = divider_module.new(raw)
      block:update_from_lines({ 'anything', 'can be here' })

      -- Should not crash or change anything
      assert.is_false(block:is_dirty())
    end)
  end)

  describe('DividerBlock:get_text', function()
    it('should return empty string', function()
      local raw = {
        id = 'test',
        type = 'divider',
        divider = {},
      }

      local block = divider_module.new(raw)

      assert.are.equal('', block:get_text())
    end)
  end)

  describe('DividerBlock:matches_content', function()
    it('should always return true (content is fixed)', function()
      local raw = {
        id = 'test',
        type = 'divider',
        divider = {},
      }

      local block = divider_module.new(raw)

      assert.is_true(block:matches_content({ '---' }))
      assert.is_true(block:matches_content({ '***' }))
      assert.is_true(block:matches_content({ 'anything' }))
    end)
  end)

  describe('DividerBlock:render', function()
    it('should apply overlay_line and return true when line is ---', function()
      local raw = {
        id = 'test',
        type = 'divider',
        divider = {},
      }

      local block = divider_module.new(raw)

      -- Create real buffer with divider content
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '---' })

      -- Create mock RenderContext with real buffer
      local overlay_called = false
      local overlay_args = {}
      local mock_ctx = {
        bufnr = bufnr,
        line = 0, -- 0-indexed
        overlay_line = function(self, char, hl_group)
          overlay_called = true
          overlay_args = { char = char, hl_group = hl_group }
        end,
      }

      local handled = block:render(mock_ctx)

      assert.is_true(handled)
      assert.is_true(overlay_called)
      assert.are.equal('─', overlay_args.char)
      assert.are.equal('NeotionDivider', overlay_args.hl_group)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('should return false when line content is not ---', function()
      local raw = {
        id = 'test',
        type = 'divider',
        divider = {},
      }

      local block = divider_module.new(raw)

      -- Create real buffer with different content
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'not a divider' })

      -- Create mock RenderContext
      local overlay_called = false
      local mock_ctx = {
        bufnr = bufnr,
        line = 0,
        overlay_line = function(self, char, hl_group)
          overlay_called = true
        end,
      }

      local handled = block:render(mock_ctx)

      assert.is_false(handled)
      assert.is_false(overlay_called)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('should return false when line is empty', function()
      local raw = {
        id = 'test',
        type = 'divider',
        divider = {},
      }

      local block = divider_module.new(raw)

      -- Create real buffer with empty content
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

      local mock_ctx = {
        bufnr = bufnr,
        line = 0,
        overlay_line = function() end,
      }

      local handled = block:render(mock_ctx)

      assert.is_false(handled)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe('DividerBlock:has_children', function()
    it('should return false', function()
      local raw = {
        id = 'test',
        type = 'divider',
        divider = {},
        has_children = false,
      }

      local block = divider_module.new(raw)

      assert.is_false(block:has_children())
    end)
  end)

  describe('M.is_editable', function()
    it('should return false', function()
      assert.is_false(divider_module.is_editable())
    end)
  end)
end)
