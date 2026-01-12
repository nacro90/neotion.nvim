---@brief [[
--- Picker abstraction for page selection.
--- Uses Telescope if available, falls back to vim.ui.select.
---@brief ]]

-- TODO(neotion:FEAT-12.4:MEDIUM): Preserve cursor position on search refresh
-- When telescope search results refresh after fetch, keep cursor on the same
-- page item (match by page_id). Currently cursor jumps to first result.

---@class neotion.ui.PickerItem
---@field id string Page ID
---@field title string Page title
---@field icon? string Page icon (emoji or URL)
---@field parent_type? string Parent type (workspace, page, database)
---@field parent_id? string Parent ID

---@class neotion.ui.PickerOpts
---@field prompt? string Picker prompt
---@field query? string Initial search query

local M = {}

---Check if Telescope is available
---@return boolean
local function has_telescope()
  local ok = pcall(require, 'telescope')
  return ok
end

---Format page icon from Notion API response
---@param icon_data? table Notion icon object
---@return string
local function format_icon(icon_data)
  -- Handle nil, vim.NIL (userdata), or non-table values
  if not icon_data or icon_data == vim.NIL or type(icon_data) ~= 'table' then
    return ''
  end
  if icon_data.type == 'emoji' then
    return icon_data.emoji or ''
  end
  if icon_data.type == 'external' then
    return '' -- Can't display external URL icons in terminal
  end
  return ''
end

---Format parent display string
---@param parent_type? string
---@return string
local function format_parent(parent_type)
  if not parent_type then
    return ''
  end
  local labels = {
    workspace = 'Workspace',
    page_id = 'Page',
    database_id = 'Database',
  }
  return labels[parent_type] or parent_type
end

---Create display string for a page item
---@param item neotion.ui.PickerItem
---@return string
local function format_display(item)
  local parts = {}
  if item.icon and item.icon ~= '' then
    table.insert(parts, item.icon)
  end
  table.insert(parts, item.title or 'Untitled')
  if item.parent_type then
    table.insert(parts, '(' .. format_parent(item.parent_type) .. ')')
  end
  return table.concat(parts, ' ')
end

---Create entry maker for Telescope
---@param item neotion.ui.PickerItem
---@return table
local function make_entry(item)
  local display = format_display(item)
  return {
    value = item,
    display = display,
    ordinal = item.title or 'Untitled',
  }
end

---Convert Notion API page response to picker item
---@param page table Notion page object
---@return neotion.ui.PickerItem
function M.page_to_item(page)
  local pages_api = require('neotion.api.pages')
  local title = pages_api.get_title(page)
  local parent_type, parent_id = pages_api.get_parent(page)

  return {
    id = page.id,
    title = title,
    icon = format_icon(page.icon),
    parent_type = parent_type,
    parent_id = parent_id,
  }
end

---Check if live search is enabled in config
---@return boolean
local function is_live_search_enabled()
  local ok, config = pcall(require, 'neotion.config')
  if not ok then
    return true -- Default to true
  end
  local cfg = config.get()
  return cfg.search and cfg.search.live_search
end

