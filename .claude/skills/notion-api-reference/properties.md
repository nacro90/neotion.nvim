# Notion Page Properties Reference

Complete reference for Notion page properties, types, and metadata.

## Property Structure

Properties are part of page objects (not blocks). Every page has a `properties` field:

```json
{
  "object": "page",
  "id": "uuid",
  "properties": {
    "title": { ... },              // Required: title property
    "Status": { ... },             // Custom properties
    "Tags": { ... }
  }
}
```

**Key points:**
- Property names are case-sensitive
- Every page **must** have a `title` property
- Property types cannot be changed after creation
- Database pages have predefined property schema

**Codebase grep:**
```bash
grep -r "properties\|page\.properties" lua/neotion/api/pages.lua
```

---

## Title Property (Required)

**Every page must have exactly one title property.**

```json
{
  "title": {
    "type": "title",
    "title": [                     // Rich text array
      {
        "type": "text",
        "text": { "content": "Page Title" }
      }
    ]
  }
}
```

**Create page with title:**
```lua
local page = api.pages.create({
  parent = { page_id = parent_id },
  properties = {
    title = {
      title = {
        { type = "text", text = { content = "My Page" } }
      }
    }
  }
})
```

**Important:**
- Property name is always `"title"` (lowercase)
- Type is `"title"`
- Value is array of rich text objects
- Cannot have multiple title properties

---

## Text Properties

### Rich Text
```json
{
  "Description": {
    "type": "rich_text",
    "rich_text": [                 // Array of rich text
      {
        "type": "text",
        "text": { "content": "Some text" },
        "annotations": {
          "bold": true,
          "color": "blue"
        }
      }
    ]
  }
}
```

**Supports:**
- Multiple rich text objects
- All annotations (bold, italic, etc.)
- Links, mentions, equations

---

### URL
```json
{
  "Website": {
    "type": "url",
    "url": "https://example.com"  // String or null
  }
}
```

**Validation:**
- Must be valid URL format
- `null` allowed (empty)

---

### Email
```json
{
  "Contact": {
    "type": "email",
    "email": "user@example.com"   // String or null
  }
}
```

**Validation:**
- Must be valid email format
- `null` allowed (empty)

---

### Phone Number
```json
{
  "Phone": {
    "type": "phone_number",
    "phone_number": "+1234567890"  // String or null
  }
}
```

**Format:**
- Free-form string
- No strict validation
- `null` allowed (empty)

---

## Number Properties

### Number
```json
{
  "Price": {
    "type": "number",
    "number": 42.5                 // Float or null
  }
}
```

**Supports:**
- Integers and floats
- Negative numbers
- `null` (empty)

**Example:**
```lua
properties = {
  Price = {
    type = "number",
    number = 99.99
  }
}
```

---

## Select Properties

### Select (Single Choice)
```json
{
  "Status": {
    "type": "select",
    "select": {
      "name": "In Progress",       // Option name
      "color": "blue"              // Option color
    }
  }
}
```

**Or null (empty):**
```json
{
  "Status": {
    "type": "select",
    "select": null
  }
}
```

**Colors:**
- `default`, `gray`, `brown`, `orange`, `yellow`, `green`, `blue`, `purple`, `pink`, `red`

**Important:**
- Options are auto-created if they don't exist
- Cannot control option IDs
- Cannot delete options via API

**Example:**
```lua
properties = {
  Status = {
    type = "select",
    select = { name = "Done", color = "green" }
  }
}
```

---

### Multi-Select (Multiple Choices)
```json
{
  "Tags": {
    "type": "multi_select",
    "multi_select": [              // Array of options
      { "name": "Tag 1", "color": "blue" },
      { "name": "Tag 2", "color": "green" }
    ]
  }
}
```

**Or empty array:**
```json
{
  "Tags": {
    "type": "multi_select",
    "multi_select": []
  }
}
```

**Example:**
```lua
properties = {
  Tags = {
    type = "multi_select",
    multi_select = {
      { name = "urgent", color = "red" },
      { name = "important", color = "orange" }
    }
  }
}
```

**Codebase grep:**
```bash
grep -r "select\|multi_select" lua/neotion/model/
```

