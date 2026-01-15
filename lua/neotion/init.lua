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

local log_module = require('neotion.log')
local log = log_module.get_logger('init')

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

  -- Format header - use page object if available, otherwise create from cached metadata
  local header_lines
  if page then
    header_lines = format.format_header(page)
  else
    -- Create header from cached metadata (consistent format)
    header_lines = format.format_header_from_metadata(title, parent_type, parent_id)
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

  -- Resolve child_page icons asynchronously
  model.resolve_child_page_icons(bufnr, blocks, header_line_count)

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

      -- Cache blocks and update sync state
      if cache.is_initialized() then
        local cache_pages = require('neotion.cache.pages')
        cache_pages.save_content(page_id, blocks_result.blocks)

        -- Update sync state with content hash
        local sync_state = require('neotion.cache.sync_state')
        local content_hash = cache.hash.page_content(blocks_result.blocks)
        sync_state.update_after_pull(page_id, content_hash)
      end

      -- Display content
      display_page_content(bufnr, page_id, page, blocks_result.blocks, false)
    end)
  end)
end

--- Helper: Background refresh - fetch from API and update buffer if content changed
--- Called after displaying cached content to ensure freshness
---@param bufnr integer Buffer number
---@param page_id string Normalized page ID
---@param cached_hash string Hash of cached content
local function bg_refresh_page(bufnr, page_id, cached_hash)
  local buffer = require('neotion.buffer')
  local pages_api = require('neotion.api.pages')
  local blocks_api = require('neotion.api.blocks')
  local cache = require('neotion.cache')
  local sync_state = require('neotion.cache.sync_state')

  log.debug('Starting background refresh', { page_id = page_id, cached_hash = cached_hash })

  -- Fetch page info
  pages_api.get(page_id, function(page_result)
    -- Check if buffer is still valid
    if not vim.api.nvim_buf_is_valid(bufnr) then
      log.debug('Buffer no longer valid, aborting refresh')
      return
    end

    -- Check if buffer was modified by user - don't overwrite their changes
    local status = buffer.get_status(bufnr)
    if status == 'modified' then
      log.debug('Buffer modified, skipping refresh')
      return
    end

    if page_result.error then
      log.warn('Background refresh failed', { error = page_result.error })
      return
    end

    local page = page_result.page

    -- Cache page metadata
    if cache.is_initialized() then
      local cache_pages = require('neotion.cache.pages')
      cache_pages.save_page(page_id, page)
    end

    -- Fetch blocks
    blocks_api.get_all_children(page_id, function(blocks_result)
      -- Check if buffer is still valid
      if not vim.api.nvim_buf_is_valid(bufnr) then
        log.debug('Buffer no longer valid, aborting refresh')
        return
      end

      -- Check again if buffer was modified
      status = buffer.get_status(bufnr)
      if status == 'modified' then
        log.debug('Buffer modified during fetch, skipping refresh')
        return
      end

      if blocks_result.error then
        log.warn('Background refresh blocks failed', { error = blocks_result.error })
        return
      end

      -- Calculate new hash
      local new_hash = cache.hash.page_content(blocks_result.blocks)

      -- Update sync state
      sync_state.update_after_pull(page_id, new_hash)

      -- Compare hashes - only update if changed
      if new_hash == cached_hash then
        log.debug('Content unchanged, no update needed', { page_id = page_id })
        return
      end

      log.info('Content changed, updating buffer', {
        page_id = page_id,
        old_hash = cached_hash,
        new_hash = new_hash,
      })

      -- Cache the new content
      if cache.is_initialized() then
        local cache_pages = require('neotion.cache.pages')
        cache_pages.save_content(page_id, blocks_result.blocks)
      end

      -- Update buffer with new content
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(bufnr) then
          -- Re-check status one more time before updating
          local final_status = buffer.get_status(bufnr)
          if final_status ~= 'modified' then
            display_page_content(bufnr, page_id, page, blocks_result.blocks, false)
            vim.notify('[neotion] Content refreshed', vim.log.levels.INFO)
          end
        end
      end)
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

  log.debug('Cache check', { available = cache.is_available(), initialized = cache.is_initialized() })

  if cache.is_available() and not cache.is_initialized() then
    local init_ok = cache.init()
    log.debug('Cache init result', { success = init_ok })
  end

  -- Try to load from cache first
  if cache.is_initialized() then
    local cache_pages = require('neotion.cache.pages')
    local cached_blocks = cache_pages.get_content(normalized_id)

    log.debug('Cache lookup', { page_id = normalized_id, found = cached_blocks ~= nil })

    if cached_blocks then
      -- Found in cache! Load from cache immediately
      local cached_hash = cache.hash.page_content(cached_blocks)

      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(bufnr) then
          display_page_content(bufnr, normalized_id, nil, cached_blocks, true)

          -- Start background refresh to check for updates
          bg_refresh_page(bufnr, normalized_id, cached_hash)
        end
      end)
      return
    end
  else
    log.debug('Cache not initialized, skipping cache lookup')
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
    open_database = function(database_id)
      M.open_database(database_id)
    end,
  })
