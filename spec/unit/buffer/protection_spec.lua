describe('neotion.buffer.protection', function()
  local protection
  local mapping
  local bufnr

  -- Helper to create a mock block
  local function create_mock_block(id, block_type, content, editable)
    return {
      id = id,
      type = block_type,
      content = content or '',
      editable = editable ~= false,
      line_start = nil,
      line_end = nil,
      get_id = function(self)
        return self.id
      end,
      get_type = function(self)
        return self.type
      end,
      is_editable = function(self)
        return self.editable
      end,
      set_line_range = function(self, start_line, end_line)
        self.line_start = start_line
        self.line_end = end_line
      end,
      get_line_range = function(self)
        return self.line_start, self.line_end
      end,
      format = function(self)
        if self.type == 'divider' then
          return { '---' }
        else
          return { self.content or '' }
        end
      end,
      matches_content = function(self, lines)
        if self.type == 'divider' then
          return #lines == 1 and lines[1] == '---'
        end
        return true
      end,
    }
  end

  before_each(function()
    -- Clear module caches
    package.loaded['neotion.buffer.protection'] = nil
    package.loaded['neotion.model.mapping'] = nil

    protection = require('neotion.buffer.protection')
    mapping = require('neotion.model.mapping')

    -- Create test buffer
    bufnr = vim.api.nvim_create_buf(false, true)

    -- Reset protection state
    protection._reset()
  end)

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      mapping.clear(bufnr)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  describe('setup', function()
    it('should initialize protection for buffer', function()
      -- Setup buffer with content
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        'Paragraph',
        '---',
        'Another paragraph',
      })

      local blocks = {
        create_mock_block('para1', 'paragraph', 'Paragraph', true),
        create_mock_block('div1', 'divider', '', false),
        create_mock_block('para2', 'paragraph', 'Another paragraph', true),
      }
      blocks[1]:set_line_range(1, 1)
      blocks[2]:set_line_range(2, 2)
      blocks[3]:set_line_range(3, 3)

      mapping.setup(bufnr, blocks)
      protection.setup(bufnr)

      assert.is_true(protection.is_enabled(bufnr))
    end)
  end)

  describe('enable/disable', function()
    it('should disable protection', function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '---' })

      local blocks = { create_mock_block('div1', 'divider', '', false) }
      blocks[1]:set_line_range(1, 1)

      mapping.setup(bufnr, blocks)
      protection.setup(bufnr)

      protection.disable(bufnr)

      assert.is_false(protection.is_enabled(bufnr))
    end)

    it('should re-enable protection', function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '---' })

      local blocks = { create_mock_block('div1', 'divider', '', false) }
      blocks[1]:set_line_range(1, 1)

      mapping.setup(bufnr, blocks)
      protection.setup(bufnr)

      protection.disable(bufnr)
      protection.enable(bufnr)

      assert.is_true(protection.is_enabled(bufnr))
    end)
  end)

  describe('is_enabled', function()
    it('should return false for unprotected buffer', function()
      assert.is_false(protection.is_enabled(bufnr))
    end)

    it('should return true after setup', function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'content' })

      local blocks = { create_mock_block('para1', 'paragraph', 'content', true) }
      blocks[1]:set_line_range(1, 1)

      mapping.setup(bufnr, blocks)
      protection.setup(bufnr)

      assert.is_true(protection.is_enabled(bufnr))
    end)
  end)

  describe('refresh', function()
    it('should update snapshot after block changes', function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '---' })

      local blocks = { create_mock_block('div1', 'divider', '', false) }
      blocks[1]:set_line_range(1, 1)

      mapping.setup(bufnr, blocks)
      protection.setup(bufnr)

      -- Should not throw
      protection.refresh(bufnr)

      assert.is_true(protection.is_enabled(bufnr))
    end)
  end)

  describe('_reset', function()
    it('should clear all protection state', function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'content' })

      local blocks = { create_mock_block('para1', 'paragraph', 'content', true) }
      blocks[1]:set_line_range(1, 1)

      mapping.setup(bufnr, blocks)
      protection.setup(bufnr)

      protection._reset()

      assert.is_false(protection.is_enabled(bufnr))
    end)
  end)
end)
