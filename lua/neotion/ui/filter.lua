---Filter UI module for neotion.nvim database views
---Provides filter state management and UI for database queries
---@brief [[
---Filter module handles building Notion API filter objects from user input.
---Supports all Notion property types with appropriate operators.
---@brief ]]

local log_module = require('neotion.log')
local log = log_module.get_logger('ui.filter')

local M = {}

---@alias neotion.FilterOperator
---| "equals" | "does_not_equal"
---| "contains" | "does_not_contain"
---| "starts_with" | "ends_with"
---| "greater_than" | "greater_than_or_equal_to"
---| "less_than" | "less_than_or_equal_to"
---| "before" | "after" | "on_or_before" | "on_or_after"
---| "past_week" | "past_month" | "past_year"
---| "next_week" | "next_month" | "next_year" | "this_week"
---| "is_empty" | "is_not_empty"

---@class neotion.Filter
---@field property string Property name
---@field property_type string Notion property type
---@field operator neotion.FilterOperator
---@field value any Filter value (type depends on operator)

---@class neotion.FilterState
---@field filters neotion.Filter[] Active filters
---@field compound_type "and"|"or" How to combine multiple filters

---Operators available for each property type
---@type table<string, string[]>
M.operators_by_type = {
  title = {
    'equals',
    'does_not_equal',
    'contains',
    'does_not_contain',
    'starts_with',
    'ends_with',
    'is_empty',
    'is_not_empty',
  },
  rich_text = {
    'equals',
    'does_not_equal',
    'contains',
    'does_not_contain',
    'starts_with',
    'ends_with',
    'is_empty',
    'is_not_empty',
  },
  number = {
    'equals',
    'does_not_equal',
    'greater_than',
    'greater_than_or_equal_to',
    'less_than',
    'less_than_or_equal_to',
    'is_empty',
    'is_not_empty',
  },
  checkbox = { 'equals', 'does_not_equal' },
  select = { 'equals', 'does_not_equal', 'is_empty', 'is_not_empty' },
  multi_select = { 'contains', 'does_not_contain', 'is_empty', 'is_not_empty' },
  status = { 'equals', 'does_not_equal', 'is_empty', 'is_not_empty' },
  date = {
    'equals',
    'before',
    'after',
    'on_or_before',
    'on_or_after',
    'past_week',
    'past_month',
    'past_year',
    'next_week',
    'next_month',
    'next_year',
    'this_week',
    'is_empty',
    'is_not_empty',
  },
  people = { 'contains', 'does_not_contain', 'is_empty', 'is_not_empty' },
  files = { 'is_empty', 'is_not_empty' },
  url = {
    'equals',
    'does_not_equal',
    'contains',
    'does_not_contain',
    'starts_with',
    'ends_with',
    'is_empty',
    'is_not_empty',
  },
  email = {
    'equals',
    'does_not_equal',
    'contains',
    'does_not_contain',
    'starts_with',
    'ends_with',
    'is_empty',
    'is_not_empty',
  },
  phone_number = {
    'equals',
    'does_not_equal',
    'contains',
    'does_not_contain',
    'starts_with',
    'ends_with',
    'is_empty',
    'is_not_empty',
  },
  relation = { 'contains', 'does_not_contain', 'is_empty', 'is_not_empty' },
  created_time = {
    'equals',
    'before',
    'after',
    'on_or_before',
    'on_or_after',
    'past_week',
    'past_month',
    'past_year',
    'next_week',
    'next_month',
    'next_year',
    'this_week',
    'is_empty',
    'is_not_empty',
  },
  created_by = { 'contains', 'does_not_contain', 'is_empty', 'is_not_empty' },
  last_edited_time = {
    'equals',
    'before',
    'after',
    'on_or_before',
    'on_or_after',
    'past_week',
    'past_month',
    'past_year',
    'next_week',
    'next_month',
    'next_year',
    'this_week',
    'is_empty',
    'is_not_empty',
  },
  last_edited_by = { 'contains', 'does_not_contain', 'is_empty', 'is_not_empty' },
  unique_id = {
    'equals',
    'does_not_equal',
    'greater_than',
    'greater_than_or_equal_to',
    'less_than',
    'less_than_or_equal_to',
  },
}

