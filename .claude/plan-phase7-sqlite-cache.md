# Phase 7: SQLite Cache - Implementation Plan

**Status:** Planning
**Last Updated:** 2025-01-05
**Dependencies:** Phase 6 (Rate Limiting) ✅ COMPLETE

---

## Executive Summary

Phase 7, Notion sayfalarının **anında açılması** ve **hızlı arama** için SQLite cache sistemi kuracak. Ana felsefe: **"Optimistic UI"** - önce cache'den göster, background'da API ile sync et.

---

## Core Philosophy

### Eski Yaklaşım (TTL-based) ❌
```
User Request → Cache valid? → Yes → Return cached
                           → No  → API Call → Return
```

### Yeni Yaklaşım (Optimistic UI) ✅
```
User Request → Cache exists? → Yes → INSTANT display + Background API sync
                             → No  → Loading + API Call → Display
```

**Fark:** TTL yok, her zaman API call yapılıyor ama kullanıcı beklemeden içeriği görüyor.

---

## User Decisions (Confirmed)

| Karar | Seçim | Rationale |
|-------|-------|-----------|
| sqlite.lua | **Required** dependency | UX için kritik |
| DB Path | `stdpath('cache')/neotion.db` | Cache semantics |
| Block storage | **Raw API JSON** | Model bağımsızlığı |
| Hash algorithm | **djb2** | Hızlı, Lua 5.1 uyumlu |
| Polling interval | **5 saniye** | Notion-like real-time feel |
| Polling scope | **Active tab only** | Resource efficiency |
| Content caching | **Page blocks dahil** | Instant page open |

---

## Architecture

### File Structure
```
lua/neotion/cache/
├── init.lua           # Public API + orchestrator
├── db.lua             # SQLite connection + query helpers
├── schema.lua         # Schema definitions + migrations
├── hash.lua           # djb2 hash utilities
├── pages.lua          # Page metadata operations
├── content.lua        # Page content (blocks) caching
├── sync_state.lua     # Sync state tracking
└── queue.lua          # Offline operation queue (Phase 10 prep)
```

### Database Location
```lua
vim.fn.stdpath('cache') .. '/neotion.db'
-- e.g. ~/.cache/nvim/neotion.db
```

### Schema
```sql
-- Schema version tracking
CREATE TABLE schema_version (
    version INTEGER PRIMARY KEY,
    applied_at INTEGER NOT NULL
);

-- Page metadata (search, picker için)
CREATE TABLE pages (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    icon TEXT,
    icon_type TEXT,           -- 'emoji' | 'external' | 'file' | NULL
    parent_type TEXT,         -- 'workspace' | 'page' | 'database'
    parent_id TEXT,
    last_edited_time INTEGER NOT NULL,
    created_time INTEGER,

    -- Cache tracking
    cached_at INTEGER NOT NULL,
    last_opened_at INTEGER,       -- Frecency için
    open_count INTEGER DEFAULT 0, -- Frecency için

    -- Status
    is_deleted INTEGER DEFAULT 0  -- 404 aldık mı? (lazy validation)
);

CREATE INDEX idx_pages_title ON pages(title);
CREATE INDEX idx_pages_frecency ON pages(open_count DESC, last_opened_at DESC);

-- Page content (blocks) - JSON blob for instant load
CREATE TABLE page_content (
    page_id TEXT PRIMARY KEY,
    blocks_json TEXT NOT NULL,    -- Raw API response JSON array
    content_hash TEXT NOT NULL,   -- djb2 hash for quick diff
    block_count INTEGER NOT NULL,
    fetched_at INTEGER NOT NULL,
    FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE
);

-- Block-level hashes (granular dirty detection)
CREATE TABLE block_hashes (
    block_id TEXT PRIMARY KEY,
    page_id TEXT NOT NULL,
    content_hash TEXT NOT NULL,
    block_type TEXT NOT NULL,
    FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE
);
CREATE INDEX idx_block_hashes_page ON block_hashes(page_id);

-- Sync state (conflict detection)
CREATE TABLE sync_state (
    page_id TEXT PRIMARY KEY,
    local_hash TEXT,              -- Current buffer state hash
    remote_hash TEXT,             -- Last known API state hash
    last_push_time INTEGER,
    last_pull_time INTEGER,
    sync_status TEXT DEFAULT 'unknown',
    FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE
);

-- Offline operation queue (Phase 10 prep)
CREATE TABLE sync_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    page_id TEXT NOT NULL,
    block_id TEXT,
    operation TEXT NOT NULL,      -- 'create' | 'update' | 'delete'
    payload TEXT NOT NULL,
    priority INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL,
    attempts INTEGER DEFAULT 0,
    last_error TEXT,
    FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE
);
CREATE INDEX idx_queue_priority ON sync_queue(priority DESC, created_at ASC);
```

---

## Data Flow

### Page Open (Instant Load)
```
:Neotion open <page_id>
         │
         ├─── [sync] Cache lookup
         │         │
         │    ┌────┴────┐
         │    ▼         ▼
         │  HIT       MISS
         │    │         │
         │    ▼         ▼
         │  INSTANT   Loading
         │  render    state
         │    │         │
         └────┴────┬────┘
                   │
         [async] API fetch
                   │
                   ▼
         Compare content_hash
                   │
         ┌────────┴────────┐
         ▼                 ▼
       SAME             DIFFERENT
         │                 │
         ▼                 ▼
       Done            Update buffer
      (synced)         (preserve cursor)
```