end

---Open a database and show its rows in a picker
---@param database_id string Database ID
function M.open_database(database_id)
  vim.validate({ database_id = { database_id, 'string' } })
  local normalized = database_id:gsub('-', '')
  if #normalized ~= 32 or not normalized:match('^%x+$') then
    vim.notify('[neotion] Invalid database ID format', vim.log.levels.ERROR)
    return
  end

  local buffer = require('neotion.buffer')
  local databases_api = require('neotion.api.databases')
  local DatabaseView = require('neotion.model.database_view').DatabaseView
  local database_renderer = require('neotion.render.database')

  -- Setup highlight groups
  database_renderer.setup_highlights()

  -- Create or get existing database buffer
  local bufnr, is_new = buffer.create_database(database_id)

  -- Open buffer in current window
  buffer.open(bufnr)

  -- If buffer already exists and has content, just show it
  if not is_new then
    return
  end

  -- Set loading indicator
  vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'Loading database...' })
  vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })

  -- Fetch database schema first
  databases_api.get(database_id, function(schema_result)
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    if schema_result.error then
      buffer.set_status(bufnr, 'error')
      vim.schedule(function()
        vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
          'Error loading database:',
          schema_result.error,
        })
        vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
      end)
      return
    end

    local database = schema_result.database

    -- Query rows
    databases_api.query(database_id, { page_size = 50 }, function(query_result)
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end

      vim.schedule(function()
        if query_result.error then
          buffer.set_status(bufnr, 'error')
          vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })
          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
            'Error querying database:',
            query_result.error,
          })
          vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
          return
        end

        -- Create database view (API returns 'pages' not 'results')
        local database_view = DatabaseView.new(database, query_result.pages, query_result)

        -- Format and set content
        local lines = database_view:format()
        buffer.set_database_content(bufnr, lines, database_view)

        -- Apply rendering (highlights, extmarks)
        database_renderer.render(bufnr, database_view)

        -- Update buffer data
        buffer.update_data(bufnr, {
          page_title = database_view.title,
          last_sync = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        })
        buffer.set_status(bufnr, 'ready')

        -- Setup keymaps for database buffer
        M._setup_database_keymaps(bufnr, database_id)
      end)
    end)
  end)
end

---Setup keymaps for database buffer
---@param bufnr integer
---@param database_id string
function M._setup_database_keymaps(bufnr, database_id)
  local buffer = require('neotion.buffer')
  local filter = require('neotion.ui.filter')
  local sort = require('neotion.ui.sort')

  local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
  end

  -- Enter: Open row as page
  map('n', '<CR>', function()
    local database_view = buffer.get_database_view(bufnr)
    if not database_view then
      return
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = database_view:get_row_at_line(cursor[1])
    if row and row.id then
      M.open(row.id)
    end
  end, 'Open row as page')

  -- gf: Same as Enter (for consistency)
  map('n', 'gf', function()
    local database_view = buffer.get_database_view(bufnr)
    if not database_view then
      return
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = database_view:get_row_at_line(cursor[1])
    if row and row.id then
      M.open(row.id)
    end
  end, 'Open row as page')

  -- f: Filter
  map('n', 'f', function()
    local database_view = buffer.get_database_view(bufnr)
    if not database_view then
      return
    end

    -- Initialize filter state if needed
    if not database_view.filter_state then
      database_view.filter_state = filter.create_state()
    end

    filter.show_popup(database_view.schema, database_view.filter_state, function()
      -- Re-query with new filter
      M._refresh_database(bufnr, database_id)
    end)
  end, 'Filter database')

  -- s: Sort
  map('n', 's', function()
    local database_view = buffer.get_database_view(bufnr)
    if not database_view then
      return
    end

    -- Initialize sort state if needed
    if not database_view.sort_state then
      database_view.sort_state = sort.create_state()
    end

    sort.show_popup(database_view.schema, database_view.sort_state, function()
      -- Re-query with new sort
      M._refresh_database(bufnr, database_id)
    end)
  end, 'Sort database')

  -- F: Clear filters
  map('n', 'F', function()
    local database_view = buffer.get_database_view(bufnr)
    if database_view and database_view.filter_state then
      filter.clear_filters(database_view.filter_state)
      M._refresh_database(bufnr, database_id)
    end
  end, 'Clear filters')

  -- S: Clear sorts
  map('n', 'S', function()
    local database_view = buffer.get_database_view(bufnr)
    if database_view and database_view.sort_state then
      sort.clear_sorts(database_view.sort_state)
      M._refresh_database(bufnr, database_id)
    end
  end, 'Clear sorts')

  -- r: Refresh
  map('n', 'r', function()
    M._refresh_database(bufnr, database_id)
  end, 'Refresh database')

  -- L: Load more (if pagination)
  map('n', 'L', function()
    M._load_more_rows(bufnr, database_id)
  end, 'Load more rows')

  -- q: Close buffer
  map('n', 'q', function()
    vim.api.nvim_buf_delete(bufnr, { force = false })
  end, 'Close database')

  -- ?: Help
  map('n', '?', function()
    vim.notify(
      table.concat({
        'Database Buffer Keymaps:',
        '  <CR>, gf  Open row as page',
        '  f         Filter database',
        '  s         Sort database',
        '  F         Clear filters',
        '  S         Clear sorts',
        '  r         Refresh',
        '  L         Load more rows',
        '  q         Close buffer',
      }, '\n'),
      vim.log.levels.INFO
    )
  end, 'Show help')
