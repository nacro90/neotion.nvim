describe('neotion.commands.formatting', function()
  local formatting

  before_each(function()
    package.loaded['neotion.commands.formatting'] = nil
    package.loaded['neotion.input.shortcuts'] = nil
    formatting = require('neotion.commands.formatting')
  end)

  describe('module interface', function()
    it('should expose subcommands table', function()
      assert.is_table(formatting.subcommands)
    end)

    it('should have bold subcommand', function()
      assert.is_function(formatting.subcommands.bold)
    end)

    it('should have italic subcommand', function()
      assert.is_function(formatting.subcommands.italic)
    end)

    it('should have strikethrough subcommand', function()
      assert.is_function(formatting.subcommands.strikethrough)
    end)

    it('should have code subcommand', function()
      assert.is_function(formatting.subcommands.code)
    end)

    it('should have underline subcommand', function()
      assert.is_function(formatting.subcommands.underline)
    end)

    it('should have color subcommand', function()
      assert.is_function(formatting.subcommands.color)
    end)

    it('should have unformat subcommand', function()
      assert.is_function(formatting.subcommands.unformat)
    end)
  end)

  describe('get_subcommand_names', function()
    it('should return list of subcommand names', function()
      local names = formatting.get_subcommand_names()
      assert.is_table(names)
      assert.is_true(vim.tbl_contains(names, 'bold'))
      assert.is_true(vim.tbl_contains(names, 'italic'))
      assert.is_true(vim.tbl_contains(names, 'color'))
      assert.is_true(vim.tbl_contains(names, 'unformat'))
    end)
  end)

  describe('color_names', function()
    it('should return list of valid colors', function()
      local colors = formatting.color_names
      assert.is_table(colors)
      assert.is_true(vim.tbl_contains(colors, 'red'))
      assert.is_true(vim.tbl_contains(colors, 'blue'))
      assert.is_true(vim.tbl_contains(colors, 'green'))
    end)
  end)
end)
