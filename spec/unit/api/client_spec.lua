describe('neotion.api.client', function()
  local client

  before_each(function()
    package.loaded['neotion.api.client'] = nil
    client = require('neotion.api.client')
  end)

  describe('module structure', function()
    it('should expose base_url', function()
      assert.is_string(client.base_url)
      assert.is_truthy(client.base_url:match('api%.notion%.com'))
    end)

    it('should expose version', function()
      assert.is_string(client.version)
      assert.is_truthy(client.version:match('%d%d%d%d%-%d%d%-%d%d'))
    end)

    it('should have request method', function()
      assert.is_function(client.request)
    end)

    it('should have get helper', function()
      assert.is_function(client.get)
    end)

    it('should have post helper', function()
      assert.is_function(client.post)
    end)

    it('should have patch helper', function()
      assert.is_function(client.patch)
    end)
  end)

  describe('constants', function()
    it('should use correct Notion API version', function()
      assert.are.equal('2022-06-28', client.version)
    end)

    it('should use correct base URL', function()
      assert.are.equal('https://api.notion.com/v1', client.base_url)
    end)
  end)

  -- Note: Actual HTTP requests require integration tests
  -- Unit tests focus on synchronous utilities and structure
end)
