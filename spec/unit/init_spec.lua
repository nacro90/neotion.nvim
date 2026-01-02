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
    it('open should accept page_id', function()
      -- Should not error
      neotion.open('test-page-id')
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
end)
