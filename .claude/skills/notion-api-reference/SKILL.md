---
name: notion-api-reference
description: Comprehensive Notion API reference covering endpoints, payloads, rate limits, block types, property types, and limitations. Use when working with Notion API integration, implementing new features, or debugging API issues.
---

# Notion API Reference Index

**Version:** 2022-06-28 (Latest stable)
**Base URL:** `https://api.notion.com/v1`
**Rate Limit:** 3 requests/second

This skill provides complete Notion API documentation split across domain-specific reference files.

---

## 📚 Reference Files

### 1. **endpoints.md** - API Operations & Authentication
Core API endpoints, authentication, rate limiting, and request/response patterns.

**Use when:**
- Making API calls (search, get, create, update, delete)
- Implementing rate limiting or retry logic
- Debugging authentication issues
- Understanding HTTP status codes

**Quick grep:**
```bash
# Find specific endpoint
grep -i "POST.*search\|GET.*pages\|PATCH.*blocks" .claude/skills/notion-api-reference/endpoints.md

# Rate limiting
grep -i "429\|rate.*limit\|retry" .claude/skills/notion-api-reference/endpoints.md
```

**Contents:**
- Authentication (tokens, headers)
- Rate limits (3/sec, retry strategies)
- 6 core endpoints (Search, Get Page, Get Blocks, Append, Update, Delete)
- Common patterns (pagination, batching, error handling)
- Performance tips

---

### 2. **blocks.md** - Block Types & Rich Text
Block types, rich text formatting, annotations, mentions, and content structure.

**Use when:**
- Creating or updating block content
- Formatting text (bold, italic, colors)
- Working with lists, headings, code blocks
- Handling mentions (@user, [[page]])
- Understanding block limitations

**Quick grep:**
```bash
# Find block type
grep -i "paragraph\|heading\|bulleted_list\|code" .claude/skills/notion-api-reference/blocks.md

# Rich text formatting
grep -i "rich_text\|annotations\|bold\|italic\|color" .claude/skills/notion-api-reference/blocks.md

# Mentions
grep -i "mention\|@\|\\[\\[" .claude/skills/notion-api-reference/blocks.md
```

**Contents:**
- 30+ block types (text, media, database, advanced)
- Rich text format (annotations, links, mentions)
- Colors (text + background)
- Block limitations (cannot change type, nesting depth)
- Type detection patterns

---

### 3. **properties.md** - Page Properties & Types
Page property types, metadata, and property operations.

**Use when:**
- Working with page properties
- Creating/updating database entries
- Reading page metadata (title, status, dates)
- Understanding property limitations

**Quick grep:**
```bash
# Find property type
grep -i "title\|select\|date\|checkbox\|number" .claude/skills/notion-api-reference/properties.md

# Read-only properties
grep -i "created_time\|formula\|rollup" .claude/skills/notion-api-reference/properties.md
```

**Contents:**
- 15+ property types (title, select, date, relation, etc.)
- Read-only properties (created_time, formula, rollup)
- Property limitations (cannot change type)
- Common patterns (extract title, toggle checkbox)

---

## 🎯 Quick Decision Tree

**What are you trying to do?**

1. **Make an API call?** → `endpoints.md`
   - Authentication? → Search "Authorization"
   - Rate limited? → Search "429" or "retry"
   - Need endpoint details? → Search endpoint name (e.g., "POST /v1/search")

2. **Create/update blocks?** → `blocks.md`
   - What block type? → Search type name (e.g., "bulleted_list")
   - Format text? → Search "rich_text" or "annotations"
   - Add mentions? → Search "mention"

3. **Work with page properties?** → `properties.md`
   - What property type? → Search type name (e.g., "select", "date")
   - Read-only property? → Search "read-only" or property name
   - Extract title? → Search "get_page_title"

---

## 🔍 Grep Strategy

### By Domain (Fastest)

**Know the domain?** Grep the specific file:
```bash
# Endpoint-related
grep -i "search_term" .claude/skills/notion-api-reference/endpoints.md

# Block-related
grep -i "search_term" .claude/skills/notion-api-reference/blocks.md

# Property-related
grep -i "search_term" .claude/skills/notion-api-reference/properties.md
```

### Cross-Domain Search

**Not sure which domain?** Search all reference files:
```bash
grep -i "search_term" .claude/skills/notion-api-reference/*.md
```

### Common Searches

```bash
# Find all mentions of "rate limit"
grep -ri "rate.*limit" .claude/skills/notion-api-reference/

# Find all block types
grep -r "\"type\":" .claude/skills/notion-api-reference/blocks.md

# Find all property types
grep -r "\"type\":" .claude/skills/notion-api-reference/properties.md

# Find codebase usage patterns
grep -r "api\." lua/neotion/api/
```

---

## 🚀 Common Use Cases

### Use Case 1: Creating a Page with Content

**Steps:**
1. Check `endpoints.md` → "Create page" pattern
2. Check `properties.md` → Title property format
3. Check `endpoints.md` → "Append blocks" endpoint
4. Check `blocks.md` → Block types you need

**Grep:**
```bash
grep -i "create.*page\|append.*children" .claude/skills/notion-api-reference/endpoints.md
grep -i "title.*property" .claude/skills/notion-api-reference/properties.md
grep -i "paragraph\|heading" .claude/skills/notion-api-reference/blocks.md
```

---

### Use Case 2: Updating Block Text

**Steps:**
1. Check `endpoints.md` → "Update block" endpoint
2. Check `blocks.md` → Rich text format
3. Check `blocks.md` → Limitations (must update entire array)

