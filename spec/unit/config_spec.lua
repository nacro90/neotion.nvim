local config = require('neotion.config')

describe('neotion.config', function()
  before_each(function()
    config.reset()
  end)

  describe('defaults', function()
    it('should have sensible defaults', function()
      local cfg = config.get()
      assert.is_nil(cfg.api_token)
      assert.equals(2000, cfg.sync_interval)
      assert.is_true(cfg.auto_sync)
      assert.equals(2, cfg.conceal_level)
      assert.equals('info', cfg.log_level)
    end)

    it('should have default icons', function()
      local icons = config.get().icons
      assert.equals('✓', icons.synced)
      assert.equals('○', icons.pending)
      assert.equals('✗', icons.error)
      assert.equals('▼', icons.toggle_open)
      assert.equals('▶', icons.toggle_closed)
    end)

    it('should have default keymaps', function()
      local keymaps = config.get().keymaps
      assert.equals('<leader>ns', keymaps.sync)
      assert.equals('<leader>np', keymaps.push)
      assert.equals('<leader>nl', keymaps.pull)
    end)
  end)

  describe('validate', function()
    it('should accept valid config with api_token', function()
      local ok, err = config.validate({
        api_token = 'secret_abcdef123456',
      })
      assert.is_true(ok)
      assert.is_nil(err)
    end)

    it('should accept empty config', function()
      local ok, err = config.validate({})
      assert.is_true(ok)
      assert.is_nil(err)
    end)

    it('should accept valid sync_interval', function()
      local ok, err = config.validate({
        sync_interval = 3000,
      })
      assert.is_true(ok)
      assert.is_nil(err)
    end)

    it('should reject sync_interval below minimum', function()
      local ok, err = config.validate({
        sync_interval = 50,
      })
      assert.is_false(ok)
      assert.is_not_nil(err)
    end)

    it('should reject sync_interval above maximum', function()
      local ok, err = config.validate({
        sync_interval = 100000,
      })
      assert.is_false(ok)
      assert.is_not_nil(err)
    end)

    it('should reject invalid sync_interval type', function()
      local ok, err = config.validate({
        sync_interval = 'fast',
      })
      assert.is_false(ok)
      assert.is_not_nil(err)
    end)

    it('should accept valid conceal_level', function()
      for level = 0, 3 do
        local ok, err = config.validate({
          conceal_level = level,
        })
        assert.is_true(ok)
        assert.is_nil(err)
      end
    end)

    it('should reject invalid conceal_level', function()
      local ok, err = config.validate({
        conceal_level = 5,
      })
      assert.is_false(ok)
      assert.is_not_nil(err)
    end)

    it('should accept valid log_level', function()
      local valid_levels = { 'debug', 'info', 'warn', 'error', 'off' }
      for _, level in ipairs(valid_levels) do
        local ok, err = config.validate({
          log_level = level,
        })
        assert.is_true(ok, 'Expected ' .. level .. ' to be valid, got error: ' .. tostring(err))
        assert.is_nil(err)
      end
    end)

    it('should reject invalid log_level', function()
      local ok, err = config.validate({
        log_level = 'verbose',
      })
      assert.is_false(ok)
      assert.is_not_nil(err)
    end)

    it('should accept valid icons table', function()
      local ok, err = config.validate({
        icons = {
          synced = '✔',
          pending = '…',
        },
      })
      assert.is_true(ok)
      assert.is_nil(err)
    end)

    it('should accept valid keymaps table', function()
      local ok, err = config.validate({
        keymaps = {
          sync = '<leader>ss',
          push = false, -- disabled
        },
      })
      assert.is_true(ok)
      assert.is_nil(err)
    end)
  end)

  describe('setup', function()
    it('should merge user options with defaults', function()
      local ok, err = config.setup({
        api_token = 'secret_test',
        sync_interval = 5000,
      })
      assert.is_true(ok)
      assert.is_nil(err)

      local cfg = config.get()
      assert.equals('secret_test', cfg.api_token)
      assert.equals(5000, cfg.sync_interval)
      assert.is_true(cfg.auto_sync) -- default preserved
    end)

    it('should deep merge nested tables', function()
      local ok, _ = config.setup({
        icons = {
          synced = '✔',
        },
      })
      assert.is_true(ok)

      local cfg = config.get()
      assert.equals('✔', cfg.icons.synced)
      assert.equals('○', cfg.icons.pending) -- default preserved
    end)

    it('should return error for invalid config', function()
      local ok, err = config.setup({
        sync_interval = 'invalid',
      })
      assert.is_false(ok)
      assert.is_not_nil(err)
    end)
  end)

  describe('reset', function()
    it('should restore defaults', function()
      config.setup({
        api_token = 'secret_test',
        sync_interval = 5000,
      })

      config.reset()

      local cfg = config.get()
      assert.is_nil(cfg.api_token)
      assert.equals(2000, cfg.sync_interval)
    end)
  end)

  describe('vim.g.neotion', function()
    it('should work without setup() call', function()
      -- Config should be accessible without calling setup
      local cfg = config.get()
      assert.is_table(cfg)
      assert.equals(2000, cfg.sync_interval)
    end)
  end)
end)
