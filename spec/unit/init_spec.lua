local neotion = require('neotion')

describe('neotion', function()
  before_each(function()
    require('neotion.config').reset()
  end)

  describe('setup', function()
    it('should accept configuration via setup()', function()
      neotion.setup({
        api_token = 'secret_test',
      })

      local config = neotion.get_config()
      assert.equals('secret_test', config.api_token)
    end)

    it('should work without arguments', function()
      neotion.setup()
      local config = neotion.get_config()
      assert.is_table(config)
    end)
  end)

  describe('get_config', function()
    it('should return current configuration', function()
      neotion.setup({
        api_token = 'secret_test',
        sync_interval = 3000,
      })

      local config = neotion.get_config()
      assert.equals('secret_test', config.api_token)
      assert.equals(3000, config.sync_interval)
    end)

    it('should work without calling setup()', function()
      -- Config should be accessible without calling setup
      local config = neotion.get_config()
      assert.is_table(config)
      assert.equals(2000, config.sync_interval)
    end)
  end)

  describe('operations', function()
    after_each(function()
      -- Clean up neotion buffers
      for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(bufnr)
        if name:match('neotion://') then
          vim.api.nvim_buf_delete(bufnr, { force = true })
        end
      end
    end)

    it('open should accept valid page_id', function()
      -- Valid 32-char hex page ID
      local valid_id = 'a1b2c3d4e5f6789012345678abcdef00'
      -- Should not error
      neotion.open(valid_id)
    end)

    it('open should accept page_id with dashes', function()
      -- Valid page ID with dashes (UUID format)
      local valid_id = 'a1b2c3d4-e5f6-7890-1234-5678abcdef00'
      -- Should not error
      neotion.open(valid_id)
    end)

    it('sync should not error', function()
      neotion.sync()
    end)

    it('push should not error', function()
      neotion.push()
    end)

    it('pull should not error', function()
      neotion.pull()
    end)
  end)

  describe('page_id validation', function()
    local notify_messages = {}

    before_each(function()
      notify_messages = {}
      -- Capture notify messages
      vim.notify = function(msg, level)
        table.insert(notify_messages, { msg = msg, level = level })
      end
    end)

    after_each(function()
      -- Clean up neotion buffers
      for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(bufnr)
        if name:match('neotion://') then
          vim.api.nvim_buf_delete(bufnr, { force = true })
        end
      end
    end)

    it('should reject page_id that is too short', function()
      neotion.open('abc123')

      assert.are.equal(1, #notify_messages)
      assert.is_truthy(notify_messages[1].msg:match('Invalid page ID'))
      assert.is_truthy(notify_messages[1].msg:match('32 hex characters'))
    end)

    it('should reject page_id that is too long', function()
      neotion.open('a1b2c3d4e5f6789012345678abcdef00extra')

      assert.are.equal(1, #notify_messages)
      assert.is_truthy(notify_messages[1].msg:match('Invalid page ID'))
    end)

    it('should reject page_id with non-hex characters', function()
      neotion.open('g1b2c3d4e5f6789012345678abcdef00') -- 'g' is not hex

      assert.are.equal(1, #notify_messages)
      assert.is_truthy(notify_messages[1].msg:match('Invalid page ID'))
      assert.is_truthy(notify_messages[1].msg:match('hex characters'))
    end)

    it('should accept valid 32-char hex page_id', function()
      neotion.open('a1b2c3d4e5f6789012345678abcdef00')

      -- No error notification (there may be other notifications)
      local has_error = false
      for _, msg in ipairs(notify_messages) do
        if msg.msg:match('Invalid page ID') then
          has_error = true
        end
      end
      assert.is_false(has_error)
    end)

    it('should accept page_id with uppercase hex', function()
      neotion.open('A1B2C3D4E5F6789012345678ABCDEF00')

      local has_error = false
      for _, msg in ipairs(notify_messages) do
        if msg.msg:match('Invalid page ID') then
          has_error = true
        end
      end
      assert.is_false(has_error)
    end)
  end)
end)
