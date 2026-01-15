---Tests for neotion.ui.filter module
local filter = require('neotion.ui.filter')

describe('neotion.ui.filter', function()
  describe('get_operators', function()
    it('should return operators for title type', function()
      local ops = filter.get_operators('title')
      assert.is_table(ops)
      assert.is_true(vim.tbl_contains(ops, 'contains'))
      assert.is_true(vim.tbl_contains(ops, 'equals'))
    end)

    it('should return operators for number type', function()
      local ops = filter.get_operators('number')
      assert.is_table(ops)
      assert.is_true(vim.tbl_contains(ops, 'greater_than'))
      assert.is_true(vim.tbl_contains(ops, 'less_than'))
    end)

    it('should return operators for checkbox type', function()
      local ops = filter.get_operators('checkbox')
      assert.is_table(ops)
      assert.is_true(vim.tbl_contains(ops, 'equals'))
    end)

    it('should return operators for date type', function()
      local ops = filter.get_operators('date')
      assert.is_table(ops)
      assert.is_true(vim.tbl_contains(ops, 'before'))
      assert.is_true(vim.tbl_contains(ops, 'after'))
      assert.is_true(vim.tbl_contains(ops, 'past_week'))
    end)

    it('should fallback to rich_text for unknown type', function()
      local ops = filter.get_operators('unknown_type')
      assert.is_table(ops)
      assert.is_true(vim.tbl_contains(ops, 'contains'))
    end)
  end)

  describe('operator_needs_value', function()
    it('should return true for value-based operators', function()
      assert.is_true(filter.operator_needs_value('equals'))
      assert.is_true(filter.operator_needs_value('contains'))
      assert.is_true(filter.operator_needs_value('greater_than'))
    end)

    it('should return false for valueless operators', function()
      assert.is_false(filter.operator_needs_value('is_empty'))
      assert.is_false(filter.operator_needs_value('is_not_empty'))
      assert.is_false(filter.operator_needs_value('past_week'))
      assert.is_false(filter.operator_needs_value('this_week'))
    end)
  end)

  describe('get_operator_label', function()
    it('should return human-readable label', function()
      assert.equal('equals', filter.get_operator_label('equals'))
      assert.equal('does not equal', filter.get_operator_label('does_not_equal'))
      assert.equal('>', filter.get_operator_label('greater_than'))
      assert.equal('is empty', filter.get_operator_label('is_empty'))
    end)

    it('should return operator name for unknown operators', function()
      assert.equal('unknown_op', filter.get_operator_label('unknown_op'))
    end)
  end)

  describe('create_state', function()
    it('should create empty filter state', function()
      local state = filter.create_state()
      assert.is_table(state)
      assert.is_table(state.filters)
      assert.equal(0, #state.filters)
      assert.equal('and', state.compound_type)
    end)
  end)

  describe('add_filter', function()
    it('should add filter to state', function()
      local state = filter.create_state()
      local f = {
        property = 'Status',
        property_type = 'select',
        operator = 'equals',
        value = 'Done',
      }
      filter.add_filter(state, f)
      assert.equal(1, #state.filters)
      assert.equal('Status', state.filters[1].property)
    end)
  end)

  describe('remove_filter', function()
    it('should remove filter at index', function()
      local state = filter.create_state()
      filter.add_filter(state, { property = 'A', operator = 'equals', value = '1' })
      filter.add_filter(state, { property = 'B', operator = 'equals', value = '2' })
      filter.remove_filter(state, 1)
      assert.equal(1, #state.filters)
      assert.equal('B', state.filters[1].property)
    end)
  end)

  describe('clear_filters', function()
    it('should clear all filters', function()
      local state = filter.create_state()
      filter.add_filter(state, { property = 'A', operator = 'equals', value = '1' })
      filter.add_filter(state, { property = 'B', operator = 'equals', value = '2' })
      filter.clear_filters(state)
      assert.equal(0, #state.filters)
    end)
  end)

  describe('build_single_filter', function()
    it('should build text filter', function()
      local f = {
        property = 'Name',
        property_type = 'rich_text',
        operator = 'contains',
        value = 'test',
      }
      local api_filter = filter.build_single_filter(f)
      assert.is_table(api_filter)
      assert.equal('Name', api_filter.property)
      assert.is_table(api_filter.rich_text)
      assert.equal('test', api_filter.rich_text.contains)
    end)

    it('should build number filter', function()
      local f = {
        property = 'Count',
        property_type = 'number',
        operator = 'greater_than',
        value = 10,
      }
      local api_filter = filter.build_single_filter(f)
      assert.is_table(api_filter)
      assert.equal('Count', api_filter.property)
      assert.is_table(api_filter.number)
      assert.equal(10, api_filter.number.greater_than)
    end)

    it('should build checkbox filter', function()
      local f = {
        property = 'Done',
        property_type = 'checkbox',
        operator = 'equals',
        value = true,
      }
      local api_filter = filter.build_single_filter(f)
      assert.is_table(api_filter)
      assert.equal('Done', api_filter.property)
      assert.is_table(api_filter.checkbox)
      assert.equal(true, api_filter.checkbox.equals)
    end)

    it('should build valueless filter', function()
      local f = {
        property = 'Notes',
        property_type = 'rich_text',
        operator = 'is_empty',
      }
      local api_filter = filter.build_single_filter(f)
      assert.is_table(api_filter)
      assert.equal('Notes', api_filter.property)
      assert.is_table(api_filter.rich_text)
      assert.equal(true, api_filter.rich_text.is_empty)
    end)

    it('should return nil for invalid filter', function()
      assert.is_nil(filter.build_single_filter({}))
      assert.is_nil(filter.build_single_filter({ property = 'X' }))
    end)
  end)

  describe('build_api_filter', function()
    it('should return nil for empty state', function()
      local state = filter.create_state()
      assert.is_nil(filter.build_api_filter(state))
    end)

    it('should return single filter without compound', function()
      local state = filter.create_state()
      filter.add_filter(state, {
        property = 'Status',
        property_type = 'select',
        operator = 'equals',
        value = 'Done',
      })
      local api_filter = filter.build_api_filter(state)
      assert.is_table(api_filter)
      assert.equal('Status', api_filter.property)
      assert.is_nil(api_filter['and'])
    end)

    it('should build compound AND filter', function()
      local state = filter.create_state()
      state.compound_type = 'and'
      filter.add_filter(state, {
        property = 'Status',
        property_type = 'select',
        operator = 'equals',
        value = 'Done',
      })
      filter.add_filter(state, {
        property = 'Priority',
        property_type = 'select',
        operator = 'equals',
        value = 'High',
      })
      local api_filter = filter.build_api_filter(state)
      assert.is_table(api_filter)
      assert.is_table(api_filter['and'])
      assert.equal(2, #api_filter['and'])
    end)

    it('should build compound OR filter', function()
      local state = filter.create_state()
      state.compound_type = 'or'
      filter.add_filter(state, {
        property = 'Status',
        property_type = 'select',
        operator = 'equals',
        value = 'Done',
      })
      filter.add_filter(state, {
        property = 'Status',
        property_type = 'select',
        operator = 'equals',
        value = 'In Progress',
      })
      local api_filter = filter.build_api_filter(state)
      assert.is_table(api_filter)
      assert.is_table(api_filter['or'])
      assert.equal(2, #api_filter['or'])
    end)
  end)

  describe('get_properties_from_schema', function()
    it('should extract properties from schema', function()
      local schema = {
        properties = {
          Name = { type = 'title' },
          Status = { type = 'select' },
          Count = { type = 'number' },
        },
      }
      local props = filter.get_properties_from_schema(schema)
      assert.is_table(props)
      assert.equal(3, #props)
    end)

    it('should return empty for nil schema', function()
      local props = filter.get_properties_from_schema(nil)
      assert.is_table(props)
      assert.equal(0, #props)
    end)

    it('should sort properties alphabetically', function()
      local schema = {
        properties = {
          Zebra = { type = 'title' },
          Alpha = { type = 'select' },
          Middle = { type = 'number' },
        },
      }
      local props = filter.get_properties_from_schema(schema)
      assert.equal('Alpha', props[1].name)
      assert.equal('Middle', props[2].name)
      assert.equal('Zebra', props[3].name)
    end)
  end)

  describe('format_state', function()
    it('should return "No filters" for empty state', function()
      local state = filter.create_state()
      assert.equal('No filters', filter.format_state(state))
    end)

    it('should format single filter', function()
      local state = filter.create_state()
      filter.add_filter(state, {
        property = 'Status',
        property_type = 'select',
        operator = 'equals',
        value = 'Done',
      })
      local formatted = filter.format_state(state)
      assert.is_true(formatted:find('Status') ~= nil)
      assert.is_true(formatted:find('equals') ~= nil)
      assert.is_true(formatted:find('Done') ~= nil)
    end)

    it('should format multiple filters with AND', function()
      local state = filter.create_state()
      state.compound_type = 'and'
      filter.add_filter(state, { property = 'A', operator = 'equals', value = '1' })
      filter.add_filter(state, { property = 'B', operator = 'equals', value = '2' })
      local formatted = filter.format_state(state)
      assert.is_true(formatted:find(' AND ') ~= nil)
    end)

    it('should format multiple filters with OR', function()
      local state = filter.create_state()
      state.compound_type = 'or'
      filter.add_filter(state, { property = 'A', operator = 'equals', value = '1' })
      filter.add_filter(state, { property = 'B', operator = 'equals', value = '2' })
      local formatted = filter.format_state(state)
      assert.is_true(formatted:find(' OR ') ~= nil)
    end)
  end)
end)
