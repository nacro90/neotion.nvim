---@diagnostic disable: undefined-field
describe('neotion.input.keymaps', function()
  local keymaps

  before_each(function()
    package.loaded['neotion.input.keymaps'] = nil
    keymaps = require('neotion.input.keymaps')
  end)

  describe('defaults', function()
    it('should have bold keymap', function()
      assert.is_not_nil(keymaps.defaults.bold)
      assert.are.equal('<C-b>', keymaps.defaults.bold.lhs)
      assert.are.equal('<Plug>(NeotionBold)', keymaps.defaults.bold.rhs)
    end)

    it('should have italic keymap', function()
      assert.is_not_nil(keymaps.defaults.italic)
      assert.are.equal('<C-i>', keymaps.defaults.italic.lhs)
    end)

    it('should have italic_alt keymap for terminal compatibility', function()
      assert.is_not_nil(keymaps.defaults.italic_alt)
      assert.are.equal('<M-i>', keymaps.defaults.italic_alt.lhs)
    end)

    it('should have underline keymap', function()
      assert.is_not_nil(keymaps.defaults.underline)
      assert.are.equal('<C-u>', keymaps.defaults.underline.lhs)
    end)

    it('should have strikethrough keymap', function()
      assert.is_not_nil(keymaps.defaults.strikethrough)
      assert.are.equal('<C-s>', keymaps.defaults.strikethrough.lhs)
    end)

    it('should have code keymap', function()
      assert.is_not_nil(keymaps.defaults.code)
    end)

    it('should have visual mode keymaps', function()
      assert.is_not_nil(keymaps.defaults.bold_visual)
      assert.are.equal('x', keymaps.defaults.bold_visual.modes)
    end)

    it('should have insert mode pair keymaps', function()
      assert.is_not_nil(keymaps.defaults.bold_insert)
      assert.are.equal('i', keymaps.defaults.bold_insert.modes)
    end)

    it('should include description for each keymap', function()
      for name, def in pairs(keymaps.defaults) do
        assert.is_string(def.desc, 'Missing desc for keymap: ' .. name)
      end
    end)
  end)

  describe('setup_buffer', function()
    local bufnr

    before_each(function()
      bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(bufnr)
    end)

    after_each(function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end)

    it('should set buffer-local keymaps', function()
      keymaps.setup_buffer(bufnr, {})

      -- Check if bold keymap was set
      local maps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
      local found_bold = false
      for _, map in ipairs(maps) do
        if map.lhs == '<C-B>' or map.lhs == '<C-b>' then
          found_bold = true
          break
        end
      end
      assert.is_true(found_bold, 'Bold keymap should be set')
    end)

    it('should respect enabled_keymaps config - disable specific', function()
      keymaps.setup_buffer(bufnr, { bold = false })

      local maps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
      local found_bold = false
      for _, map in ipairs(maps) do
        if map.lhs == '<C-B>' or map.lhs == '<C-b>' then
          found_bold = true
          break
        end
      end
      assert.is_false(found_bold, 'Bold keymap should NOT be set when disabled')
    end)

    it('should set visual mode keymaps', function()
      keymaps.setup_buffer(bufnr, {})

      local maps = vim.api.nvim_buf_get_keymap(bufnr, 'x')
      local found_visual = false
      for _, map in ipairs(maps) do
        if map.lhs == '<C-B>' or map.lhs == '<C-b>' then
          found_visual = true
          break
        end
      end
      assert.is_true(found_visual, 'Visual bold keymap should be set')
    end)

    it('should set insert mode keymaps', function()
      keymaps.setup_buffer(bufnr, {})

      local maps = vim.api.nvim_buf_get_keymap(bufnr, 'i')
      local found_insert = false
      for _, map in ipairs(maps) do
        if map.lhs == '<C-B>' or map.lhs == '<C-b>' then
          found_insert = true
          break
        end
      end
      assert.is_true(found_insert, 'Insert bold keymap should be set')
    end)
  end)

  describe('get_keymap_list', function()
    it('should return list of all keymaps', function()
      local list = keymaps.get_keymap_list()

      assert.is_table(list)
      assert.is_true(#list > 0)
    end)

    it('should include name in each entry', function()
      local list = keymaps.get_keymap_list()

      for _, entry in ipairs(list) do
        assert.is_string(entry.name)
      end
    end)
  end)
end)
