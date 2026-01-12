---Notion Databases API
---@class neotion.api.Databases
local M = {}

---@class neotion.api.Database
---@field id string Database ID
---@field title table[] Rich text array
---@field properties table<string, neotion.api.DatabaseProperty>
---@field icon table|nil
---@field cover table|nil
---@field parent table
---@field created_time string ISO timestamp
---@field last_edited_time string ISO timestamp
---@field archived boolean
---@field is_inline boolean
---@field url string

---@class neotion.api.DatabaseProperty
---@field id string Property ID
---@field name string Property name
---@field type string Property type (title, select, date, etc.)

---@class neotion.api.DatabaseResult
---@field database neotion.api.Database|nil
---@field error string|nil

---@class neotion.api.DatabaseQueryOpts
---@field filter? table Filter object
---@field sorts? table[] Sort array
---@field page_size? number Results per page (max 100)
---@field start_cursor? string Pagination cursor

---@class neotion.api.DatabaseQueryResult
---@field pages neotion.api.Page[]
---@field has_more boolean
---@field next_cursor string|nil
---@field error string|nil

---@class neotion.api.DatabaseQueryHandle
---@field request_id string The request ID for cancellation
---@field cancel fun(): boolean Function to cancel the request

---Get a database by ID (retrieves schema)
---@param database_id string
---@param callback fun(result: neotion.api.DatabaseResult)
function M.get(database_id, callback)
  local auth = require('neotion.api.auth')
  local throttle = require('neotion.api.throttle')

  local token_result = auth.get_token()
  if not token_result.token then
    callback({ database = nil, error = token_result.error })
    return
  end

  -- Normalize database ID (remove dashes if present)
  local normalized_id = database_id:gsub('-', '')

  throttle.get('/databases/' .. normalized_id, token_result.token, function(response)
    if response.cancelled then
      callback({ database = nil, error = 'Request cancelled' })
      return
    end
    if response.error then
      callback({ database = nil, error = response.error })
    else
      callback({ database = response.body, error = nil })
    end
  end)
end

---Query a database (get rows/pages)
---@param database_id string
---@param opts neotion.api.DatabaseQueryOpts
---@param callback fun(result: neotion.api.DatabaseQueryResult)
function M.query(database_id, opts, callback)
  local auth = require('neotion.api.auth')
  local throttle = require('neotion.api.throttle')

  local token_result = auth.get_token()
  if not token_result.token then
    callback({ pages = {}, has_more = false, error = token_result.error })
    return
  end

  -- Normalize database ID (remove dashes if present)
  local normalized_id = database_id:gsub('-', '')

  local body = {
    page_size = opts.page_size or 100,
  }

  if opts.filter then
    body.filter = opts.filter
  end

  if opts.sorts then
    body.sorts = opts.sorts
  end

  if opts.start_cursor then
    body.start_cursor = opts.start_cursor
  end

  throttle.post('/databases/' .. normalized_id .. '/query', token_result.token, body, function(response)
    if response.cancelled then
      callback({ pages = {}, has_more = false, error = 'Request cancelled' })
      return
    end
    if response.error then
      callback({ pages = {}, has_more = false, error = response.error })
      return
    end

    local pages = response.body.results or {}
    callback({
      pages = pages,
      has_more = response.body.has_more or false,
      next_cursor = response.body.next_cursor,
      error = nil,
    })
  end)
end

---Query a database with cancellation support (for live search)
---@param database_id string
---@param opts neotion.api.DatabaseQueryOpts
---@param callback fun(result: neotion.api.DatabaseQueryResult)
---@return neotion.api.DatabaseQueryHandle|nil handle Request handle with cancel function, or nil if auth failed
function M.query_with_cancel(database_id, opts, callback)
  local auth = require('neotion.api.auth')
  local throttle = require('neotion.api.throttle')

  local token_result = auth.get_token()
  if not token_result.token then
    -- Schedule callback to maintain async semantics
    vim.schedule(function()
      callback({ pages = {}, has_more = false, error = token_result.error })
    end)
    return nil
  end

  -- Normalize database ID (remove dashes if present)
  local normalized_id = database_id:gsub('-', '')

  local body = {
    page_size = opts.page_size or 100,
  }

  if opts.filter then
    body.filter = opts.filter
  end

  if opts.sorts then
    body.sorts = opts.sorts
  end

  if opts.start_cursor then
    body.start_cursor = opts.start_cursor
  end

  local request_id = throttle.post(
    '/databases/' .. normalized_id .. '/query',
    token_result.token,
    body,
    function(response)
      if response.cancelled then
        callback({ pages = {}, has_more = false, error = 'Request cancelled' })
        return
      end
      if response.error then
        callback({ pages = {}, has_more = false, error = response.error })
        return
      end

      local pages = response.body.results or {}
      callback({
        pages = pages,
        has_more = response.body.has_more or false,
        next_cursor = response.body.next_cursor,
        error = nil,
      })
    end
  )

  return {
    request_id = request_id,
    cancel = function()
      return throttle.cancel(request_id)
    end,
  }
end

---Extract database title from title array
---@param database neotion.api.Database
---@return string
function M.get_title(database)
  if not database or not database.title then
    return 'Untitled'
  end

  local parts = {}
  for _, text in ipairs(database.title) do
    if text.plain_text then
      table.insert(parts, text.plain_text)
    end
  end

  if #parts > 0 then
    return table.concat(parts)
  end

  return 'Untitled'
end

---Extract icon from database (handles vim.NIL safely)
---@param database neotion.api.Database
---@return string|nil icon Emoji or nil if no icon
function M.get_icon(database)
  -- Check for nil, missing field, or vim.NIL (userdata from cjson)
  if not database or not database.icon or type(database.icon) ~= 'table' then
    return nil
  end

  if database.icon.type == 'emoji' then
    return database.icon.emoji
  elseif database.icon.type == 'external' and database.icon.external then
    -- External icons are URLs, return Nerd Font image icon
    return '\u{f03e}' -- nf-fa-image
  elseif database.icon.type == 'file' and database.icon.file then
    -- File icons are uploaded images, return Nerd Font image icon
    return '\u{f03e}' -- nf-fa-image
  end

  return nil
end

return M
