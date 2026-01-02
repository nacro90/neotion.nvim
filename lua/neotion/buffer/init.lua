---Buffer management for Neotion
---@class neotion.buffer
local M = {}

---@alias neotion.BufferStatus 'loading'|'ready'|'modified'|'syncing'|'error'

---@class neotion.BufferData
---@field page_id string
---@field page_title string
---@field parent_type string
---@field parent_id string|nil
---@field last_sync string|nil ISO timestamp
---@field status neotion.BufferStatus Current buffer state

-- Store buffer metadata
---@type table<integer, neotion.BufferData>
local buffer_data = {}

---@class neotion.RecentPage
---@field page_id string
---@field title string
---@field icon? string
---@field parent_type? string
---@field accessed_at number Timestamp

-- Store recent pages (persists across buffer deletions)
---@type neotion.RecentPage[]
local recent_pages = {}

-- Maximum number of recent pages to track
local MAX_RECENT = 20

---Create or get buffer for a page
---@param page_id string
---@return integer bufnr
---@return boolean is_new True if buffer was newly created
function M.create(page_id)
  -- Check if buffer already exists
  local existing = M.find_by_page_id(page_id)
  if existing then
    return existing, false
  end

  -- Create new buffer
  local bufnr = vim.api.nvim_create_buf(true, false)

  -- Set buffer options
  vim.bo[bufnr].buftype = 'acwrite'
  vim.bo[bufnr].filetype = 'neotion'
  vim.bo[bufnr].modifiable = false

  -- Set buffer name
  local normalized_id = page_id:gsub('-', '')
  local short_id = normalized_id:sub(1, 8)
  vim.api.nvim_buf_set_name(bufnr, 'neotion://' .. short_id)

  -- Initialize buffer data
  buffer_data[bufnr] = {
    page_id = normalized_id,
    page_title = 'Loading...',
    parent_type = 'unknown',
    parent_id = nil,
    last_sync = nil,
    status = 'loading',
  }

  -- Set up autocmd for buffer deletion
  vim.api.nvim_create_autocmd('BufDelete', {
    buffer = bufnr,
    callback = function()
      buffer_data[bufnr] = nil
    end,
  })

  return bufnr, true
end

---Find buffer by page ID
---@param page_id string
---@return integer|nil bufnr
function M.find_by_page_id(page_id)
  local normalized_id = page_id:gsub('-', '')
  for bufnr, data in pairs(buffer_data) do
    if data.page_id == normalized_id and vim.api.nvim_buf_is_valid(bufnr) then
      return bufnr
    end
  end
  return nil
end

---Get buffer data
---@param bufnr integer
---@return neotion.BufferData|nil
function M.get_data(bufnr)
  return buffer_data[bufnr]
end

---Update buffer data
---@param bufnr integer
---@param updates table Partial updates
function M.update_data(bufnr, updates)
  if not buffer_data[bufnr] then
    return
  end
  for k, v in pairs(updates) do
    buffer_data[bufnr][k] = v
  end

  -- Update buffer name if title changed
  if updates.page_title then
    local data = buffer_data[bufnr]
    local short_id = data.page_id:sub(1, 8)
    local safe_title = updates.page_title:gsub('[/\\]', '_'):sub(1, 30)
    vim.api.nvim_buf_set_name(bufnr, 'neotion://' .. short_id .. ' ' .. safe_title)
  end
end

---Set buffer content
---@param bufnr integer
---@param lines string[]
function M.set_content(bufnr, lines)
  vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
  vim.api.nvim_set_option_value('modified', false, { buf = bufnr })
end

---Check if buffer is a neotion buffer
---@param bufnr? integer
---@return boolean
function M.is_neotion_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return buffer_data[bufnr] ~= nil
end

---Check if buffer is currently loading
---@param bufnr integer
---@return boolean
function M.is_loading(bufnr)
  local data = buffer_data[bufnr]
  return data ~= nil and data.status == 'loading'
end

---Set buffer status and emit status change event
---@param bufnr integer
---@param status neotion.BufferStatus
function M.set_status(bufnr, status)
  if not buffer_data[bufnr] then
    return
  end
  local old_status = buffer_data[bufnr].status
  buffer_data[bufnr].status = status
  if old_status ~= status then
    vim.api.nvim_exec_autocmds('User', { pattern = 'NeotionStatusChanged', data = { bufnr = bufnr, status = status } })
  end
end

---Get buffer status
---@param bufnr integer
---@return neotion.BufferStatus|nil
function M.get_status(bufnr)
  local data = buffer_data[bufnr]
  return data and data.status
end

---Open buffer in current window
---@param bufnr integer
function M.open(bufnr)
  vim.api.nvim_set_current_buf(bufnr)
end

---Get all active neotion buffers
---@return integer[]
function M.list()
  local buffers = {}
  for bufnr in pairs(buffer_data) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      table.insert(buffers, bufnr)
    end
  end
  return buffers
end

---Add or update a page in recent history
---@param page_id string
---@param title string
---@param icon? string
---@param parent_type? string
function M.add_recent(page_id, title, icon, parent_type)
  local normalized_id = page_id:gsub('-', '')

  -- Remove if already exists
  for i, item in ipairs(recent_pages) do
    if item.page_id == normalized_id then
      table.remove(recent_pages, i)
      break
    end
  end

  -- Add to front
  table.insert(recent_pages, 1, {
    page_id = normalized_id,
    title = title,
    icon = icon,
    parent_type = parent_type,
    accessed_at = os.time(),
  })

  -- Trim to max size
  while #recent_pages > MAX_RECENT do
    table.remove(recent_pages)
  end
end

---Get recent pages
---@return neotion.RecentPage[]
function M.get_recent()
  return recent_pages
end

---Clear recent pages
function M.clear_recent()
  recent_pages = {}
end

return M
