---Tests for neotion.model.database_view module
local database_view_module = require('neotion.model.database_view')
local DatabaseView = database_view_module.DatabaseView

describe('neotion.model.database_view', function()
  local sample_database = {
    id = '12345678-1234-1234-1234-123456789abc',
    title = {
      { plain_text = 'Test Database' },
    },
    icon = {
      type = 'emoji',
      emoji = '📊',
    },
    properties = {
      Name = { type = 'title' },
      Status = { type = 'select' },
      Priority = { type = 'select' },
      Done = { type = 'checkbox' },
      Count = { type = 'number' },
      Notes = { type = 'rich_text' },
    },
  }

  local sample_rows = {
    {
      id = 'row-1',
      properties = {
        Name = { type = 'title', title = { { plain_text = 'Task 1' } } },
        Status = { type = 'select', select = { name = 'In Progress', color = 'blue' } },
        Done = { type = 'checkbox', checkbox = false },
        Count = { type = 'number', number = 5 },
      },
    },
    {
      id = 'row-2',
      properties = {
        Name = { type = 'title', title = { { plain_text = 'Task 2' } } },
        Status = { type = 'select', select = { name = 'Done', color = 'green' } },
        Done = { type = 'checkbox', checkbox = true },
        Count = { type = 'number', number = 10 },
      },
    },
  }

  describe('DatabaseView.new', function()
    it('should create a new database view', function()
      local view = DatabaseView.new(sample_database, sample_rows, {})

      assert.is_table(view)
      assert.equal('12345678123412341234123456789abc', view.database_id)
      assert.equal('Test Database', view.title)
      assert.equal('📊', view.icon)
    end)

    it('should deserialize rows', function()
      local view = DatabaseView.new(sample_database, sample_rows, {})

      assert.equal(2, #view.rows)
      assert.equal('Task 1', view.rows[1]:get_title())
      assert.equal('Task 2', view.rows[2]:get_title())
    end)

    it('should auto-select columns', function()
      local view = DatabaseView.new(sample_database, sample_rows, {})

      assert.is_table(view.columns)
      assert.is_true(#view.columns > 0)
      assert.is_true(#view.columns <= 6)

      -- Title should be first
      assert.equal('Name', view.columns[1].name)
      assert.equal('title', view.columns[1].type)
    end)

    it('should handle pagination info', function()
      local query_result = {
        has_more = true,
        next_cursor = 'cursor-abc',
      }

      local view = DatabaseView.new(sample_database, sample_rows, query_result)

      assert.is_true(view.has_more)
      assert.equal('cursor-abc', view.next_cursor)
    end)

    it('should handle missing icon', function()
      local db_without_icon = {
        id = '12345678-1234-1234-1234-123456789abc',
        title = { { plain_text = 'Test Database' } },
        icon = nil,
        properties = sample_database.properties,
      }

      local view = DatabaseView.new(db_without_icon, sample_rows, {})

      assert.is_nil(view.icon)
    end)

    it('should handle empty title', function()
      local db_without_title = vim.tbl_extend('force', sample_database, { title = {} })

      local view = DatabaseView.new(db_without_title, sample_rows, {})

      assert.equal('Untitled Database', view.title)
    end)
  end)

  describe('select_columns', function()
    it('should respect max_columns limit', function()
      local view = DatabaseView.new(sample_database, sample_rows, {})

      view:select_columns(3)

      assert.equal(3, #view.columns)
    end)

    it('should prioritize title column', function()
      local view = DatabaseView.new(sample_database, sample_rows, {})

      view:select_columns(1)

      assert.equal('Name', view.columns[1].name)
      assert.equal('title', view.columns[1].type)
    end)
  end)

  describe('format_cell', function()
    it('should format title cell', function()
      local view = DatabaseView.new(sample_database, sample_rows, {})
      local cell = view:format_cell(view.rows[1], 'Name')

      assert.equal('Task 1', cell)
    end)

    it('should format select cell', function()
      local view = DatabaseView.new(sample_database, sample_rows, {})
      local cell = view:format_cell(view.rows[1], 'Status')

      assert.equal('In Progress', cell)
    end)

    it('should format checkbox cell', function()
      local view = DatabaseView.new(sample_database, sample_rows, {})

      local cell1 = view:format_cell(view.rows[1], 'Done')
      local cell2 = view:format_cell(view.rows[2], 'Done')

      assert.equal('[ ]', cell1)
      assert.equal('[x]', cell2)
    end)

    it('should format number cell', function()
      local view = DatabaseView.new(sample_database, sample_rows, {})
      local cell = view:format_cell(view.rows[1], 'Count')

      assert.equal('5', cell)
    end)

    it('should return "-" for missing property', function()
      local view = DatabaseView.new(sample_database, sample_rows, {})
      local cell = view:format_cell(view.rows[1], 'NonExistent')

      assert.equal('-', cell)
    end)
  end)

  describe('format', function()
    it('should return array of lines', function()
      local view = DatabaseView.new(sample_database, sample_rows, {})
      local lines = view:format()

      assert.is_table(lines)
      assert.is_true(#lines > 0)
    end)

    it('should include header line with title', function()
      local view = DatabaseView.new(sample_database, sample_rows, {})
      local lines = view:format()

      assert.is_true(lines[1]:find('Test Database') ~= nil)
    end)

    it('should include row count', function()
      local view = DatabaseView.new(sample_database, sample_rows, {})
      local lines = view:format()

      assert.is_true(lines[1]:find('%[2 rows%]') ~= nil)
    end)

    it('should include table separator', function()
      local view = DatabaseView.new(sample_database, sample_rows, {})
      local lines = view:format()

      -- Find a line that looks like |---|---|---|
      local has_separator = false
      for _, line in ipairs(lines) do
        if line:match('^|%-+') then
          has_separator = true
          break
        end
      end
      assert.is_true(has_separator)
    end)

    it('should set line ranges on rows', function()
      local view = DatabaseView.new(sample_database, sample_rows, {})
      view:format()

      local start1, end1 = view.rows[1]:get_line_range()
      local start2, end2 = view.rows[2]:get_line_range()

      assert.is_number(start1)
      assert.is_number(end1)
      assert.is_number(start2)
      assert.is_number(end2)
      assert.is_true(start2 > end1)
    end)
  end)

  describe('get_row_at_line', function()
    it('should return row at line', function()
      local view = DatabaseView.new(sample_database, sample_rows, {})
      view:format()

      local start_line = view.rows[1]:get_line_range()
      local row = view:get_row_at_line(start_line)

      assert.is_table(row)
      assert.equal('Task 1', row:get_title())
    end)

    it('should return nil for header lines', function()
      local view = DatabaseView.new(sample_database, sample_rows, {})
      view:format()

      local row = view:get_row_at_line(1)

      assert.is_nil(row)
    end)

    it('should return nil for lines beyond data', function()
      local view = DatabaseView.new(sample_database, sample_rows, {})
      view:format()

      local row = view:get_row_at_line(1000)

      assert.is_nil(row)
    end)
  end)

  describe('append_rows', function()
    it('should add rows to view', function()
      local view = DatabaseView.new(sample_database, sample_rows, {})
      local initial_count = #view.rows

      local new_rows = {
        {
          id = 'row-3',
          properties = {
            Name = { type = 'title', title = { { plain_text = 'Task 3' } } },
          },
        },
      }

      view:append_rows(new_rows, { has_more = false })

      assert.equal(initial_count + 1, #view.rows)
      assert.equal('Task 3', view.rows[3]:get_title())
    end)

    it('should update pagination state', function()
      local view = DatabaseView.new(sample_database, sample_rows, { has_more = true, next_cursor = 'c1' })

      view:append_rows({}, { has_more = false, next_cursor = nil })

      assert.is_false(view.has_more)
      assert.is_nil(view.next_cursor)
    end)
  end)

  describe('clear_rows', function()
    it('should clear all rows', function()
      local view = DatabaseView.new(sample_database, sample_rows, {})

      view:clear_rows()

      assert.equal(0, #view.rows)
      assert.is_false(view.has_more)
      assert.is_nil(view.next_cursor)
    end)
  end)

  describe('format_header', function()
    it('should include icon when present', function()
      local view = DatabaseView.new(sample_database, sample_rows, {})
      local header = view:format_header()

      assert.is_true(header[1]:find('📊') ~= nil)
    end)

    it('should show filter indicator when filtered', function()
      local view = DatabaseView.new(sample_database, sample_rows, {})
      view.filter_state = { filters = { { property = 'Status' } } }
      local header = view:format_header()

      assert.is_true(header[1]:find('%[Filtered%]') ~= nil)
    end)

    it('should show sort indicator when sorted', function()
      local view = DatabaseView.new(sample_database, sample_rows, {})
      view.sort_state = { sorts = { { property = 'Name' } } }
      local header = view:format_header()

      assert.is_true(header[1]:find('%[Sorted%]') ~= nil)
    end)

    it('should show more indicator when paginated', function()
      local view = DatabaseView.new(sample_database, sample_rows, { has_more = true })
      local header = view:format_header()

      assert.is_true(header[1]:find('%[More%.%.%.%]') ~= nil)
    end)
  end)
end)
