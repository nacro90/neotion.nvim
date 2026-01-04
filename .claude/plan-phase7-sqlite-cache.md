# Phase 6 + 7: Rate Limiting + SQLite Cache - Implementation Plan

## Executive Summary

**Phase 6** önce rate limiting altyapısını kuracak, ardından **Phase 7** bu altyapı üzerine SQLite cache sistemini inşa edecek. Bu sıralama, background refresh'in güvenli çalışmasını sağlayacak.

## User Decisions
- ✅ **Phase 6 önce:** Rate limiting tamamlanacak, sonra cache
- ✅ **TTL: 15 dakika (900s):** Daha az API çağrısı, batarya tasarrufu
- ✅ **Required dependency:** sqlite.lua Makefile'a eklenecek

---

# PART 1: Phase 6 - Rate Limiting + Request Queue

## Phase 6 Goal
Notion API koruması (3 req/s limiti), request queue, retry mechanism

## Phase 6 Scope
1. Token bucket rate limiter (3 tokens/s, burst 10)
2. FIFO request queue
3. HTTP 429 handling with `Retry-After` header
4. Exponential backoff retry
5. Request cancellation (superseded searches için)

## Phase 6 Architecture

### File Structure
```
lua/neotion/api/
└── throttle.lua         # Token bucket + request queue
```

### Token Bucket Algorithm
```lua
-- 3 requests/second, burst capacity 10
local bucket = {
  tokens = 10,           -- Current tokens
  capacity = 10,         -- Max tokens
  refill_rate = 3,       -- Tokens per second
  last_refill = 0,       -- Last refill timestamp
}
```

### Request Queue
```lua
---@class neotion.QueuedRequest
---@field id string Unique request ID
---@field endpoint string API endpoint
---@field opts table Request options
---@field callback function Response callback
---@field priority number Lower = higher priority
---@field timestamp number Queue time
---@field cancelled boolean

---@class neotion.RequestQueue
---@field requests neotion.QueuedRequest[]
---@field processing boolean
```

### API Design (`throttle.lua`)
```lua
M.request(endpoint, token, opts, callback)  -- Rate-limited request
M.cancel(request_id)                        -- Cancel pending request
M.get_queue_size()                          -- Current queue length
M.get_rate_info()                           -- Bucket status
M.pause()                                   -- Pause processing
M.resume()                                  -- Resume processing
M.clear()                                   -- Clear queue
```

## Phase 6 Implementation Steps

### Step 6.1: Token Bucket (`throttle.lua`)
```lua
local function refill_tokens()
  local now = vim.loop.now() / 1000  -- seconds
  local elapsed = now - bucket.last_refill
  local new_tokens = elapsed * bucket.refill_rate
  bucket.tokens = math.min(bucket.capacity, bucket.tokens + new_tokens)
  bucket.last_refill = now
end

local function try_consume()
  refill_tokens()
  if bucket.tokens >= 1 then
    bucket.tokens = bucket.tokens - 1
    return true
  end
  return false
end
```

### Step 6.2: Request Queue
```lua
local queue = {}
local processing = false

local function enqueue(request)
  table.insert(queue, request)
  table.sort(queue, function(a, b) return a.priority < b.priority end)
  process_queue()
end

local function process_queue()
  if processing or #queue == 0 then return end

  if try_consume() then
    processing = true
    local req = table.remove(queue, 1)
    if not req.cancelled then
      execute_request(req)
    else
      processing = false
      process_queue()
    end
  else
    -- Schedule retry after token refill
    local wait_time = (1 / bucket.refill_rate) * 1000  -- ms
    vim.defer_fn(process_queue, wait_time)
  end
end
```

### Step 6.3: HTTP 429 Handling
```lua
local function handle_response(req, response)
  if response.status == 429 then
    local retry_after = tonumber(response.headers['Retry-After']) or 1
    req.attempts = (req.attempts or 0) + 1

    if req.attempts < 5 then  -- Max 5 retries
      -- Exponential backoff with jitter
      local delay = math.min(retry_after * 1000, 2^req.attempts * 1000)
      delay = delay + math.random(100, 500)  -- Jitter

      vim.defer_fn(function()
        enqueue(req)
      end, delay)
    else
      req.callback({ error = 'Rate limit exceeded after 5 retries' })
    end
  else
    processing = false
    req.callback(response)
    process_queue()
  end
end
```

