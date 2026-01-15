# neotion.nvim

Neovim'de Notion entegrasyonu - **zero data loss** prensibiyle.

## TODO System

**Kod = Source of Truth**. Tüm aktif TODO'lar ilgili dosyalarda inline olarak bulunur.

### Format

```lua
-- TODO(neotion:ID:PRIORITY): Kısa açıklama
-- Detay satırları (opsiyonel)
```

**Priority:** `CRITICAL` > `HIGH` > `MEDIUM` > `LOW`

**ID örnekleri:** `11.3` (bug), `FEAT-9.4` (feature), `REFACTOR-X`

### Komutlar

```bash
# Tüm TODO'ları listele
grep -rn "TODO(neotion:" --include="*.lua" lua/

# Sıradaki TODO (en yüksek priority)
/todo-list next
```

### Nereye Bakılır

| Bilgi | Konum |
|-------|-------|
| Aktif TODO'lar | `grep "TODO(neotion:"` |
| Architectural decisions | Serena memories |
| Geçmiş fazlar | Git history |

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

- **Dogru mimari oncelikli** - Quick fix yerine proper fix, technical debt birakma
- **LuaCATS annotations** - Her public fonksiyon icin
- **Lazy loading** - `require()` fonksiyon icinde
- **Async by default** - Blocking API cagrisi yapma
- **Conventional Commits** - `feat:`, `fix:`, `test:`, `docs:`, `perf:`
- Code-reviewer agent kullan commit oncesi
- commit mesajlarinda bot mesaji koymak yok

## Current Status

**Phase 1-10:** Done | **Phase 11:** Active (Bug Fixes)

Aktif TODO'lar için: `grep -rn "TODO(neotion:" lua/`

### Roadmap

- `FEAT-14` - **File block support** (image, video, pdf, file) → [Detay](.claude/docs/FEAT-14-file-blocks.md)
- `FEAT-9.4` - Link completion `[[`
- `FEAT-9.5` - Mention completion `@`
- Tier 1: to_do block
- Tier 2: callout, toggle, bookmark (editable)

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
