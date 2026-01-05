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

  local buffer = require('neotion.buffer')
  local pages_api = require('neotion.api.pages')
  local blocks_api = require('neotion.api.blocks')
  local format = require('neotion.buffer.format')

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

  -- Set loading state and show placeholder
  buffer.set_status(bufnr, 'loading')
  buffer.set_content(bufnr, { 'Loading...' })

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
    local title = pages_api.get_title(page)
    local parent_type, parent_id = pages_api.get_parent(page)

    -- Get icon from page
    local icon = pages_api.get_icon(page)

    buffer.update_data(bufnr, {
      page_title = title,
      parent_type = parent_type,
      parent_id = parent_id,
    })

    -- Fetch blocks
    blocks_api.get_all_children(page_id, function(blocks_result)
      -- Check if buffer is still valid
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end

      if blocks_result.error then
        buffer.set_status(bufnr, 'error')
        buffer.set_content(bufnr, { '# ' .. title, '', 'Error loading content: ' .. blocks_result.error })
        vim.notify('[neotion] ' .. blocks_result.error, vim.log.levels.ERROR)
        return
      end

      -- Use model layer for block handling
      local model = require('neotion.model')
      local blocks = model.deserialize_blocks(blocks_result.blocks)

      -- Check editability and notify if some blocks are read-only
      local is_fully_editable, unsupported = model.check_editability(blocks)
      if not is_fully_editable then
        vim.notify('[neotion] Some blocks are read-only: ' .. table.concat(unsupported, ', '), vim.log.levels.WARN)
      end

      -- Format header
      local header_lines = format.format_header(page)
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

      vim.notify('[neotion] Loaded: ' .. title, vim.log.levels.INFO)
    end)
  end)
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
