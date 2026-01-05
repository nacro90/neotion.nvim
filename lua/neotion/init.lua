---@brief [[
---neotion.nvim - Notion integration for Neovim
---
---Zero data loss Notion editing with full round-trip sync.
---Preserves block IDs, colors, mentions, toggles, and all rich metadata.
---
---Configuration (all methods are optional):
---
---1. Via vim.g.neotion (before plugin loads):
---   vim.g.neotion = { api_token = 'secret_xxx' }
---
---2. Via setup() (optional, only overrides):
---   require('neotion').setup({ api_token = 'secret_xxx' })
---
---3. Via environment variable:
---   export NOTION_API_TOKEN=secret_xxx
---@brief ]]

---@class Neotion
local M = {}

---Configure neotion (optional, only overrides defaults)
---Configuration can also be done via vim.g.neotion
---@param opts neotion.Config? Optional configuration table
function M.setup(opts)
  local config = require('neotion.config')
  local ok, err = config.setup(opts)

  if not ok then
    vim.notify('[neotion] Configuration error: ' .. (err or 'unknown'), vim.log.levels.ERROR)
  end
end

---Get current configuration
---@return neotion.InternalConfig
function M.get_config()
  return require('neotion.config').get()
end

-- Page Operations

---Validate page ID format (32 hex characters, with or without dashes)
---@param page_id string
---@return boolean is_valid
---@return string|nil error_message
local function validate_page_id(page_id)
  local normalized = page_id:gsub('-', '')
  if #normalized ~= 32 then
    return false, 'Page ID must be 32 hex characters (got ' .. #normalized .. ')'
  end
  if not normalized:match('^%x+$') then
    return false, 'Page ID must contain only hex characters'
  end
  return true, nil
end

--- Helper: Display page content in buffer
---@param bufnr integer Buffer number
---@param page_id string Normalized page ID
---@param page table? Page metadata (nil if from cache)
---@param raw_blocks table[] Raw blocks from API or cache
---@param from_cache boolean Whether loaded from cache
local function display_page_content(bufnr, page_id, page, raw_blocks, from_cache)
  local buffer = require('neotion.buffer')
  local format = require('neotion.buffer.format')
  local model = require('neotion.model')
  local pages_api = require('neotion.api.pages')

  -- Get page info
  local title, parent_type, parent_id, icon
  if page then
    title = pages_api.get_title(page)
    parent_type, parent_id = pages_api.get_parent(page)
    icon = pages_api.get_icon(page)
  else
    -- From cache - use cached metadata
    local cache_pages = require('neotion.cache.pages')
    local cached_meta = cache_pages.get_page(page_id)
    if cached_meta then
      title = cached_meta.title
      parent_type = cached_meta.parent_type
      parent_id = cached_meta.parent_id
      icon = cached_meta.icon
    else
      title = 'Untitled'
      parent_type = 'unknown'
    end
  end

  buffer.update_data(bufnr, {
    page_title = title,
    parent_type = parent_type,
    parent_id = parent_id,
  })

  -- Use model layer for block handling
  local blocks = model.deserialize_blocks(raw_blocks)

  -- Check editability and notify if some blocks are read-only
  local is_fully_editable, unsupported = model.check_editability(blocks)
  if not is_fully_editable then
    vim.notify('[neotion] Some blocks are read-only: ' .. table.concat(unsupported, ', '), vim.log.levels.WARN)
  end

  -- Format header - use page object if available, otherwise create minimal header
  local header_lines
  if page then
    header_lines = format.format_header(page)
  else
    -- Create header from cache data
    header_lines = { '# ' .. title, '' }
  end
  local header_line_count = #header_lines

  -- Format blocks
  local block_lines = model.format_blocks(blocks)

  -- Combine header + blocks
  local lines = {}
  vim.list_extend(lines, header_lines)
  vim.list_extend(lines, block_lines)

  -- Set buffer content
  buffer.set_content(bufnr, lines)

  -- Setup model layer with extmarks
  model.setup_buffer(bufnr, blocks, header_line_count)

  -- Update buffer data
  buffer.update_data(bufnr, {
    last_sync = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    header_line_count = header_line_count,
  })
  buffer.set_status(bufnr, 'ready')

  -- Add to recent pages
  buffer.add_recent(page_id, title, icon, parent_type)

  local source = from_cache and '(cached)' or ''
  vim.notify('[neotion] Loaded: ' .. title .. ' ' .. source, vim.log.levels.INFO)
end

--- Helper: Fetch page from API and cache it
---@param bufnr integer Buffer number
---@param page_id string Normalized page ID
local function fetch_and_cache_page(bufnr, page_id)
  local buffer = require('neotion.buffer')
  local pages_api = require('neotion.api.pages')
  local blocks_api = require('neotion.api.blocks')

  -- Fetch page info
  pages_api.get(page_id, function(page_result)
    -- Check if buffer is still valid (user might have closed it)
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    if page_result.error then
      buffer.set_status(bufnr, 'error')
      buffer.set_content(bufnr, { 'Error: ' .. page_result.error })
      vim.notify('[neotion] ' .. page_result.error, vim.log.levels.ERROR)
      return
    end

    local page = page_result.page

    -- Cache page metadata
    local cache = require('neotion.cache')
    if cache.is_initialized() then
      local cache_pages = require('neotion.cache.pages')
      cache_pages.save_page(page_id, page)
    end

    -- Fetch blocks
    blocks_api.get_all_children(page_id, function(blocks_result)
      -- Check if buffer is still valid
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end

      if blocks_result.error then
        buffer.set_status(bufnr, 'error')
        local title = pages_api.get_title(page)
        buffer.set_content(bufnr, { '# ' .. title, '', 'Error loading content: ' .. blocks_result.error })
        vim.notify('[neotion] ' .. blocks_result.error, vim.log.levels.ERROR)
        return
      end

      -- Cache blocks
      if cache.is_initialized() then
        local cache_pages = require('neotion.cache.pages')
        cache_pages.save_content(page_id, blocks_result.blocks)
      end

      -- Display content
      display_page_content(bufnr, page_id, page, blocks_result.blocks, false)
    end)
  end)
