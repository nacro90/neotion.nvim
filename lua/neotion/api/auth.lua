---Token management for Notion API
---@class neotion.api.Auth
local M = {}

---@class neotion.api.AuthResult
---@field token string|nil The API token if found
---@field source string|nil Where the token came from
---@field error string|nil Error message if token not found

---Get API token from available sources
---Priority: 1. config, 2. vim.g.neotion, 3. env var
---@return neotion.api.AuthResult
function M.get_token()
  -- 1. Check config (setup was called)
  local config = require('neotion.config')
  local cfg = config.get()
  if cfg.api_token and cfg.api_token ~= '' then
    return {
      token = cfg.api_token,
      source = 'config',
      error = nil,
    }
  end

  -- 2. Check vim.g.neotion directly (setup might not be called)
  local g_neotion = vim.g.neotion
  if type(g_neotion) == 'table' and g_neotion.api_token and g_neotion.api_token ~= '' then
    return {
      token = g_neotion.api_token,
      source = 'vim.g.neotion',
      error = nil,
    }
  end

  -- 3. Check environment variable
  local env_token = vim.env.NOTION_API_TOKEN
  if env_token and env_token ~= '' then
    return {
      token = env_token,
      source = 'NOTION_API_TOKEN',
      error = nil,
    }
  end

  return {
    token = nil,
    source = nil,
    error = 'No API token found. Set via setup(), vim.g.neotion, or NOTION_API_TOKEN env var',
  }
end

---Check if token is available
---@return boolean
function M.has_token()
  local result = M.get_token()
  return result.token ~= nil
end

---Validate token format (basic check)
---@param token string
---@return boolean, string|nil
function M.validate_token_format(token)
  if not token or token == '' then
    return false, 'Token is empty'
  end

  -- Notion tokens start with 'secret_' or 'ntn_'
  if not (token:match('^secret_') or token:match('^ntn_')) then
    return false, "Token should start with 'secret_' or 'ntn_'"
  end

  return true, nil
end

---Test token by making a simple API call
---@param callback fun(success: boolean, error: string|nil)
function M.test_connection(callback)
  local result = M.get_token()
  if not result.token then
    callback(false, result.error)
    return
  end

  local client = require('neotion.api.client')
  client.get('/users/me', result.token, function(response)
    if response.error then
      callback(false, response.error)
    else
      callback(true, nil)
    end
  end)
end

return M