---

## Date Properties

### Date
```json
{
  "Due Date": {
    "type": "date",
    "date": {
      "start": "2024-01-01",
      "end": "2024-01-31",         // Optional (for ranges)
      "time_zone": "America/New_York"  // Optional
    }
  }
}
```

**Or null (empty):**
```json
{
  "Due Date": {
    "type": "date",
    "date": null
  }
}
```

**Date Formats:**
- Date only: `"2024-01-01"`
- Date + time: `"2024-01-01T14:30:00"`
- ISO 8601 format

**Date Range:**
```json
{
  "date": {
    "start": "2024-01-01",
    "end": "2024-01-31"
  }
}
```

**Time Zones:**
- Use IANA time zone names
- Examples: `"America/New_York"`, `"Europe/London"`, `"Asia/Tokyo"`
- Optional field

**Example:**
```lua
properties = {
  ["Due Date"] = {
    type = "date",
    date = {
      start = "2024-12-31",
      end = nil,                   -- Single date
      time_zone = nil
    }
  }
}
```

---

## Boolean Properties

### Checkbox
```json
{
  "Done": {
    "type": "checkbox",
    "checkbox": true               // Boolean
  }
}
```

**Values:**
- `true` - Checked
- `false` - Unchecked

**Example:**
```lua
properties = {
  Done = {
    type = "checkbox",
    checkbox = true
  }
}
```

---

## Relation Properties

### Relation (Link to Other Pages)
```json
{
  "Related": {
    "type": "relation",
    "relation": [                  // Array of page references
      { "id": "page_uuid_1" },
      { "id": "page_uuid_2" }
    ]
  }
}
```

**Or empty array:**
```json
{
  "Related": {
    "type": "relation",
    "relation": []
  }
}
```

**Important:**
- Must be configured in database schema first
- Cannot create relation properties via API
- Can only update existing relations
- Pages must be in related database

**Example:**
```lua
properties = {
  Related = {
    type = "relation",
    relation = {
      { id = "abc123..." },
      { id = "def456..." }
    }
  }
}
```

---

## File Properties

### Files
```json
{
  "Attachments": {
    "type": "files",
    "files": [                     // Array of files
      {
        "name": "document.pdf",
        "type": "external",
        "external": {
          "url": "https://example.com/doc.pdf"
        }
      }
    ]
  }
}
```

**Or empty array:**
```json
{
  "Attachments": {
    "type": "files",
    "files": []
  }
}
```

**File Types:**
- `external` - URL to external file
- `file` - Uploaded to Notion (has expiring URL)

**Example:**
```lua
properties = {
  Attachments = {
    type = "files",
    files = {
      {
        name = "report.pdf",
        type = "external",
        external = { url = "https://example.com/report.pdf" }
      }
    }
  }
}
```

---

## Read-Only Properties

These properties are computed by Notion and **cannot be updated** via API:

### Created Time
```json
{
  "Created": {
    "type": "created_time",
    "created_time": "2024-01-01T12:00:00.000Z"  // ISO 8601
  }
}
```

---

### Created By
```json
{
  "Created By": {
    "type": "created_by",
    "created_by": {
      "object": "user",
      "id": "user_uuid",
      "name": "John Doe",
      "avatar_url": "https://...",
      "type": "person",            // or "bot"
      "person": {
        "email": "john@example.com"
      }
    }
  }
}
```

---

### Last Edited Time
```json
{
  "Last Edited": {
    "type": "last_edited_time",
    "last_edited_time": "2024-01-15T14:30:00.000Z"
  }
}
```

---

### Last Edited By
```json
{
  "Last Edited By": {
    "type": "last_edited_by",
    "last_edited_by": {
      "object": "user",
      "id": "user_uuid"
    }
  }
}
```

---

### Formula
```json
{
  "Total": {
    "type": "formula",
    "formula": {
      "type": "number",            // Result type: number, string, boolean, date
      "number": 42.5
    }
  }
}
```

**Formula types:**
- `number` - Numeric result
- `string` - Text result
- `boolean` - True/false result
- `date` - Date result

**Important:**
- Formula is defined in database schema
- Cannot update via API
- Only read values

---

