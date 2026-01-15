---Database picker for neotion.nvim
---Shows database rows in Telescope and allows opening them as pages
---@brief [[
---Database picker opens a Telescope window showing all rows (pages) in a database.
---Users can filter and sort the results, then select a row to open as a page.
---Keybindings:
---  <C-f> - Add filter
---  <C-s> - Add sort
---  <C-x> - Clear filters and sorts
---@brief ]]

local log_module = require('neotion.log')
local log = log_module.get_logger('ui.database_picker')

local M = {}

---@class neotion.DatabasePickerState
---@field database_id string Database ID
---@field schema table|nil Database schema (properties)
---@field filter_state neotion.FilterState Filter state
---@field sort_state neotion.SortState Sort state
---@field rows table[] Current database rows

---Check if Telescope is available
---@return boolean
local function has_telescope()
  local ok = pcall(require, 'telescope')
  return ok
end

---Extract title from database row (page)
---@param row table Database row (page object)
---@return string
local function get_row_title(row)
  if not row or not row.properties then
    return 'Untitled'
  end

  -- Find title property
  for _, prop in pairs(row.properties) do
    if prop.type == 'title' and prop.title and type(prop.title) == 'table' then
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

---Extract icon from database row
---@param row table Database row (page object)
---@return string
local function get_row_icon(row)
  if not row or not row.icon or type(row.icon) ~= 'table' then
    return ''
  end

  if row.icon.type == 'emoji' then
    return row.icon.emoji or ''
  elseif row.icon.type == 'external' or row.icon.type == 'file' then
    return '\u{f03e}' -- nf-fa-image
  end

  return ''
end

---Convert database row to picker item
---@param row table Database row from API
---@return table
local function row_to_item(row)
  local normalized_id = row.id and row.id:gsub('-', '') or ''

  return {
    id = normalized_id,
    title = get_row_title(row),
    icon = get_row_icon(row),
    object_type = 'page', -- Database rows are pages
  }
end

---Create Telescope entry maker
---@return function
local function make_entry_maker()
  local entry_display = require('telescope.pickers.entry_display')

  local displayer = entry_display.create({
    separator = ' ',
    items = {
      { width = 2 }, -- Icon
      { remaining = true }, -- Title
    },
  })

  return function(item)
    return {
      value = item,
      display = function(entry)
        return displayer({
          { entry.value.icon, 'TelescopeResultsIdentifier' },
          { entry.value.title },
        })
      end,
      ordinal = item.title,
    }
  end
end

