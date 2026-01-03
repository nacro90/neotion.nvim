describe('neotion.input', function()
  local input

  before_each(function()
    package.loaded['neotion.input'] = nil
    package.loaded['neotion.input.shortcuts'] = nil
    package.loaded['neotion.input.triggers'] = nil
    input = require('neotion.input')
  end)

  describe('module interface', function()
    it('should expose setup function', function()
      assert.is_function(input.setup)
    end)

    it('should expose shortcuts module', function()
      assert.is_table(input.shortcuts)
    end)
  end)

  describe('setup', function()
    it('should not error when called with buffer number', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      assert.has_no.errors(function()
        input.setup(bufnr)
      end)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('should not error when called with options', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      assert.has_no.errors(function()
        input.setup(bufnr, { shortcuts = { enabled = true } })
      end)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('should skip shortcuts when disabled', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      assert.has_no.errors(function()
        input.setup(bufnr, { shortcuts = { enabled = false } })
      end)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)
end)