end

---Open a Notion page in a new buffer
---@param page_id string Notion page ID
function M.open(page_id)
  vim.validate({
    page_id = { page_id, 'string' },
  })

  -- Validate page ID format
  local valid, err = validate_page_id(page_id)
  if not valid then
    vim.notify('[neotion] Invalid page ID: ' .. err, vim.log.levels.ERROR)
    return
  end

  -- Normalize page ID
  local normalized_id = page_id:gsub('-', '')

  local buffer = require('neotion.buffer')

  -- Create or get buffer
  local bufnr, is_new = buffer.create(page_id)
  buffer.open(bufnr)

  -- If buffer already exists and is ready, don't reload - just show it
  if not is_new then
    local status = buffer.get_status(bufnr)
    if status == 'loading' then
      vim.notify('[neotion] Page is already loading', vim.log.levels.INFO)
      return
    elseif status == 'ready' then
      -- Buffer already has content, no need to reload
      local data = buffer.get_data(bufnr)
      if data then
        vim.notify('[neotion] ' .. data.page_title, vim.log.levels.INFO)
      end
      return
    elseif status == 'syncing' then
      vim.notify('[neotion] Sync in progress, please wait', vim.log.levels.INFO)
      return
    end
    -- If status is 'error' or 'modified', allow reload
  end

  -- Set loading state
  buffer.set_status(bufnr, 'loading')

  -- Initialize cache if not already done
  local cache = require('neotion.cache')
  if cache.is_available() and not cache.is_initialized() then
    cache.init()
  end

  -- Try to load from cache first
  if cache.is_initialized() then
    local cache_pages = require('neotion.cache.pages')
    local cached_blocks = cache_pages.get_content(normalized_id)

    if cached_blocks then
      -- Found in cache! Load from cache
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(bufnr) then
          display_page_content(bufnr, normalized_id, nil, cached_blocks, true)
        end
      end)
      return
    end
  end

  -- Not in cache, show loading placeholder and fetch from API
  buffer.set_content(bufnr, { 'Loading...' })
  fetch_and_cache_page(bufnr, normalized_id)
end

---Create a new Notion page
---@param title string? Page title
function M.create(title)
  -- TODO: Implement page creation
  vim.notify('[neotion] create() not yet implemented', vim.log.levels.WARN)
end

---Delete the current Notion page
function M.delete()
  -- TODO: Implement page deletion
  vim.notify('[neotion] delete() not yet implemented', vim.log.levels.WARN)
end

-- Sync Operations

---Sync current buffer with Notion
function M.sync()
  local bufnr = vim.api.nvim_get_current_buf()
  local sync_module = require('neotion.sync')
  sync_module.sync(bufnr)
end

---Force push local changes to Notion
function M.push()
  local bufnr = vim.api.nvim_get_current_buf()
  local sync_module = require('neotion.sync')
  sync_module.push(bufnr)
end

---Force pull remote changes from Notion
function M.pull()
  local bufnr = vim.api.nvim_get_current_buf()
  local sync_module = require('neotion.sync')
  sync_module.pull(bufnr)
end

-- Navigation

---Navigate to parent page
function M.goto_parent()
  -- TODO: Implement parent navigation
  vim.notify('[neotion] goto_parent() not yet implemented', vim.log.levels.WARN)
end

---Follow link under cursor
---Opens external links in browser, Notion pages in new buffer
function M.goto_link()
  local navigation = require('neotion.navigation')
  navigation.goto_link_at_cursor({
    open_page = function(page_id)
      M.open(page_id)
    end,
  })
end

---Search Notion pages
---@param opts table? Search options
function M.search(query)
  local picker = require('neotion.ui.picker')

  picker.search(query, function(item)
    if item then
      M.open(item.id)
    end
  end)
end

-- Block Operations

---Move block in specified direction
---@param direction "up"|"down" Direction to move
function M.block_move(direction)
  vim.validate({
    direction = {
      direction,
      function(v)
        return v == 'up' or v == 'down'
      end,
      'up or down',
    },
  })
  -- TODO: Implement block move
  vim.notify('[neotion] block_move() not yet implemented', vim.log.levels.WARN)
end

---Indent current block
function M.block_indent()
  -- TODO: Implement block indent
  vim.notify('[neotion] block_indent() not yet implemented', vim.log.levels.WARN)
end

---Dedent current block
function M.block_dedent()
  -- TODO: Implement block dedent
  vim.notify('[neotion] block_dedent() not yet implemented', vim.log.levels.WARN)
end

---Open recent pages picker
function M.recent()
  local buffer = require('neotion.buffer')
  local picker = require('neotion.ui.picker')

  local recent = buffer.get_recent()
  if #recent == 0 then
    vim.notify('[neotion] No recent pages', vim.log.levels.INFO)
    return
  end

  -- Convert recent pages to picker items
  ---@type neotion.ui.PickerItem[]
  local items = {}
  for _, page in ipairs(recent) do
    table.insert(items, {
      id = page.page_id,
      title = page.title,
      icon = page.icon,
      parent_type = page.parent_type,
    })
  end

  picker.select(items, { prompt = 'Recent Pages' }, function(item)
    if item then
      M.open(item.id)
    end
  end)
end

---Get sync status for current buffer
---@return table? status Sync status or nil if not a neotion buffer
function M.status()
  -- TODO: Implement status
  return nil
end

return M
