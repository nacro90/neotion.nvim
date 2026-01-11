describe('neotion.model.blocks.child_page', function()
  local child_page_module

  before_each(function()
    package.loaded['neotion.model.blocks.child_page'] = nil
    package.loaded['neotion.model.block'] = nil
    child_page_module = require('neotion.model.blocks.child_page')
  end)

  describe('ChildPageBlock.new', function()
    it('should create a child page from raw JSON', function()
      local raw = {
        id = 'page123',
        type = 'child_page',
        child_page = {
          title = 'My Sub Page',
        },
      }

      local block = child_page_module.new(raw)

      assert.are.equal('page123', block:get_id())
      assert.are.equal('child_page', block:get_type())
      assert.are.equal('My Sub Page', block.title)
      assert.are.equal('page123', block:get_page_id())
    end)

    it('should be marked as NOT editable', function()
      local raw = {
        id = 'test',
        type = 'child_page',
        child_page = {
          title = 'Test Page',
        },
      }

      local block = child_page_module.new(raw)

      assert.is_false(block:is_editable())
    end)

    it('should handle missing title with default', function()
      local raw = {
        id = 'test',
        type = 'child_page',
        child_page = {},
      }

      local block = child_page_module.new(raw)

      assert.are.equal('Untitled', block.title)
    end)

    it('should handle missing child_page field', function()
      local raw = {
        id = 'test',
        type = 'child_page',
      }

      local block = child_page_module.new(raw)

      assert.are.equal('child_page', block:get_type())
      assert.are.equal('Untitled', block.title)
    end)
  end)

  describe('ChildPageBlock:format', function()
    it('should return single line with icon and title', function()
      local raw = {
        id = 'test',
        type = 'child_page',
        child_page = {
          title = 'My Page',
        },
      }

      local block = child_page_module.new(raw)
      local lines = block:format()

      assert.are.equal(1, #lines)
      assert.are.equal('📄 My Page', lines[1])
    end)

    it('should respect indent options', function()
      local raw = {
        id = 'test',
        type = 'child_page',
        child_page = {
          title = 'Nested Page',
        },
      }

      local block = child_page_module.new(raw)
      local lines = block:format({ indent = 1, indent_size = 2 })

      assert.are.equal('  📄 Nested Page', lines[1])
    end)

    it('should handle empty title with Untitled fallback', function()
      local raw = {
        id = 'test',
        type = 'child_page',
        child_page = {
          title = '',
        },
      }

      local block = child_page_module.new(raw)
      local lines = block:format()

      assert.are.equal('📄 Untitled', lines[1])
    end)
  end)

  describe('ChildPageBlock:serialize', function()
    it('should return original raw JSON unchanged', function()
      local raw = {
        id = 'test',
        type = 'child_page',
        child_page = {
          title = 'My Page',
        },
        created_time = '2024-01-01',
        last_edited_time = '2024-01-02',
      }

      local block = child_page_module.new(raw)
      local result = block:serialize()

      assert.are.same(raw, result)
    end)
  end)

  describe('ChildPageBlock:update_from_lines', function()
    it('should be a no-op (child_page is not editable)', function()
      local raw = {
        id = 'test',
        type = 'child_page',
        child_page = {
          title = 'Original Title',
        },
      }

      local block = child_page_module.new(raw)
      block:update_from_lines({ '📄 Different Title' })

      -- Should not crash or change anything
      assert.is_false(block:is_dirty())
      assert.are.equal('Original Title', block.title)
    end)
  end)

  describe('ChildPageBlock:get_text', function()
    it('should return the title', function()
      local raw = {
        id = 'test',
        type = 'child_page',
        child_page = {
          title = 'Page Title',
        },
      }

      local block = child_page_module.new(raw)

      assert.are.equal('Page Title', block:get_text())
    end)
  end)

  describe('ChildPageBlock:matches_content', function()
    it('should return true when content matches', function()
      local raw = {
        id = 'test',
        type = 'child_page',
        child_page = {
          title = 'My Page',
        },
      }

      local block = child_page_module.new(raw)

      assert.is_true(block:matches_content({ '📄 My Page' }))
    end)

    it('should return true with leading whitespace', function()
      local raw = {
        id = 'test',
        type = 'child_page',
        child_page = {
          title = 'My Page',
        },
      }

      local block = child_page_module.new(raw)

      assert.is_true(block:matches_content({ '  📄 My Page' }))
    end)

    it('should return false when content does not match', function()
      local raw = {
        id = 'test',
        type = 'child_page',
        child_page = {
          title = 'My Page',
        },
      }

      local block = child_page_module.new(raw)

      assert.is_false(block:matches_content({ '📄 Different Page' }))
    end)

    it('should return false for empty lines', function()
      local raw = {
        id = 'test',
        type = 'child_page',
        child_page = {
          title = 'My Page',
        },
      }

      local block = child_page_module.new(raw)

      assert.is_false(block:matches_content({}))
    end)
  end)

  describe('ChildPageBlock:render', function()
    it('should apply highlight and return true when line matches', function()
      local raw = {
        id = 'test',
        type = 'child_page',
        child_page = {
          title = 'My Page',
        },
      }

      local block = child_page_module.new(raw)

      -- Create real buffer with child page content
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '📄 My Page' })

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
      assert.are.equal('NeotionChildPage', highlight_args.hl_group)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('should return false when line does not match', function()
      local raw = {
        id = 'test',
        type = 'child_page',
        child_page = {
          title = 'My Page',
        },
      }

      local block = child_page_module.new(raw)

      -- Create real buffer with different content
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'not a child page' })

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
        type = 'child_page',
        child_page = {
          title = 'My Page',
        },
      }

      local block = child_page_module.new(raw)

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

  describe('ChildPageBlock:get_gutter_icon', function()
    it('should return navigation arrow icon', function()
      local raw = {
        id = 'test',
        type = 'child_page',
        child_page = {
          title = 'My Page',
        },
      }

      local block = child_page_module.new(raw)

      assert.are.equal('->', block:get_gutter_icon())
    end)
  end)

  describe('ChildPageBlock:get_page_id', function()
    it('should return the block ID as page ID', function()
      local raw = {
        id = 'abc123def456',
        type = 'child_page',
        child_page = {
          title = 'My Page',
        },
      }

      local block = child_page_module.new(raw)

      assert.are.equal('abc123def456', block:get_page_id())
    end)
  end)

  describe('ChildPageBlock:has_children', function()
    it('should return false (child_page content is accessed by navigating)', function()
      local raw = {
        id = 'test',
        type = 'child_page',
        child_page = {
          title = 'My Page',
        },
        has_children = true, -- Even if API says it has children
      }

      local block = child_page_module.new(raw)

      -- Child page blocks don't render their children inline
      -- Users navigate to see content
      assert.is_false(block:has_children())
    end)
  end)

  describe('M.is_editable', function()
    it('should return false', function()
      assert.is_false(child_page_module.is_editable())
    end)
  end)
end)
