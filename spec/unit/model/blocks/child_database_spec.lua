describe('neotion.model.blocks.child_database', function()
  local child_database_module

  before_each(function()
    package.loaded['neotion.model.blocks.child_database'] = nil
    package.loaded['neotion.model.block'] = nil
    child_database_module = require('neotion.model.blocks.child_database')
  end)

  describe('ChildDatabaseBlock.new', function()
    it('should create a child database from raw JSON', function()
      local raw = {
        id = 'db123',
        type = 'child_database',
        child_database = {
          title = 'My Tasks Database',
        },
      }

      local block = child_database_module.new(raw)

      assert.are.equal('db123', block:get_id())
      assert.are.equal('child_database', block:get_type())
      assert.are.equal('My Tasks Database', block.title)
      assert.are.equal('db123', block:get_database_id())
    end)

    it('should be marked as NOT editable', function()
      local raw = {
        id = 'test',
        type = 'child_database',
        child_database = {
          title = 'Test DB',
        },
      }

      local block = child_database_module.new(raw)

      assert.is_false(block:is_editable())
    end)

    it('should handle missing title with default', function()
      local raw = {
        id = 'test',
        type = 'child_database',
        child_database = {},
      }

      local block = child_database_module.new(raw)

      assert.are.equal('Untitled', block.title)
    end)

    it('should handle missing child_database field', function()
      local raw = {
        id = 'test',
        type = 'child_database',
      }

      local block = child_database_module.new(raw)

      assert.are.equal('child_database', block:get_type())
      assert.are.equal('Untitled', block.title)
    end)
  end)

  describe('ChildDatabaseBlock:format', function()
    it('should return single line with icon and title', function()
      local raw = {
        id = 'test',
        type = 'child_database',
        child_database = {
          title = 'My Database',
        },
      }

      local block = child_database_module.new(raw)
      local lines = block:format()

      assert.are.equal(1, #lines)
      assert.are.equal('\u{f1c0} My Database', lines[1])
    end)

    it('should respect indent options', function()
      local raw = {
        id = 'test',
        type = 'child_database',
        child_database = {
          title = 'Nested Database',
        },
      }

      local block = child_database_module.new(raw)
      local lines = block:format({ indent = 1, indent_size = 2 })

      assert.are.equal('  \u{f1c0} Nested Database', lines[1])
    end)

    it('should handle empty title with Untitled fallback', function()
      local raw = {
        id = 'test',
        type = 'child_database',
        child_database = {
          title = '',
        },
      }

      local block = child_database_module.new(raw)
      local lines = block:format()

      assert.are.equal('\u{f1c0} Untitled', lines[1])
    end)
  end)

  describe('ChildDatabaseBlock:serialize', function()
    it('should return original raw JSON unchanged', function()
      local raw = {
        id = 'test',
        type = 'child_database',
        child_database = {
          title = 'My Database',
        },
        created_time = '2024-01-01',
        last_edited_time = '2024-01-02',
      }

      local block = child_database_module.new(raw)
      local result = block:serialize()

      assert.are.same(raw, result)
    end)
  end)

  describe('ChildDatabaseBlock:update_from_lines', function()
    it('should be a no-op (child_database is not editable)', function()
      local raw = {
        id = 'test',
        type = 'child_database',
        child_database = {
          title = 'Original Title',
        },
      }

      local block = child_database_module.new(raw)
      block:update_from_lines({ '\u{f1c0} Different Title' })

      -- Should not crash or change anything
      assert.is_false(block:is_dirty())
      assert.are.equal('Original Title', block.title)
    end)
  end)

  describe('ChildDatabaseBlock:get_text', function()
    it('should return the title', function()
      local raw = {
        id = 'test',
        type = 'child_database',
        child_database = {
          title = 'Database Title',
        },
      }

      local block = child_database_module.new(raw)

      assert.are.equal('Database Title', block:get_text())
    end)
  end)

  describe('ChildDatabaseBlock:matches_content', function()
    it('should return true when content matches', function()
      local raw = {
        id = 'test',
        type = 'child_database',
        child_database = {
          title = 'My Database',
        },
      }

      local block = child_database_module.new(raw)

      assert.is_true(block:matches_content({ '\u{f1c0} My Database' }))
    end)

    it('should return true with leading whitespace', function()
      local raw = {
        id = 'test',
        type = 'child_database',
        child_database = {
          title = 'My Database',
        },
      }

      local block = child_database_module.new(raw)

      assert.is_true(block:matches_content({ '  \u{f1c0} My Database' }))
    end)

    it('should return false when content does not match', function()
      local raw = {
        id = 'test',
        type = 'child_database',
        child_database = {
          title = 'My Database',
        },
      }

      local block = child_database_module.new(raw)

      assert.is_false(block:matches_content({ '\u{f1c0} Different Database' }))
    end)

    it('should return false for empty lines', function()
      local raw = {
        id = 'test',
        type = 'child_database',
        child_database = {
          title = 'My Database',
        },
      }

      local block = child_database_module.new(raw)

      assert.is_false(block:matches_content({}))
    end)
  end)

  describe('ChildDatabaseBlock:render', function()
    it('should apply highlight and return true when line matches', function()
      local raw = {
        id = 'test',
        type = 'child_database',
        child_database = {
          title = 'My Database',
        },
      }

      local block = child_database_module.new(raw)

      -- Create real buffer with child database content
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '\u{f1c0} My Database' })

      -- Create mock RenderContext
      local highlight_called = false
      local highlight_args = {}
      local mock_ctx = {
        bufnr = bufnr,
        line = 0, -- 0-indexed
        highlight = function(self, start_col, end_col, hl_group)
          highlight_called = true
          highlight_args = { start_col = start_col, end_col = end_col, hl_group = hl_group }
        end,
      }

      local handled = block:render(mock_ctx)

      assert.is_true(handled)
      assert.is_true(highlight_called)
      assert.are.equal('NeotionChildDatabase', highlight_args.hl_group)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('should return false when line does not match', function()
      local raw = {
        id = 'test',
        type = 'child_database',
        child_database = {
          title = 'My Database',
        },
      }

      local block = child_database_module.new(raw)

      -- Create real buffer with different content
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'not a child database' })

      local highlight_called = false
      local mock_ctx = {
        bufnr = bufnr,
        line = 0,
        highlight = function()
          highlight_called = true
        end,
      }

      local handled = block:render(mock_ctx)

      assert.is_false(handled)
      assert.is_false(highlight_called)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('should return false when buffer is empty', function()
      local raw = {
        id = 'test',
        type = 'child_database',
        child_database = {
          title = 'My Database',
        },
      }

      local block = child_database_module.new(raw)

      -- Create empty buffer
      local bufnr = vim.api.nvim_create_buf(false, true)

      local mock_ctx = {
        bufnr = bufnr,
        line = 0,
        highlight = function() end,
      }

      local handled = block:render(mock_ctx)

      assert.is_false(handled)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe('ChildDatabaseBlock:get_gutter_icon', function()
    it('should return navigation arrow icon', function()
      local raw = {
        id = 'test',
        type = 'child_database',
        child_database = {
          title = 'My Database',
        },
      }

      local block = child_database_module.new(raw)

      assert.are.equal('->', block:get_gutter_icon())
    end)
  end)

  describe('ChildDatabaseBlock:get_database_id', function()
    it('should return the block ID as database ID', function()
      local raw = {
        id = 'abc123def456',
        type = 'child_database',
        child_database = {
          title = 'My Database',
        },
      }

      local block = child_database_module.new(raw)

      assert.are.equal('abc123def456', block:get_database_id())
    end)
  end)

  describe('ChildDatabaseBlock:has_children', function()
    it('should return false (child_database content is accessed by navigating)', function()
      local raw = {
        id = 'test',
        type = 'child_database',
        child_database = {
          title = 'My Database',
        },
        has_children = true, -- Even if API says it has children
      }

      local block = child_database_module.new(raw)

      -- Child database blocks don't render their children inline
      -- Users navigate to see content
      assert.is_false(block:has_children())
    end)
  end)

  describe('M.is_editable', function()
    it('should return false', function()
      assert.is_false(child_database_module.is_editable())
    end)
  end)

  describe('ChildDatabaseBlock:set_icon', function()
    it('should set custom icon', function()
      local raw = {
        id = 'test',
        type = 'child_database',
        child_database = { title = 'My Database' },
      }

      local block = child_database_module.new(raw)
      block:set_icon('📊')

      assert.are.equal('📊', block:get_display_icon())
    end)

    it('should allow nil to reset to default', function()
      local raw = {
        id = 'test',
        type = 'child_database',
        child_database = { title = 'My Database' },
      }

      local block = child_database_module.new(raw)
      block:set_icon('📊')
      block:set_icon(nil)

      -- Should fall back to default
      assert.are.equal(child_database_module.DEFAULT_ICON, block:get_display_icon())
    end)
  end)

  describe('ChildDatabaseBlock:get_display_icon', function()
    it('should return default icon when no custom icon set', function()
      local raw = {
        id = 'test',
        type = 'child_database',
        child_database = { title = 'My Database' },
      }

      local block = child_database_module.new(raw)

      assert.are.equal(child_database_module.DEFAULT_ICON, block:get_display_icon())
    end)

    it('should return custom icon when set', function()
      local raw = {
        id = 'test',
        type = 'child_database',
        child_database = { title = 'My Database' },
      }

      local block = child_database_module.new(raw)
      block:set_icon('📈')

      assert.are.equal('📈', block:get_display_icon())
    end)
  end)

  describe('ChildDatabaseBlock:format with custom icon', function()
    it('should use custom icon in formatted output', function()
      local raw = {
        id = 'test',
        type = 'child_database',
        child_database = { title = 'My Database' },
      }

      local block = child_database_module.new(raw)
      block:set_icon('📊')
      local lines = block:format()

      assert.are.equal('📊 My Database', lines[1])
    end)

    it('should use default icon when custom icon not set', function()
      local raw = {
        id = 'test',
        type = 'child_database',
        child_database = { title = 'My Database' },
      }

      local block = child_database_module.new(raw)
      local lines = block:format()

      assert.are.equal('\u{f1c0} My Database', lines[1])
    end)

    it('should respect indent with custom icon', function()
      local raw = {
        id = 'test',
        type = 'child_database',
        child_database = { title = 'Nested Database' },
      }

      local block = child_database_module.new(raw)
      block:set_icon('🗃️')
      local lines = block:format({ indent = 1, indent_size = 2 })

      assert.are.equal('  🗃️ Nested Database', lines[1])
    end)
  end)
end)
