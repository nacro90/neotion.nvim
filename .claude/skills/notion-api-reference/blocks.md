# Notion Block Types & Rich Text Reference

Complete reference for Notion block types, rich text formatting, and content structure.

## Block Structure

Every block has this base structure:

```json
{
  "object": "block",               // Always "block"
  "id": "uuid",                    // Unique identifier
  "type": "paragraph",             // Block type (see below)
  "paragraph": {...},              // Type-specific data
  "has_children": false,           // Whether block has nested blocks
  "created_time": "ISO8601",
  "last_edited_time": "ISO8601",
  "archived": false
}
```

**Codebase grep:**
```bash
grep -r "object.*block\|block\.type" lua/neotion/model/block.lua
```

---

## Text Blocks

### Paragraph
```json
{
  "type": "paragraph",
  "paragraph": {
    "rich_text": [...],            // Array of rich text objects
    "color": "default"             // Optional color
  }
}
```

**Codebase:** `lua/neotion/model/blocks/paragraph.lua`

---

### Headings (3 levels)

**Heading 1:**
```json
{
  "type": "heading_1",
  "heading_1": {
    "rich_text": [...],
    "color": "default",
    "is_toggleable": false         // Optional
  }
}
```

**Heading 2, Heading 3:** Same structure, different type

**Codebase:** `lua/neotion/model/blocks/heading.lua`

**Grep:**
```bash
grep -r "heading_[123]" lua/neotion/model/blocks/
```

---

### Lists

**Bulleted List:**
```json
{
  "type": "bulleted_list_item",
  "bulleted_list_item": {
    "rich_text": [...],
    "color": "default"
  }
}
```

**Numbered List:**
```json
{
  "type": "numbered_list_item",
  "numbered_list_item": {
    "rich_text": [...],
    "color": "default"
  }
}
```

**Important:**
- List items can have children (nested lists)
- Consecutive list items form a visual list
- Use `has_children: true` for nested items

**Codebase:**
- `lua/neotion/model/blocks/bulleted_list.lua`
- `lua/neotion/model/blocks/numbered_list.lua`

**Grep:**
```bash
grep -r "bulleted_list\|numbered_list" lua/neotion/model/blocks/
```

---

### To-Do (Checkbox)
```json
{
  "type": "to_do",
  "to_do": {
    "rich_text": [...],
    "checked": false,              // Boolean
    "color": "default"
  }
}
```

---

### Toggle (Collapsible)
```json
{
  "type": "toggle",
  "toggle": {
    "rich_text": [...],
    "color": "default"
  }
}
```

**Must have children** for toggle to work.

---

### Quote
```json
{
  "type": "quote",
  "quote": {
    "rich_text": [...],
    "color": "default"
  }
}
```

**Buffer syntax:** `| text` (pipe prefix)

---

### Callout (Highlighted Box)
```json
{
  "type": "callout",
  "callout": {
    "rich_text": [...],
    "icon": {
      "type": "emoji",
      "emoji": "💡"                // Or external URL
    },
    "color": "gray_background"
  }
}
```

---

### Code Block
```json
{
  "type": "code",
  "code": {
    "rich_text": [...],
    "caption": [...],              // Optional caption
    "language": "javascript"       // Syntax highlighting
  }
}
```

**Supported languages:**
- javascript, typescript, python, lua, rust, go, java, cpp, c, ruby, php, swift, kotlin, bash, shell, sql, html, css, json, yaml, markdown, plaintext, etc.

**Codebase:** Check language detection logic

**Grep:**
```bash
grep -r "code.*language\|code_block" lua/neotion/model/blocks/
```

---

## Media Blocks

### Image
```json
{
  "type": "image",
  "image": {
    "type": "external",            // or "file"
    "external": {
      "url": "https://..."
    },
    "caption": [...]               // Optional rich text
  }
}
```

**Types:**
- `external` - URL to external image
- `file` - Uploaded to Notion (includes expiring URL)

---

### Video
```json
{
  "type": "video",
  "video": {
    "type": "external",
    "external": {
      "url": "https://youtube.com/..."
    }
  }
}
```

---

### File Attachment
```json
{
  "type": "file",
  "file": {
    "type": "external",
    "external": {
      "url": "https://..."
    },
    "caption": [...],
    "name": "document.pdf"         // Optional
  }
}
```

---

### PDF
```json
{
  "type": "pdf",
  "pdf": {
    "type": "external",
    "external": {
      "url": "https://..."
    }
  }
}
```

---

### Bookmark (Link Preview)
```json
{
  "type": "bookmark",
  "bookmark": {
    "url": "https://example.com",
    "caption": [...]               // Optional
  }
}
```

**Note:** `link_preview` type is read-only (auto-generated). Use `bookmark` for manual links.

---

## Database Blocks

### Child Database (Inline)
```json
{
  "type": "child_database",
  "child_database": {
    "title": "Database Title"
  }
}
```

**Note:** Cannot create/configure database schema via API. Only create container.

---

