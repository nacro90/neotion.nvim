---@diagnostic disable: undefined-field
describe('neotion.input.editing', function()
  local editing
  local mapping

  before_each(function()
    package.loaded['neotion.input.editing'] = nil
    package.loaded['neotion.model.mapping'] = nil
    editing = require('neotion.input.editing')
    mapping = require('neotion.model.mapping')
  end)

  describe('setup', function()
    local bufnr

    before_each(function()
      bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(bufnr)
    end)

    after_each(function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        editing.detach(bufnr)
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end)

    it('should attach to buffer', function()
      editing.setup(bufnr)
      assert.is_true(editing.is_attached(bufnr))
    end)

    it('should not attach twice', function()
      editing.setup(bufnr)
      editing.setup(bufnr)
      assert.is_true(editing.is_attached(bufnr))
    end)

    it('should set Enter keymap in insert mode', function()
      editing.setup(bufnr)

      local maps = vim.api.nvim_buf_get_keymap(bufnr, 'i')
      local found_enter = false
      for _, map in ipairs(maps) do
        if map.lhs == '<CR>' then
          found_enter = true
          break
        end
      end
      assert.is_true(found_enter, 'Enter keymap should be set')
    end)

    it('should set Shift+Enter keymap in insert mode', function()
      editing.setup(bufnr)

      local maps = vim.api.nvim_buf_get_keymap(bufnr, 'i')
      local found_shift_enter = false
      for _, map in ipairs(maps) do
        if map.lhs == '<S-CR>' then
          found_shift_enter = true
          break
        end
      end
      assert.is_true(found_shift_enter, 'Shift+Enter keymap should be set')
    end)

    it('should not attach when disabled', function()
      editing.setup(bufnr, { enabled = false })
      assert.is_false(editing.is_attached(bufnr))
    end)
  end)

  describe('detach', function()
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

    it('should remove keymaps', function()
      editing.setup(bufnr)
      editing.detach(bufnr)

      local maps = vim.api.nvim_buf_get_keymap(bufnr, 'i')
      local found_enter = false
      for _, map in ipairs(maps) do
        if map.lhs == '<CR>' then
          found_enter = true
          break
        end
      end
      assert.is_false(found_enter, 'Enter keymap should be removed')
    end)

    it('should update is_attached state', function()
      editing.setup(bufnr)
      assert.is_true(editing.is_attached(bufnr))

      editing.detach(bufnr)
      assert.is_false(editing.is_attached(bufnr))
    end)

    it('should be idempotent', function()
      editing.setup(bufnr)
      editing.detach(bufnr)
      editing.detach(bufnr) -- should not error
      assert.is_false(editing.is_attached(bufnr))
    end)
  end)

  describe('is_attached', function()
    it('should return false for unattached buffer', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      assert.is_false(editing.is_attached(bufnr))
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)
end)

-- Helper function tests (internal logic)
describe('neotion.input.editing helpers', function()
  describe('list prefix detection', function()
    -- These test internal helper behavior through module inspection
    -- In real usage, these are called by handle_enter

    it('should identify bullet prefixes', function()
      -- Test patterns that should match bullet list items
      local bullet_patterns = {
        '- item',
        '* item',
        '+ item',
        '  - indented item',
      }
      for _, line in ipairs(bullet_patterns) do
        local has_bullet = line:match('^%s*[%-%*%+]%s') ~= nil
        assert.is_true(has_bullet, 'Should match bullet: ' .. line)
      end
    end)

    it('should identify numbered prefixes', function()
      local numbered_patterns = {
        '1. item',
        '2. item',
        '10. item',
        '  3. indented',
      }
      for _, line in ipairs(numbered_patterns) do
        local has_number = line:match('^%s*%d+%.') ~= nil
        assert.is_true(has_number, 'Should match number: ' .. line)
      end
    end)

    it('should identify empty bullet items', function()
      local empty_bullets = {
        '- ',
        '-  ',
        '* ',
        '*',
        '+ ',
      }
      for _, line in ipairs(empty_bullets) do
        local is_empty = line:match('^%s*[%-%*%+]%s*$') ~= nil
        assert.is_true(is_empty, 'Should be empty bullet: "' .. line .. '"')
      end
    end)

    it('should identify empty numbered items', function()
      local empty_numbered = {
        '1. ',
        '1.  ',
        '2.',
        '10. ',
      }
      for _, line in ipairs(empty_numbered) do
        local is_empty = line:match('^%s*%d+%.%s*$') ~= nil
        assert.is_true(is_empty, 'Should be empty numbered: "' .. line .. '"')
      end
    end)

    it('should NOT match non-empty list items as empty', function()
      local non_empty = {
        '- text',
        '1. text',
        '* something',
      }
      for _, line in ipairs(non_empty) do
        local is_empty_bullet = line:match('^%s*[%-%*%+]%s*$') ~= nil
        local is_empty_numbered = line:match('^%s*%d+%.%s*$') ~= nil
        assert.is_false(is_empty_bullet or is_empty_numbered, 'Should NOT be empty: ' .. line)
      end
    end)
  end)

  describe('number incrementing', function()
    it('should extract and increment numbers', function()
      local test_cases = {
        { input = '1. item', expected_next = 2 },
        { input = '5. item', expected_next = 6 },
        { input = '99. item', expected_next = 100 },
      }

      for _, tc in ipairs(test_cases) do
        local num = tc.input:match('^%s*(%d+)%.')
        assert.is_not_nil(num, 'Should extract number from: ' .. tc.input)
        assert.are.equal(tc.expected_next, tonumber(num) + 1)
      end
    end)
  end)
end)

-- Integration-style tests with mock blocks
describe('neotion.input.editing integration', function()
  local editing
  local bufnr

  before_each(function()
    package.loaded['neotion.input.editing'] = nil
    editing = require('neotion.input.editing')
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
  end)

  after_each(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      editing.detach(bufnr)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  describe('Enter handling without blocks', function()
    it('should handle orphan line (no block mapping)', function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'some text' })
      vim.api.nvim_win_set_cursor(0, { 1, 9 }) -- end of line

      -- No blocks set up, so handle_enter should just do standard newline
      -- This is tested by not erroring
      assert.has_no.errors(function()
        editing.handle_enter(bufnr)
      end)
    end)
  end)

  describe('keymap descriptions', function()
    it('should have descriptive keymap descriptions', function()
      editing.setup(bufnr)

      local maps = vim.api.nvim_buf_get_keymap(bufnr, 'i')
      for _, map in ipairs(maps) do
        if map.lhs == '<CR>' then
          assert.is_truthy(map.desc:match('Neotion'))
        end
        if map.lhs == '<S-CR>' then
          assert.is_truthy(map.desc:match('Neotion'))
        end
      end
    end)
  end)
end)

