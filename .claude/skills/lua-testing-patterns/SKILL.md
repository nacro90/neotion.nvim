---
name: lua-testing-patterns
description: Neovim Lua plugin test patterns. Serena/busted framework, mocking, async testing.
---

# Lua Testing Patterns

## Serena Test Yapısı
```lua
-- spec/unit/my_module_spec.lua

describe("my_module", function()
  local my_module
  
  before_each(function()
    -- Her test öncesi temiz state
    package.loaded["neotion.my_module"] = nil
    my_module = require("neotion.my_module")
  end)
  
  after_each(function()
    -- Cleanup
  end)
  
  describe("function_name", function()
    it("should do something", function()
      local result = my_module.function_name()
      assert.are.equal("expected", result)
    end)
    
    it("should handle edge case", function()
      assert.has_error(function()
        my_module.function_name(nil)
      end, "expected error message")
    end)
  end)
end)
```

## Assertions
```lua
-- Equality
assert.are.equal(expected, actual)
assert.are.same({a = 1}, {a = 1})  -- Deep equal
assert.are_not.equal(a, b)

-- Truthiness
assert.is_true(value)
assert.is_false(value)
assert.is_nil(value)
assert.is_not_nil(value)
assert.truthy(value)
assert.falsy(value)

-- Types
assert.is_string(value)
assert.is_number(value)
assert.is_table(value)
assert.is_function(value)

-- Errors
assert.has_error(fn)
assert.has_error(fn, "message")
assert.has_no_error(fn)

-- Strings
assert.matches("pattern", string)
assert.has_match("pattern", string)

-- Tables
assert.contains(element, table)
assert.has_key(key, table)
```

## Mocking

### vim.* Functions
```lua
-- Mock vim.notify
local notify_calls = {}
local original_notify = vim.notify

before_each(function()
  notify_calls = {}
  vim.notify = function(msg, level, opts)
    table.insert(notify_calls, {msg = msg, level = level, opts = opts})
  end
end)

after_each(function()
  vim.notify = original_notify
end)

it("should notify on error", function()
  my_module.do_something_bad()
  assert.are.equal(1, #notify_calls)
  assert.are.equal(vim.log.levels.ERROR, notify_calls[1].level)
end)
```

### API Responses
```lua
-- Mock HTTP client
local mock_responses = {}

local function mock_api_client()
  return {
    request = function(method, url, opts)
      local key = method .. ":" .. url
      return mock_responses[key] or {status = 404, body = ""}
    end
  }
end

before_each(function()
  -- Inject mock
  package.loaded["neotion.api.client"] = mock_api_client()
end)

it("should parse page response", function()
  mock_responses["GET:/v1/pages/123"] = {
    status = 200,
    body = '{"id": "123", "properties": {}}'
  }
  
  local page = require("neotion.api.pages").get("123")
  assert.are.equal("123", page.id)
end)
```

### Buffer Operations
```lua
local function create_test_buffer(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  return buf
end

it("should parse buffer content", function()
  local buf = create_test_buffer({
    "§ page:abc123",
    "",
    "# Heading",
    "Paragraph text",
  })
  
  local result = require("neotion.buffer.format").parse(buf)
  
  assert.are.equal("abc123", result.page_id)
  assert.are.equal(2, #result.blocks)
  
  vim.api.nvim_buf_delete(buf, {force = true})
end)
```

## Async Testing
```lua
-- Async helper
local function async_test(fn)
  local co = coroutine.create(fn)
  local success, err = coroutine.resume(co)
  
  -- Wait for completion
  vim.wait(5000, function()
    return coroutine.status(co) == "dead"
  end, 10)
  
  if not success then
    error(err)
  end
end

describe("async operations", function()
  it("should fetch page", function()
    async_test(function()
      local result = nil
      
      require("neotion.api.pages").get("123", function(err, page)
        result = {err = err, page = page}
      end)
      
      -- Wait for callback
      vim.wait(1000, function() return result ~= nil end)
      
      assert.is_nil(result.err)
      assert.is_not_nil(result.page)
    end)
  end)
end)
```

## Integration Testing
```lua
-- spec/integration/sync_spec.lua

describe("sync integration", function()
  local buf
  
  before_each(function()
    -- Real buffer setup
    vim.cmd("new")
    buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].filetype = "neotion"
  end)
  
  after_each(function()
    vim.cmd("bdelete!")
  end)
  
  it("should sync on save", function()
    -- Setup
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "§ page:test123",
      "",
      "New content",
    })
    
    -- Trigger save
    vim.cmd("write")
    
    -- Assert sync was triggered
    -- (check mock API calls, statusline, etc.)
  end)
end)
```

## Snapshot Testing
```lua
local function snapshot(name, value)
  local snapshot_dir = "spec/snapshots/"
  local path = snapshot_dir .. name .. ".snap"
  
  local serialized = vim.inspect(value)
  
  if vim.fn.filereadable(path) == 1 then
    local expected = vim.fn.readfile(path)
    assert.are.same(expected, vim.split(serialized, "\n"))
  else
    -- Create snapshot
    vim.fn.mkdir(snapshot_dir, "p")
    vim.fn.writefile(vim.split(serialized, "\n"), path)
  end
end

it("should format blocks correctly", function()
  local blocks = parser.parse(test_input)
  snapshot("formatted_blocks", blocks)
end)
```

## Test Fixtures
```lua
-- spec/fixtures/notion_responses.lua
return {
  simple_page = {
    object = "page",
    id = "test-page-id",
    properties = {
      title = {
        type = "title",
        title = {{text = {content = "Test Page"}}}
      }
    }
  },
  
  paragraph_block = {
    object = "block",
    id = "block-id",
    type = "paragraph",
    paragraph = {
      rich_text = {{text = {content = "Hello"}}}
    }
  },
}

-- Kullanım
local fixtures = require("spec.fixtures.notion_responses")
mock_responses["GET:/v1/pages/123"] = {
  status = 200,
  body = vim.json.encode(fixtures.simple_page)
}
```

## CI Configuration
```yaml
# .github/workflows/ci.yml
test:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    
    - uses: rhysd/action-setup-vim@v1
      with:
        neovim: true
        version: stable
    
    - name: Install dependencies
      run: |
        git clone --depth 1 https://github.com/your/serena.nvim ~/.local/share/nvim/site/pack/test/start/serena.nvim
    
    - name: Run tests
      run: |
        nvim --headless -c "lua require('serena').run('spec/')" -c "qa!"
```

## minimal_init.lua
```lua
-- spec/minimal_init.lua

-- Paths
vim.opt.rtp:prepend(".")
vim.opt.rtp:prepend("~/.local/share/nvim/site/pack/test/start/serena.nvim")

-- Disable plugins
vim.g.loaded_matchparen = 1
vim.g.loaded_netrwPlugin = 1

-- Load serena
require("serena").setup({
  output_file = "test-results.txt",
})

-- Load plugin
require("neotion").setup({
  api_token = "test_token",
})
```