---Search and select using Telescope with live search (debounce + cancel + hybrid display)
---@param initial_query? string Initial search query
---@param on_choice fun(item: neotion.ui.PickerItem|nil)
local function search_telescope_live(initial_query, on_choice)
  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local sorters = require('telescope.sorters')
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  local live_search = require('neotion.ui.live_search')

  local log_module = require('neotion.log')
  local log = log_module.get_logger('ui.picker')

  -- Use a unique instance ID (could use buffer number or counter)
  local instance_id = vim.loop.hrtime()

  local picker -- forward declaration

  -- Helper to restore selection after refresh
  local function restore_selection(selected_id, items)
    if not selected_id or selected_id == '' then
      log.debug('No selection to restore', { selected_id = selected_id })
      return
    end
    -- Find the index of the selected item in new results
    for i, item in ipairs(items) do
      if item.id == selected_id then
        log.debug('Restoring selection', { selected_id = selected_id, index = i - 1 })
        -- Use defer_fn with delay to ensure Telescope has finished updating
        vim.defer_fn(function()
          if picker and picker.prompt_bufnr and vim.api.nvim_buf_is_valid(picker.prompt_bufnr) then
            -- Use row directly (0-indexed from top of results)
            local row = i - 1
            picker:set_selection(row)
            log.debug('Selection restored', { row = row })
          end
        end, 10) -- Small delay to ensure refresh is complete
        return
      end
    end
    log.debug('Selected item not found in new results', { selected_id = selected_id })
  end

  -- Create live search instance with callbacks
  live_search.create(instance_id, {
    on_results = function(items, is_final)
      vim.schedule(function()
        -- CRITICAL: Check if this instance is still active
        -- This prevents old API responses from updating a NEW picker
        if not live_search.get_state(instance_id) then
          log.debug('Ignoring results for destroyed instance', { instance_id = instance_id })
          return
        end

        -- Check if picker is still valid
        if not picker or not picker.prompt_bufnr or not vim.api.nvim_buf_is_valid(picker.prompt_bufnr) then
          log.debug('Picker no longer valid, ignoring results')
          return
        end

        -- Save current selection before refresh
        local current_selection = action_state.get_selected_entry()
        local selected_id = current_selection and current_selection.value and current_selection.value.id
        log.debug('Refresh starting', {
          is_final = is_final,
          item_count = #items,
          selected_id = selected_id,
        })

        -- Show placeholder if no results
        if #items == 0 then
          local placeholder = is_final and { id = '', title = 'No pages found', icon = '📭' }
            or { id = '', title = 'Searching...', icon = '🔍' }
          picker:refresh(
            finders.new_table({
              results = { placeholder },
              entry_maker = make_entry,
            }),
            { reset_prompt = false }
          )
          return
        end

        -- Refresh picker with results
        picker:refresh(
          finders.new_table({
            results = items,
            entry_maker = make_entry,
          }),
          { reset_prompt = false }
        )

        -- Restore selection after refresh
        restore_selection(selected_id, items)
      end)
    end,
    on_error = function(err)
      vim.schedule(function()
        -- Check if instance is still active
        if not live_search.get_state(instance_id) then
          return
        end
        if picker and picker.prompt_bufnr and vim.api.nvim_buf_is_valid(picker.prompt_bufnr) then
          local error_item = { id = '', title = 'Error: ' .. err, icon = '❌' }
          picker:refresh(
            finders.new_table({
              results = { error_item },
              entry_maker = make_entry,
            }),
            { reset_prompt = false }
          )
        end
      end)
    end,
  })

  -- Create picker with loading placeholder
  local loading_item = { id = '', title = 'Loading...', icon = '⏳' }
  picker = pickers.new({
    default_text = initial_query or '',
  }, {
    prompt_title = 'Neotion Search',
    finder = finders.new_table({
      results = { loading_item },
      entry_maker = make_entry,
    }),
    -- IMPORTANT: Use empty sorter to disable Telescope filtering
    -- Our results are already filtered/sorted by API and cache frecency
    sorter = sorters.empty(),
    attach_mappings = function(prompt_bufnr, map)
      -- Watch for prompt changes (live search)
      -- Initialize to initial_query to prevent duplicate search trigger
      local last_prompt = initial_query or ''
      -- Flag to skip first TextChanged (Telescope initialization fires TextChanged
      -- before prompt is fully set up, causing action_state to return stale values)
      local is_first_change = true
      vim.api.nvim_create_autocmd({ 'TextChangedI', 'TextChanged' }, {
        buffer = prompt_bufnr,
        callback = function()
          -- CRITICAL: Use vim.schedule to defer reading prompt value
          -- This ensures Telescope's global state is fully updated
          -- Without this, action_state.get_current_line() may return stale values
          -- from a previous picker instance (race condition on rapid open/close)
          vim.schedule(function()
            -- Verify picker and instance are still valid
            if not picker or not picker.prompt_bufnr or not vim.api.nvim_buf_is_valid(picker.prompt_bufnr) then
              return
            end
            if not live_search.get_state(instance_id) then
              return
            end

            -- Skip first TextChanged event (initial setup)
            -- Telescope fires TextChanged during initialization before prompt is ready
            -- At this point, action_state.get_current_line() may return stale values
            -- from previous picker instance
            if is_first_change then
              is_first_change = false
              -- Sync last_prompt with actual current value (should be initial_query or '')
              last_prompt = action_state.get_current_line()
              log.debug('Synced last_prompt on first change', { last_prompt = last_prompt })
              return
            end

            local current_prompt = action_state.get_current_line()
            if current_prompt ~= last_prompt then
              last_prompt = current_prompt
              live_search.update_query(instance_id, current_prompt)
            end
          end)
        end,
      })

      -- Cleanup on buffer delete/wipeout (handles ESC, close, and any other close method)
      -- Using both BufDelete and BufWipeout for robust cleanup (destroy is idempotent)
      -- BufDelete fires earlier than BufWipeout, ensuring cleanup before new picker can open
      vim.api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, {
        buffer = prompt_bufnr,
        callback = function()
          log.debug('Buffer cleanup triggered', { instance_id = instance_id })
          live_search.destroy(instance_id)
        end,
        once = true, -- Only fire once for this buffer
      })

      -- Handle selection
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        log.debug('Selection made', {
          instance_id = instance_id,
          selection_id = selection and selection.value and selection.value.id,
        })
        -- Cleanup BEFORE closing to ensure state is cleared
        live_search.destroy(instance_id)
        actions.close(prompt_bufnr)
        -- Don't select placeholder items
        if selection and selection.value.id ~= '' then
          on_choice(selection.value)
        else
          on_choice(nil)
        end
      end)

      return true
    end,
  })

  -- Open picker immediately
  picker:find()

  -- Trigger initial search
  live_search.search_immediate(instance_id, initial_query or '')
