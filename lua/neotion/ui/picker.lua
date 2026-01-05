---@brief [[
--- Picker abstraction for page selection.
--- Uses Telescope if available, falls back to vim.ui.select.
---@brief ]]

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

  -- Use a unique instance ID (could use buffer number or counter)
  local instance_id = vim.loop.hrtime()

  local picker -- forward declaration

  -- Create live search instance with callbacks
  live_search.create(instance_id, {
    on_results = function(items, is_final)
      vim.schedule(function()
        -- Check if picker is still valid
        if not picker or not picker.prompt_bufnr or not vim.api.nvim_buf_is_valid(picker.prompt_bufnr) then
          return
        end

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
      end)
    end,
    on_error = function(err)
      vim.schedule(function()
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
  picker = pickers.new({}, {
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
      local last_prompt = ''
      vim.api.nvim_create_autocmd({ 'TextChangedI', 'TextChanged' }, {
        buffer = prompt_bufnr,
        callback = function()
          local current_prompt = action_state.get_current_line()
          if current_prompt ~= last_prompt then
            last_prompt = current_prompt
            live_search.update_query(instance_id, current_prompt)
          end
        end,
      })

      -- Cleanup on close
      actions.close:enhance({
        post = function()
          live_search.destroy(instance_id)
        end,
      })

      -- Handle selection
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
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
  local picker = pickers.new({}, {
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

---Select a page from a list of items (for recent pages, etc.)
---@param items neotion.ui.PickerItem[]
---@param opts? neotion.ui.PickerOpts
---@param on_choice fun(item: neotion.ui.PickerItem|nil)
function M.select(items, opts, on_choice)
  opts = opts or {}

  if #items == 0 then
    vim.notify('[neotion] No pages found', vim.log.levels.WARN)
    on_choice(nil)
    return
  end

  if has_telescope() then
    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local conf = require('telescope.config').values
    local actions = require('telescope.actions')
    local action_state = require('telescope.actions.state')

    pickers
      .new(opts, {
        prompt_title = opts.prompt or 'Notion Pages',
        finder = finders.new_table({
          results = items,
          entry_maker = make_entry,
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
      prompt = opts.prompt or 'Select page:',
      format_item = format_display,
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
