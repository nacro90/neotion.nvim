# neotion.nvim

Neovim'de Notion entegrasyonu - **zero data loss** prensibiyle.

## Quick Reference

```bash
make deps    # Bagimliliklar
make test    # Testler
make ci      # Format + test
```

```vim
:Neotion open <page_id>
:Neotion search [query]
:Neotion sync | push | pull
:Neotion cache [stats|clear|vacuum]
:Neotion log [show|tail|clear|level]
```

## Project Structure

```
lua/neotion/
├── init.lua           # Public API
├── config.lua         # Configuration
├── api/               # Notion API client (async)
├── buffer/            # Buffer management
├── model/             # Data models
├── render/            # Rendering system
├── cache/             # SQLite cache
├── sync/              # Push/pull operations
├── input/             # Keymaps, editing
└── ui/                # Picker, live search
```

## Dev Rules

- **LuaCATS annotations** - Her public fonksiyon icin
- **Lazy loading** - `require()` fonksiyon icinde
- **Async by default** - Blocking API cagrisi yapma
- **Conventional Commits** - `feat:`, `fix:`, `test:`, `docs:`, `perf:`
- Code-reviewer agent kullan commit oncesi
- commit mesajlarinda bot mesaji koymak yok

## Current Status

| Phase | Status |
|-------|--------|
| 1-10 | ✅ Done |
| **11: Bug Fixes** | **Active** |

### Phase 11 Bugs

| Bug | Status | Description |
|-----|--------|-------------|
| 11.1 | ✅ Done | Cache sync |
| 11.2 | TODO | Enter orphan soft break |
| 11.3 | TODO | List virtual line |

**Detaylar**: `TODO.md`

## Syntax

| Format | Buffer |
|--------|--------|
| Bold | `**text**` |
| Italic | `*text*` |
| Strike | `~text~` |
| Code | `` `text` `` |
| Underline | `<u>text</u>` |
| Color | `<c:red>text</c>` |
| Link | `[text](url)` |
| Bullet | `- `, `* `, `+ ` |
| Numbered | `1. `, `2. ` |
| Quote | `\| ` |
| Code block | ` ``` ` |

## Architecture

```
Buffer ←→ Model ←→ Sync ←→ API
              ↓
           Cache (SQLite)
```

**Prensip**: Cache-first, background refresh

## Key Files

| Area | Files |
|------|-------|
| Sync | `sync/init.lua`, `sync/plan.lua` |
| Cache | `cache/pages.lua`, `cache/sync_state.lua` |
| Input | `input/editing.lua`, `input/keymaps.lua` |
| Render | `render/init.lua`, `render/extmarks.lua` |

## Serena Memories

- `sync-cache-flow` - Sync/cache akislari
- `project-structure` - Proje yapisi
- `phase10-gutter-icons` - Gutter icons

**Full Documentation**: `TODO.md`