### Child Page (Sub-page)
```json
{
  "type": "child_page",
  "child_page": {
    "title": "Page Title"
  }
}
```

---

## Advanced Blocks

### Table
```json
{
  "type": "table",
  "table": {
    "table_width": 3,              // Number of columns
    "has_column_header": true,
    "has_row_header": false
  }
}
```

**Table Row:**
```json
{
  "type": "table_row",
  "table_row": {
    "cells": [                     // Array of cell rich_text arrays
      [...],                       // Cell 1
      [...],                       // Cell 2
      [...]                        // Cell 3
    ]
  }
}
```

**Important:**
- Table rows must be children of table block
- Number of cells must match `table_width`

---

### Columns

**Column List (Container):**
```json
{
  "type": "column_list",
  "column_list": {}
}
```

**Column:**
```json
{
  "type": "column",
  "column": {}
}
```

**Usage:**
- `column_list` contains `column` blocks as children
- Each `column` contains other blocks

---

### Divider (Horizontal Rule)
```json
{
  "type": "divider",
  "divider": {}
}
```

**Buffer syntax:** `---` (three dashes)

---

### Breadcrumb
```json
{
  "type": "breadcrumb",
  "breadcrumb": {}
}
```

Auto-generates breadcrumb navigation.

---

### Table of Contents
```json
{
  "type": "table_of_contents",
  "table_of_contents": {
    "color": "default"
  }
}
```

Auto-generates TOC from headings.

---

### Link to Page
```json
{
  "type": "link_to_page",
  "link_to_page": {
    "type": "page_id",
    "page_id": "uuid"
  }
}
```

---

### Synced Block
```json
{
  "type": "synced_block",
  "synced_block": {
    "synced_from": {               // Null for original
      "block_id": "uuid"           // Reference to original
    }
  }
}
```

**Types:**
- Original: `synced_from: null`
- Reference: `synced_from: { block_id: "..." }`

---

### Template Button
```json
{
  "type": "template",
  "template": {
    "rich_text": [...]             // Button text
  }
}
```

Children are the template content.

---

### Equation (Math)
```json
{
  "type": "equation",
  "equation": {
    "expression": "E = mc^2"       // KaTeX syntax
  }
}
```

**Syntax:** KaTeX (LaTeX subset)

---

### Embed (Generic)
```json
{
  "type": "embed",
  "embed": {
    "url": "https://..."
  }
}
```

For websites not covered by specific block types.

---

## Unsupported Block Types

⚠️ **Read-Only (Cannot create/update via API):**

```json
{
  "type": "unsupported",
  "unsupported": {}
}
```

**Examples:**
- Advanced database views
- Some Notion-specific blocks
- Experimental features

**How to check:**
```lua
if block.type == "unsupported" then
  -- Handle read-only block
end
```

**Codebase grep:**
```bash
grep -r "unsupported" lua/neotion/model/block.lua
```

---

## Rich Text Format

**Structure:**
```json
{
  "type": "text",                  // "text", "mention", "equation"
  "text": {
    "content": "Hello World",
    "link": {                      // Optional
      "url": "https://example.com"
    }
  },
  "annotations": {                 // Optional formatting
    "bold": false,
    "italic": false,
    "strikethrough": false,
    "underline": false,
    "code": false,
    "color": "default"
  },
  "plain_text": "Hello World",   // Read-only
  "href": "https://..."            // Read-only (if link exists)
}
```

### Annotations (Formatting)

**Bold:** `annotations.bold = true`
```json
{ "type": "text", "text": { "content": "bold" }, "annotations": { "bold": true } }
```
**Buffer:** `**text**`

**Italic:** `annotations.italic = true`
**Buffer:** `*text*`

**Strikethrough:** `annotations.strikethrough = true`
**Buffer:** `~text~`

**Code:** `annotations.code = true`
**Buffer:** `` `text` ``

**Underline:** `annotations.underline = true`
**Buffer:** `<u>text</u>`

**Multiple annotations can be combined:**
```json
{
  "annotations": {
    "bold": true,
    "italic": true,
    "underline": true
  }
}
```

**Codebase grep:**
```bash
grep -r "annotations\|bold\|italic" lua/neotion/render/
```

---

### Colors

**Text Colors:**
- `default`, `gray`, `brown`, `orange`, `yellow`, `green`, `blue`, `purple`, `pink`, `red`

**Background Colors:**
- `gray_background`, `brown_background`, `orange_background`, `yellow_background`, `green_background`, `blue_background`, `purple_background`, `pink_background`, `red_background`

**Usage:**
```json
{
  "annotations": {
    "color": "red"                 // Text color
  }
}
```

**Block-level color:**
```json
{
  "type": "paragraph",
  "paragraph": {
    "rich_text": [...],
    "color": "blue_background"     // Background color
  }
}
```

**Buffer syntax:** `<c:red>text</c>`

**Codebase grep:**
```bash
grep -r "color.*red\|color.*background" lua/neotion/model/
```

---

### Links