---Human-readable operator labels
---@type table<string, string>
M.operator_labels = {
  equals = 'equals',
  does_not_equal = 'does not equal',
  contains = 'contains',
  does_not_contain = 'does not contain',
  starts_with = 'starts with',
  ends_with = 'ends with',
  greater_than = '>',
  greater_than_or_equal_to = '>=',
  less_than = '<',
  less_than_or_equal_to = '<=',
  before = 'before',
  after = 'after',
  on_or_before = 'on or before',
  on_or_after = 'on or after',
  past_week = 'past week',
  past_month = 'past month',
  past_year = 'past year',
  next_week = 'next week',
  next_month = 'next month',
  next_year = 'next year',
  this_week = 'this week',
  is_empty = 'is empty',
  is_not_empty = 'is not empty',
}

---Operators that don't require a value
---@type table<string, boolean>
M.valueless_operators = {
  is_empty = true,
  is_not_empty = true,
  past_week = true,
  past_month = true,
  past_year = true,
  next_week = true,
  next_month = true,
  next_year = true,
  this_week = true,
}

---Get available operators for a property type
---@param property_type string Notion property type
---@return string[] operators List of available operators
function M.get_operators(property_type)
  return M.operators_by_type[property_type] or M.operators_by_type.rich_text
end

---Check if operator requires a value
---@param operator string Operator name
---@return boolean
function M.operator_needs_value(operator)
  return not M.valueless_operators[operator]
end

---Get human-readable label for operator
---@param operator string Operator name
---@return string
function M.get_operator_label(operator)
  return M.operator_labels[operator] or operator
end

---Build a single filter condition for Notion API
---@param filter neotion.Filter Filter specification
---@return table|nil api_filter Notion API filter object
function M.build_single_filter(filter)
  if not filter.property or not filter.operator then
    return nil
  end

  local prop_type = filter.property_type or 'rich_text'

  -- Map property types to API filter keys
  local type_key_map = {
    title = 'rich_text',
    rich_text = 'rich_text',
    number = 'number',
    checkbox = 'checkbox',
    select = 'select',
    multi_select = 'multi_select',
    status = 'status',
    date = 'date',
    people = 'people',
    files = 'files',
    url = 'url',
    email = 'email',
    phone_number = 'phone_number',
    relation = 'relation',
    created_time = 'timestamp',
    created_by = 'people',
    last_edited_time = 'timestamp',
    last_edited_by = 'people',
    unique_id = 'unique_id',
  }

  local filter_key = type_key_map[prop_type] or 'rich_text'

  -- Handle timestamp types specially
  if prop_type == 'created_time' or prop_type == 'last_edited_time' then
    return {
      timestamp = prop_type,
      [filter_key] = {
        [filter.operator] = M.operator_needs_value(filter.operator) and filter.value or true,
      },
    }
  end

  -- Standard property filter
  local condition = {}
  if M.operator_needs_value(filter.operator) then
    condition[filter.operator] = filter.value
  else
    condition[filter.operator] = true
  end

  return {
    property = filter.property,
    [filter_key] = condition,
  }
end

---Build Notion API filter object from filter state
---@param state neotion.FilterState Filter state
---@return table|nil api_filter Notion API filter object
function M.build_api_filter(state)
  if not state or not state.filters or #state.filters == 0 then
    return nil
  end

  -- Single filter - no compound needed
  if #state.filters == 1 then
    return M.build_single_filter(state.filters[1])
  end

  -- Multiple filters - use compound
  local conditions = {}
  for _, filter in ipairs(state.filters) do
    local condition = M.build_single_filter(filter)
    if condition then
      table.insert(conditions, condition)
    end
  end

  if #conditions == 0 then
    return nil
  end

  if #conditions == 1 then
    return conditions[1]
  end

  return {
    [state.compound_type or 'and'] = conditions,
  }
