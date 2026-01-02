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

---Search and select using Telescope (async - opens immediately)
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
    search_telescope(query, on_choice)
  else
    search_native(query, on_choice)
  end
end

return M
