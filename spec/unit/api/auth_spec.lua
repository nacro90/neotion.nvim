describe('neotion.api.auth', function()
  local auth
  local config

  before_each(function()
    -- Reset vim.g.neotion first (before any module load)
    vim.g.neotion = nil

    -- Reset env var
    vim.env.NOTION_API_TOKEN = nil

    -- Fully unload modules
    package.loaded['neotion.api.auth'] = nil
    package.loaded['neotion.config'] = nil

    -- Reload modules fresh - config first, then reset, then auth
    config = require('neotion.config')
    config.reset()
    auth = require('neotion.api.auth')
  end)

  describe('get_token', function()
    it('should return token from config when set via setup', function()
      config.setup({ api_token = 'secret_test123' })

      local result = auth.get_token()

      assert.is_not_nil(result.token)
      assert.are.equal('secret_test123', result.token)
      assert.are.equal('config', result.source)
      assert.is_nil(result.error)
    end)

    it('should return token from vim.g.neotion when config not set', function()
      -- Set vim.g.neotion BEFORE config is loaded
      vim.g.neotion = { api_token = 'secret_from_g' }

      -- Reload config to pick up vim.g.neotion
      package.loaded['neotion.config'] = nil
      package.loaded['neotion.api.auth'] = nil
      auth = require('neotion.api.auth')

      local result = auth.get_token()

      -- Token comes from config which loaded it from vim.g.neotion
      assert.are.equal('secret_from_g', result.token)
      assert.are.equal('config', result.source) -- config loaded it from vim.g.neotion
      assert.is_nil(result.error)
    end)

    it('should return token from env var as last resort', function()
      -- Set env var BEFORE config is loaded
      vim.env.NOTION_API_TOKEN = 'secret_from_env'

      -- Reload config to pick up env var
      package.loaded['neotion.config'] = nil
      package.loaded['neotion.api.auth'] = nil
      auth = require('neotion.api.auth')

      local result = auth.get_token()

      -- Token comes from config which loaded it from env var
      assert.are.equal('secret_from_env', result.token)
      assert.are.equal('config', result.source) -- config loaded it from env var
      assert.is_nil(result.error)
    end)

    it('should prioritize config over vim.g.neotion', function()
      vim.g.neotion = { api_token = 'secret_from_g' }
      config.setup({ api_token = 'secret_from_config' })

      local result = auth.get_token()

      assert.are.equal('secret_from_config', result.token)
      assert.are.equal('config', result.source)
    end)

    it('should prioritize vim.g.neotion over env var', function()
      -- Set both BEFORE config is loaded
      vim.env.NOTION_API_TOKEN = 'secret_from_env'
      vim.g.neotion = { api_token = 'secret_from_g' }

      -- Reload config
      package.loaded['neotion.config'] = nil
      package.loaded['neotion.api.auth'] = nil
      auth = require('neotion.api.auth')

      local result = auth.get_token()

      -- vim.g.neotion should take priority over env var
      assert.are.equal('secret_from_g', result.token)
      assert.are.equal('config', result.source) -- config loaded it from vim.g.neotion
    end)

    it('should return error when no token available', function()
      local result = auth.get_token()

      assert.is_nil(result.token)
      assert.is_nil(result.source)
      assert.is_not_nil(result.error)
      assert.is_truthy(result.error:match('No API token found'))
    end)

    it('should treat empty string as no token', function()
      vim.g.neotion = { api_token = '' }

      local result = auth.get_token()

      assert.is_nil(result.token)
      assert.is_not_nil(result.error)
    end)
  end)

  describe('has_token', function()
    it('should return true when token is available', function()
      vim.g.neotion = { api_token = 'secret_test' }

      assert.is_true(auth.has_token())
    end)

    it('should return false when no token', function()
      assert.is_false(auth.has_token())
    end)
  end)

  describe('validate_token_format', function()
    it('should accept tokens starting with secret_', function()
      local valid, err = auth.validate_token_format('secret_abc123xyz')

      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it('should accept tokens starting with ntn_', function()
      local valid, err = auth.validate_token_format('ntn_abc123xyz')

      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it('should reject empty token', function()
      local valid, err = auth.validate_token_format('')

      assert.is_false(valid)
      assert.are.equal('Token is empty', err)
    end)

    it('should reject nil token', function()
      local valid, err = auth.validate_token_format(nil)

      assert.is_false(valid)
      assert.are.equal('Token is empty', err)
    end)

    it('should reject token with wrong prefix', function()
      local valid, err = auth.validate_token_format('invalid_token_format')

      assert.is_false(valid)
      assert.is_truthy(err:match('should start with'))
    end)
  end)
end)