end

---Create empty filter state
---@return neotion.FilterState
function M.create_state()
  return {
    filters = {},
    compound_type = 'and',
  }
end

---Add a filter to state
---@param state neotion.FilterState
---@param filter neotion.Filter
function M.add_filter(state, filter)
  table.insert(state.filters, filter)
end

---Remove filter at index
---@param state neotion.FilterState
---@param index integer
function M.remove_filter(state, index)
  table.remove(state.filters, index)
end

---Clear all filters
---@param state neotion.FilterState
function M.clear_filters(state)
  state.filters = {}
end

---Extract property list from database schema
---@param schema table Database schema from API
---@return table[] properties List of {name, type} pairs
function M.get_properties_from_schema(schema)
  local properties = {}

  if not schema or not schema.properties then
    return properties
  end

  for name, prop in pairs(schema.properties) do
    table.insert(properties, {
      name = name,
      type = prop.type,
    })
  end

  -- Sort alphabetically
  table.sort(properties, function(a, b)
    return a.name < b.name
  end)

  return properties
end

---Show filter selection popup using vim.ui.select
---@param schema table Database schema
---@param current_state neotion.FilterState Current filter state
---@param on_change fun(state: neotion.FilterState) Callback when filter changes
function M.show_popup(schema, current_state, on_change)
  local properties = M.get_properties_from_schema(schema)

  if #properties == 0 then
    vim.notify('[neotion] No filterable properties found', vim.log.levels.WARN)
    return
  end

  -- Step 1: Select property
  vim.ui.select(properties, {
    prompt = 'Select property to filter:',
    format_item = function(item)
      return item.name .. ' (' .. item.type .. ')'
    end,
  }, function(property)
    if not property then
      return
    end

    -- Step 2: Select operator
    local operators = M.get_operators(property.type)
    local operator_items = {}
    for _, op in ipairs(operators) do
      table.insert(operator_items, {
        operator = op,
        label = M.get_operator_label(op),
      })
    end

    vim.ui.select(operator_items, {
      prompt = 'Select operator:',
      format_item = function(item)
        return item.label
      end,
    }, function(op_item)
      if not op_item then
        return
      end

      local operator = op_item.operator

      -- Step 3: Get value (if needed)
      if M.operator_needs_value(operator) then
        vim.ui.input({
          prompt = 'Enter value: ',
        }, function(value)
          if not value or value == '' then
            return
          end

          -- Parse value based on type
          local parsed_value = value
          if property.type == 'number' or property.type == 'unique_id' then
            parsed_value = tonumber(value) or value
          elseif property.type == 'checkbox' then
            parsed_value = value:lower() == 'true' or value == '1' or value:lower() == 'yes'
          end

          local filter = {
            property = property.name,
            property_type = property.type,
            operator = operator,
            value = parsed_value,
          }

          M.add_filter(current_state, filter)
          log.debug('Filter added', { filter = filter })
          on_change(current_state)
        end)
      else
        -- Valueless operator
        local filter = {
          property = property.name,
          property_type = property.type,
          operator = operator,
          value = nil,
        }

        M.add_filter(current_state, filter)
        log.debug('Filter added', { filter = filter })
        on_change(current_state)
      end
    end)
  end)
end

---Format filter state for display
---@param state neotion.FilterState
---@return string
function M.format_state(state)
  if not state or not state.filters or #state.filters == 0 then
    return 'No filters'
  end

  local parts = {}
  for _, filter in ipairs(state.filters) do
    local value_str = ''
    if filter.value ~= nil then
      value_str = ' ' .. tostring(filter.value)
    end
    table.insert(parts, filter.property .. ' ' .. M.get_operator_label(filter.operator) .. value_str)
  end

  local connector = state.compound_type == 'or' and ' OR ' or ' AND '
  return table.concat(parts, connector)
end

return M
