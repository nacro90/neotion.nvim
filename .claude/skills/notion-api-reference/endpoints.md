# Notion API Endpoints Reference

Complete reference for Notion REST API endpoints, authentication, and rate limiting.

## Authentication

**Base URL:** `https://api.notion.com/v1`

**Required Headers:**
```
Authorization: Bearer {token}
Notion-Version: 2022-06-28
Content-Type: application/json
```

**Token Types:**
- **Integration Token:** `secret_...` (internal integrations)
- **Bot Token:** `ntn_...` (public integrations)
- **User Token:** OAuth tokens (user-scoped access)

**Codebase grep:**
```bash
grep -r "Authorization.*Bearer\|Notion-Version" lua/neotion/api/
```

---

## Rate Limits

**Official Limits:**
- **3 requests per second** per integration
- Burst limit: ~5-10 requests before throttling
- Response header: `Retry-After` (seconds to wait)

**HTTP Status Codes:**
- `429 Too Many Requests` - Rate limit exceeded
- `400 Bad Request` - Invalid request payload
- `401 Unauthorized` - Invalid or missing token
- `403 Forbidden` - Insufficient permissions
- `404 Not Found` - Resource doesn't exist
- `409 Conflict` - Concurrent update conflict
- `500 Internal Server Error` - Notion API error
- `503 Service Unavailable` - Temporary outage

**Retry Strategy (Exponential Backoff):**
```lua
local function api_call_with_retry(fn, max_retries)
  max_retries = max_retries or 3
  local retries = 0

  while retries < max_retries do
    local ok, result = pcall(fn)

    if ok then
      return result
    elseif result.status == 429 then
      -- Use Retry-After header or exponential backoff
      local retry_after = result.headers["Retry-After"] or (2 ^ retries)
      vim.wait(retry_after * 1000)
      retries = retries + 1
    else
      error(result)
    end
  end

  error("Max retries exceeded")
end
```

**Codebase grep:**
```bash
grep -r "429\|rate.*limit\|throttle\|retry" lua/neotion/api/
```

---

## Endpoint 1: Search

**`POST /v1/search`**

Search for pages and databases across the workspace.

**Request:**
```json
{
  "query": "search term",          // Optional: search text
  "filter": {
    "property": "object",          // "page" or "database"
    "value": "page"
  },
  "sort": {
    "direction": "ascending",      // or "descending"
    "timestamp": "last_edited_time"
  },
  "start_cursor": "uuid",          // For pagination
  "page_size": 100                 // Max: 100, default: 100
}
```

**Response:**
```json
{
  "object": "list",
  "results": [...],                // Array of pages/databases
  "next_cursor": "uuid",           // Null if no more results
  "has_more": false
}
```

**Limitations:**
- Only searches pages/databases shared with integration
- Max 100 results per request (use pagination)
- Search is eventually consistent (new pages may take time)
- **Cannot search page content**, only titles

**Pagination Pattern:**
```lua
local function search_all(query)
  local all_results = {}
  local cursor = nil

  repeat
    local response = api.search({
      query = query,
      start_cursor = cursor,
      page_size = 100
    })

    vim.list_extend(all_results, response.results)
    cursor = response.next_cursor
  until not response.has_more

  return all_results
end
```

**Codebase grep:**
```bash
grep -r "POST.*search\|/v1/search" lua/neotion/api/
```

---

## Endpoint 2: Get Page

**`GET /v1/pages/{page_id}`**

Retrieve page properties and metadata (**NOT content**).

**Response:**
```json
{
  "object": "page",
  "id": "uuid",
  "created_time": "ISO8601",
  "last_edited_time": "ISO8601",
  "archived": false,
  "properties": {                  // Title, select, etc.
    "title": {
      "type": "title",
      "title": [...]
    }
  },
  "parent": {                      // Page or database parent
    "type": "page_id",
    "page_id": "uuid"
  },
  "url": "https://notion.so/...",
  "icon": {...},                   // emoji or external URL
  "cover": {...}                   // external URL
}
```

**Important:**
- This does **NOT** return page content (blocks)
- Use `GET /v1/blocks/{page_id}/children` for content
- Returns page properties only (metadata)

**Codebase grep:**
```bash
grep -r "GET.*pages/\|pages\.get" lua/neotion/api/pages.lua
```

---

## Endpoint 3: Get Block Children

**`GET /v1/blocks/{block_id}/children`**

Retrieve child blocks (page content).

**Request:**
```
GET /v1/blocks/{block_id}/children?page_size=100&start_cursor={cursor}
```

**Query Parameters:**
- `page_size` - Max 100, default 100
- `start_cursor` - Pagination cursor

