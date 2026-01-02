describe('neotion.api.pages', function()
  local pages

  before_each(function()
    package.loaded['neotion.api.pages'] = nil
    pages = require('neotion.api.pages')
  end)

  describe('get_title', function()
    it('should return Untitled for nil page', function()
      local title = pages.get_title(nil)

      assert.are.equal('Untitled', title)
    end)

    it('should return Untitled for page without properties', function()
      local title = pages.get_title({})

      assert.are.equal('Untitled', title)
    end)

    it('should extract title from page properties', function()
      local page = {
        properties = {
          Name = {
            type = 'title',
            title = {
              { plain_text = 'My Page Title' },
            },
          },
        },
      }

      local title = pages.get_title(page)

      assert.are.equal('My Page Title', title)
    end)

    it('should concatenate multiple title parts', function()
      local page = {
        properties = {
          Name = {
            type = 'title',
            title = {
              { plain_text = 'Part 1 ' },
              { plain_text = 'Part 2' },
            },
          },
        },
      }

      local title = pages.get_title(page)

      assert.are.equal('Part 1 Part 2', title)
    end)

    it('should return Untitled for empty title array', function()
      local page = {
        properties = {
          Name = {
            type = 'title',
            title = {},
          },
        },
      }

      local title = pages.get_title(page)

      assert.are.equal('Untitled', title)
    end)

    it('should handle title parts without plain_text', function()
      local page = {
        properties = {
          Name = {
            type = 'title',
            title = {
              { text = { content = 'ignored' } },
              { plain_text = 'visible' },
            },
          },
        },
      }

      local title = pages.get_title(page)

      assert.are.equal('visible', title)
    end)
  end)

  describe('get_parent', function()
    it('should return unknown for nil page', function()
      local parent_type, parent_id = pages.get_parent(nil)

      assert.are.equal('unknown', parent_type)
      assert.is_nil(parent_id)
    end)

    it('should return unknown for page without parent', function()
      local parent_type, parent_id = pages.get_parent({})

      assert.are.equal('unknown', parent_type)
      assert.is_nil(parent_id)
    end)

    it('should extract workspace parent', function()
      local page = {
        parent = {
          type = 'workspace',
        },
      }

      local parent_type, parent_id = pages.get_parent(page)

      assert.are.equal('workspace', parent_type)
      assert.is_nil(parent_id)
    end)

    it('should extract page parent', function()
      local page = {
        parent = {
          type = 'page_id',
          page_id = 'parent-page-id-123',
        },
      }

      local parent_type, parent_id = pages.get_parent(page)

      assert.are.equal('page', parent_type)
      assert.are.equal('parent-page-id-123', parent_id)
    end)

    it('should extract database parent', function()
      local page = {
        parent = {
          type = 'database_id',
          database_id = 'db-id-456',
        },
      }

      local parent_type, parent_id = pages.get_parent(page)

      assert.are.equal('database', parent_type)
      assert.are.equal('db-id-456', parent_id)
    end)

    it('should return unknown for unrecognized parent type', function()
      local page = {
        parent = {
          type = 'some_new_type',
        },
      }

      local parent_type, parent_id = pages.get_parent(page)

      assert.are.equal('unknown', parent_type)
      assert.is_nil(parent_id)
    end)
  end)

  -- Note: get() and search() are async and require mocking
  -- These would be integration tests or require a mock client
  describe('get (requires auth)', function()
    it('should call callback with error when no token', function()
      -- Mock auth to return no token
      package.loaded['neotion.api.auth'] = {
        get_token = function()
          return { token = nil, error = 'No API token configured' }
        end,
      }

      local result = nil
      pages.get('test-page-id', function(r)
        result = r
      end)

      -- Wait for callback
      vim.wait(100, function()
        return result ~= nil
      end)

      assert.is_not_nil(result)
      assert.is_nil(result.page)
      assert.is_truthy(result.error:match('No API token'))

      -- Clean up mock
      package.loaded['neotion.api.auth'] = nil
    end)
  end)

  describe('search (requires auth)', function()
    it('should call callback with error when no token', function()
      -- Mock auth to return no token
      package.loaded['neotion.api.auth'] = {
        get_token = function()
          return { token = nil, error = 'No API token configured' }
        end,
      }

      local result = nil
      pages.search('test query', function(r)
        result = r
      end)

      -- Wait for callback
      vim.wait(100, function()
        return result ~= nil
      end)

      assert.is_not_nil(result)
      assert.are.equal(0, #result.pages)
      assert.is_false(result.has_more)
      assert.is_truthy(result.error:match('No API token'))

      -- Clean up mock
      package.loaded['neotion.api.auth'] = nil
    end)
  end)
end)