### Search (Feed-style)
```
:Neotion search "meeting"
         │
         ├─── [sync] Cache search → Picker'a göster
         │
         └─── [async] API search (paginated)
                   │
                   ├─── Page 1 results → Picker'a feed (dedupe)
                   ├─── Page 2 results → Picker'a feed (dedupe)
                   └─── ... (max 100 per page)
```

### Polling (5s interval, active buffer)
```
Every 5 seconds (aktif tab):
         │
         ▼
    API GET page
         │
    ┌────┴────┐
    ▼         ▼
   404      200
    │         │
    ▼         ▼
  Mark      Check
  deleted   content_hash
    │         │
    ▼    ┌────┴────┐
  Notify ▼         ▼
  user  SAME    DIFFERENT
          │         │
          ▼         ▼
        Done    Buffer dirty?
                    │
               ┌────┴────┐
               ▼         ▼
              NO        YES
               │         │
               ▼         ▼
            Update    Notify
            buffer    "remote changed"
```

---

## Deleted Page Detection Strategy ✅ DECIDED

### UX Agent Consultation Result (2025-01-05)

**Decision: Lazy Validation + Opportunistic Search Reconciliation**

Neovim power users understand caching and eventual consistency. A 404 followed by cleanup is expected behavior, not a UX failure.

### Why NOT Other Options

| Option | Rejection Reason |
|--------|------------------|
| Background cleanup job | 500 pages = 8+ min background work, wasteful |
| Visual staleness (dim/icon) | Wrong signal - "stale" ≠ "deleted", adds noise |
| last_validated_at threshold | Overengineered, cognitive overhead |

### Chosen Approach

**1. Lazy Validation (on page open)**
```
User opens cached page → API 404
    ↓
Graceful message: "Page was deleted. Removed from cache."
    ↓
Auto cleanup from cache + close buffer
```

**2. Opportunistic Search Reconciliation**
```
:Neotion search
    ↓
[instant] Show cached results
    ↓
[async] API search returns
    ↓
Merge to cache (ADD/UPDATE only, NO DELETE)
```

### Schema Simplification

```sql
-- REMOVED: last_validated_at (not needed)
-- REMOVED: staleness tracking (not needed)

CREATE TABLE pages (
    id TEXT PRIMARY KEY,
    -- ... metadata ...
    cached_at INTEGER NOT NULL,
    last_opened_at INTEGER,       -- Frecency
    open_count INTEGER DEFAULT 0, -- Frecency
    is_deleted INTEGER DEFAULT 0  -- Set to 1 on 404
);
```

### Graceful 404 UX

```
┌─────────────────────────────────────────────────┐
│  Page not found                                 │
│                                                 │
│  "Project Roadmap" was deleted in Notion.       │
│  Removed from local cache.                      │
│                                                 │
│  [Press any key to dismiss]                     │
└─────────────────────────────────────────────────┘
```

---

## Config

```lua
cache = {
  enabled = true,                    -- false = no caching
  path = nil,                        -- nil = stdpath('cache')/neotion.db

  -- Polling (active buffer only)
  poll_interval = 5,                 -- seconds
  poll_only_active_tab = true,

  -- Limits
  max_pages = 1000,                  -- LRU eviction
},
```

---

## Implementation Sub-Phases

| Phase | Scope | Description | Est. Tests |
|-------|-------|-------------|------------|
| **7.1** | DB Foundation | `db.lua`, `schema.lua`, `hash.lua` | ~30 |
| **7.2** | Page Metadata | `pages.lua` + CRUD | ~40 |
| **7.3** | Page Content | `content.lua` + instant open | ~35 |
| **7.4** | Search Integration | Picker feed + deduplication | ~25 |
| **7.5** | Sync State | `sync_state.lua` + block hashes | ~30 |
| **7.6** | Polling | 5s interval + deletion detection | ~20 |
| **7.7** | Offline Queue | `queue.lua` (Phase 10 prep) | ~15 |
| **7.8** | Polish | Commands, health, cleanup | ~20 |
| **Total** | | | **~215** |

---

## Commands

```vim
:Neotion cache stats      " Show cache statistics
:Neotion cache clear      " Clear all cached data
:Neotion cache path       " Show database file path
:Neotion cache vacuum     " Optimize database size
```

---

## Health Check Additions

```lua
-- lua/neotion/health.lua
-- Check sqlite.lua
if pcall(require, 'sqlite') then
  vim.health.ok("sqlite.lua: installed")
else
  vim.health.error("sqlite.lua: not found", {
    "Install with: Lazy.nvim deps or Rocks.nvim",
  })
end

-- Check database
local db_path = cache.get_path()
if vim.fn.filereadable(db_path) == 1 then
  local stats = cache.stats()
  vim.health.ok(string.format(
    "Cache: %d pages, %d with content, %.1f KB",
    stats.pages, stats.content, stats.size_kb
  ))
else
  vim.health.info("Cache: not initialized yet")
end
```

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| sqlite.lua not installed | Required dep, clear error message |
| Database corruption | Auto-rebuild, log warning |
| Large database | LRU eviction, periodic VACUUM |
| Stale deleted pages | Lazy validation on open (TBD) |
| Rate limit from polling | Throttle module handles it |

---

## Success Criteria

1. `:Neotion open` instant (< 50ms) for cached pages
2. `:Neotion search` instant results, API results stream in
3. 5s polling updates buffer without flicker
4. Deleted pages cleaned up on access attempt
5. ~215 new tests passing
6. No performance regression

---

## Next Steps

1. [x] UX agent consultation for deleted page handling ✅
2. [x] Finalize cleanup strategy ✅ (Lazy validation + opportunistic reconciliation)
3. [ ] User approval for final plan
4. [ ] Start implementation Phase 7.1 (DB Foundation)
