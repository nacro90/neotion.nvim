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
| 11: Editing Bug Fixes | **In Progress** |

### Phase 11: Editing Bug Fixes (Current)

| Bug | Priority | Status | Description |
|-----|----------|--------|-------------|
| 11.1 | CRITICAL | ✅ Done | Cache sync sonrası güncellenmiyor |
| 11.2 | CRITICAL | TODO | Enter orphan line'da soft break yapıyor |
| 11.3 | HIGH | TODO | List item virtual line pozisyon hatası |

Detaylar: `TODO.md` → Phase 11

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

**Recent Work (2026-01-09)**: Bug 11.1 (cache sync) çözüldü. Push success callback'ine cache update eklendi, 3 yeni test yazıldı.

**Next**: Bug 11.2 (Enter orphan soft break) veya Bug 11.3 (list item virtual line)

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