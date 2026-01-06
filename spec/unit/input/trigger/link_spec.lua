describe('neotion.input.trigger.link', function()
  local link
  local detection
  local state_module

  before_each(function()
    package.loaded['neotion.input.trigger.link'] = nil
    package.loaded['neotion.input.trigger.detection'] = nil
    package.loaded['neotion.input.trigger.state'] = nil
    link = require('neotion.input.trigger.link')
    detection = require('neotion.input.trigger.detection')
    state_module = require('neotion.input.trigger.state')
  end)

  describe('module interface', function()
    it('exposes TRIGGER constant', function()
      assert.are.equal('[[', link.TRIGGER)
    end)

    it('exposes handle function', function()
      assert.is_function(link.handle)
    end)

    it('exposes get_items function', function()
      assert.is_function(link.get_items)
    end)

    it('exposes format_link function', function()
      assert.is_function(link.format_link)
    end)
  end)

  describe('format_link', function()
    it('formats page link with title and id', function()
      local result = link.format_link('Meeting Notes', 'abc-123-def')
      assert.are.equal('[Meeting Notes](notion://page/abc-123-def)', result)
    end)

    it('handles empty title', function()
      local result = link.format_link('', 'abc-123')
      assert.are.equal('[Untitled](notion://page/abc-123)', result)
    end)

    it('handles nil title', function()
      local result = link.format_link(nil, 'abc-123')
      assert.are.equal('[Untitled](notion://page/abc-123)', result)
    end)

    it('preserves special characters in title', function()
      local result = link.format_link('Q4 [Planning] Notes', 'abc-123')
      assert.are.equal('[Q4 [Planning] Notes](notion://page/abc-123)', result)
    end)
  end)

  describe('calculate_replacement', function()
    it('calculates correct replacement range at line start', function()
      local line = '[[meeting'
      local trigger_col = 1
      local query = 'meeting'

      local start_col, end_col = link.calculate_replacement(line, trigger_col, query)
      assert.are.equal(1, start_col)
      assert.are.equal(9, end_col) -- [[ (2) + meeting (7) = 9
    end)

    it('calculates correct replacement range mid-line', function()
      local line = 'Check the [[notes'
      local trigger_col = 11
      local query = 'notes'

      local start_col, end_col = link.calculate_replacement(line, trigger_col, query)
      assert.are.equal(11, start_col)
      assert.are.equal(17, end_col) -- [[ (2) + notes (5) = 7, starting at 11 = 17
    end)

    it('handles empty query', function()
      local line = '[['
      local trigger_col = 1
      local query = ''

      local start_col, end_col = link.calculate_replacement(line, trigger_col, query)
      assert.are.equal(1, start_col)
      assert.are.equal(2, end_col) -- Just [[
    end)
  end)

  describe('get_items', function()
    local mock_items

    before_each(function()
      mock_items = {
        { id = 'page-1', title = 'Meeting Notes', icon = '' },
        { id = 'page-2', title = 'Project Plan', icon = '' },
        { id = 'page-3', title = 'Daily Log', icon = '' },
      }

      -- Mock the pages completion module
      package.loaded['neotion.input.completion.pages'] = {
        get_items = function(query, callback)
          -- Filter by query
          local filtered = {}
          for _, item in ipairs(mock_items) do
            if query == '' or item.title:lower():find(query:lower(), 1, true) then
              table.insert(filtered, item)
            end
          end
          callback(filtered)
        end,
      }
    end)

    after_each(function()
      package.loaded['neotion.input.completion.pages'] = nil
    end)

    it('returns all items for empty query', function()
      local items
      link.get_items('', function(result)
        items = result
      end)
      -- Synchronous mock, so items should be set
      assert.are.equal(3, #items)
    end)

    it('filters items by query', function()
      local items
      link.get_items('meeting', function(result)
        items = result
      end)
      assert.are.equal(1, #items)
      assert.are.equal('Meeting Notes', items[1].title)
    end)

    it('returns empty for non-matching query', function()
      local items
      link.get_items('xyz', function(result)
        items = result
      end)
      assert.are.equal(0, #items)
    end)
  end)

  describe('handle', function()
    local mock_picker_called
    local mock_picker_query
    local mock_selection

    before_each(function()
      mock_picker_called = false
      mock_picker_query = nil
      mock_selection = nil

      -- Mock picker
      package.loaded['neotion.ui.picker'] = {
        search = function(query, on_choice)
          mock_picker_called = true
          mock_picker_query = query
          -- Simulate selection
          if mock_selection then
            on_choice(mock_selection)
          else
            on_choice(nil) -- cancelled
          end
        end,
      }
    end)

    after_each(function()
      package.loaded['neotion.ui.picker'] = nil
    end)

    it('opens picker with query', function()
      local ctx = {
        bufnr = 0,
        line = 1,
        col = 10,
        line_content = '[[meeting',
        trigger_start = 1,
        trigger_text = '[[',
      }

      link.handle(ctx, 'meeting')

      assert.is_true(mock_picker_called)
      assert.are.equal('meeting', mock_picker_query)
    end)

    it('returns insert result on selection', function()
      mock_selection = { id = 'page-123', title = 'Test Page' }

      local ctx = {
        bufnr = 0,
        line = 1,
        col = 10,
        line_content = '[[test',
        trigger_start = 1,
        trigger_text = '[[',
      }

      local result
      link.handle(ctx, 'test', function(r)
        result = r
      end)

      assert.are.equal('insert', result.type)
      assert.are.equal('[Test Page](notion://page/page-123)', result.text)
    end)

    it('does not call callback when picker cancelled', function()
      mock_selection = nil

      local ctx = {
        bufnr = 0,
        line = 1,
        col = 5,
        line_content = '[[',
        trigger_start = 1,
        trigger_text = '[[',
      }

      local callback_called = false
      link.handle(ctx, '', function(r)
        callback_called = true
      end)

      assert.is_false(callback_called)
    end)
  end)

  describe('integration with detection', function()
    it('detection module detects [[ as link trigger', function()
      local result = detection.detect_trigger('[[', 1)
      assert.is_not_nil(result)
      assert.are.equal('[[', result.trigger)
    end)

    it('trigger constant matches detection', function()
      local result = detection.detect_trigger(link.TRIGGER, 1)
      assert.is_not_nil(result)
      assert.are.equal(link.TRIGGER, result.trigger)
    end)
  end)
end)
