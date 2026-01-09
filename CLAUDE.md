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
└── ui/                # Picker, live search
```

## Dev Rules

- **LuaCATS annotations** - Her public fonksiyon icin
- **Lazy loading** - `require()` fonksiyon icinde
- **Async by default** - Blocking API cagrisi yapma
- **Conventional Commits** - `feat:`, `fix:`, `test:`, `docs:`
- Code-reviewer agent kullan commit oncesi

## Roadmap

| Phase | Status |
|-------|--------|
| 1-6: Foundation, Formatting, Navigation, Rate Limiting | Done |
| 7: SQLite Cache (pages, content, frecency) | Done |
| 8.1-8.3: Live Search + Query Cache | Done |
| 9.0-9.3: `/` Slash Commands (blocks, colors) | Done |
| 9.4: `[[` Link Completion | TODO |
| 9.5: `@` Mention | TODO |
| 10: Editing Experience Refactor | Done |

### Phase 10: Editing Experience

Complete editing experience overhaul:

| Sub-Phase | Status | Description |
|-----------|--------|-------------|
| 10.1-10.5 | Done | Block fixes, orphan handling, type detection |
| 10.6 | Done | Virtual lines (block spacing) |
| 10.6.1 | Done | Code block detection bug fix (2026-01-08) |
| 10.7 | Done | Empty paragraph spacing optimization |
| 10.8 | Done | Gutter icons (configurable, default: off) |
| 10.9 | Done | Enter/Shift+Enter editing model |
| 10.10 | Done | Continuation markers (multi-line block `│` indicator) |

**Recent Work (2026-01-09)**: Phase 10 completed. Continuation markers were implemented as part of Phase 10.8 (gutter icons). Multi-line blocks show `│` on subsequent lines with `NeotionGutterContinuation` highlight group.

**Current Plan**: `~/.claude/plans/quizzical-stargazing-ember.md`

Detaylar: `TODO.md`

## Syntax

| Format | Buffer | Notes |
|--------|--------|-------|
| Bold | `**text**` | |
| Italic | `*text*` | |
| Strike | `~text~` | |
| Code | `` `text` `` | |
| Underline | `<u>text</u>` | |
| Color | `<c:red>text</c>` | |
| Link | `[text](url)` | |
| Bullet | `- `, `* `, `+ ` | |
| Numbered | `1. `, `2. ` | |
| Quote | `\| ` | |
| Code block | ` ``` ` | |

## Cache Architecture

```
Query Cache (Notion order) → Pages Cache → Content Cache
         ↓
   Frecency Fallback
```

**Prensip:** Cache-first, background refresh

## Known Issues

Bkz: `TODO.md`
- commit mesajlarinda bot mesaji koymak yok