describe('neotion.buffer', function()
  local buffer

  before_each(function()
    -- Clean up any existing neotion buffers first
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name:match('neotion://') then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end

    -- Reload module fresh
    package.loaded['neotion.buffer'] = nil
    buffer = require('neotion.buffer')
  end)

  after_each(function()
    -- Clean up buffers
    for _, bufnr in ipairs(buffer.list()) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  end)

  describe('create', function()
    it('should create a new buffer for page_id', function()
      local bufnr = buffer.create('abc123def456')

      assert.is_number(bufnr)
      assert.is_true(vim.api.nvim_buf_is_valid(bufnr))
    end)

    it('should set buffer filetype to neotion', function()
      local bufnr = buffer.create('abc123def456')

      local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
      assert.are.equal('neotion', ft)
    end)

    it('should set buffer as not modifiable initially', function()
      local bufnr = buffer.create('abc123def456')

      local modifiable = vim.api.nvim_get_option_value('modifiable', { buf = bufnr })
      assert.is_false(modifiable)
    end)

    it('should set buftype to acwrite', function()
      -- Create a fresh buffer with unique id
      local bufnr = buffer.create('unique_buftype_test_' .. os.time())

      -- Need to ensure buffer is still valid before checking option
      assert.is_true(vim.api.nvim_buf_is_valid(bufnr))
      local buftype = vim.bo[bufnr].buftype
      assert.are.equal('acwrite', buftype)
    end)

    it('should return existing buffer for same page_id', function()
      local bufnr1 = buffer.create('abc123def456')
      local bufnr2 = buffer.create('abc123def456')

      assert.are.equal(bufnr1, bufnr2)
    end)

    it('should normalize page_id by removing dashes', function()
      local bufnr1 = buffer.create('abc-123-def-456')
      local bufnr2 = buffer.create('abc123def456')

      assert.are.equal(bufnr1, bufnr2)
    end)

    it('should set buffer name with neotion:// prefix', function()
      local bufnr = buffer.create('abc123def456')

      local name = vim.api.nvim_buf_get_name(bufnr)
      assert.is_truthy(name:match('neotion://'))
    end)
  end)

  describe('find_by_page_id', function()
    it('should find existing buffer by page_id', function()
      local bufnr = buffer.create('test123page')

      local found = buffer.find_by_page_id('test123page')

      assert.are.equal(bufnr, found)
    end)

    it('should return nil for non-existent page_id', function()
      local found = buffer.find_by_page_id('nonexistent')

      assert.is_nil(found)
    end)

    it('should find buffer with normalized id', function()
      buffer.create('abc-123-def')

      local found = buffer.find_by_page_id('abc123def')

      assert.is_not_nil(found)
    end)
  end)

  describe('get_data', function()
    it('should return buffer data', function()
      local bufnr = buffer.create('abc123')

      local data = buffer.get_data(bufnr)

      assert.is_not_nil(data)
      assert.are.equal('abc123', data.page_id)
      assert.are.equal('Loading...', data.page_title)
    end)

    it('should return nil for non-neotion buffer', function()
      local bufnr = vim.api.nvim_create_buf(false, true)

      local data = buffer.get_data(bufnr)

      assert.is_nil(data)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe('update_data', function()
    it('should update buffer data fields', function()
      local bufnr = buffer.create('abc123')

      buffer.update_data(bufnr, { page_title = 'New Title' })

      local data = buffer.get_data(bufnr)
      assert.are.equal('New Title', data.page_title)
    end)

    it('should not fail for non-neotion buffer', function()
      local bufnr = vim.api.nvim_create_buf(false, true)

      -- Should not throw
      buffer.update_data(bufnr, { page_title = 'Test' })

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('should update buffer name when title changes', function()
      local bufnr = buffer.create('abc123')

      buffer.update_data(bufnr, { page_title = 'My Page' })

      local name = vim.api.nvim_buf_get_name(bufnr)
      assert.is_truthy(name:match('My Page'))
    end)
  end)

  describe('set_content', function()
    it('should set buffer lines', function()
      local bufnr = buffer.create('abc123')

      buffer.set_content(bufnr, { 'Line 1', 'Line 2' })

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.equal(2, #lines)
      assert.are.equal('Line 1', lines[1])
      assert.are.equal('Line 2', lines[2])
    end)

    it('should set buffer as not modified after content set', function()
      local bufnr = buffer.create('abc123')

      buffer.set_content(bufnr, { 'Content' })

      local modified = vim.api.nvim_get_option_value('modified', { buf = bufnr })
      assert.is_false(modified)
    end)
  end)

  describe('is_neotion_buffer', function()
    it('should return true for neotion buffer', function()
      local bufnr = buffer.create('abc123')
      vim.api.nvim_set_current_buf(bufnr)

      assert.is_true(buffer.is_neotion_buffer())
    end)

    it('should return false for regular buffer', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(bufnr)

      assert.is_false(buffer.is_neotion_buffer())

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('should check specific buffer when passed', function()
      local neotion_buf = buffer.create('abc123')
      local regular_buf = vim.api.nvim_create_buf(false, true)

      assert.is_true(buffer.is_neotion_buffer(neotion_buf))
      assert.is_false(buffer.is_neotion_buffer(regular_buf))

      vim.api.nvim_buf_delete(regular_buf, { force = true })
    end)
  end)

  describe('list', function()
    it('should return empty array when no neotion buffers', function()
      local buffers = buffer.list()

      assert.are.equal(0, #buffers)
    end)

    it('should return all neotion buffers', function()
      buffer.create('page1')
      buffer.create('page2')
      buffer.create('page3')

      local buffers = buffer.list()

      assert.are.equal(3, #buffers)
    end)
  end)

  describe('status tracking', function()
    it('should initialize with loading status', function()
      local bufnr = buffer.create('test123')

      local data = buffer.get_data(bufnr)
      assert.are.equal('loading', data.status)
    end)

    it('should check is_loading correctly', function()
      local bufnr = buffer.create('test123')

      assert.is_true(buffer.is_loading(bufnr))
    end)

    it('should return false for is_loading on non-neotion buffer', function()
      local bufnr = vim.api.nvim_create_buf(false, true)

      assert.is_false(buffer.is_loading(bufnr))

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('should set status correctly', function()
      local bufnr = buffer.create('test123')

      buffer.set_status(bufnr, 'ready')

      local status = buffer.get_status(bufnr)
      assert.are.equal('ready', status)
    end)

    it('should emit NeotionStatusChanged event on status change', function()
      local bufnr = buffer.create('test123')
      local event_fired = false
      local event_data = nil

      vim.api.nvim_create_autocmd('User', {
        pattern = 'NeotionStatusChanged',
        callback = function(args)
          event_fired = true
          event_data = args.data
        end,
        once = true,
      })

      buffer.set_status(bufnr, 'ready')

      assert.is_true(event_fired)
      assert.are.equal(bufnr, event_data.bufnr)
      assert.are.equal('ready', event_data.status)
    end)

    it('should not emit event when status unchanged', function()
      local bufnr = buffer.create('test123')
      local event_count = 0

      vim.api.nvim_create_autocmd('User', {
        pattern = 'NeotionStatusChanged',
        callback = function()
          event_count = event_count + 1
        end,
      })

      -- First change should emit
      buffer.set_status(bufnr, 'ready')
      -- Same status should not emit
      buffer.set_status(bufnr, 'ready')

      assert.are.equal(1, event_count)
    end)

    it('should get_status return nil for non-neotion buffer', function()
      local bufnr = vim.api.nvim_create_buf(false, true)

      local status = buffer.get_status(bufnr)

      assert.is_nil(status)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('should not fail set_status on non-neotion buffer', function()
      local bufnr = vim.api.nvim_create_buf(false, true)

      -- Should not throw
      buffer.set_status(bufnr, 'ready')

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('should track status transitions correctly', function()
      local bufnr = buffer.create('test123')

      -- Initial: loading
      assert.are.equal('loading', buffer.get_status(bufnr))

      -- Transition to ready
      buffer.set_status(bufnr, 'ready')
      assert.are.equal('ready', buffer.get_status(bufnr))
      assert.is_false(buffer.is_loading(bufnr))

      -- Transition to modified
      buffer.set_status(bufnr, 'modified')
      assert.are.equal('modified', buffer.get_status(bufnr))

      -- Transition to syncing
      buffer.set_status(bufnr, 'syncing')
      assert.are.equal('syncing', buffer.get_status(bufnr))

      -- Transition to error
      buffer.set_status(bufnr, 'error')
      assert.are.equal('error', buffer.get_status(bufnr))
    end)
  end)

  describe('recent pages tracking', function()
    before_each(function()
      buffer.clear_recent()
    end)

    it('should return empty array initially', function()
      local recent = buffer.get_recent()
      assert.are.equal(0, #recent)
    end)

    it('should add page to recent list', function()
      buffer.add_recent('abc123', 'Test Page', '📝', 'workspace')

      local recent = buffer.get_recent()
      assert.are.equal(1, #recent)
      assert.are.equal('abc123', recent[1].page_id)
      assert.are.equal('Test Page', recent[1].title)
      assert.are.equal('📝', recent[1].icon)
      assert.are.equal('workspace', recent[1].parent_type)
    end)

    it('should add accessed_at timestamp', function()
      buffer.add_recent('abc123', 'Test Page')

      local recent = buffer.get_recent()
      assert.is_number(recent[1].accessed_at)
    end)

    it('should move existing page to front', function()
      buffer.add_recent('page1', 'Page 1')
      buffer.add_recent('page2', 'Page 2')
      buffer.add_recent('page1', 'Page 1 Updated')

      local recent = buffer.get_recent()
      assert.are.equal(2, #recent)
      assert.are.equal('page1', recent[1].page_id)
      assert.are.equal('Page 1 Updated', recent[1].title)
      assert.are.equal('page2', recent[2].page_id)
    end)

    it('should normalize page_id', function()
      buffer.add_recent('abc-123-def', 'Test')

      local recent = buffer.get_recent()
      assert.are.equal('abc123def', recent[1].page_id)
    end)

    it('should limit to MAX_RECENT pages', function()
      -- Add 25 pages
      for i = 1, 25 do
        buffer.add_recent('page' .. i, 'Page ' .. i)
      end

      local recent = buffer.get_recent()
      assert.are.equal(20, #recent) -- MAX_RECENT is 20
      assert.are.equal('page25', recent[1].page_id) -- Most recent first
    end)

    it('should clear recent list', function()
      buffer.add_recent('page1', 'Page 1')
      buffer.add_recent('page2', 'Page 2')

      buffer.clear_recent()

      local recent = buffer.get_recent()
      assert.are.equal(0, #recent)
    end)
  end)
end)