### Rollup
```json
{
  "Sum of Prices": {
    "type": "rollup",
    "rollup": {
      "type": "number",            // Result type
      "number": 123.45,
      "function": "sum"            // Aggregation function
    }
  }
}
```

**Rollup functions:**
- `count`, `count_values`, `empty`, `not_empty`, `unique`, `show_unique`
- `percent_empty`, `percent_not_empty`
- `sum`, `average`, `median`, `min`, `max`, `range`
- `earliest_date`, `latest_date`, `date_range`
- `checked`, `unchecked`, `percent_checked`, `percent_unchecked`

**Important:**
- Rollup is defined in database schema
- Cannot update via API
- Only read aggregated values

---

## Property Limitations

### Cannot Change Property Type

Once a property is created, its type cannot be changed via API.

❌ **Cannot do this:**
```lua
-- Change "Status" from select to multi_select
properties = {
  Status = {
    type = "multi_select",         -- Error: type mismatch
    multi_select = [...]
  }
}
```

✅ **Must:**
- Manually change in Notion UI
- Or create new property with different name

---

### Auto-Created Select Options

When you set a select/multi-select value with a new option name, Notion auto-creates it:

```lua
properties = {
  Status = {
    type = "select",
    select = { name = "New Status" }  -- Auto-created if doesn't exist
  }
}
```

**Implications:**
- Typos create unwanted options
- Cannot control option order
- Cannot delete options via API

**Best practice:** Validate option names before setting.

---

### Relation Properties Must Pre-Exist

Cannot create relation properties via API. They must be configured in the database schema first (in Notion UI).

---

### Formula/Rollup Are Read-Only

Cannot set or update formula/rollup values. They are computed by Notion.

---

## Property Naming

**Case-sensitive:**
- `"Status"` ≠ `"status"`
- Must match exactly

**Special characters allowed:**
- Spaces: `"Due Date"`
- Emojis: `"📅 Deadline"`
- Most Unicode characters

**Best practices:**
- Use descriptive names
- Be consistent with casing
- Avoid special characters that might cause issues in code

---

## Creating Pages with Properties

**Basic page:**
```lua
local page = api.pages.create({
  parent = { page_id = parent_id },
  properties = {
    title = {
      title = { { type = "text", text = { content = "New Page" } } }
    }
  }
})
```

**Page with multiple properties:**
```lua
local page = api.pages.create({
  parent = { database_id = database_id },
  properties = {
    title = {
      title = { { type = "text", text = { content = "Task" } } }
    },
    Status = {
      type = "select",
      select = { name = "In Progress" }
    },
    ["Due Date"] = {
      type = "date",
      date = { start = "2024-12-31" }
    },
    Done = {
      type = "checkbox",
      checkbox = false
    }
  }
})
```

---

## Updating Page Properties

**Update specific properties:**
```lua
api.pages.update(page_id, {
  properties = {
    Status = {
      select = { name = "Completed" }
    },
    Done = {
      checkbox = true
    }
  }
})
```

**Important:**
- Only updated properties need to be included
- Other properties remain unchanged
- Must include type for some properties

---

## Reading Page Properties

**Get page with properties:**
```lua
local page = api.pages.get(page_id)

-- Access properties
local title = page.properties.title.title[1].plain_text
local status = page.properties.Status.select.name
local done = page.properties.Done.checkbox
```

**Handle optional properties:**
```lua
local function get_property_value(page, property_name)
  local prop = page.properties[property_name]
  if not prop then
    return nil
  end

  -- Handle different types
  if prop.type == "select" then
    return prop.select and prop.select.name or nil
  elseif prop.type == "checkbox" then
    return prop.checkbox
  elseif prop.type == "number" then
    return prop.number
  -- etc...
  end
end
```

---

## Property Type Detection

