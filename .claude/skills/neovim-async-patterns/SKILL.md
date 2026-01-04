---
name: neovim-async-patterns
description: Neovim'de async programming patterns. vim.loop (libuv), vim.schedule, coroutine kullanımı.
---

# Neovim Async Patterns

## vim.schedule - Main Thread'e Dön

Callback'lerden Neovim API çağrısı yapabilmek için:
```lua
-- YANLIŞ: vim.loop callback'inden direkt API çağrısı
uv.read_start(handle, function(err, data)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {data}) -- CRASH!
end)

-- DOĞRU: vim.schedule ile wrap et
uv.read_start(handle, function(err, data)
  vim.schedule(function()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {data})
  end)
end)
```

## vim.loop (libuv) - Async I/O

### HTTP Request (TCP)
```lua
local uv = vim.loop

---@param opts {method: string, url: string, headers: table, body: string?}
---@param callback fun(err: string?, response: {status: number, body: string})
local function http_request(opts, callback)
  local parsed = parse_url(opts.url)
  local client = uv.new_tcp()
  
  client:connect(parsed.host, parsed.port, function(err)
    if err then
      callback(err, nil)
      return
    end
    
    local request = build_http_request(opts)
    client:write(request)
    
    local response_data = {}
    client:read_start(function(err, chunk)
      if err then
        callback(err, nil)
      elseif chunk then
        table.insert(response_data, chunk)
      else
        client:close()
        local response = parse_http_response(table.concat(response_data))
        vim.schedule(function()
          callback(nil, response)
        end)
      end
    end)
  end)
end
```

### Timer (Debounce)
```lua
local timer = nil

local function debounced_sync(delay_ms)
  if timer then
    timer:stop()
    timer:close()
  end
  
  timer = uv.new_timer()
  timer:start(delay_ms, 0, function()
    timer:close()
    timer = nil
    vim.schedule(function()
      require("neotion.sync").execute()
    end)
  end)
end
```

### File System
```lua
-- Async file read
local function read_file_async(path, callback)
  uv.fs_open(path, "r", 438, function(err, fd)
    if err then return callback(err) end
    
    uv.fs_fstat(fd, function(err, stat)
      if err then return callback(err) end
      
      uv.fs_read(fd, stat.size, 0, function(err, data)
        uv.fs_close(fd)
        vim.schedule(function()
          callback(err, data)
        end)
      end)
    end)
  end)
end
```

## Coroutine Pattern (async/await style)
```lua
local co = coroutine

---@generic T
---@param fn fun(): T
---@return T
local function await(fn)
  local current = co.running()
  local result, err
  
  fn(function(e, r)
    err, result = e, r
    if current then
      co.resume(current)
    end
  end)
  
  co.yield()
  
  if err then error(err) end
  return result
end

---@param fn fun()
local function async(fn)
  local thread = co.create(fn)
  co.resume(thread)
end

-- Usage
async(function()
  local page = await(function(cb)
    notion_api.get_page(page_id, cb)
  end)
  
  local blocks = await(function(cb)
    notion_api.get_blocks(page.id, cb)
  end)
  
  -- Bu noktada her ikisi de hazır
  render_page(page, blocks)
end)
```

## plenary.nvim async (Alternatif)
```lua
local async = require("plenary.async")

local fetch_page = async.wrap(function(page_id, callback)
  notion_api.get_page(page_id, callback)
end, 2)

async.run(function()
  local page = fetch_page(page_id)
  local blocks = fetch_page(page.id)
  render_page(page, blocks)
end)
```

## Job Control (External Process)
```lua
local function run_curl(args, callback)
  local stdout_data = {}
  local stderr_data = {}
  
  vim.fn.jobstart(vim.list_extend({"curl", "-s"}, args), {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      stdout_data = data
    end,
    on_stderr = function(_, data)
      stderr_data = data
    end,
    on_exit = function(_, exit_code)
      if exit_code == 0 then
        callback(nil, table.concat(stdout_data, "\n"))
      else
        callback(table.concat(stderr_data, "\n"), nil)
      end
    end,
  })
end
```

## Best Practices

1. **Her callback'te vim.schedule** - Neovim API kullanacaksan
2. **Error handling** - Her async işlemde hata durumunu handle et
3. **Cleanup** - Timer/handle'ları kapat, memory leak önle
4. **Cancellation** - Uzun işlemleri iptal edebilme mekanizması
5. **Rate limiting** - Çok fazla concurrent request açma

## Anti-Patterns
```lua
-- YANLIŞ: Blocking wait
local result
api_call(function(r) result = r end)
while not result do end -- CPU 100%, UI donuk!

-- YANLIŞ: vim.wait içinde API çağrısı
vim.wait(1000, function()
  return some_condition -- Bu sık çağrılır, pahalı işlem koyma
end)

-- DOĞRU: Callback chain veya coroutine kullan
```