---Open database picker with Telescope
---@param database_id string Database ID
---@param opts? table Options (filter, sorts)
function M.open(database_id, opts)
  opts = opts or {}

  if not has_telescope() then
    vim.notify('[neotion] Database picker requires Telescope', vim.log.levels.ERROR)
    return
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  local databases_api = require('neotion.api.databases')
  local filter_mod = require('neotion.ui.filter')
  local sort_mod = require('neotion.ui.sort')

  log.debug('Opening database picker', { database_id = database_id })

  -- Normalize database ID
  local normalized_id = database_id:gsub('-', '')

  -- Initialize state
  local state = {
    database_id = normalized_id,
    schema = nil,
    filter_state = filter_mod.create_state(),
    sort_state = sort_mod.create_state(),
    db_title = 'Database',
  }

  -- Show loading picker immediately
  local loading_item = { id = '', title = 'Loading database...', icon = '⏳' }
  local picker

  -- Function to refresh results with current filter/sort
  local function refresh_results()
    if not picker or not picker.prompt_bufnr or not vim.api.nvim_buf_is_valid(picker.prompt_bufnr) then
      return
    end

    -- Show loading
    picker:refresh(
      finders.new_table({
        results = { { id = '', title = 'Refreshing...', icon = '🔄' } },
        entry_maker = make_entry_maker(),
      }),
      { reset_prompt = false }
    )

    -- Build API filter and sorts
    local api_filter = filter_mod.build_api_filter(state.filter_state)
    local api_sorts = sort_mod.build_api_sorts(state.sort_state)

    log.debug('Refreshing with filter/sort', {
      filter = api_filter,
      sorts = api_sorts,
    })

    -- Query database
    databases_api.query(normalized_id, {
      filter = api_filter,
      sorts = api_sorts,
      page_size = 100,
    }, function(result)
      vim.schedule(function()
        if not picker or not picker.prompt_bufnr or not vim.api.nvim_buf_is_valid(picker.prompt_bufnr) then
          return
        end

        if result.error then
          log.error('Failed to query database', { error = result.error })
          picker:refresh(
            finders.new_table({
              results = { { id = '', title = 'Error: ' .. result.error, icon = '❌' } },
              entry_maker = make_entry_maker(),
            }),
            { reset_prompt = false }
          )
          return
        end

        -- Convert rows to items
        local items = {}
        for _, row in ipairs(result.pages or {}) do
          table.insert(items, row_to_item(row))
        end

        log.debug('Database query complete', { row_count = #items })

        -- Show empty state if no results
        if #items == 0 then
          items = { { id = '', title = 'No rows found', icon = '📭' } }
        end

        -- Update picker
        picker:refresh(
          finders.new_table({
            results = items,
            entry_maker = make_entry_maker(),
          }),
          { reset_prompt = false }
        )

        -- Show current filter/sort status
        local filter_str = filter_mod.format_state(state.filter_state)
        local sort_str = sort_mod.format_state(state.sort_state)
        if filter_str ~= 'No filters' or sort_str ~= 'No sorting' then
          vim.notify(string.format('[neotion] Filter: %s | Sort: %s', filter_str, sort_str), vim.log.levels.INFO)
        end
      end)
    end)
  end

  picker = pickers.new({}, {
    prompt_title = 'Database',
    finder = finders.new_table({
      results = { loading_item },
      entry_maker = make_entry_maker(),
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      -- Select row
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        if selection and selection.value.id ~= '' then
          -- Open selected row as page
          local neotion = require('neotion')
          neotion.open(selection.value.id)
        end
      end)

      -- Add filter (<C-f>)
      map('i', '<C-f>', function()
        if not state.schema then
          vim.notify('[neotion] Database schema not loaded yet', vim.log.levels.WARN)
          return
        end

        filter_mod.show_popup(state.schema, state.filter_state, function(_)
          refresh_results()
        end)
      end)

      map('n', '<C-f>', function()
        if not state.schema then
          vim.notify('[neotion] Database schema not loaded yet', vim.log.levels.WARN)
          return
        end

        filter_mod.show_popup(state.schema, state.filter_state, function(_)
          refresh_results()
        end)
      end)

      -- Add sort (<C-s>)
      map('i', '<C-s>', function()
        if not state.schema then
          vim.notify('[neotion] Database schema not loaded yet', vim.log.levels.WARN)
          return
        end

        sort_mod.show_popup(state.schema, state.sort_state, function(_)
          refresh_results()
        end)
      end)

      map('n', '<C-s>', function()
        if not state.schema then
          vim.notify('[neotion] Database schema not loaded yet', vim.log.levels.WARN)
          return
        end

        sort_mod.show_popup(state.schema, state.sort_state, function(_)
          refresh_results()
        end)
      end)

      -- Clear filters and sorts (<C-x>)
      map('i', '<C-x>', function()
        filter_mod.clear_filters(state.filter_state)
        sort_mod.clear_sorts(state.sort_state)
        vim.notify('[neotion] Filters and sorts cleared', vim.log.levels.INFO)
        refresh_results()
      end)

      map('n', '<C-x>', function()
        filter_mod.clear_filters(state.filter_state)
        sort_mod.clear_sorts(state.sort_state)
        vim.notify('[neotion] Filters and sorts cleared', vim.log.levels.INFO)
        refresh_results()
      end)

      return true
    end,
  })

  picker:find()

  -- Fetch database schema first (for title and filter/sort options)
  databases_api.get(normalized_id, function(schema_result)
    if schema_result.error then
      vim.schedule(function()
        log.error('Failed to get database schema', { error = schema_result.error })
        if picker and picker.prompt_bufnr and vim.api.nvim_buf_is_valid(picker.prompt_bufnr) then
          picker:refresh(
            finders.new_table({
              results = { { id = '', title = 'Error: ' .. schema_result.error, icon = '❌' } },
              entry_maker = make_entry_maker(),
            }),
            { reset_prompt = false }
          )
        end
      end)
      return
    end

    -- Store schema for filter/sort
    state.schema = schema_result.database

    -- Extract database title
    if schema_result.database and schema_result.database.title then
      local parts = {}
      for _, text in ipairs(schema_result.database.title) do
        if text.plain_text then
          table.insert(parts, text.plain_text)
        end
      end
      if #parts > 0 then
        state.db_title = table.concat(parts)
      end
    end

    -- Query database rows
    databases_api.query(normalized_id, {
      filter = opts.filter,
      sorts = opts.sorts,
      page_size = 100,
    }, function(result)
      vim.schedule(function()
        if result.error then
          log.error('Failed to query database', { error = result.error })
          if picker and picker.prompt_bufnr and vim.api.nvim_buf_is_valid(picker.prompt_bufnr) then
            picker:refresh(
              finders.new_table({
                results = { { id = '', title = 'Error: ' .. result.error, icon = '❌' } },
                entry_maker = make_entry_maker(),
              }),
              { reset_prompt = false }
            )
          end
          return
        end

        -- Convert rows to items
        local items = {}
        for _, row in ipairs(result.pages or {}) do
          table.insert(items, row_to_item(row))
        end

        log.debug('Database query complete', { row_count = #items, database = state.db_title })

        -- Show empty state if no results
        if #items == 0 then
          items = { { id = '', title = 'No rows found', icon = '📭' } }
        end

        -- Update picker with results
        if picker and picker.prompt_bufnr and vim.api.nvim_buf_is_valid(picker.prompt_bufnr) then
          log.debug('Refreshing picker', { title = state.db_title, count = #items })

          picker:refresh(
            finders.new_table({
              results = items,
              entry_maker = make_entry_maker(),
            }),
            { reset_prompt = false }
          )

          -- Show keybinding help
          vim.notify(
            string.format('[neotion] %s loaded. <C-f> filter, <C-s> sort, <C-x> clear', state.db_title),
            vim.log.levels.INFO
          )
        end
      end)
    end)
  end)
end

return M