**Grep:**
```bash
grep -i "PATCH.*blocks\|update.*block" .claude/skills/notion-api-reference/endpoints.md
grep -i "rich_text\|entire.*array" .claude/skills/notion-api-reference/blocks.md
```

---

### Use Case 3: Handling Rate Limits

**Steps:**
1. Check `endpoints.md` → Rate limits section
2. Check `endpoints.md` → Retry strategy pattern

**Grep:**
```bash
grep -i "429\|rate.*limit\|retry\|exponential" .claude/skills/notion-api-reference/endpoints.md
```

---

### Use Case 4: Working with List Blocks

**Steps:**
1. Check `blocks.md` → Bulleted/numbered list types
2. Check `blocks.md` → Nested block patterns

**Grep:**
```bash
grep -i "bulleted_list\|numbered_list" .claude/skills/notion-api-reference/blocks.md
grep -i "nested\|has_children" .claude/skills/notion-api-reference/blocks.md
```

---

### Use Case 5: Reading Page Properties

**Steps:**
1. Check `endpoints.md` → Get page endpoint
2. Check `properties.md` → Property type you need
3. Check `properties.md` → Extract value pattern

**Grep:**
```bash
grep -i "GET.*pages" .claude/skills/notion-api-reference/endpoints.md
grep -i "select\|date\|checkbox" .claude/skills/notion-api-reference/properties.md
grep -i "get_property_value" .claude/skills/notion-api-reference/properties.md
```

---

## 📖 Quick Reference Cards

### Endpoints Summary
| Operation | Endpoint | Method | File |
|-----------|----------|--------|------|
| Search | `/v1/search` | POST | endpoints.md |
| Get page | `/v1/pages/{id}` | GET | endpoints.md |
| Get blocks | `/v1/blocks/{id}/children` | GET | endpoints.md |
| Create blocks | `/v1/blocks/{id}/children` | PATCH | endpoints.md |
| Update block | `/v1/blocks/{id}` | PATCH | endpoints.md |
| Delete block | `/v1/blocks/{id}` | DELETE | endpoints.md |

### Block Types Summary
| Category | Types | File |
|----------|-------|------|
| Text | paragraph, heading_1/2/3, quote | blocks.md |
| Lists | bulleted_list_item, numbered_list_item, to_do | blocks.md |
| Code | code (with language) | blocks.md |
| Media | image, video, file, pdf, bookmark | blocks.md |
| Advanced | table, column_list, divider, equation | blocks.md |

### Property Types Summary
| Type | Editable | Nullable | File |
|------|----------|----------|------|
| title | Yes | No | properties.md |
| rich_text | Yes | Yes | properties.md |
| select | Yes | Yes | properties.md |
| multi_select | Yes | Yes | properties.md |
| date | Yes | Yes | properties.md |
| checkbox | Yes | No | properties.md |
| number | Yes | Yes | properties.md |
| created_time | **No** | No | properties.md |
| formula | **No** | No | properties.md |
| rollup | **No** | No | properties.md |

---

## 🔧 Codebase Integration

**Find API usage in codebase:**
```bash
# API client
grep -r "api\." lua/neotion/api/

# Block handling
grep -r "block\.type\|block_type" lua/neotion/model/

# Property handling
grep -r "properties\|property" lua/neotion/model/

# Rate limiting
grep -r "throttle\|rate_limit" lua/neotion/api/

# Rich text processing
grep -r "rich_text\|annotations" lua/neotion/render/
```

---

## 💡 Tips for Bot Usage

**When searching:**
1. **Know the domain first** → Search specific file
2. **Use targeted grep** → Grep pattern in file path
3. **Check limitations** → Search "limitation" or "cannot"
4. **Find patterns** → Search "pattern" or "example"
5. **Understand errors** → Search error code (e.g., "404", "429")

**Examples:**
```bash
# Bot searching for "bulleted list"
grep -i "bulleted_list" .claude/skills/notion-api-reference/blocks.md

# Bot searching for "rate limit handling"
grep -i "rate.*limit\|retry" .claude/skills/notion-api-reference/endpoints.md

# Bot searching for "select property"
grep -i "select.*property\|\"select\"" .claude/skills/notion-api-reference/properties.md
```

---

## 📝 Key Concepts

**Rate Limiting:**
- 3 requests/second (strict enforcement)
- Use exponential backoff: 1s, 2s, 4s, 8s...
- Check `Retry-After` header
- Details in `endpoints.md`

**Pagination:**
- Max 100 items per request
- Use `start_cursor` + `next_cursor`
- Check `has_more` flag
- Details in `endpoints.md`

**Block Limitations:**
- Cannot change block type (must recreate)
- Must update entire rich_text array
- Max 100 blocks per append request
- Details in `blocks.md`

**Property Limitations:**
- Cannot change property type
- Formula/rollup are read-only
- Select options auto-created
- Details in `properties.md`

---

## 🌐 External Resources

**Official Docs:** https://developers.notion.com/reference/intro
**Status Page:** https://status.notion.so/
**Changelog:** https://developers.notion.com/page/changelog

**Codebase:**
- `lua/neotion/api/client.lua` - HTTP client wrapper
- `lua/neotion/api/throttle.lua` - Rate limiting
- `lua/neotion/api/blocks.lua` - Block operations
- `lua/neotion/api/pages.lua` - Page operations
- `lua/neotion/model/` - Data models
- `lua/neotion/render/` - Rendering system
