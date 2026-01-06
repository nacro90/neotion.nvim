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
| 8.4: `[[` Link Completion | TODO |
| 9: `/` Slash Commands | TODO |
| 10: Full Lossless + Polish | TODO |

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

- Block links (`notion://block/id`) desteklenmiyor
- Nested list items → Future
- Auto-continuation (Enter after list) → Future

Aktif sorunlar: `.claude/plans/`