end

---Refresh database content with current filter/sort
---@param bufnr integer
---@param database_id string
function M._refresh_database(bufnr, database_id)
  local buffer = require('neotion.buffer')
  local databases_api = require('neotion.api.databases')
  local filter = require('neotion.ui.filter')
  local sort = require('neotion.ui.sort')
  local database_renderer = require('neotion.render.database')
  local DatabaseView = require('neotion.model.database_view').DatabaseView

  local database_view = buffer.get_database_view(bufnr)
  if not database_view then
    return
  end

  buffer.set_status(bufnr, 'loading')

  -- Build query options
  local query_opts = { page_size = 50 }
  if database_view.filter_state then
    query_opts.filter = filter.build_api_filter(database_view.filter_state)
  end
  if database_view.sort_state then
    query_opts.sorts = sort.build_api_sorts(database_view.sort_state)
  end

  -- Re-fetch schema (in case it changed) and query
  databases_api.get(database_id, function(schema_result)
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    if schema_result.error then
      buffer.set_status(bufnr, 'error')
      vim.notify('[neotion] ' .. schema_result.error, vim.log.levels.ERROR)
      return
    end

    databases_api.query(database_id, query_opts, function(query_result)
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end

      vim.schedule(function()
        if query_result.error then
          buffer.set_status(bufnr, 'error')
          vim.notify('[neotion] ' .. query_result.error, vim.log.levels.ERROR)
          return
        end

        -- Create new database view (preserving filter/sort state)
        local old_filter_state = database_view.filter_state
        local old_sort_state = database_view.sort_state

        local new_view = DatabaseView.new(schema_result.database, query_result.pages, query_result)
        new_view.filter_state = old_filter_state
        new_view.sort_state = old_sort_state

        -- Format and set content
        local lines = new_view:format()
        buffer.set_database_content(bufnr, lines, new_view)

        -- Apply rendering
        database_renderer.render(bufnr, new_view)

        -- Update buffer data
        buffer.update_data(bufnr, {
          page_title = new_view.title,
          last_sync = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        })
        buffer.set_status(bufnr, 'ready')
      end)
    end)
  end)
end

---Load more rows for pagination
---@param bufnr integer
---@param database_id string
function M._load_more_rows(bufnr, database_id)
  local buffer = require('neotion.buffer')
  local databases_api = require('neotion.api.databases')
  local filter = require('neotion.ui.filter')
  local sort = require('neotion.ui.sort')
  local database_renderer = require('neotion.render.database')

  local database_view = buffer.get_database_view(bufnr)
  if not database_view or not database_view.has_more then
    vim.notify('[neotion] No more rows to load', vim.log.levels.INFO)
    return
  end

  buffer.set_status(bufnr, 'loading')

  -- Build query options with cursor
  local query_opts = {
    page_size = 50,
    start_cursor = database_view.next_cursor,
  }
  if database_view.filter_state then
    query_opts.filter = filter.build_api_filter(database_view.filter_state)
  end
  if database_view.sort_state then
    query_opts.sorts = sort.build_api_sorts(database_view.sort_state)
  end

  databases_api.query(database_id, query_opts, function(query_result)
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    vim.schedule(function()
      if query_result.error then
        buffer.set_status(bufnr, 'error')
        vim.notify('[neotion] ' .. query_result.error, vim.log.levels.ERROR)
        return
      end

      -- Append rows to view
      database_view:append_rows(query_result.pages, query_result)

      -- Re-format and set content
      local lines = database_view:format()
      buffer.set_database_content(bufnr, lines, database_view)

      -- Apply rendering
      database_renderer.render(bufnr, database_view)

      buffer.set_status(bufnr, 'ready')
      vim.notify('[neotion] Loaded ' .. #query_result.pages .. ' more rows', vim.log.levels.INFO)
    end)
  end)
end

---Search Notion pages
---@param opts table? Search options
function M.search(query)
  local picker = require('neotion.ui.picker')

  picker.search(query, function(item)
    if item then
      -- Check if selected item is a database
      if item.object_type == 'database' then
        M.open_database(item.id)
      else
        M.open(item.id)
      end
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
