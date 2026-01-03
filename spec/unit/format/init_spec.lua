---@diagnostic disable: undefined-field
local format = require('neotion.format.init')

describe('neotion.format.init', function()
  describe('register_provider', function()
    it('should register a provider', function()
      local provider = {
        name = 'test',
        parse = function() end,
        render = function() end,
      }

      format.register_provider(provider)

      assert.is_not_nil(format.get_provider('test'))
    end)

    it('should error when provider has no name', function()
      local provider = {
        parse = function() end,
        render = function() end,
      }

      assert.has_error(function()
        format.register_provider(provider)
      end)
    end)

    it('should error when provider has no parse function', function()
      local provider = {
        name = 'test2',
        render = function() end,
      }

      assert.has_error(function()
        format.register_provider(provider)
      end)
    end)

    it('should error when provider has no render function', function()
      local provider = {
        name = 'test3',
        parse = function() end,
      }

      assert.has_error(function()
        format.register_provider(provider)
      end)
    end)
  end)

  describe('get_provider', function()
    before_each(function()
      -- Reset providers
      format._providers = {}
    end)

    it('should return nil for unknown provider', function()
      local provider = format.get_provider('unknown')

      assert.is_nil(provider)
    end)

    it('should return registered provider', function()
      local test_provider = {
        name = 'mytest',
        parse = function() end,
        render = function() end,
      }
      format.register_provider(test_provider)

      local provider = format.get_provider('mytest')

      assert.are.equal('mytest', provider.name)
    end)
  end)

  describe('get_default_provider', function()
    it('should return notion provider by default', function()
      local provider = format.get_default_provider()

      assert.is_not_nil(provider)
      assert.are.equal('notion', provider.name)
    end)
  end)

  describe('set_default_provider', function()
    before_each(function()
      format._providers = {}
      format._default = 'notion'
    end)

    it('should change default provider', function()
      local custom = {
        name = 'custom',
        parse = function() end,
        render = function() end,
      }
      format.register_provider(custom)

      format.set_default_provider('custom')

      assert.are.equal('custom', format.get_default_provider().name)
    end)

    it('should error for unknown provider', function()
      assert.has_error(function()
        format.set_default_provider('nonexistent')
      end)
    end)
  end)

  describe('parse', function()
    it('should delegate to default provider parse', function()
      local called = false
      local test_provider = {
        name = 'parsetest',
        parse = function(text)
          called = true
          return { { text = text, annotations = {} } }
        end,
        render = function() end,
      }
      format.register_provider(test_provider)
      format.set_default_provider('parsetest')

      format.parse('hello')

      assert.is_true(called)
    end)

    it('should use specified provider', function()
      local notion_called = false
      local custom_called = false

      format._providers = {}
      format.register_provider({
        name = 'notion',
        parse = function()
          notion_called = true
          return {}
        end,
        render = function() end,
      })
      format.register_provider({
        name = 'custom',
        parse = function()
          custom_called = true
          return {}
        end,
        render = function() end,
      })
      format._default = 'notion'

      format.parse('test', 'custom')

      assert.is_false(notion_called)
      assert.is_true(custom_called)
    end)
  end)

  describe('render', function()
    it('should delegate to default provider render', function()
      local called = false
      local test_provider = {
        name = 'rendertest',
        parse = function() end,
        render = function(segments)
          called = true
          return 'rendered'
        end,
      }
      format.register_provider(test_provider)
      format.set_default_provider('rendertest')

      format.render({})

      assert.is_true(called)
    end)

    it('should use specified provider', function()
      local notion_called = false
      local custom_called = false

      format._providers = {}
      format.register_provider({
        name = 'notion',
        parse = function() end,
        render = function()
          notion_called = true
          return ''
        end,
      })
      format.register_provider({
        name = 'custom',
        parse = function() end,
        render = function()
          custom_called = true
          return ''
        end,
      })
      format._default = 'notion'

      format.render({}, 'custom')

      assert.is_false(notion_called)
      assert.is_true(custom_called)
    end)
  end)

  describe('list_providers', function()
    before_each(function()
      format._providers = {}
    end)

    it('should return empty table when no providers', function()
      local list = format.list_providers()

      assert.are.equal(0, #list)
    end)

    it('should return all registered provider names', function()
      format.register_provider({
        name = 'a',
        parse = function() end,
        render = function() end,
      })
      format.register_provider({
        name = 'b',
        parse = function() end,
        render = function() end,
      })

      local list = format.list_providers()

      assert.are.equal(2, #list)
      assert.is_true(vim.tbl_contains(list, 'a'))
      assert.is_true(vim.tbl_contains(list, 'b'))
    end)
  end)

  describe('provider interface', function()
    it('should define FormatProvider type', function()
      -- This test documents the expected interface
      ---@class neotion.FormatProvider
      ---@field name string Provider name
      ---@field parse fun(text: string): neotion.RichTextSegment[] Parse text to segments
      ---@field render fun(segments: neotion.RichTextSegment[]): string Render segments to text
      ---@field render_segment? fun(segment: neotion.RichTextSegment): string Render single segment

      -- Just verify the module exists
      assert.is_table(format)
    end)
  end)
end)
