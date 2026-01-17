---DatabaseView model for Neotion
---Represents a database table view with column selection, formatting, and state
---@class neotion.model.DatabaseView
local M = {}

local database = require('neotion.model.database')

--- Display string for empty/null values
local EMPTY_VALUE = '-'

---Check if value is empty (nil, vim.NIL, or empty string)
---@param value any
---@return boolean
local function is_empty(value)
  return value == nil or value == vim.NIL or value == ''
end

---@class neotion.ColumnConfig
---@field name string Property name
---@field type neotion.PropertyType Property type
---@field width number Calculated column width
---@field max_width number Maximum allowed width

---@class neotion.DatabaseView
---@field database_id string Database ID
---@field title string Database title
---@field icon string|nil Database icon (emoji or placeholder)
---@field schema table<string, table> Property schema from database
---@field rows neotion.DatabaseRow[] Database rows
---@field columns neotion.ColumnConfig[] Selected and configured columns
---@field filter_state table|nil Current filter state
---@field sort_state table|nil Current sort state
---@field has_more boolean More rows available from API
---@field next_cursor string|nil Cursor for pagination
---@field header_line_count number Number of header lines (title + table header)
local DatabaseView = {}
DatabaseView.__index = DatabaseView

-- Column type priorities for auto-selection (higher = more important)
local COLUMN_PRIORITY = {
  title = 100, -- Always first
  status = 90,
  select = 85,
  date = 80,
  checkbox = 75,
  number = 70,
  rich_text = 60,
  url = 50,
  email = 45,
  phone_number = 40,
  created_time = 35,
  last_edited_time = 30,
  -- Lower priority (complex types)
  multi_select = 25,
  people = 20,
  relation = 15,
  formula = 10,
  rollup = 5,
  files = 0,
  unique_id = 0,
}

-- Default column widths by type
local DEFAULT_WIDTHS = {
  title = 30,
  status = 15,
  select = 15,
  multi_select = 20,
  date = 12,
  checkbox = 5,
  number = 10,
  rich_text = 25,
  url = 25,
  email = 25,
  created_time = 12,
  last_edited_time = 12,
}

---Extract title from database raw data
---@param raw table Notion database object
---@return string
local function extract_database_title(raw)
  if not raw.title then
    return 'Untitled Database'
  end

  local parts = {}
  for _, text in ipairs(raw.title) do
    if text.plain_text then
      table.insert(parts, text.plain_text)
    end
  end

  return #parts > 0 and table.concat(parts) or 'Untitled Database'
end

---Extract icon from database raw data
---@param raw table Notion database object
---@return string|nil
local function extract_database_icon(raw)
  local icon = raw.icon
  -- Handle nil, vim.NIL (JSON null), or non-table values
  if not icon or icon == vim.NIL or type(icon) ~= 'table' then
    return nil
  end

  if icon.type == 'emoji' then
    return icon.emoji
  elseif icon.type == 'external' or icon.type == 'file' then
    return '\u{f03e}' -- nf-fa-image placeholder
  end

  return nil
end

---Create a new DatabaseView from API data
---@param raw_database table Notion database object
---@param raw_rows table[]|nil Raw page objects from query
---@param query_result table|nil Query result with pagination info
---@return neotion.DatabaseView
function DatabaseView.new(raw_database, raw_rows, query_result)
  local self = setmetatable({}, DatabaseView)

  self.database_id = (raw_database.id or ''):gsub('-', '')
  self.title = extract_database_title(raw_database)
  self.icon = extract_database_icon(raw_database)
  self.schema = raw_database.properties or {}
  self.rows = database.deserialize_database_rows(raw_rows)
  self.columns = {}
  self.filter_state = nil
  self.sort_state = nil
  self.has_more = query_result and query_result.has_more or false
  self.next_cursor = query_result and query_result.next_cursor or nil
  self.header_line_count = 4 -- Default: title line + blank + table header + separator

  -- Auto-select columns based on schema
  self:select_columns()

  return self
end

