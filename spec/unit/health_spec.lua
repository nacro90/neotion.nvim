describe('neotion.health', function()
  local health

  before_each(function()
    package.loaded['neotion.health'] = nil
    health = require('neotion.health')
  end)

  describe('module structure', function()
    it('should have check function', function()
      assert.is_function(health.check)
    end)
  end)

  describe('check', function()
    -- Mock vim.health functions for testing
    local health_calls = {}

    before_each(function()
      health_calls = { ok = {}, warn = {}, error = {}, info = {}, start = {} }

      -- Save original functions
      local original_health = vim.health

      -- Mock vim.health
      vim.health = {
        ok = function(msg)
          table.insert(health_calls.ok, msg)
        end,
        warn = function(msg, advice)
          table.insert(health_calls.warn, { msg = msg, advice = advice })
        end,
        error = function(msg, advice)
          table.insert(health_calls.error, { msg = msg, advice = advice })
        end,
        info = function(msg)
          table.insert(health_calls.info, msg)
        end,
        start = function(name)
          table.insert(health_calls.start, name)
        end,
      }
    end)

    it('should start health check sections', function()
      health.check()

      assert.is_truthy(#health_calls.start > 0)
    end)

    it('should check neovim version', function()
      health.check()

      -- Should have at least one ok or error for version
      local version_checked = false
      for _, msg in ipairs(health_calls.ok) do
        if msg:match('Neovim version') then
          version_checked = true
        end
      end
      for _, item in ipairs(health_calls.error) do
        if item.msg:match('Neovim') then
          version_checked = true
        end
      end

      assert.is_true(version_checked)
    end)

    it('should check curl availability', function()
      health.check()

      local curl_checked = false
      for _, msg in ipairs(health_calls.ok) do
        if msg:match('curl') then
          curl_checked = true
        end
      end
      for _, item in ipairs(health_calls.error) do
        if item.msg:match('curl') then
          curl_checked = true
        end
      end

      assert.is_true(curl_checked)
    end)
  end)
end)
