---Tests for neotion.ui.sort module
local sort = require('neotion.ui.sort')

describe('neotion.ui.sort', function()
  describe('is_sortable', function()
    it('should return true for sortable types', function()
      assert.is_true(sort.is_sortable('title'))
      assert.is_true(sort.is_sortable('number'))
      assert.is_true(sort.is_sortable('date'))
      assert.is_true(sort.is_sortable('checkbox'))
      assert.is_true(sort.is_sortable('select'))
      assert.is_true(sort.is_sortable('created_time'))
      assert.is_true(sort.is_sortable('last_edited_time'))
    end)

    it('should return false for non-sortable types', function()
      assert.is_false(sort.is_sortable('multi_select'))
      assert.is_false(sort.is_sortable('people'))
      assert.is_false(sort.is_sortable('relation'))
      assert.is_false(sort.is_sortable('formula'))
      assert.is_false(sort.is_sortable('unknown'))
    end)
  end)

  describe('create_state', function()
    it('should create empty sort state', function()
      local state = sort.create_state()
      assert.is_table(state)
      assert.is_table(state.sorts)
      assert.equal(0, #state.sorts)
    end)
  end)

  describe('add_sort', function()
    it('should add sort to state', function()
      local state = sort.create_state()
      local s = {
        property = 'Name',
        direction = 'ascending',
      }
      sort.add_sort(state, s)
      assert.equal(1, #state.sorts)
      assert.equal('Name', state.sorts[1].property)
      assert.equal('ascending', state.sorts[1].direction)
    end)

    it('should add timestamp sort', function()
      local state = sort.create_state()
      sort.add_sort(state, {
        timestamp = 'created_time',
        direction = 'descending',
      })
      assert.equal(1, #state.sorts)
      assert.equal('created_time', state.sorts[1].timestamp)
    end)
  end)

  describe('remove_sort', function()
    it('should remove sort at index', function()
      local state = sort.create_state()
      sort.add_sort(state, { property = 'A', direction = 'ascending' })
      sort.add_sort(state, { property = 'B', direction = 'descending' })
      sort.remove_sort(state, 1)
      assert.equal(1, #state.sorts)
      assert.equal('B', state.sorts[1].property)
    end)
  end)

  describe('clear_sorts', function()
    it('should clear all sorts', function()
      local state = sort.create_state()
      sort.add_sort(state, { property = 'A', direction = 'ascending' })
      sort.add_sort(state, { property = 'B', direction = 'descending' })
      sort.clear_sorts(state)
      assert.equal(0, #state.sorts)
    end)
  end)

  describe('move_up', function()
    it('should move sort up in priority', function()
      local state = sort.create_state()
      sort.add_sort(state, { property = 'A', direction = 'ascending' })
      sort.add_sort(state, { property = 'B', direction = 'descending' })
      sort.move_up(state, 2)
      assert.equal('B', state.sorts[1].property)
      assert.equal('A', state.sorts[2].property)
    end)

    it('should not move first sort up', function()
      local state = sort.create_state()
      sort.add_sort(state, { property = 'A', direction = 'ascending' })
      sort.add_sort(state, { property = 'B', direction = 'descending' })
      sort.move_up(state, 1)
      assert.equal('A', state.sorts[1].property)
    end)
  end)

  describe('move_down', function()
    it('should move sort down in priority', function()
      local state = sort.create_state()
      sort.add_sort(state, { property = 'A', direction = 'ascending' })
      sort.add_sort(state, { property = 'B', direction = 'descending' })
      sort.move_down(state, 1)
      assert.equal('B', state.sorts[1].property)
      assert.equal('A', state.sorts[2].property)
    end)

    it('should not move last sort down', function()
      local state = sort.create_state()
      sort.add_sort(state, { property = 'A', direction = 'ascending' })
      sort.add_sort(state, { property = 'B', direction = 'descending' })
      sort.move_down(state, 2)
      assert.equal('B', state.sorts[2].property)
    end)
  end)

  describe('build_api_sorts', function()
    it('should return nil for empty state', function()
      local state = sort.create_state()
      assert.is_nil(sort.build_api_sorts(state))
    end)

    it('should build single property sort', function()
      local state = sort.create_state()
      sort.add_sort(state, { property = 'Name', direction = 'ascending' })
      local api_sorts = sort.build_api_sorts(state)
      assert.is_table(api_sorts)
      assert.equal(1, #api_sorts)
      assert.equal('Name', api_sorts[1].property)
      assert.equal('ascending', api_sorts[1].direction)
    end)

    it('should build single timestamp sort', function()
      local state = sort.create_state()
      sort.add_sort(state, { timestamp = 'created_time', direction = 'descending' })
      local api_sorts = sort.build_api_sorts(state)
      assert.is_table(api_sorts)
      assert.equal(1, #api_sorts)
      assert.equal('created_time', api_sorts[1].timestamp)
      assert.equal('descending', api_sorts[1].direction)
    end)

    it('should build multiple sorts preserving order', function()
      local state = sort.create_state()
      sort.add_sort(state, { property = 'Status', direction = 'ascending' })
      sort.add_sort(state, { property = 'Name', direction = 'descending' })
      local api_sorts = sort.build_api_sorts(state)
      assert.is_table(api_sorts)
      assert.equal(2, #api_sorts)
      assert.equal('Status', api_sorts[1].property)
      assert.equal('Name', api_sorts[2].property)
    end)

    it('should handle mixed property and timestamp sorts', function()
      local state = sort.create_state()
      sort.add_sort(state, { property = 'Status', direction = 'ascending' })
      sort.add_sort(state, { timestamp = 'last_edited_time', direction = 'descending' })
      local api_sorts = sort.build_api_sorts(state)
      assert.is_table(api_sorts)
      assert.equal(2, #api_sorts)
      assert.equal('Status', api_sorts[1].property)
      assert.equal('last_edited_time', api_sorts[2].timestamp)
    end)
  end)

  describe('get_sortable_properties', function()
    it('should extract sortable properties from schema', function()
      local schema = {
        properties = {
          Name = { type = 'title' },
          Status = { type = 'select' },
          Tags = { type = 'multi_select' }, -- not sortable
          Count = { type = 'number' },
        },
      }
      local props = sort.get_sortable_properties(schema)
      assert.is_table(props)
      assert.equal(3, #props) -- Name, Status, Count (not Tags)
    end)

    it('should return empty for nil schema', function()
      local props = sort.get_sortable_properties(nil)
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
      local props = sort.get_sortable_properties(schema)
      assert.equal('Alpha', props[1].name)
      assert.equal('Middle', props[2].name)
      assert.equal('Zebra', props[3].name)
    end)
  end)

  describe('format_state', function()
    it('should return "No sorting" for empty state', function()
      local state = sort.create_state()
      assert.equal('No sorting', sort.format_state(state))
    end)

    it('should format single sort with ascending', function()
      local state = sort.create_state()
      sort.add_sort(state, { property = 'Name', direction = 'ascending' })
      local formatted = sort.format_state(state)
      assert.is_true(formatted:find('Name') ~= nil)
      assert.is_true(formatted:find('↑') ~= nil)
    end)

    it('should format single sort with descending', function()
      local state = sort.create_state()
      sort.add_sort(state, { property = 'Date', direction = 'descending' })
      local formatted = sort.format_state(state)
      assert.is_true(formatted:find('Date') ~= nil)
      assert.is_true(formatted:find('↓') ~= nil)
    end)

    it('should format timestamp sort', function()
      local state = sort.create_state()
      sort.add_sort(state, { timestamp = 'created_time', direction = 'descending' })
      local formatted = sort.format_state(state)
      assert.is_true(formatted:find('created_time') ~= nil)
    end)

    it('should format multiple sorts with comma', function()
      local state = sort.create_state()
      sort.add_sort(state, { property = 'A', direction = 'ascending' })
      sort.add_sort(state, { property = 'B', direction = 'descending' })
      local formatted = sort.format_state(state)
      assert.is_true(formatted:find(', ') ~= nil)
    end)
  end)
end)