---Select which columns to display based on schema and priority
---@param max_columns? number Maximum columns to show (default: 6)
function DatabaseView:select_columns(max_columns)
  max_columns = max_columns or 6
  self.columns = {}

  -- Build list of all properties with their priorities
  local candidates = {}
  for name, prop in pairs(self.schema) do
    local priority = COLUMN_PRIORITY[prop.type] or 0
    table.insert(candidates, {
      name = name,
      type = prop.type,
      priority = priority,
    })
  end

  -- Sort by priority (descending)
  table.sort(candidates, function(a, b)
    return a.priority > b.priority
  end)

  -- Select top N columns
  for i = 1, math.min(#candidates, max_columns) do
    local candidate = candidates[i]
    table.insert(self.columns, {
      name = candidate.name,
      type = candidate.type,
      width = DEFAULT_WIDTHS[candidate.type] or 20,
      max_width = 40,
    })
  end

  -- Calculate actual widths based on content
  self:calculate_column_widths()
end

---Calculate column widths based on actual content
function DatabaseView:calculate_column_widths()
  for _, col in ipairs(self.columns) do
    -- Start with header width
    local max_width = vim.fn.strdisplaywidth(col.name)

    -- Check content widths
    for _, row in ipairs(self.rows) do
      local cell = self:format_cell(row, col.name)
      local cell_width = vim.fn.strdisplaywidth(cell)
      max_width = math.max(max_width, cell_width)
    end

    -- Clamp to min/max
    col.width = math.max(8, math.min(max_width, col.max_width))
  end
end

---Format a cell value for display
---@param row neotion.DatabaseRow
---@param prop_name string Property name
---@return string
function DatabaseView:format_cell(row, prop_name)
  local prop = row:get_property(prop_name)
  if not prop then
    return EMPTY_VALUE
  end

  local value = prop.value
  local prop_type = prop.type

  if is_empty(value) then
    return EMPTY_VALUE
  end

  if prop_type == 'title' or prop_type == 'rich_text' then
    return tostring(value) or EMPTY_VALUE
  elseif prop_type == 'select' or prop_type == 'status' then
    if type(value) == 'table' and value.name then
      return value.name
    end
    return EMPTY_VALUE
  elseif prop_type == 'multi_select' then
    if type(value) == 'table' then
      local names = {}
      for _, item in ipairs(value) do
        if item.name then
          table.insert(names, item.name)
        end
      end
      return #names > 0 and table.concat(names, ', ') or EMPTY_VALUE
    end
    return EMPTY_VALUE
  elseif prop_type == 'checkbox' then
    -- checkbox with vim.NIL means unchecked (not set)
    if value == vim.NIL then
      return '[ ]'
    end
    return value and '[x]' or '[ ]'
  elseif prop_type == 'number' then
    if is_empty(value) then
      return EMPTY_VALUE
    end
    return tostring(value)
  elseif prop_type == 'date' then
    if type(value) == 'table' and value.start then
      -- Format as YYYY-MM-DD
      return value.start:sub(1, 10)
    end
    return EMPTY_VALUE
  elseif prop_type == 'url' then
    if type(value) == 'string' and #value > 0 then
      -- Truncate long URLs
      if #value > 30 then
        return value:sub(1, 27) .. '...'
      end
      return value
    end
    return EMPTY_VALUE
  elseif prop_type == 'email' or prop_type == 'phone_number' then
    return (type(value) == 'string' and not is_empty(value)) and value or EMPTY_VALUE
  elseif prop_type == 'created_time' or prop_type == 'last_edited_time' then
    if type(value) == 'string' then
      return value:sub(1, 10)
    end
    return EMPTY_VALUE
  elseif prop_type == 'people' then
    if type(value) == 'table' then
      local count = #value
      return count > 0 and (count .. ' user' .. (count > 1 and 's' or '')) or EMPTY_VALUE
    end
    return EMPTY_VALUE
  elseif prop_type == 'relation' then
    if type(value) == 'table' then
      local count = #value
      return count > 0 and (count .. ' linked') or EMPTY_VALUE
    end
    return EMPTY_VALUE
  elseif prop_type == 'formula' then
    if type(value) == 'table' then
      local formula_type = value.type
      if formula_type == 'string' then
        return value.string or EMPTY_VALUE
      elseif formula_type == 'number' then
        return tostring(value.number)
      elseif formula_type == 'boolean' then
        return value.boolean and 'true' or 'false'
      elseif formula_type == 'date' and value.date then
        return value.date.start:sub(1, 10)
      end
    end
    return EMPTY_VALUE
  elseif prop_type == 'files' then
    if type(value) == 'table' then
      local count = #value
      return count > 0 and (count .. ' file' .. (count > 1 and 's' or '')) or EMPTY_VALUE
    end
    return EMPTY_VALUE
  elseif prop_type == 'unique_id' then
    if type(value) == 'table' and value.number then
      local prefix = value.prefix or ''
      return prefix .. tostring(value.number)
    end
    return EMPTY_VALUE
  end

  return EMPTY_VALUE
end

---Truncate string to width with ellipsis
---@param str string
---@param width number
---@return string
local function truncate(str, width)
  local display_width = vim.fn.strdisplaywidth(str)
  if display_width <= width then
    return str
  end

  -- Truncate and add ellipsis
  local result = ''
  local current_width = 0
  for char in str:gmatch('.') do
    local char_width = vim.fn.strdisplaywidth(char)
    if current_width + char_width + 3 > width then -- +3 for '...'
      break
    end
    result = result .. char
    current_width = current_width + char_width
  end

  return result .. '...'
end

---Pad string to width
---@param str string
---@param width number
---@param align? "left"|"right"|"center" Default: "left"
---@return string
local function pad(str, width, align)
  align = align or 'left'
  local display_width = vim.fn.strdisplaywidth(str)
  local padding = width - display_width

  if padding <= 0 then
    return str
  end

  if align == 'right' then
    return string.rep(' ', padding) .. str
  elseif align == 'center' then
    local left = math.floor(padding / 2)
    local right = padding - left
    return string.rep(' ', left) .. str .. string.rep(' ', right)
  else
    return str .. string.rep(' ', padding)
  end
end

---Format the database title header
---@return string[]
function DatabaseView:format_header()
  local lines = {}

  -- Title line with icon
  local title_line = ''
  if self.icon then
    title_line = self.icon .. ' '
  end
  title_line = title_line .. self.title

  -- Add row count and filter status
  local status_parts = {}
  table.insert(status_parts, '[' .. #self.rows .. ' rows]')

  if self.filter_state and self.filter_state.filters and #self.filter_state.filters > 0 then
    table.insert(status_parts, '[Filtered]')
  end
  if self.sort_state and self.sort_state.sorts and #self.sort_state.sorts > 0 then
    table.insert(status_parts, '[Sorted]')
  end
  if self.has_more then
    table.insert(status_parts, '[More...]')
  end

  title_line = title_line .. string.rep(' ', 4) .. table.concat(status_parts, ' ')
  table.insert(lines, title_line)

  -- Blank line
  table.insert(lines, '')

  return lines
end

---Format the table header row
---@return string
function DatabaseView:format_table_header()
  local cells = {}
  for _, col in ipairs(self.columns) do
    local header = truncate(col.name, col.width)
    table.insert(cells, pad(header, col.width))
  end
  return '| ' .. table.concat(cells, ' | ') .. ' |'
end

---Format the separator row
---@return string
function DatabaseView:format_separator()
  local cells = {}
  for _, col in ipairs(self.columns) do
    table.insert(cells, string.rep('-', col.width))
  end
  return '|-' .. table.concat(cells, '-|-') .. '-|'
end

---Format a data row
---@param row neotion.DatabaseRow
---@return string
function DatabaseView:format_data_row(row)
  local cells = {}
  for _, col in ipairs(self.columns) do
    local cell = self:format_cell(row, col.name)
    cell = truncate(cell, col.width)

    -- Right-align numbers
    local align = 'left'
    if col.type == 'number' then
      align = 'right'
    end

    table.insert(cells, pad(cell, col.width, align))
  end
  return '| ' .. table.concat(cells, ' | ') .. ' |'
end

---Format entire view to buffer lines
---@return string[]
function DatabaseView:format()
  local lines = {}

  -- Header (title + status)
  vim.list_extend(lines, self:format_header())

  -- Table header
  table.insert(lines, self:format_table_header())

  -- Separator
  table.insert(lines, self:format_separator())

  -- Data rows
  local data_start_line = #lines + 1
  for i, row in ipairs(self.rows) do
    local row_line = self:format_data_row(row)
    table.insert(lines, row_line)
    -- Set line range for navigation (1-indexed)
    row:set_line_range(data_start_line + i - 1, data_start_line + i - 1)
  end

  -- Store header line count for line range calculations
  self.header_line_count = data_start_line - 1

  -- Help line if no rows
  if #self.rows == 0 then
    table.insert(lines, '')
    table.insert(lines, 'No results. Press f to filter, r to refresh.')
  end

  return lines
end

---Add more rows (for pagination)
---@param raw_rows table[] Raw page objects
---@param query_result table Query result with pagination info
function DatabaseView:append_rows(raw_rows, query_result)
  local new_rows = database.deserialize_database_rows(raw_rows)
  vim.list_extend(self.rows, new_rows)
  self.has_more = query_result and query_result.has_more or false
  self.next_cursor = query_result and query_result.next_cursor or nil

  -- Recalculate column widths with new data
  self:calculate_column_widths()
end

---Get row at buffer line
---@param line number 1-indexed buffer line
---@return neotion.DatabaseRow|nil
function DatabaseView:get_row_at_line(line)
  for _, row in ipairs(self.rows) do
    if row:contains_line(line) then
      return row
    end
  end
  return nil
end

---Clear rows (for re-query)
function DatabaseView:clear_rows()
  self.rows = {}
  self.has_more = false
  self.next_cursor = nil
end

M.DatabaseView = DatabaseView

return M