**Response:**
```json
{
  "object": "list",
  "results": [                     // Array of blocks
    {
      "object": "block",
      "id": "uuid",
      "type": "paragraph",
      "paragraph": {...},          // Type-specific data
      "has_children": false,
      "created_time": "ISO8601",
      "last_edited_time": "ISO8601",
      "archived": false
    }
  ],
  "next_cursor": "uuid",
  "has_more": false
}
```

**Pagination Required:**
- Max 100 blocks per request
- Use `next_cursor` for pagination
- Nested blocks require separate requests

**Recursive Fetch Pattern:**
```lua
local function get_all_blocks(block_id, depth)
  depth = depth or 0
  if depth > 10 then return {} end  -- Prevent infinite recursion

  local blocks = {}
  local cursor = nil

  repeat
    local response = api.blocks.get_children(block_id, {
      page_size = 100,
      start_cursor = cursor
    })

    for _, block in ipairs(response.results) do
      table.insert(blocks, block)

      -- Recursively fetch children if has_children is true
      if block.has_children then
        block.children = get_all_blocks(block.id, depth + 1)
      end
    end

    cursor = response.next_cursor
  until not response.has_more

  return blocks
end
```

**Codebase grep:**
```bash
grep -r "blocks.*children\|get_children" lua/neotion/api/blocks.lua
```

---

## Endpoint 4: Append Block Children

**`PATCH /v1/blocks/{block_id}/children`**

Add new blocks as children (create content).

**Request:**
```json
{
  "children": [
    {
      "object": "block",
      "type": "paragraph",
      "paragraph": {
        "rich_text": [
          {
            "type": "text",
            "text": { "content": "Hello World" }
          }
        ]
      }
    }
  ],
  "after": "block_id"              // Optional: insert after this block
}
```

**Response:**
```json
{
  "object": "list",
  "results": [...]                 // Created blocks with IDs
}
```

**Limitations:**
- Max **100 blocks per request** (batch optimization!)
- Cannot insert **before** a block (only after or at end)
- No bulk delete/move operations
- Must provide full block structure

**Batch Creation Pattern (Optimize API calls):**
```lua
-- ✅ Good: Create 100 blocks in 1 request
api.blocks.append_children(page_id, {
  children = { block1, block2, ..., block100 }
})

-- ❌ Bad: 100 separate requests
for _, block in ipairs(blocks) do
  api.blocks.append_children(page_id, {
    children = { block }
  })
end
```

**Codebase grep:**
```bash
grep -r "PATCH.*children\|append_children" lua/neotion/api/blocks.lua
```

---

## Endpoint 5: Update Block

**`PATCH /v1/blocks/{block_id}`**

Update existing block content.

**Request:**
```json
{
  "paragraph": {                   // Type-specific update
    "rich_text": [
      {
        "type": "text",
        "text": { "content": "Updated text" }
      }
    ]
  }
}
```

**Limitations:**
- Can only update **content**, not **type**
  - Cannot change `paragraph` → `heading_1`
  - Must delete and recreate to change type
- Cannot update `has_children` directly
- Must update **entire rich_text array** (no partial updates)

**Update Pattern:**
```lua
-- Get current block first
local block = api.blocks.get(block_id)

-- Modify the content
block[block.type].rich_text = new_rich_text

-- Update with full content
api.blocks.update(block_id, {
  [block.type] = block[block.type]
})
```

**Codebase grep:**
```bash
grep -r "PATCH.*blocks/\|blocks\.update" lua/neotion/api/blocks.lua
```

---

## Endpoint 6: Delete Block

**`DELETE /v1/blocks/{block_id}`**

Archive a block (soft delete).

**Response:**
```json
{
  "object": "block",
  "id": "uuid",
  "archived": true                 // Marked as deleted
}
```

**Important:**
- Blocks are **archived**, not permanently deleted
- Child blocks are also archived recursively
- **Cannot restore via API** (manual restoration only in UI)
- Archived blocks still count toward storage

**Codebase grep:**
```bash
grep -r "DELETE.*blocks\|blocks\.delete" lua/neotion/api/blocks.lua
```

---

## Common Patterns

### Pattern 1: Create Page with Content

```lua
-- Step 1: Create page (metadata only)
local page = api.pages.create({
  parent = { page_id = parent_id },
  properties = {
    title = {
      title = {
        { type = "text", text = { content = "New Page" } }
      }
    }
  }
})

-- Step 2: Add content blocks
api.blocks.append_children(page.id, {
  children = {
    {
      object = "block",
      type = "paragraph",
      paragraph = {
        rich_text = {
          { type = "text", text = { content = "First paragraph" } }
        }
      }
    },
    {
      object = "block",
      type = "heading_1",
      heading_1 = {
        rich_text = {
          { type = "text", text = { content = "Heading" } }
        }
      }
    }
  }
})
```

### Pattern 2: Batch Operations