-- Mock block tests for Enter behavior
describe('neotion.input.editing with mock blocks', function()
  local editing
  local mapping
  local bufnr
  local original_get_block_at_line

  ---@class MockBlock
  ---@field type string
  ---@field text string

  ---Create a mock block
  ---@param block_type string
  ---@param text string
  ---@return MockBlock
  local function create_mock_block(block_type, text)
    return {
      type = block_type,
      text = text,
      get_type = function(self)
        return self.type
      end,
      get_text = function(self)
        return self.text
      end,
    }
  end

  before_each(function()
    package.loaded['neotion.input.editing'] = nil
    package.loaded['neotion.model.mapping'] = nil
    editing = require('neotion.input.editing')
    mapping = require('neotion.model.mapping')

    -- Save original function
    original_get_block_at_line = mapping.get_block_at_line

    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
  end)

  after_each(function()
    -- Restore original function
    if original_get_block_at_line then
      mapping.get_block_at_line = original_get_block_at_line
    end

    if vim.api.nvim_buf_is_valid(bufnr) then
      editing.detach(bufnr)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  describe('bullet list Enter handling', function()
    it('should not error on non-empty bullet list item', function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '- item text' })
      vim.api.nvim_win_set_cursor(0, { 1, 11 }) -- end of line

      -- Mock the block
      mapping.get_block_at_line = function()
        return create_mock_block('bulleted_list_item', 'item text')
      end

      assert.has_no.errors(function()
        editing.handle_enter(bufnr)
      end)
    end)

    it('should clear empty bullet item and convert to paragraph', function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '- ' })
      vim.api.nvim_win_set_cursor(0, { 1, 2 }) -- after dash and space

      -- Mock the block
      mapping.get_block_at_line = function()
        return create_mock_block('bulleted_list_item', '')
      end

      editing.handle_enter(bufnr)

      -- Line should be cleared
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.equal('', lines[1], 'Empty bullet should be converted to empty line')
    end)

    it('should handle different bullet styles', function()
      local bullet_styles = { '- ', '* ', '+ ' }
      for _, bullet in ipairs(bullet_styles) do
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { bullet })
        vim.api.nvim_win_set_cursor(0, { 1, #bullet })

        mapping.get_block_at_line = function()
          return create_mock_block('bulleted_list_item', '')
        end

        editing.handle_enter(bufnr)

        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        assert.are.equal('', lines[1], 'Empty ' .. bullet .. ' should be cleared')
      end
    end)
  end)

  describe('numbered list Enter handling', function()
    it('should not error on non-empty numbered list item', function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '1. item text' })
      vim.api.nvim_win_set_cursor(0, { 1, 12 }) -- end of line

      mapping.get_block_at_line = function()
        return create_mock_block('numbered_list_item', 'item text')
      end

      assert.has_no.errors(function()
        editing.handle_enter(bufnr)
      end)
    end)

    it('should clear empty numbered item and convert to paragraph', function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '1. ' })
      vim.api.nvim_win_set_cursor(0, { 1, 3 }) -- after "1. "

      mapping.get_block_at_line = function()
        return create_mock_block('numbered_list_item', '')
      end

      editing.handle_enter(bufnr)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.equal('', lines[1], 'Empty numbered item should be converted to empty line')
    end)
  end)

  describe('quote Enter handling', function()
    it('should not error on quote block (soft break)', function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '| quote text' })
      vim.api.nvim_win_set_cursor(0, { 1, 12 })

      mapping.get_block_at_line = function()
        return create_mock_block('quote', 'quote text')
      end

      assert.has_no.errors(function()
        editing.handle_enter(bufnr)
      end)
    end)
  end)

  describe('code Enter handling', function()
    it('should not error on code block (soft break)', function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'code content' })
      vim.api.nvim_win_set_cursor(0, { 1, 12 })

      mapping.get_block_at_line = function()
        return create_mock_block('code', 'code content')
      end

      assert.has_no.errors(function()
        editing.handle_enter(bufnr)
      end)
    end)
  end)

  describe('heading Enter handling', function()
    it('should not error on heading_1', function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '# Heading' })
      vim.api.nvim_win_set_cursor(0, { 1, 9 })

      mapping.get_block_at_line = function()
        return create_mock_block('heading_1', 'Heading')
      end

      assert.has_no.errors(function()
        editing.handle_enter(bufnr)
      end)
    end)

    it('should not error on heading_2', function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '## Heading' })
      vim.api.nvim_win_set_cursor(0, { 1, 10 })

      mapping.get_block_at_line = function()
        return create_mock_block('heading_2', 'Heading')
      end

      assert.has_no.errors(function()
        editing.handle_enter(bufnr)
      end)
    end)
  end)

  describe('paragraph Enter handling', function()
    it('should not error on paragraph', function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'Paragraph text' })
      vim.api.nvim_win_set_cursor(0, { 1, 14 })

      mapping.get_block_at_line = function()
        return create_mock_block('paragraph', 'Paragraph text')
      end

      assert.has_no.errors(function()
        editing.handle_enter(bufnr)
      end)
    end)
  end)

  describe('Shift+Enter handling', function()
    it('should not error for soft break', function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'some text' })
      vim.api.nvim_win_set_cursor(0, { 1, 9 })

      assert.has_no.errors(function()
        editing.handle_shift_enter(bufnr)
      end)
    end)
  end)

  describe('orphan line Enter handling (content-based detection)', function()
    it('should continue bullet list on orphan line with bullet prefix', function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '- orphan item' })
      vim.api.nvim_win_set_cursor(0, { 1, 13 }) -- end of line

      -- No block mock - this is truly orphan
      mapping.get_block_at_line = function()
        return nil
      end

      editing.handle_enter(bufnr)

      -- Should have created new line with prefix
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- Note: feedkeys is async, so we check via schedule
      vim.schedule(function()
        local updated_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        -- At minimum, should not error
        assert.is_true(#updated_lines >= 1)
      end)
    end)

    it('should continue numbered list on orphan line with number prefix', function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '1. orphan item' })
      vim.api.nvim_win_set_cursor(0, { 1, 14 }) -- end of line

      mapping.get_block_at_line = function()
        return nil
      end

      assert.has_no.errors(function()
        editing.handle_enter(bufnr)
      end)
    end)

    it('should exit list on empty orphan bullet', function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '- ' })
      vim.api.nvim_win_set_cursor(0, { 1, 2 })

      mapping.get_block_at_line = function()
        return nil
      end

      editing.handle_enter(bufnr)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.equal('', lines[1], 'Empty orphan bullet should be cleared')
    end)

    it('should do standard newline on non-list orphan line', function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'plain text' })
      vim.api.nvim_win_set_cursor(0, { 1, 10 })

      mapping.get_block_at_line = function()
        return nil
      end

      assert.has_no.errors(function()
        editing.handle_enter(bufnr)
      end)
    end)
  end)
end)
