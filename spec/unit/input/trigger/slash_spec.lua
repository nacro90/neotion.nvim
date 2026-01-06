describe('neotion.input.trigger.slash', function()
  local slash
  local detection

  before_each(function()
    package.loaded['neotion.input.trigger.slash'] = nil
    package.loaded['neotion.input.trigger.detection'] = nil
    package.loaded['neotion.input.completion.blocks'] = nil
    slash = require('neotion.input.trigger.slash')
    detection = require('neotion.input.trigger.detection')
  end)

  describe('module interface', function()
    it('exposes TRIGGER constant', function()
      assert.are.equal('/', slash.TRIGGER)
    end)

    it('exposes handle function', function()
      assert.is_function(slash.handle)
    end)

    it('exposes get_items function', function()
      assert.is_function(slash.get_items)
    end)

    it('exposes get_block_prefix function', function()
      assert.is_function(slash.get_block_prefix)
    end)
  end)

  describe('get_block_prefix', function()
    it('returns "# " for heading_1', function()
      assert.are.equal('# ', slash.get_block_prefix('heading_1'))
    end)

    it('returns "## " for heading_2', function()
      assert.are.equal('## ', slash.get_block_prefix('heading_2'))
    end)

    it('returns "### " for heading_3', function()
      assert.are.equal('### ', slash.get_block_prefix('heading_3'))
    end)

    it('returns "- " for bulleted_list_item', function()
      assert.are.equal('- ', slash.get_block_prefix('bulleted_list_item'))
    end)

    it('returns "| " for quote', function()
      assert.are.equal('| ', slash.get_block_prefix('quote'))
    end)

    it('returns "```\\n" for code', function()
      assert.are.equal('```\n', slash.get_block_prefix('code'))
    end)

    it('returns "---\\n" for divider', function()
      assert.are.equal('---\n', slash.get_block_prefix('divider'))
    end)

    it('returns "" for paragraph', function()
      assert.are.equal('', slash.get_block_prefix('paragraph'))
    end)

    it('returns "" for unknown type', function()
      assert.are.equal('', slash.get_block_prefix('unknown_type'))
    end)
  end)

  describe('get_items', function()
    describe('block items', function()
      it('includes all supported block types', function()
        local items
        slash.get_items('', function(result)
          items = result
        end)

        -- Check that items exist
        assert.is_table(items)
        assert.is_true(#items > 0)

        -- Check for expected block types
        local labels = {}
        for _, item in ipairs(items) do
          labels[item.label] = true
        end

        assert.is_true(labels['Text'] or labels['Paragraph'])
        assert.is_true(labels['Heading 1'])
        assert.is_true(labels['Heading 2'])
        assert.is_true(labels['Heading 3'])
        assert.is_true(labels['Bullet list'] or labels['Bulleted list'])
        assert.is_true(labels['Quote'])
        assert.is_true(labels['Code'])
        assert.is_true(labels['Divider'])
      end)

      it('filters items by query', function()
        local items
        slash.get_items('head', function(result)
          items = result
        end)

        -- Should only return heading-related items
        for _, item in ipairs(items) do
          assert.is_true(item.label:lower():find('head') ~= nil, 'Item "' .. item.label .. '" should match "head"')
        end
      end)

      it('returns empty for non-matching query', function()
        local items
        slash.get_items('xyznonexistent', function(result)
          items = result
        end)

        assert.are.equal(0, #items)
      end)

      it('items have required fields', function()
        local items
        slash.get_items('', function(result)
          items = result
        end)

        for _, item in ipairs(items) do
          assert.is_string(item.label)
          assert.is_not_nil(item.value)
          -- icon and description are optional but should be strings if present
          if item.icon then
            assert.is_string(item.icon)
          end
          if item.description then
            assert.is_string(item.description)
          end
        end
      end)
    end)
  end)

  describe('handle', function()
    local mock_picker_called
    local mock_items_passed
    local mock_selection

    before_each(function()
      mock_picker_called = false
      mock_items_passed = nil
      mock_selection = nil

      -- Mock the select function
      package.loaded['neotion.ui.picker'] = {
        select = function(items, opts, on_choice)
          mock_picker_called = true
          mock_items_passed = items
          if mock_selection then
            on_choice(mock_selection)
          else
            on_choice(nil)
          end
        end,
        search = function() end,
      }
    end)

    after_each(function()
      package.loaded['neotion.ui.picker'] = nil
    end)

    it('shows picker with block items', function()
      local ctx = {
        bufnr = 0,
        line = 1,
        col = 1,
        line_content = '/',
        trigger_start = 1,
        trigger_text = '/',
      }

      slash.handle(ctx, '')

      assert.is_true(mock_picker_called)
      assert.is_table(mock_items_passed)
      assert.is_true(#mock_items_passed > 0)
    end)

    it('returns insert result for block selection', function()
      mock_selection = { label = 'Heading 1', value = 'heading_1' }

      local ctx = {
        bufnr = 0,
        line = 1,
        col = 1,
        line_content = '/',
        trigger_start = 1,
        trigger_text = '/',
      }

      local result
      slash.handle(ctx, '', function(r)
        result = r
      end)

      assert.are.equal('insert', result.type)
      assert.are.equal('# ', result.text)
    end)

    it('returns insert result for bullet list', function()
      mock_selection = { label = 'Bullet list', value = 'bulleted_list_item' }

      local ctx = {
        bufnr = 0,
        line = 1,
        col = 1,
        line_content = '/',
        trigger_start = 1,
        trigger_text = '/',
      }

      local result
      slash.handle(ctx, '', function(r)
        result = r
      end)

      assert.are.equal('insert', result.type)
      assert.are.equal('- ', result.text)
    end)

    it('does not call callback when picker cancelled', function()
      mock_selection = nil

      local ctx = {
        bufnr = 0,
        line = 1,
        col = 1,
        line_content = '/',
        trigger_start = 1,
        trigger_text = '/',
      }

      local callback_called = false
      slash.handle(ctx, '', function(r)
        callback_called = true
      end)

      assert.is_false(callback_called)
    end)
  end)

  describe('integration with detection', function()
    it('detection module detects / as slash trigger', function()
      local result = detection.detect_trigger('/', 1)
      assert.is_not_nil(result)
      assert.are.equal('/', result.trigger)
    end)

    it('trigger constant matches detection', function()
      local result = detection.detect_trigger(slash.TRIGGER, 1)
      assert.is_not_nil(result)
      assert.are.equal(slash.TRIGGER, result.trigger)
    end)
  end)
end)