**Codebase pattern:**
```lua
local function get_property_type(prop)
  return prop.type
end

local function format_property_value(prop)
  if prop.type == "title" or prop.type == "rich_text" then
    return prop[prop.type][1] and prop[prop.type][1].plain_text or ""
  elseif prop.type == "select" then
    return prop.select and prop.select.name or ""
  elseif prop.type == "multi_select" then
    local names = {}
    for _, opt in ipairs(prop.multi_select) do
      table.insert(names, opt.name)
    end
    return table.concat(names, ", ")
  elseif prop.type == "checkbox" then
    return tostring(prop.checkbox)
  elseif prop.type == "number" then
    return tostring(prop.number)
  elseif prop.type == "date" then
    return prop.date and prop.date.start or ""
  -- etc...
  end
end
```

**Codebase grep:**
```bash
grep -r "properties\.\|property.*type" lua/neotion/model/
```

---

## Common Patterns

### Extract Plain Text from Title
```lua
local function get_page_title(page)
  local title_prop = page.properties.title
  if not title_prop or not title_prop.title[1] then
    return ""
  end
  return title_prop.title[1].plain_text
end
```

---

### Update Select Option
```lua
local function update_status(page_id, status_name)
  api.pages.update(page_id, {
    properties = {
      Status = {
        select = { name = status_name }
      }
    }
  })
end
```

---

### Toggle Checkbox
```lua
local function toggle_checkbox(page_id, property_name)
  local page = api.pages.get(page_id)
  local current = page.properties[property_name].checkbox

  api.pages.update(page_id, {
    properties = {
      [property_name] = {
        checkbox = not current
      }
    }
  })
end
```

---

### Add Multi-Select Tags
```lua
local function add_tags(page_id, new_tags)
  local page = api.pages.get(page_id)
  local current_tags = page.properties.Tags.multi_select

  -- Merge with new tags
  local tag_names = {}
  for _, tag in ipairs(current_tags) do
    tag_names[tag.name] = true
  end

  local all_tags = vim.deepcopy(current_tags)
  for _, new_tag in ipairs(new_tags) do
    if not tag_names[new_tag] then
      table.insert(all_tags, { name = new_tag })
    end
  end

  api.pages.update(page_id, {
    properties = {
      Tags = {
        multi_select = all_tags
      }
    }
  })
end
```

---

## Debugging Properties

### Log Property Structure
```lua
local function debug_properties(page)
  for name, prop in pairs(page.properties) do
    print(string.format("Property: %s, Type: %s", name, prop.type))
    print(vim.inspect(prop))
  end
end
```

---

### Validate Property Before Update
```lua
local function validate_property(prop_name, prop_type, prop_value)
  if prop_type == "select" then
    assert(type(prop_value) == "table", "Select must be table")
    assert(prop_value.name, "Select must have name")
  elseif prop_type == "checkbox" then
    assert(type(prop_value) == "boolean", "Checkbox must be boolean")
  elseif prop_type == "number" then
    assert(type(prop_value) == "number", "Number must be number type")
  -- etc...
  end
end
```

---

## Grep Patterns Summary

```bash
# Properties general
grep -r "properties\|page\.properties" lua/neotion/api/pages.lua

# Select properties
grep -r "select\|multi_select" lua/neotion/model/

# Property types
grep -r "properties\.\|property.*type" lua/neotion/model/

# Title extraction
grep -r "title\|plain_text" lua/neotion/model/

# Date properties
grep -r "date\|start.*end" lua/neotion/model/

# Checkbox properties
grep -r "checkbox" lua/neotion/model/
```

---

## Quick Reference Card

| Property Type | Value Type | Nullable | Read-Only |
|---------------|------------|----------|-----------|
| title | rich_text[] | No | No |
| rich_text | rich_text[] | Yes (empty []) | No |
| number | float | Yes | No |
| select | { name, color } | Yes | No |
| multi_select | [{ name, color }] | Yes (empty []) | No |
| date | { start, end?, time_zone? } | Yes | No |
| checkbox | boolean | No | No |
| url | string | Yes | No |
| email | string | Yes | No |
| phone_number | string | Yes | No |
| relation | [{ id }] | Yes (empty []) | No |
| files | [{ name, url }] | Yes (empty []) | No |
| created_time | ISO8601 | No | **Yes** |
| created_by | user object | No | **Yes** |
| last_edited_time | ISO8601 | No | **Yes** |
| last_edited_by | user object | No | **Yes** |
| formula | varies | No | **Yes** |
| rollup | varies | No | **Yes** |
