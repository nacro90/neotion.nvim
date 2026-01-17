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
- **Red-Green-Refactor** - TDD yaklaşımı, aşağıdaki workflow'u takip et
- **LuaCATS annotations** - Her public fonksiyon icin
- **Lazy loading** - `require()` fonksiyon icinde
- **Async by default** - Blocking API cagrisi yapma
- **Conventional Commits** - `feat:`, `fix:`, `test:`, `docs:`, `perf:`
- Code-reviewer agent kullan commit oncesi
- commit mesajlarinda bot mesaji koymak yok
- **Logging** - Manuel test sirasinda detayli log iste, debug callari ekle (`:Neotion log tail`)
- **Manuel test isteme** - Max 3 senaryo, kısa ve öz (kullanıcı context'i biliyor)

## Red-Green-Refactor Workflow

Yeni feature veya bug fix implementasyonunda TDD yaklaşımı kullan:

### 1. RED Phase - Test Yaz (Fail)

Agent: `lua-test-writer` (`.claude/agents/lua-test-writer.md`)

```bash
# Agent'ı çağır
# Task tool ile subagent olarak kullan
```

- Davranışı tanımlayan **failing test** yaz
- Test MUST fail (henüz implementation yok)
- Tek bir davranış, tek bir test
- `make test` ile fail ettiğini doğrula

### 2. GREEN Phase - Minimal Implementation

Agent: `lua-implementer` (`.claude/agents/lua-implementer.md`)

```bash
# Agent'ı çağır
# Task tool ile subagent olarak kullan
```

- Testi geçirecek **minimum kod** yaz
- Fazla feature ekleme, sadece test'i geçir
- `make test` ile pass ettiğini doğrula

### 3. REFACTOR Phase - İyileştir

Agent: `lua-refactorer` (`.claude/agents/lua-refactorer.md`)

```bash
# Agent'ı çağır
# Task tool ile subagent olarak kullan
```

- Davranışı değiştirmeden kodu iyileştir
- DRY, readability, code style
- `make ci` ile tüm testlerin hala geçtiğini doğrula

### Workflow Örneği

```
1. /todo-start veya /task-start ile başla
2. RED: lua-test-writer agent → failing test
3. GREEN: lua-implementer agent → minimal code
4. REFACTOR: lua-refactorer agent → clean code
5. Cycle'ı tekrarla (gerekirse)
6. code-reviewer agent ile review
7. Commit
```

### Ne Zaman TDD Kullan

- Yeni feature implementasyonu
- Bug fix (önce bug'ı reproduce eden test)
- Refactoring (önce mevcut davranışı test et)
- API değişiklikleri

### Ne Zaman TDD Kullanma

- Trivial değişiklikler (typo fix, comment)
- Config değişiklikleri
- Documentation

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

## Test Structure

```
spec/
├── minimal_init.lua       # Test initialization
├── helpers/
│   ├── buffer.lua         # Buffer test utilities
│   └── mock_api.lua       # Notion API mock
├── unit/                  # Unit tests (isolated)
│   ├── model/
│   ├── input/
│   ├── render/
│   └── ...
└── integration/           # Integration tests (full workflow)
    ├── editing_spec.lua
    └── navigation_spec.lua
```

## Serena Memories

- `sync-cache-flow` - Sync/cache akislari
- `project-structure` - Proje yapisi
- `phase10-gutter-icons` - Gutter icons


