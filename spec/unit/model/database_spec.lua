describe('neotion.model.database', function()
  local database

  before_each(function()
    package.loaded['neotion.model.database'] = nil
    database = require('neotion.model.database')
  end)

  describe('DatabaseRow', function()
    describe('new', function()
      it('should create row from raw page JSON', function()
        local raw = {
          id = 'page-123',
          object = 'page',
          properties = {
            Name = {
              type = 'title',
              title = { { plain_text = 'Test Row' } },
            },
          },
        }

        local row = database.DatabaseRow.new(raw)

        assert.are.equal('page-123', row.id)
        assert.are.same(raw, row.raw)
      end)

      it('should validate raw input is table', function()
        assert.has_error(function()
          database.DatabaseRow.new(nil)
        end)
      end)

      it('should handle page without properties', function()
        local raw = {
          id = 'page-456',
          object = 'page',
        }

        local row = database.DatabaseRow.new(raw)

        assert.are.equal('page-456', row.id)
      end)
    end)

    describe('get_title', function()
      it('should extract title from title property', function()
        local raw = {
          id = 'page-1',
          properties = {
            Name = {
              type = 'title',
              title = { { plain_text = 'My Title' } },
            },
          },
        }

        local row = database.DatabaseRow.new(raw)

        assert.are.equal('My Title', row:get_title())
      end)

      it('should concatenate multiple title parts', function()
        local raw = {
          id = 'page-1',
          properties = {
            Title = {
              type = 'title',
              title = {
                { plain_text = 'Part 1 ' },
                { plain_text = 'Part 2' },
              },
            },
          },
        }

        local row = database.DatabaseRow.new(raw)

        assert.are.equal('Part 1 Part 2', row:get_title())
      end)

      it('should return Untitled for empty title', function()
        local raw = {
          id = 'page-1',
          properties = {
            Name = {
              type = 'title',
              title = {},
            },
          },
        }

        local row = database.DatabaseRow.new(raw)

        assert.are.equal('Untitled', row:get_title())
      end)

      it('should return Untitled when no title property exists', function()
        local raw = {
          id = 'page-1',
          properties = {
            Status = {
              type = 'select',
              select = { name = 'Done' },
            },
          },
        }

        local row = database.DatabaseRow.new(raw)

        assert.are.equal('Untitled', row:get_title())
      end)

      it('should find title property regardless of name', function()
        local raw = {
          id = 'page-1',
          properties = {
            ['Task Name'] = {
              type = 'title',
              title = { { plain_text = 'Custom Title Prop' } },
            },
          },
        }

        local row = database.DatabaseRow.new(raw)

        assert.are.equal('Custom Title Prop', row:get_title())
      end)
    end)

    describe('get_property', function()
      it('should return nil for non-existent property', function()
        local raw = {
          id = 'page-1',
          properties = {},
        }

        local row = database.DatabaseRow.new(raw)

        assert.is_nil(row:get_property('NonExistent'))
      end)

      it('should return select value', function()
        local raw = {
          id = 'page-1',
          properties = {
            Status = {
              type = 'select',
              select = { name = 'In Progress', color = 'blue' },
            },
          },
        }

        local row = database.DatabaseRow.new(raw)
        local prop = row:get_property('Status')

        assert.are.equal('select', prop.type)
        assert.are.equal('In Progress', prop.value.name)
        assert.are.equal('blue', prop.value.color)
      end)

      it('should return nil select when empty', function()
        local raw = {
          id = 'page-1',
          properties = {
            Status = {
              type = 'select',
              select = nil,
            },
          },
        }

        local row = database.DatabaseRow.new(raw)
        local prop = row:get_property('Status')

        assert.are.equal('select', prop.type)
        assert.is_nil(prop.value)
      end)

      it('should return multi_select values', function()
        local raw = {
          id = 'page-1',
          properties = {
            Tags = {
              type = 'multi_select',
              multi_select = {
                { name = 'urgent', color = 'red' },
                { name = 'important', color = 'orange' },
              },
            },
          },
        }

        local row = database.DatabaseRow.new(raw)
        local prop = row:get_property('Tags')

        assert.are.equal('multi_select', prop.type)
        assert.are.equal(2, #prop.value)
        assert.are.equal('urgent', prop.value[1].name)
      end)

      it('should return checkbox value', function()
        local raw = {
          id = 'page-1',
          properties = {
            Done = {
              type = 'checkbox',
              checkbox = true,
            },
          },
        }

        local row = database.DatabaseRow.new(raw)
        local prop = row:get_property('Done')

        assert.are.equal('checkbox', prop.type)
        assert.is_true(prop.value)
      end)

      it('should return number value', function()
        local raw = {
          id = 'page-1',
          properties = {
            Price = {
              type = 'number',
              number = 42.5,
            },
          },
        }

        local row = database.DatabaseRow.new(raw)
        local prop = row:get_property('Price')

        assert.are.equal('number', prop.type)
        assert.are.equal(42.5, prop.value)
      end)

      it('should return date value', function()
        local raw = {
          id = 'page-1',
          properties = {
            ['Due Date'] = {
              type = 'date',
              date = { start = '2024-12-31', ['end'] = nil },
            },
          },
        }

        local row = database.DatabaseRow.new(raw)
        local prop = row:get_property('Due Date')

        assert.are.equal('date', prop.type)
        assert.are.equal('2024-12-31', prop.value.start)
      end)

      it('should return rich_text value', function()
        local raw = {
          id = 'page-1',
          properties = {
            Description = {
              type = 'rich_text',
              rich_text = { { plain_text = 'Some description' } },
            },
          },
        }

        local row = database.DatabaseRow.new(raw)
        local prop = row:get_property('Description')

        assert.are.equal('rich_text', prop.type)
        assert.are.equal('Some description', prop.value)
      end)

      it('should return url value', function()
        local raw = {
          id = 'page-1',
          properties = {
            Website = {
              type = 'url',
              url = 'https://example.com',
            },
          },
        }

        local row = database.DatabaseRow.new(raw)
        local prop = row:get_property('Website')

        assert.are.equal('url', prop.type)
        assert.are.equal('https://example.com', prop.value)
      end)

      it('should return created_time value', function()
        local raw = {
          id = 'page-1',
          properties = {
            Created = {
              type = 'created_time',
              created_time = '2024-01-15T10:30:00.000Z',
            },
          },
        }

        local row = database.DatabaseRow.new(raw)
        local prop = row:get_property('Created')

        assert.are.equal('created_time', prop.type)
        assert.are.equal('2024-01-15T10:30:00.000Z', prop.value)
      end)

      it('should return status value', function()
        local raw = {
          id = 'page-1',
          properties = {
            Status = {
              type = 'status',
              status = { name = 'In Progress', color = 'blue' },
            },
          },
        }

        local row = database.DatabaseRow.new(raw)
        local prop = row:get_property('Status')

        assert.are.equal('status', prop.type)
        assert.are.equal('In Progress', prop.value.name)
        assert.are.equal('blue', prop.value.color)
      end)

      it('should return people value', function()
        local raw = {
          id = 'page-1',
          properties = {
            Assignee = {
              type = 'people',
              people = {
                { id = 'user-1', name = 'John Doe' },
              },
            },
          },
        }

        local row = database.DatabaseRow.new(raw)
        local prop = row:get_property('Assignee')

        assert.are.equal('people', prop.type)
        assert.are.equal(1, #prop.value)
        assert.are.equal('John Doe', prop.value[1].name)
      end)

      it('should return unique_id value', function()
        local raw = {
          id = 'page-1',
          properties = {
            ID = {
              type = 'unique_id',
              unique_id = { prefix = 'TASK', number = 42 },
            },
          },
        }

        local row = database.DatabaseRow.new(raw)
        local prop = row:get_property('ID')

        assert.are.equal('unique_id', prop.type)
        assert.are.equal('TASK', prop.value.prefix)
        assert.are.equal(42, prop.value.number)
      end)
    end)

    describe('get_property_names', function()
      it('should return all property names', function()
        local raw = {
          id = 'page-1',
          properties = {
            Name = { type = 'title', title = {} },
            Status = { type = 'select', select = nil },
            Done = { type = 'checkbox', checkbox = false },
          },
        }

        local row = database.DatabaseRow.new(raw)
        local names = row:get_property_names()

        assert.are.equal(3, #names)
        assert.is_truthy(vim.tbl_contains(names, 'Name'))
        assert.is_truthy(vim.tbl_contains(names, 'Status'))
        assert.is_truthy(vim.tbl_contains(names, 'Done'))
      end)
    end)

    describe('format', function()
      it('should return title as single line', function()
        local raw = {
          id = 'page-1',
          properties = {
            Name = {
              type = 'title',
              title = { { plain_text = 'My Row' } },
            },
          },
        }

        local row = database.DatabaseRow.new(raw)
        local lines = row:format()

        assert.are.equal(1, #lines)
        assert.are.equal('My Row', lines[1])
      end)

      it('should return Untitled for empty row', function()
        local raw = {
          id = 'page-1',
          properties = {},
        }

        local row = database.DatabaseRow.new(raw)
        local lines = row:format()

        assert.are.equal(1, #lines)
        assert.are.equal('Untitled', lines[1])
      end)
    end)

    describe('set_line_range', function()
      it('should set buffer line range', function()
        local raw = { id = 'page-1', properties = {} }
        local row = database.DatabaseRow.new(raw)

        row:set_line_range(5, 5)

        local line_start, line_end = row:get_line_range()
        assert.are.equal(5, line_start)
        assert.are.equal(5, line_end)
      end)
    end)

    describe('contains_line', function()
      it('should return true when line is within range', function()
        local raw = { id = 'page-1', properties = {} }
        local row = database.DatabaseRow.new(raw)
        row:set_line_range(3, 5)

        assert.is_true(row:contains_line(3))
        assert.is_true(row:contains_line(4))
        assert.is_true(row:contains_line(5))
      end)

      it('should return false when line is outside range', function()
        local raw = { id = 'page-1', properties = {} }
        local row = database.DatabaseRow.new(raw)
        row:set_line_range(3, 5)

        assert.is_false(row:contains_line(2))
        assert.is_false(row:contains_line(6))
      end)

      it('should return false when no line range set', function()
        local raw = { id = 'page-1', properties = {} }
        local row = database.DatabaseRow.new(raw)

        assert.is_false(row:contains_line(1))
      end)
    end)

    describe('get_icon', function()
      it('should return emoji icon', function()
        local raw = {
          id = 'page-1',
          icon = { type = 'emoji', emoji = '📋' },
          properties = {},
        }

        local row = database.DatabaseRow.new(raw)

        assert.are.equal('📋', row:get_icon())
      end)

      it('should return nil for no icon', function()
        local raw = {
          id = 'page-1',
          properties = {},
        }

        local row = database.DatabaseRow.new(raw)

        assert.is_nil(row:get_icon())
      end)

      it('should return placeholder for external icon', function()
        local raw = {
          id = 'page-1',
          icon = { type = 'external', external = { url = 'http://example.com/icon.png' } },
          properties = {},
        }

        local row = database.DatabaseRow.new(raw)

        -- nf-fa-image placeholder
        assert.are.equal('\u{f03e}', row:get_icon())
      end)
    end)
  end)

  describe('deserialize_database_rows', function()
    it('should convert raw pages to DatabaseRow array', function()
      local raw_pages = {
        {
          id = 'page-1',
          properties = {
            Name = { type = 'title', title = { { plain_text = 'Row 1' } } },
          },
        },
        {
          id = 'page-2',
          properties = {
            Name = { type = 'title', title = { { plain_text = 'Row 2' } } },
          },
        },
      }

      local rows = database.deserialize_database_rows(raw_pages)

      assert.are.equal(2, #rows)
      assert.are.equal('page-1', rows[1].id)
      assert.are.equal('Row 1', rows[1]:get_title())
      assert.are.equal('page-2', rows[2].id)
      assert.are.equal('Row 2', rows[2]:get_title())
    end)

    it('should return empty array for empty input', function()
      local rows = database.deserialize_database_rows({})

      assert.are.equal(0, #rows)
    end)

    it('should return empty array for nil input', function()
      local rows = database.deserialize_database_rows(nil)

      assert.are.equal(0, #rows)
    end)
  end)
end)
