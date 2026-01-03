describe('neotion.input.triggers', function()
  local triggers

  before_each(function()
    package.loaded['neotion.input.triggers'] = nil
    triggers = require('neotion.input.triggers')
  end)

  describe('module interface', function()
    it('should expose setup function', function()
      assert.is_function(triggers.setup)
    end)

    it('should expose register function', function()
      assert.is_function(triggers.register)
    end)

    it('should expose unregister function', function()
      assert.is_function(triggers.unregister)
    end)

    it('should expose triggers table', function()
      assert.is_table(triggers.triggers)
    end)
  end)

  describe('register', function()
    it('should register a trigger', function()
      local handler = function() end
      triggers.register('/', handler, { description = 'Slash commands' })

      assert.is_not_nil(triggers.triggers['/'])
      assert.are.equal('/', triggers.triggers['/'].char)
      assert.are.equal(handler, triggers.triggers['/'].handler)
      assert.is_true(triggers.triggers['/'].enabled)
    end)

    it('should register with enabled = false', function()
      local handler = function() end
      triggers.register('@', handler, { enabled = false })

      assert.is_not_nil(triggers.triggers['@'])
      assert.is_false(triggers.triggers['@'].enabled)
    end)
  end)

  describe('unregister', function()
    it('should remove a registered trigger', function()
      triggers.register('/', function() end)
      triggers.unregister('/')

      assert.is_nil(triggers.triggers['/'])
    end)

    it('should not error when unregistering non-existent trigger', function()
      assert.has_no.errors(function()
        triggers.unregister('nonexistent')
      end)
    end)
  end)

  describe('setup', function()
    it('should not error when called with buffer number', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      assert.has_no.errors(function()
        triggers.setup(bufnr)
      end)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)
end)
