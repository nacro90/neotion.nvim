---Database row model for Neotion
---Represents a single row in a Notion database (a page with properties)
---@class neotion.model.Database
local M = {}

---@alias neotion.PropertyType
---| "title"
---| "rich_text"
---| "number"
---| "select"
---| "multi_select"
---| "status"
---| "date"
---| "checkbox"
---| "url"
---| "email"
---| "phone_number"
---| "people"
---| "relation"
---| "files"
---| "created_time"
---| "created_by"
---| "last_edited_time"
---| "last_edited_by"
---| "formula"
---| "rollup"
---| "unique_id"

---@class neotion.PropertyValue
---@field type neotion.PropertyType
---@field value any Type-specific value

---@class neotion.DatabaseRow
---@field id string Page ID from Notion
---@field raw table Original Notion JSON (preserved for round-trip)
---@field line_start integer|nil Buffer line start (1-indexed)
---@field line_end integer|nil Buffer line end (1-indexed)
local DatabaseRow = {}
DatabaseRow.__index = DatabaseRow

---Extract value from a property based on its type
---@param prop table Raw Notion property
---@return neotion.PropertyValue
local function extract_property_value(prop)
  local prop_type = prop.type

  -- Handle nil/unknown type
  if not prop_type then
    return { type = 'unknown', value = nil }
  end

  if prop_type == 'title' or prop_type == 'rich_text' then
    local texts = prop[prop_type] or {}
    local result = {}
    for _, text in ipairs(texts) do
      table.insert(result, text.plain_text or '')
    end
    return {
      type = prop_type,
      value = table.concat(result, ''),
    }
  elseif prop_type == 'select' or prop_type == 'status' then
    return {
      type = prop_type,
      value = prop[prop_type],
    }
  elseif prop_type == 'multi_select' then
    return {
      type = prop_type,
      value = prop.multi_select or {},
    }
  elseif prop_type == 'checkbox' then
    return {
      type = prop_type,
      value = prop.checkbox,
    }
  elseif prop_type == 'number' then
    return {
      type = prop_type,
      value = prop.number,
    }
  elseif prop_type == 'date' then
    return {
      type = prop_type,
      value = prop.date,
    }
  elseif prop_type == 'url' then
    return {
      type = prop_type,
      value = prop.url,
    }
  elseif prop_type == 'email' then
    return {
      type = prop_type,
      value = prop.email,
    }
  elseif prop_type == 'phone_number' then
    return {
      type = prop_type,
      value = prop.phone_number,
    }
  elseif prop_type == 'created_time' then
    return {
      type = prop_type,
      value = prop.created_time,
    }
  elseif prop_type == 'created_by' then
    return {
      type = prop_type,
      value = prop.created_by,
    }
  elseif prop_type == 'last_edited_time' then
    return {
      type = prop_type,
      value = prop.last_edited_time,
    }
  elseif prop_type == 'last_edited_by' then
    return {
      type = prop_type,
      value = prop.last_edited_by,
    }
  elseif prop_type == 'formula' then
    return {
      type = prop_type,
      value = prop.formula,
    }
  elseif prop_type == 'rollup' then
    return {
      type = prop_type,
      value = prop.rollup,
    }
  elseif prop_type == 'relation' then
    return {
      type = prop_type,
      value = prop.relation or {},
    }
  elseif prop_type == 'people' then
    return {
      type = prop_type,
      value = prop.people or {},
    }
  elseif prop_type == 'unique_id' then
    return {
      type = prop_type,
      value = prop.unique_id,
    }
  elseif prop_type == 'files' then
    return {
      type = prop_type,
      value = prop.files or {},
    }
  else
    -- Unknown type, return raw value
    return {
      type = prop_type,
      value = prop[prop_type],
    }
  end
end

---Create a new DatabaseRow from Notion API page JSON
---@param raw table Notion API page JSON
---@return neotion.DatabaseRow
function DatabaseRow.new(raw)
  vim.validate({
    raw = { raw, 'table' },
  })

  local self = setmetatable({}, DatabaseRow)
  self.id = raw.id or ''
  self.raw = raw
  self.line_start = nil
  self.line_end = nil
  return self
end

---Get the title of this database row
---Searches for the property with type 'title'
---@return string
function DatabaseRow:get_title()
  local properties = self.raw.properties
  if not properties then
    return 'Untitled'
  end

  -- Find the title property (any property with type 'title')
  for _, prop in pairs(properties) do
    if prop.type == 'title' then
      local title_parts = prop.title or {}
      if #title_parts == 0 then
        return 'Untitled'
      end
      local result = {}
      for _, part in ipairs(title_parts) do
        table.insert(result, part.plain_text or '')
      end
      return table.concat(result, '')
    end
  end

  return 'Untitled'
end

---Get a property value by name
---@param name string Property name
---@return neotion.PropertyValue|nil
function DatabaseRow:get_property(name)
  local properties = self.raw.properties
  if not properties then
    return nil
  end

  local prop = properties[name]
  if not prop then
    return nil
  end

  return extract_property_value(prop)
end

---Get all property names
---@return string[]
function DatabaseRow:get_property_names()
  local properties = self.raw.properties
  if not properties then
    return {}
  end

  local names = {}
  for name, _ in pairs(properties) do
    table.insert(names, name)
  end
  return names
end

---Format row to buffer lines (basic: just title)
---@return string[]
function DatabaseRow:format()
  return { self:get_title() }
end

---Set buffer line range for this row
---@param line_start integer 1-indexed start line
---@param line_end integer 1-indexed end line
function DatabaseRow:set_line_range(line_start, line_end)
  self.line_start = line_start
  self.line_end = line_end
end

---Get buffer line range
---@return integer|nil line_start
---@return integer|nil line_end
function DatabaseRow:get_line_range()
  return self.line_start, self.line_end
end

---Check if a line is within this row's range
---@param line integer 1-indexed line number
---@return boolean
function DatabaseRow:contains_line(line)
  if not self.line_start or not self.line_end then
    return false
  end
  return line >= self.line_start and line <= self.line_end
end

---Get the icon for this row (page icon)
---@return string|nil
function DatabaseRow:get_icon()
  local icon = self.raw.icon
  if not icon then
    return nil
  end

  if icon.type == 'emoji' then
    return icon.emoji
  elseif icon.type == 'external' or icon.type == 'file' then
    -- Return nf-fa-image placeholder for non-emoji icons
    return '\u{f03e}'
  end

  return nil
end

M.DatabaseRow = DatabaseRow

---Deserialize raw pages from database query to DatabaseRow array
---@param raw_pages table[]|nil Raw Notion API pages
---@return neotion.DatabaseRow[]
function M.deserialize_database_rows(raw_pages)
  if not raw_pages then
    return {}
  end

  local rows = {}
  for _, raw in ipairs(raw_pages) do
    table.insert(rows, DatabaseRow.new(raw))
  end
  return rows
end

return M
