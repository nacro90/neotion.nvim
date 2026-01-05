---Notion Pages API
---@class neotion.api.Pages
local M = {}

---@class neotion.api.Page
---@field id string Page ID
---@field created_time string ISO timestamp
---@field last_edited_time string ISO timestamp
---@field archived boolean
---@field icon table|nil
---@field cover table|nil
---@field properties table
---@field parent table
---@field url string

---@class neotion.api.PageListResult
---@field pages neotion.api.Page[]
---@field has_more boolean
---@field next_cursor string|nil
---@field error string|nil

---@class neotion.api.PageResult
---@field page neotion.api.Page|nil
---@field error string|nil

---Get a page by ID
---@param page_id string
---@param callback fun(result: neotion.api.PageResult)
function M.get(page_id, callback)
  local auth = require('neotion.api.auth')
  local throttle = require('neotion.api.throttle')

  local token_result = auth.get_token()
  if not token_result.token then
    callback({ page = nil, error = token_result.error })
    return
  end

  -- Normalize page ID (remove dashes if present)
  local normalized_id = page_id:gsub('-', '')

  throttle.get('/pages/' .. normalized_id, token_result.token, function(response)
    if response.cancelled then
      callback({ page = nil, error = 'Request cancelled' })
      return
    end
    if response.error then
      callback({ page = nil, error = response.error })
    else
      callback({ page = response.body, error = nil })
    end
  end)
end

---Search for pages accessible by the integration
---@param query? string Search query (optional)
---@param callback fun(result: neotion.api.PageListResult)
function M.search(query, callback)
  local auth = require('neotion.api.auth')
  local throttle = require('neotion.api.throttle')

  local token_result = auth.get_token()
  if not token_result.token then
    callback({ pages = {}, has_more = false, error = token_result.error })
    return
  end

  local body = {
    filter = { property = 'object', value = 'page' },
    page_size = 100,
  }

  if query and query ~= '' then
    body.query = query
  end

  throttle.post('/search', token_result.token, body, function(response)
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

---@class neotion.api.SearchHandle
---@field request_id string The request ID for cancellation
---@field cancel fun(): boolean Function to cancel the request

---Search for pages with cancellation support (for live search)
---@param query? string Search query (optional)
---@param callback fun(result: neotion.api.PageListResult)
---@return neotion.api.SearchHandle|nil handle Request handle with cancel function, or nil if auth failed
function M.search_with_cancel(query, callback)
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

  local body = {
    filter = { property = 'object', value = 'page' },
    page_size = 100,
  }

  if query and query ~= '' then
    body.query = query
  end

  local request_id = throttle.post('/search', token_result.token, body, function(response)
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

  return {
    request_id = request_id,
    cancel = function()
      return throttle.cancel(request_id)
    end,
  }
end

---Extract page title from properties
---@param page neotion.api.Page
---@return string
function M.get_title(page)
  if not page or not page.properties then
    return 'Untitled'
  end

  -- Find title property
  for _, prop in pairs(page.properties) do
    if prop.type == 'title' and prop.title then
      local parts = {}
      for _, text in ipairs(prop.title) do
        if text.plain_text then
          table.insert(parts, text.plain_text)
        end
      end
      if #parts > 0 then
        return table.concat(parts)
      end
    end
  end

  return 'Untitled'
end

---Extract parent info from page
---@param page neotion.api.Page
---@return string type, string|nil id
function M.get_parent(page)
  if not page or not page.parent then
    return 'unknown', nil
  end

  local parent = page.parent
  if parent.type == 'workspace' then
    return 'workspace', nil
  elseif parent.type == 'page_id' then
    return 'page', parent.page_id
  elseif parent.type == 'database_id' then
    return 'database', parent.database_id
  end

  return 'unknown', nil
end

---Extract icon from page (handles vim.NIL safely)
---@param page neotion.api.Page
---@return string|nil icon Emoji or nil if no icon
function M.get_icon(page)
  -- Check for nil, missing field, or vim.NIL (userdata from cjson)
  if not page or not page.icon or type(page.icon) ~= 'table' then
    return nil
  end

  if page.icon.type == 'emoji' then
    return page.icon.emoji
  elseif page.icon.type == 'external' and page.icon.external then
    -- External icons are URLs, return a placeholder
    return '🔗'
  elseif page.icon.type == 'file' and page.icon.file then
    -- File icons are uploaded images, return a placeholder
    return '📄'
  end

  return nil
end

return M