### Step 6.4: Integration with `client.lua`
```lua
-- client.lua modification
function M.request(endpoint, token, opts, callback)
  local throttle = require('neotion.api.throttle')
  return throttle.request(endpoint, token, opts, callback)
end
```

## Phase 6 Config
```lua
throttle = {
  enabled = true,
  requests_per_second = 3,
  burst_capacity = 10,
  max_retries = 5,
},
```

## Phase 6 Tests (~40 tests)
- Token bucket refill logic
- Request queuing and dequeuing
- Priority ordering
- Request cancellation
- HTTP 429 handling
- Exponential backoff
- Integration with client

---

# PART 2: Phase 7 - SQLite Cache (After Phase 6)

## sqlite.lua Dependency
- **Library:** [kkharji/sqlite.lua](https://github.com/kkharji/sqlite.lua)
- **Requirement:** SQLite3 sistem kütüphanesi (`libsqlite3`)
- **API:** Senkron, LuaJIT FFI binding
- **Handling:** Required - Makefile'a eklenecek

## Architecture Design

### File Structure
```
lua/neotion/cache/
├── init.lua           # Cache orchestrator + public API
├── schema.lua         # SQLite schema definitions
├── pages.lua          # Page metadata CRUD operations
└── sync_state.lua     # Sync state persistence
```

### Database Location
```lua
-- vim.fn.stdpath('data')/neotion/cache.db
-- e.g. ~/.local/share/nvim/neotion/cache.db
```

Rationale: `stdpath('data')` kalıcı veri için, `stdpath('cache')` geçici veri için kullanılır.

### Schema Design

```sql
-- pages: Page metadata cache
CREATE TABLE IF NOT EXISTS pages (
    id TEXT PRIMARY KEY,           -- Notion page ID (32 hex)
    title TEXT NOT NULL DEFAULT '',
    icon TEXT,                     -- emoji or icon URL
    icon_type TEXT,                -- 'emoji' | 'external' | 'file' | null
    parent_type TEXT,              -- 'workspace' | 'page_id' | 'database_id'
    parent_id TEXT,                -- null for workspace
    last_edited_time INTEGER,      -- Unix timestamp from Notion
    last_synced_time INTEGER,      -- Unix timestamp when we synced
    sync_status TEXT DEFAULT 'synced', -- 'synced' | 'pending' | 'error'
    content_hash TEXT,             -- MD5/SHA1 of block content for dirty detection
    raw_json TEXT                  -- Full page JSON for future extensibility
);

-- sync_queue: Pending sync operations (for offline mode - Phase 10)
CREATE TABLE IF NOT EXISTS sync_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    page_id TEXT NOT NULL,
    operation TEXT NOT NULL,       -- 'update' | 'create' | 'delete'
    payload TEXT,                  -- JSON payload
    attempts INTEGER DEFAULT 0,
    last_attempt INTEGER,          -- Unix timestamp
    error_message TEXT,
    FOREIGN KEY (page_id) REFERENCES pages(id)
);

-- Index for common queries
CREATE INDEX IF NOT EXISTS idx_pages_title ON pages(title);
CREATE INDEX IF NOT EXISTS idx_pages_last_edited ON pages(last_edited_time DESC);
CREATE INDEX IF NOT EXISTS idx_pages_parent ON pages(parent_type, parent_id);
```

## Implementation Steps

### Step 1: Core Infrastructure (schema.lua + init.lua)
**Files:** `cache/schema.lua`, `cache/init.lua`
**Tests:** `spec/unit/cache/schema_spec.lua`, `spec/unit/cache/init_spec.lua`

1. sqlite.lua availability check (graceful fallback)
2. Database path management (`M.get_db_path()`)
3. Database initialization with schema
4. Connection management (lazy open, proper close)
5. Error handling wrapper

```lua
-- cache/init.lua API
M.is_available()          -- Check if sqlite.lua is available
M.get_db_path()           -- Get database file path
M.open()                  -- Open/create database
M.close()                 -- Close database connection
M.clear()                 -- Clear all cached data
M.get_stats()             -- Get cache statistics
```

### Step 2: Page Metadata Operations (pages.lua)
**Files:** `cache/pages.lua`
**Tests:** `spec/unit/cache/pages_spec.lua`

1. CRUD operations for pages table
2. TTL-based staleness check
3. Batch operations for efficiency
4. Integration with `api/pages.lua`

```lua
-- cache/pages.lua API
M.upsert(page_data)       -- Insert or update page
M.upsert_many(pages)      -- Batch upsert
M.get(page_id)            -- Get single page by ID
M.get_all()               -- Get all cached pages
M.search(query)           -- Search by title (LIKE query)
M.get_recent(limit)       -- Get recently edited pages
M.remove(page_id)         -- Remove from cache
M.is_stale(page_id, ttl)  -- Check if cache entry is stale
M.mark_synced(page_id)    -- Update sync timestamp
```

### Step 3: Sync State Persistence (sync_state.lua)
**Files:** `cache/sync_state.lua`
**Tests:** `spec/unit/cache/sync_state_spec.lua`

1. Content hash calculation and storage
2. Sync queue for offline operations (foundation for Phase 10)
3. Dirty detection

```lua
-- cache/sync_state.lua API
M.get_content_hash(page_id)      -- Get stored content hash
M.set_content_hash(page_id, hash) -- Update content hash
M.is_dirty(page_id, current_hash) -- Check if content changed
M.queue_operation(page_id, op, payload) -- Add to sync queue
M.get_pending_operations()       -- Get queued operations
M.clear_operation(op_id)         -- Remove completed operation
```

### Step 4: Integration Points

#### 4.1 Config Update (`config.lua`)
```lua
cache = {
  enabled = true,
  ttl = 900,           -- 15 minutes default (user choice)
  db_path = nil,       -- nil = auto (stdpath)
  auto_refresh = true, -- Enabled with Phase 6 rate limiting
},
```

#### 4.2 Health Check (`health.lua`)
```lua
-- Add cache health checks
check_sqlite_available()   -- sqlite.lua library
check_libsqlite3()         -- System SQLite3
check_cache_db()           -- Database file access
check_cache_stats()        -- Cache statistics
```

#### 4.3 API Pages Integration (`api/pages.lua`)
```lua
-- Modify M.search() to use cache
function M.search(query, opts, callback)
  local cache = require('neotion.cache')

  -- Try cache first if available and not forcing refresh
  if cache.is_available() and not opts.force_refresh then
    local cached = cache.pages.search(query)
    if #cached > 0 and not cache.pages.is_stale(cached[1].id) then
      callback({ body = { results = cached } })
      return
    end
  end

  -- Fallback to API
  -- ... existing API call ...

  -- Update cache on success
  if cache.is_available() then
    cache.pages.upsert_many(results)
  end
end
```

#### 4.4 UI Picker Integration (`ui/picker.lua`)
- Use cached pages for instant picker display
- Show "(cached)" indicator for stale entries
- Background refresh while picker is open

### Step 5: Commands
```vim
:Neotion cache status      " Show cache statistics
:Neotion cache refresh     " Force refresh all cached pages
:Neotion cache clear       " Clear cache
:Neotion cache path        " Show database path
```

## Config Schema

```lua
---@class neotion.CacheConfig
---@field enabled boolean Whether cache is enabled (default: true)
---@field ttl integer Cache TTL in seconds (default: 300)
---@field db_path? string Custom database path (nil = auto)
---@field auto_refresh boolean Auto-refresh on startup (default: false, Phase 6)
```

## Error Handling

1. **sqlite.lua not installed:** Graceful degradation, log warning
2. **libsqlite3 not found:** Health check warning, cache disabled
3. **Database corruption:** Auto-rebuild, notify user
4. **Write errors:** Log, continue without cache
5. **Schema migration:** Version table, auto-migrate

## Testing Strategy

### Unit Tests (mock sqlite)
- Schema creation
- CRUD operations
- TTL calculation
- Content hash comparison
- Graceful degradation when sqlite unavailable

### Integration Tests (real sqlite)
- Database file creation
- Data persistence across restarts
- Concurrent access (if applicable)

## Implementation Order

| Order | File | Description | Est. Tests |
|-------|------|-------------|------------|
| 1 | `cache/schema.lua` | Schema definitions, version | 15 |
| 2 | `cache/init.lua` | Core orchestrator | 20 |
| 3 | `cache/pages.lua` | Page metadata CRUD | 25 |
| 4 | `cache/sync_state.lua` | Sync state, hash | 15 |
| 5 | `config.lua` | Cache config options | 5 |
| 6 | `health.lua` | Cache health checks | 10 |
| 7 | `api/pages.lua` | Cache integration | 10 |
| 8 | Commands | `:Neotion cache` | 5 |
| **Total** | | | **~105** |

## Out of Scope (Deferred)

1. **Offline mode queue processing** → Phase 10
2. **Block-level caching** → Future consideration
3. **Database encryption** → Not needed for metadata

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| sqlite.lua LuaJIT dependency | Graceful fallback, health warning |
| Database corruption | Auto-rebuild, backup before migrations |
| Large page counts | Pagination, index optimization |
| Sync conflicts | Content hash comparison, user confirmation |

## Success Criteria

1. `:Neotion search` opens instantly with cached pages
2. Cache persists across Neovim restarts
3. Stale entries automatically refreshed
4. `:checkhealth neotion` shows cache status
5. ~105 new tests passing
6. No performance regression

## Implementation Timeline

### Phase 6: Rate Limiting (~40 tests)
| Step | Description | Files |
|------|-------------|-------|
| 6.1 | Token bucket implementation | `api/throttle.lua` |
| 6.2 | Request queue with priority | `api/throttle.lua` |
| 6.3 | HTTP 429 + exponential backoff | `api/throttle.lua` |
| 6.4 | Integration with client.lua | `api/client.lua` |
| 6.5 | Config + health check | `config.lua`, `health.lua` |
| 6.6 | Tests | `spec/unit/api/throttle_spec.lua` |

### Phase 7: SQLite Cache (~105 tests)
| Step | Description | Files |
|------|-------------|-------|
| 7.1 | sqlite.lua dependency setup | `Makefile`, `spec/minimal_init.lua` |
| 7.2 | Schema + core module | `cache/schema.lua`, `cache/init.lua` |
| 7.3 | Page metadata operations | `cache/pages.lua` |
| 7.4 | Sync state persistence | `cache/sync_state.lua` |
| 7.5 | Config + health check | `config.lua`, `health.lua` |
| 7.6 | API integration + background refresh | `api/pages.lua` |
| 7.7 | Commands + UI | `plugin/neotion.lua`, `ui/picker.lua` |
| 7.8 | Tests | `spec/unit/cache/*_spec.lua` |

**Total new tests: ~145**

---

## Documentation Updates

### README.md - lazy.nvim Installation

```lua
-- lazy.nvim
{
  "nacro90/neotion.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "kkharji/sqlite.lua",  -- Required for page caching
  },
  config = function()
    vim.g.neotion = {
      api_token = vim.env.NOTION_API_TOKEN,
    }
  end,
}
```

### README.md - Requirements Section

```markdown
## Requirements

- Neovim 0.10+
- [Notion Integration Token](https://developers.notion.com/docs/getting-started)
- [sqlite.lua](https://github.com/kkharji/sqlite.lua) (for page caching)
- SQLite3 system library (`libsqlite3`)
  - Ubuntu/Debian: `sudo apt-get install sqlite3 libsqlite3-dev`
  - macOS: Pre-installed
  - Arch: `sudo pacman -S sqlite`
```
