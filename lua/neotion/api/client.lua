---@class neotion.api.Client
---@field private base_url string
---@field private version string
local M = {}

---Safely invoke a callback and log errors
---@param callback function The callback to invoke
---@param ... any Arguments to pass to the callback
local function safe_callback(callback, ...)
  local ok, err = pcall(callback, ...)
  if not ok then
    local log = require('neotion.log')
    local logger = log.get_logger('api.client')
    logger.error('Callback error', { error = err })
    -- Re-raise so Neovim shows the error to the user
    error(err)
  end
end

---@class neotion.api.Response
---@field status integer HTTP status code
---@field body table|nil Parsed JSON body
---@field error string|nil Error message if request failed

---@class neotion.api.RequestOpts
---@field method? string HTTP method (default: GET)
---@field body? table Request body (will be JSON encoded)
---@field headers? table<string, string> Additional headers

M.base_url = 'https://api.notion.com/v1'
M.version = '2022-06-28'

---Build headers for Notion API request
---@param token string API token
---@param extra? table<string, string> Additional headers
---@return table<string, string>
local function build_headers(token, extra)
  local headers = {
    ['Authorization'] = 'Bearer ' .. token,
    ['Notion-Version'] = M.version,
    ['Content-Type'] = 'application/json',
  }
  if extra then
    for k, v in pairs(extra) do
      headers[k] = v
    end
  end
  return headers
end

---Convert headers table to curl format
---@param headers table<string, string>
---@return string[]
local function headers_to_curl_args(headers)
  local args = {}
  for k, v in pairs(headers) do
    table.insert(args, '-H')
    table.insert(args, k .. ': ' .. v)
  end
  return args
end

---Parse JSON response safely
---@param str string
---@return table|nil, string|nil
local function parse_json(str)
  if not str or str == '' then
    return nil, 'Empty response'
  end
  local ok, result = pcall(vim.json.decode, str)
  if not ok then
    return nil, 'JSON parse error: ' .. tostring(result)
  end
  return result, nil
end

---Make an async HTTP request to Notion API
---@param endpoint string API endpoint (e.g., '/pages/xxx')
---@param token string API token
---@param opts? neotion.api.RequestOpts Request options
---@param callback fun(response: neotion.api.Response) Callback with response
function M.request(endpoint, token, opts, callback)
  opts = opts or {}
  local method = opts.method or 'GET'
  local url = M.base_url .. endpoint

  local cmd = { 'curl', '-s', '-w', '\n%{http_code}', '--connect-timeout', '10', '--max-time', '30', '-X', method }

  -- Add headers
  local headers = build_headers(token, opts.headers)
  vim.list_extend(cmd, headers_to_curl_args(headers))

  -- Add body for POST/PATCH
  if opts.body then
    local body_json = vim.json.encode(opts.body)
    table.insert(cmd, '-d')
    table.insert(cmd, body_json)
  end

  table.insert(cmd, url)

  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        safe_callback(callback, {
          status = 0,
          body = nil,
          error = 'curl failed: ' .. (result.stderr or 'unknown error'),
        })
        return
      end

      local stdout = result.stdout or ''
      -- Last line is status code
      local lines = vim.split(stdout, '\n', { trimempty = false })
      local status_code = tonumber(lines[#lines]) or 0
      table.remove(lines, #lines)
      local body_str = table.concat(lines, '\n')

      local body, parse_err = parse_json(body_str)

      if status_code >= 400 then
        local err_msg = 'HTTP ' .. status_code
        if body and body.message then
          err_msg = err_msg .. ': ' .. body.message
        end
        safe_callback(callback, {
          status = status_code,
          body = body,
          error = err_msg,
        })
        return
      end

      if parse_err and status_code == 200 then
        safe_callback(callback, {
          status = status_code,
          body = nil,
          error = parse_err,
        })
        return
      end

      safe_callback(callback, {
        status = status_code,
        body = body,
        error = nil,
      })
    end)
  end)
end

---GET request helper
---@param endpoint string
---@param token string
---@param callback fun(response: neotion.api.Response)
function M.get(endpoint, token, callback)
  M.request(endpoint, token, { method = 'GET' }, callback)
end

---POST request helper
---@param endpoint string
---@param token string
---@param body table
---@param callback fun(response: neotion.api.Response)
function M.post(endpoint, token, body, callback)
  M.request(endpoint, token, { method = 'POST', body = body }, callback)
end

---PATCH request helper
---@param endpoint string
---@param token string
---@param body table
---@param callback fun(response: neotion.api.Response)
function M.patch(endpoint, token, body, callback)
  M.request(endpoint, token, { method = 'PATCH', body = body }, callback)
end

return M
