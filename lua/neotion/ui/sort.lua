---Sort UI module for neotion.nvim database views
---Provides sort state management and UI for database queries
---@brief [[
---Sort module handles building Notion API sort objects from user input.
---Supports both property-based and timestamp-based sorting.
---@brief ]]

local log_module = require('neotion.log')
local log = log_module.get_logger('ui.sort')

local M = {}

---@alias neotion.SortDirection "ascending"|"descending"

---@class neotion.Sort
---@field property? string Property name (for property-based sort)
---@field timestamp? "created_time"|"last_edited_time" Timestamp type (for timestamp-based sort)
---@field direction neotion.SortDirection Sort direction

---@class neotion.SortState
---@field sorts neotion.Sort[] Active sorts (first has highest priority)

---Property types that support sorting
---@type table<string, boolean>
M.sortable_types = {
  title = true,
  rich_text = true,
  number = true,
  checkbox = true,
  select = true,
  status = true,
  date = true,
  url = true,
  email = true,
  phone_number = true,
  created_time = true,
  last_edited_time = true,
  unique_id = true,
}

---Built-in timestamp options for sorting
---@type table[]
M.timestamp_options = {
  { name = 'Created time', timestamp = 'created_time' },
  { name = 'Last edited time', timestamp = 'last_edited_time' },
}

---Check if property type supports sorting
---@param property_type string Notion property type
---@return boolean
function M.is_sortable(property_type)
  return M.sortable_types[property_type] == true
end

---Build Notion API sorts array from sort state
---@param state neotion.SortState Sort state
---@return table[]|nil api_sorts Notion API sorts array
function M.build_api_sorts(state)
  if not state or not state.sorts or #state.sorts == 0 then
    return nil
  end

  local sorts = {}
  for _, sort in ipairs(state.sorts) do
    if sort.timestamp then
      -- Timestamp-based sort
      table.insert(sorts, {
        timestamp = sort.timestamp,
        direction = sort.direction,
      })
    elseif sort.property then
      -- Property-based sort
      table.insert(sorts, {
        property = sort.property,
        direction = sort.direction,
      })
    end
  end

  return #sorts > 0 and sorts or nil
end

---Create empty sort state
---@return neotion.SortState
function M.create_state()
  return {
    sorts = {},
  }
end

---Add a sort to state
---@param state neotion.SortState
---@param sort neotion.Sort
function M.add_sort(state, sort)
  table.insert(state.sorts, sort)
end

---Remove sort at index
---@param state neotion.SortState
---@param index integer
function M.remove_sort(state, index)
  table.remove(state.sorts, index)
end

---Clear all sorts
---@param state neotion.SortState
function M.clear_sorts(state)
  state.sorts = {}
end

---Move sort up in priority
---@param state neotion.SortState
---@param index integer
function M.move_up(state, index)
  if index > 1 and index <= #state.sorts then
    state.sorts[index], state.sorts[index - 1] = state.sorts[index - 1], state.sorts[index]
  end
end

---Move sort down in priority
---@param state neotion.SortState
---@param index integer
function M.move_down(state, index)
  if index >= 1 and index < #state.sorts then
    state.sorts[index], state.sorts[index + 1] = state.sorts[index + 1], state.sorts[index]
  end
end

---Extract sortable properties from database schema
---@param schema table Database schema from API
---@return table[] properties List of {name, type} pairs
function M.get_sortable_properties(schema)
  local properties = {}

  if not schema or not schema.properties then
    return properties
  end

  for name, prop in pairs(schema.properties) do
    if M.is_sortable(prop.type) then
      table.insert(properties, {
        name = name,
        type = prop.type,
      })
    end
  end

  -- Sort alphabetically
  table.sort(properties, function(a, b)
    return a.name < b.name
  end)

  return properties
end

---Show sort selection popup using vim.ui.select
---@param schema table Database schema
---@param current_state neotion.SortState Current sort state
---@param on_change fun(state: neotion.SortState) Callback when sort changes
function M.show_popup(schema, current_state, on_change)
  local properties = M.get_sortable_properties(schema)

  -- Build options list: timestamps + properties
  local options = {}

  -- Add timestamp options
  for _, ts in ipairs(M.timestamp_options) do
    table.insert(options, {
      display = '⏱️ ' .. ts.name,
      timestamp = ts.timestamp,
      property = nil,
      type = 'timestamp',
    })
  end

  -- Add property options
  for _, prop in ipairs(properties) do
    table.insert(options, {
      display = prop.name .. ' (' .. prop.type .. ')',
      property = prop.name,
      timestamp = nil,
      type = prop.type,
    })
  end

  if #options == 0 then
    vim.notify('[neotion] No sortable properties found', vim.log.levels.WARN)
    return
  end

  -- Step 1: Select property/timestamp
  vim.ui.select(options, {
    prompt = 'Sort by:',
    format_item = function(item)
      return item.display
    end,
  }, function(selected)
    if not selected then
      return
    end

    -- Step 2: Select direction
    local directions = {
      { direction = 'ascending', label = '↑ Ascending (A-Z, 0-9, oldest first)' },
      { direction = 'descending', label = '↓ Descending (Z-A, 9-0, newest first)' },
    }

    vim.ui.select(directions, {
      prompt = 'Direction:',
      format_item = function(item)
        return item.label
      end,
    }, function(dir)
      if not dir then
        return
      end

      local sort = {
        property = selected.property,
        timestamp = selected.timestamp,
        direction = dir.direction,
      }

      M.add_sort(current_state, sort)
      log.debug('Sort added', { sort = sort })
      on_change(current_state)
    end)
  end)
end

---Format sort state for display
---@param state neotion.SortState
---@return string
function M.format_state(state)
  if not state or not state.sorts or #state.sorts == 0 then
    return 'No sorting'
  end

  local parts = {}
  for _, sort in ipairs(state.sorts) do
    local name = sort.property or sort.timestamp or 'unknown'
    local arrow = sort.direction == 'ascending' and '↑' or '↓'
    table.insert(parts, name .. ' ' .. arrow)
  end

  return table.concat(parts, ', ')
end

return M