```lua
-- Batch consecutive creates into single call
local function batch_create_blocks(page_id, blocks)
  local batch_size = 100

  for i = 1, #blocks, batch_size do
    local batch = vim.list_slice(blocks, i, math.min(i + batch_size - 1, #blocks))

    api.blocks.append_children(page_id, {
      children = batch
    })
  end
end
```

### Pattern 3: Error Recovery

```lua
local function safe_api_call(fn)
  local ok, result = pcall(fn)

  if not ok then
    if result.status == 404 then
      -- Block/page doesn't exist or no access
      return nil, "not_found"
    elseif result.status == 409 then
      -- Conflict: retry after delay
      vim.wait(1000)
      return safe_api_call(fn)
    elseif result.status >= 500 then
      -- Server error: retry with backoff
      return nil, "server_error"
    else
      error(result)
    end
  end

  return result
end
```

---

## Performance Tips

### 1. Minimize API Calls
```lua
-- ❌ Bad: N+1 problem
for _, page_id in ipairs(page_ids) do
  local page = api.pages.get(page_id)
  -- Process page
end

-- ✅ Good: Batch with search
local pages = api.search({ filter = { ... } })
```

### 2. Cache Aggressively
```lua
-- Pages rarely change, cache for 5+ minutes
local cache = {}
local cache_ttl = 300  -- 5 minutes

local function get_page_cached(page_id)
  local now = os.time()
  local cached = cache[page_id]

  if cached and (now - cached.time) < cache_ttl then
    return cached.data
  end

  local page = api.pages.get(page_id)
  cache[page_id] = { data = page, time = now }
  return page
end
```

### 3. Parallel Requests (within rate limit)
```lua
-- Make independent requests in parallel
local function fetch_multiple(page_ids)
  local results = {}
  local threads = {}

  for _, page_id in ipairs(page_ids) do
    table.insert(threads, vim.schedule_wrap(function()
      results[page_id] = api.pages.get(page_id)
    end))
  end

  -- Wait for all to complete
  for _, thread in ipairs(threads) do
    thread()
  end

  return results
end
```

---

## Debugging

### Log API Requests
```lua
local function log_api_call(method, endpoint, payload)
  local log_file = vim.fn.stdpath("cache") .. "/neotion_api.log"
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")

  local entry = string.format(
    "[%s] %s %s\nPayload: %s\n\n",
    timestamp,
    method,
    endpoint,
    vim.inspect(payload)
  )

  local f = io.open(log_file, "a")
  f:write(entry)
  f:close()
end
```

### Common Errors

**400 Bad Request:**
- Missing required fields (`object`, `type`, type-specific data)
- Invalid block structure
- Invalid rich_text format
- Check payload against API docs

**404 Not Found:**
- Block/page doesn't exist
- Integration doesn't have access
- Block was archived
- Check page sharing settings

**409 Conflict:**
- Concurrent update conflict
- Another client modified the same block
- Retry with exponential backoff

**500/503 Errors:**
- Notion API issue (server-side)
- Check https://status.notion.so/
- Retry after delay

---

## Quick Reference Card

| Operation | Endpoint | Method | Max Items |
|-----------|----------|--------|-----------|
| Search workspace | `/v1/search` | POST | 100/request |
| Get page metadata | `/v1/pages/{id}` | GET | - |
| Get page content | `/v1/blocks/{id}/children` | GET | 100/request |
| Create blocks | `/v1/blocks/{id}/children` | PATCH | 100/request |
| Update block | `/v1/blocks/{id}` | PATCH | - |
| Delete block | `/v1/blocks/{id}` | DELETE | - |

**Rate Limit:** 3 requests/second (enforced strictly)
**Pagination:** Use `start_cursor` + `next_cursor` + `has_more`

---

## Grep Patterns Summary

```bash
# Authentication
grep -r "Authorization.*Bearer\|Notion-Version" lua/neotion/api/

# Rate limiting
grep -r "429\|rate.*limit\|throttle" lua/neotion/api/

# Search endpoint
grep -r "POST.*search\|/v1/search" lua/neotion/api/

# Pages endpoint
grep -r "GET.*pages/\|pages\.get" lua/neotion/api/pages.lua

# Blocks endpoints
grep -r "blocks.*children\|get_children" lua/neotion/api/blocks.lua
grep -r "PATCH.*children\|append_children" lua/neotion/api/blocks.lua
grep -r "PATCH.*blocks/\|blocks\.update" lua/neotion/api/blocks.lua
grep -r "DELETE.*blocks\|blocks\.delete" lua/neotion/api/blocks.lua

# Error handling
grep -r "pcall\|error\|assert" lua/neotion/api/

# Pagination
grep -r "next_cursor\|has_more" lua/neotion/api/
```