end

---Search and select using Telescope (async - opens immediately, single query)
---@param query? string Search query
---@param on_choice fun(item: neotion.ui.PickerItem|nil)
local function search_telescope(query, on_choice)
  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  local pages_api = require('neotion.api.pages')

  -- Create picker with loading placeholder
  local loading_item = { id = '', title = 'Loading...', icon = '⏳' }
  local picker = pickers.new({
    default_text = query or '',
  }, {
    prompt_title = query and ('Search: ' .. query) or 'Notion Pages',
    finder = finders.new_table({
      results = { loading_item },
      entry_maker = make_entry,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        -- Don't select the loading placeholder
        if selection and selection.value.id ~= '' then
          on_choice(selection.value)
        else
          on_choice(nil)
        end
      end)
      return true
    end,
  })

  -- Open picker immediately
  picker:find()

  -- Start async search
  pages_api.search(query, function(result)
    vim.schedule(function()
      -- Check if picker is still open
      if not picker.prompt_bufnr or not vim.api.nvim_buf_is_valid(picker.prompt_bufnr) then
        return
      end

      if result.error then
        -- Show error in picker
        local error_item = { id = '', title = 'Error: ' .. result.error, icon = '❌' }
        picker:refresh(
          finders.new_table({
            results = { error_item },
            entry_maker = make_entry,
          }),
          { reset_prompt = false }
        )
        return
      end

      -- Convert pages to items
      local items = {}
      for _, page in ipairs(result.pages) do
        table.insert(items, M.page_to_item(page))
      end

      if #items == 0 then
        local empty_item = { id = '', title = 'No pages found', icon = '📭' }
        picker:refresh(
          finders.new_table({
            results = { empty_item },
            entry_maker = make_entry,
          }),
          { reset_prompt = false }
        )
        return
      end

      -- Refresh with actual results
      picker:refresh(
        finders.new_table({
          results = items,
          entry_maker = make_entry,
        }),
        { reset_prompt = false }
      )
    end)
  end)
end

---Search and select using vim.ui.select (blocking - waits for results)
---@param query? string Search query
---@param on_choice fun(item: neotion.ui.PickerItem|nil)
local function search_native(query, on_choice)
  local pages_api = require('neotion.api.pages')

  vim.notify('[neotion] Searching...', vim.log.levels.INFO)

  pages_api.search(query, function(result)
    vim.schedule(function()
      if result.error then
        vim.notify('[neotion] Search failed: ' .. result.error, vim.log.levels.ERROR)
        on_choice(nil)
        return
      end

      local items = {}
      for _, page in ipairs(result.pages) do
        table.insert(items, M.page_to_item(page))
      end

      if #items == 0 then
        vim.notify('[neotion] No pages found', vim.log.levels.WARN)
        on_choice(nil)
        return
      end

      vim.ui.select(items, {
        prompt = query and ('Search: ' .. query) or 'Select page:',
        format_item = format_display,
      }, function(item)
        on_choice(item)
      end)
    end)
  end)
end

---Select from a list of items (generic - works for pages, blocks, colors, etc.)
---@param items table[] Items to select from
---@param opts? table Options (prompt, format_item)
---@param on_choice fun(item: table|nil)
function M.select(items, opts, on_choice)
  opts = opts or {}

  if #items == 0 then
    vim.notify('[neotion] No items found', vim.log.levels.WARN)
    on_choice(nil)
    return
  end

  -- Custom format_item function or default to page format
  local format_item = opts.format_item or format_display

  if has_telescope() then
    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local conf = require('telescope.config').values
    local actions = require('telescope.actions')
    local action_state = require('telescope.actions.state')

    -- Custom entry maker that uses the format_item function
    local custom_entry_maker = function(item)
      local display = format_item(item)
      return {
        value = item,
        display = display,
        ordinal = display, -- Use display for filtering
      }
    end

    pickers
      .new(opts, {
        prompt_title = opts.prompt or 'Notion Pages',
        finder = finders.new_table({
          results = items,
          entry_maker = custom_entry_maker,
        }),
        sorter = conf.generic_sorter(opts),
        attach_mappings = function(prompt_bufnr, _)
          actions.select_default:replace(function()
            actions.close(prompt_bufnr)
            local selection = action_state.get_selected_entry()
            if selection then
              on_choice(selection.value)
            else
              on_choice(nil)
            end
          end)
          return true
        end,
      })
      :find()
  else
    vim.ui.select(items, {
      prompt = opts.prompt or 'Select:',
      format_item = format_item,
    }, function(item)
      on_choice(item)
    end)
  end
end

---Search and select pages
---@param query? string Search query
---@param on_choice fun(item: neotion.ui.PickerItem|nil)
function M.search(query, on_choice)
  if has_telescope() then
    if is_live_search_enabled() then
      search_telescope_live(query, on_choice)
    else
      search_telescope(query, on_choice)
    end
  else
    search_native(query, on_choice)
  end
end

return M