**Inline link:**
```json
{
  "type": "text",
  "text": {
    "content": "Click here",
    "link": {
      "url": "https://example.com"
    }
  }
}
```

**Buffer:** `[text](url)`

---

### Mentions

**User Mention:**
```json
{
  "type": "mention",
  "mention": {
    "type": "user",
    "user": {
      "id": "user_uuid",
      "object": "user"
    }
  },
  "plain_text": "@John Doe",        // Read-only
  "href": null
}
```

**Buffer:** `@username`

---

**Page Mention:**
```json
{
  "type": "mention",
  "mention": {
    "type": "page",
    "page": {
      "id": "page_uuid"
    }
  },
  "plain_text": "Page Title",     // Read-only
  "href": "https://notion.so/..."  // Read-only
}
```

**Buffer:** `[[page title]]`

---

**Date Mention:**
```json
{
  "type": "mention",
  "mention": {
    "type": "date",
    "date": {
      "start": "2024-01-01",
      "end": "2024-01-31",         // Optional (for ranges)
      "time_zone": null            // Optional
    }
  },
  "plain_text": "2024-01-01",   // Read-only
  "href": null
}
```

**Codebase grep:**
```bash
grep -r "mention\|@\|\\[\\[" lua/neotion/model/
```

---

**Database Mention:**
```json
{
  "type": "mention",
  "mention": {
    "type": "database",
    "database": {
      "id": "database_uuid"
    }
  }
}
```

---

### Equations (Inline Math)

```json
{
  "type": "equation",
  "equation": {
    "expression": "E = mc^2"       // KaTeX syntax
  },
  "plain_text": "E = mc^2",       // Read-only
  "href": null
}
```

**Syntax:** KaTeX (subset of LaTeX)

---

## Block Limitations

### Cannot Change Block Type
❌ **Cannot convert paragraph to heading:**
```lua
-- This will fail
api.blocks.update(block_id, {
  type = "heading_1",              -- Cannot change type
  heading_1 = { ... }
})
```

✅ **Must delete and recreate:**
```lua
api.blocks.delete(block_id)
api.blocks.append_children(parent_id, {
  children = { { type = "heading_1", ... } }
})
```

---

### Must Update Entire Rich Text Array
❌ **Cannot partial update:**
```lua
-- Cannot append to existing rich_text
block.paragraph.rich_text[#block.paragraph.rich_text + 1] = new_text
api.blocks.update(block_id, block.paragraph)
```

✅ **Must send full array:**
```lua
local current = api.blocks.get(block_id)
local rich_text = current.paragraph.rich_text

-- Add new text
table.insert(rich_text, new_text)

-- Update with full array
api.blocks.update(block_id, {
  paragraph = { rich_text = rich_text }
})
```

---

### Nested Blocks Require Separate Requests

❌ **Cannot create nested structure in one call:**
```json
{
  "type": "bulleted_list_item",
  "bulleted_list_item": {
    "rich_text": [...]
  },
  "children": [...]                // Not supported
}
```

✅ **Must create parent first, then children:**
```lua
-- Create parent
local parent = api.blocks.append_children(page_id, {
  children = { { type = "bulleted_list_item", ... } }
})

-- Then add children
api.blocks.append_children(parent.results[1].id, {
  children = { ... }
})
```

---

### Max Block Nesting Depth

No official limit, but deep nesting (10+ levels) can cause:
- Performance issues
- API timeouts
- UI rendering problems

**Best practice:** Keep nesting under 5 levels.

---

## Block Type Detection Patterns

**Codebase pattern for type detection:**
```lua
local function get_block_type(line)
  -- Heading detection
  if line:match("^#+ ") then
    return "heading"
  end

  -- List detection
  if line:match("^[-*+] ") then
    return "bulleted_list_item"
  end

  if line:match("^%d+%. ") then
    return "numbered_list_item"
  end

  -- Quote detection
  if line:match("^| ") then
    return "quote"
  end

  -- Code block detection
  if line:match("^```") then
    return "code"
  end

  -- Default to paragraph
  return "paragraph"
end
```

**Codebase grep:**
```bash
grep -r "detect.*type\|get_block_type" lua/neotion/model/
```

---

## Grep Patterns Summary

```bash
# Block structure
grep -r "object.*block\|block\.type" lua/neotion/model/block.lua

# Block types
grep -r "heading_[123]" lua/neotion/model/blocks/
grep -r "bulleted_list\|numbered_list" lua/neotion/model/blocks/
grep -r "code.*language\|code_block" lua/neotion/model/blocks/

# Rich text
grep -r "rich_text\|annotations" lua/neotion/render/
grep -r "annotations\|bold\|italic" lua/neotion/render/

# Colors
grep -r "color.*red\|color.*background" lua/neotion/model/

# Mentions
grep -r "mention\|@\|\\[\\[" lua/neotion/model/

# Type detection
grep -r "detect.*type\|get_block_type" lua/neotion/model/

# Unsupported blocks
grep -r "unsupported" lua/neotion/model/block.lua
```
