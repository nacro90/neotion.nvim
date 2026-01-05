# neotion.nvim

Neovim'de Notion entegrasyonu sağlayan, **zero data loss** prensibiyle tasarlanmış bir plugin. En basit kullanımdan başlayarak kademeli olarak Notion'ın tüm özelliklerini desteklemeyi hedefler.

## Geliştirme Felsefesi

1. **Basit başla, kademeli ilerle** - Her phase çalışır durumda olmalı
2. **Test-first** - Özellik yazmadan önce test yaz
3. **Her commit çalışır** - Kırık kod commit'leme
4. **Incremental value** - Her phase kullanıcıya değer katmalı

## Teknik Gereksinimler

- Neovim 0.10+
- Lua 5.1 API (LuaJIT extensions kullanma)
- Notion API token (Integration)

## Proje Yapısı

```
neotion.nvim/
├── lua/neotion/
│   ├── init.lua           # Public API
│   ├── config.lua         # Configuration + validation
│   ├── health.lua         # :checkhealth support
│   ├── log.lua            # Logging system
│   ├── api/               # Notion API client (async)
│   │   ├── auth.lua       # Token management
│   │   ├── blocks.lua     # Block operations
│   │   ├── client.lua     # HTTP client (curl)
│   │   ├── pages.lua      # Page operations
│   │   └── throttle.lua   # Rate limiting (Phase 6)
│   ├── buffer/            # Buffer management
│   │   ├── init.lua       # Buffer create/open
│   │   └── format.lua     # Block → text conversion
│   ├── model/             # Data models
│   │   ├── init.lua       # Model orchestration
│   │   ├── block.lua      # Base Block class
│   │   ├── mapping.lua    # Line ↔ Block mapping
│   │   ├── registry.lua   # Block type registry
│   │   ├── rich_text.lua  # RichTextSegment (Phase 5)
│   │   └── blocks/        # Block implementations
│   │       ├── heading.lua
│   │       ├── paragraph.lua
│   │       └── ...        # (Phase 9: todo, quote, code, etc.)
│   ├── sync/              # Sync engine
│   │   ├── init.lua       # Push/pull/sync
│   │   ├── confirm.lua    # User confirmation
│   │   └── plan.lua       # Sync planning
│   ├── format/            # Format providers (Phase 5)
│   │   ├── init.lua       # Provider registry
│   │   ├── types.lua      # Type definitions
│   │   ├── notion.lua     # Notion syntax
│   │   └── markdown.lua   # Markdown syntax (Phase 5.5)
│   ├── render/            # Rendering system (Phase 5)
│   │   ├── init.lua       # Render orchestrator
│   │   ├── anti_conceal.lua
│   │   ├── extmarks.lua
│   │   ├── highlight.lua
│   │   └── icons.lua
│   ├── commands/          # Command handlers (Phase 5)
│   │   └── formatting.lua # :Neotion bold/italic/color
│   ├── input/             # Input system (Phase 5.5)
│   │   ├── init.lua       # Input orchestrator
│   │   ├── shortcuts.lua  # Formatting shortcuts
│   │   ├── keymaps.lua    # Default keymaps (Phase 5.6)
│   │   ├── triggers.lua   # Trigger registry (/ @ [[)
│   │   └── completions/   # Completion handlers (Phase 8+)
│   │       ├── page_link.lua  # [[ handler
│   │       └── slash_menu.lua # / handler
│   ├── navigation/        # Link navigation (Phase 5.6)
│   │   └── init.lua       # Link detection + goto
│   ├── cache/             # SQLite cache (Phase 7)
│   │   ├── init.lua       # Cache orchestrator
│   │   ├── schema.lua     # SQLite schema
│   │   ├── pages.lua      # Page metadata ops
│   │   └── sync_state.lua # Sync persistence
│   └── ui/                # UI components
│       └── picker.lua     # Telescope/vim.ui.select
├── plugin/neotion.lua     # Commands, <Plug> mappings
├── ftplugin/neotion.lua   # Filetype settings
├── doc/neotion.txt        # Vimdoc
├── spec/                  # Tests (plenary.busted)
│   ├── unit/
│   │   ├── api/
│   │   ├── buffer/
│   │   ├── model/
│   │   ├── format/
│   │   ├── render/
│   │   ├── navigation/
│   │   ├── cache/
│   │   └── ...
│   ├── integration/
│   └── minimal_init.lua
└── .github/workflows/     # CI pipeline
```

## Geliştirme Kuralları

### Kod Standartları

1. **LuaCATS annotations zorunlu** - Her public fonksiyon için
2. **Lazy loading** - `require()` fonksiyon içinde
3. **Async by default** - Blocking API çağrısı yapma
4. **Error handling** - `pcall` kullan, anlamlı mesajlar göster
5. **Lua 5.1 uyumluluğu** - LuaJIT extensions kullanma

### Configuration Pattern

`setup()` fonksiyonu **opsiyoneldir**:

```lua
-- 1. vim.g.neotion (plugin yüklenmeden önce)
vim.g.neotion = { api_token = 'secret_xxx' }

-- 2. setup() ile (opsiyonel, sadece override)
require('neotion').setup({ api_token = 'secret_xxx' })

-- 3. Environment variable
-- export NOTION_API_TOKEN=secret_xxx
```

### User Commands

Tek bir `:Neotion` komutu, subcommand pattern:

```vim
:Neotion open <page_id>
:Neotion sync
:Neotion push
:Neotion pull
:Neotion search
:Neotion status
:Neotion log [show|tail|clear|path|level]
```

### Logging

Neotion has a built-in logging system for debugging and monitoring:

```lua
-- Log file location: vim.fn.stdpath('log')/neotion.log
-- e.g. ~/.local/state/nvim/neotion.log

-- Log levels: DEBUG, INFO, WARN, ERROR, OFF
-- Set via config:
require('neotion').setup({
  log_level = 'DEBUG', -- or 'INFO', 'WARN', 'ERROR', 'OFF'
})

-- Or at runtime:
:Neotion log level DEBUG
```

**Log Commands:**
- `:Neotion log show` - Show last 100 lines in split buffer
- `:Neotion log tail [n]` - Show last n lines (default: 100)
- `:Neotion log clear` - Clear the log file
- `:Neotion log path` - Show log file path
- `:Neotion log level [level]` - Get/set log level

**Using loggers in code:**
```lua
local log = require('neotion.log').get_logger('module_name')
log.debug('Detailed info', { key = value })
log.info('Operation completed')
log.warn('Something might be wrong')
log.error('Operation failed', { error = err })
```

### Keymaps

Sadece `<Plug>` mappings, kullanıcı kendi keymap'ini tanımlar.

### Test

```bash
make deps    # Bağımlılıkları yükle
make test    # Tüm testleri çalıştır
make ci      # Format check + test
make format  # Format code with StyLua

# Test sayma
make test 2>&1 | grep "Success:" | sed 's/\x1b\[[0-9;]*m//g' | awk '{sum += $2} END {print sum}'

# Tek dosya test
nvim --headless -u spec/minimal_init.lua -c "PlenaryBustedFile spec/unit/path/to_spec.lua" 2>&1 | tail -10
```

### Code Quality Tools

- **StyLua** - Code formatting (checked in CI)
- **lua-language-server** - Type checking with LuaCATS annotations (checked in CI)
- **plenary.busted** - Unit and integration tests

### Test Yazım Standartları

**Framework:** plenary.busted (BDD style)

**Dosya Yapısı:**
```
spec/
├── unit/           # İzole birim testleri (mock kullanır)
│   ├── api/
│   │   ├── auth_spec.lua
│   │   ├── blocks_spec.lua
│   │   ├── client_spec.lua
│   │   └── pages_spec.lua
│   ├── buffer/
│   │   ├── format_spec.lua
│   │   └── init_spec.lua
│   ├── config_spec.lua
│   ├── health_spec.lua
│   └── init_spec.lua
├── integration/    # Gerçek API testleri (token gerekir)
└── minimal_init.lua
```

**Test Yapısı (BDD):**
```lua
describe('module_name', function()
  describe('function_name', function()
    it('should do something when condition', function()
      -- Arrange
      local input = ...

      -- Act
      local result = module.function_name(input)

      -- Assert
      assert.are.equal(expected, result)
    end)

    it('should handle edge case', function()
      -- ...
    end)
  end)
end)
```

**Kurallar:**
1. Her public fonksiyon için en az bir test
2. Edge case'ler ayrı `it()` blokları
3. Mock'lar `before_each()` içinde setup
4. Async testler için `vim.wait()` kullan
5. Test isimleri açıklayıcı: `'should return nil when token is empty'`
6. **Yeni kod yazıldığında testleri de ekle** - Her yeni modül için `spec/unit/` altında test dosyası oluştur

### Commit Standartları

- Conventional Commits: `feat:`, `fix:`, `test:`, `docs:`, `refactor:`
- Her commit çalışır durumda
- Test geçmeden commit yapma
- **Commit öncesi code-reviewer agent kullan** - Değişiklikleri gözden geçir

## Implementation Phases

### Phase 1: Project Foundation ✅ COMPLETE
**Goal:** Sağlam altyapı, CI/CD, test framework

- [x] Proje yapısını oluştur
- [x] Config dosyaları (`.luarc.json`, `selene.toml`, `stylua.toml`)
- [x] `lua/neotion/config.lua` - vim.g.neotion + setup() + validation
- [x] `lua/neotion/health.lua` - `:checkhealth neotion`
- [x] `lua/neotion/init.lua` - Public API stubs
- [x] `plugin/neotion.lua` - Subcommand pattern, `<Plug>` mappings
- [x] `.github/workflows/ci.yml` - Format check, typecheck, test
- [x] Test altyapısı (plenary.busted, 28 test geçiyor)

---

### Phase 2: Read-Only Connection ✅ COMPLETE
**Goal:** Notion'dan sayfa okuyabilme

- [x] `lua/neotion/api/client.lua` - Async HTTP (vim.system + curl)
- [x] `lua/neotion/api/auth.lua` - Token management (config, vim.g, env var)
- [x] `lua/neotion/api/pages.lua` - `search()`, `get(page_id)`
- [x] `lua/neotion/api/blocks.lua` - `get_children(block_id)`, `get_all_children()`
- [x] `lua/neotion/buffer/init.lua` - Buffer oluşturma ve yönetimi
- [x] `lua/neotion/buffer/format.lua` - Blocks → plain text (Markdown)
- [x] `:Neotion open <page_id>` implementasyonu
- [x] Read-only buffer (modifiable=false, buftype=acwrite)
- [x] Unit testler (121 test geçiyor)
- [x] Buffer status tracking (`loading`, `ready`, `modified`, `syncing`, `error`)
- [x] Page ID validation (32 hex characters)
- [x] Race condition prevention in `M.open()`

**Acceptance Criteria:**
- [x] API token ile bağlantı kurulur
- [x] Sayfa içeriği buffer'da düz metin olarak görünür
- [x] API hataları kullanıcıya gösterilir

---

### Phase 3: Page Selection & Navigation ✅ COMPLETE
**Goal:** Kolay sayfa seçimi ve gezinti

- [x] `lua/neotion/ui/picker.lua` - Picker abstraction
- [x] Telescope extension (varsa)
- [x] `vim.ui.select` fallback
- [x] `:Neotion search [query]` - Sayfa arama ve seçim
- [x] `:Neotion recent` - Son açılan sayfalar
- [x] Sayfa listesinde icon, title, parent gösterimi
- [x] Seçilen sayfayı `M.open()` ile aç
- [x] Unit testler (149 test geçiyor)

**Acceptance Criteria:**
- [x] `:Neotion search` ile sayfa listesi görünür
- [x] Telescope varsa Telescope, yoksa vim.ui.select kullanılır
- [x] Sayfa seçilince açılır

---

### Phase 4: Basic Write ✅ COMPLETE
**Goal:** Basit metin yazıp kaydedebilme (zero data loss)

- [x] Buffer'ı writable yap (read-only blocks InsertEnter autocmd ile korunuyor)
- [x] Block abstraction layer (`lua/neotion/model/`)
  - [x] `block.lua` - Base Block class (read-only for unsupported types)
  - [x] `blocks/paragraph.lua` - Fully editable paragraph blocks
  - [x] `blocks/heading.lua` - Fully editable heading_1/2/3 blocks
  - [x] `registry.lua` - Block type dispatch and handler registration
  - [x] `mapping.lua` - Line-to-block mapping with extmarks
- [x] Sync layer (`lua/neotion/sync/`)
  - [x] `plan.lua` - Sync plan creation (updates/creates/deletes)
  - [x] `confirm.lua` - User confirmation dialogs
  - [x] `init.lua` - Sync orchestration (push/pull/sync)
- [x] `:w` autocmd ile push (BufWriteCmd)
- [x] TextChanged tracking ve dirty detection
- [x] Config options: `editing_mode`, `confirm_sync`
- [x] Rich text preservation (unchanged text keeps formatting)
- [x] Zero data loss: unsupported block types are read-only

**Acceptance Criteria:**
- [x] Düz metin (paragraph, heading) yazılıp kaydedilebilir
- [x] Notion'da değişiklik görünür
- [x] Desteklenmeyen block türleri read-only (zero data loss)
- [x] Rich text formatting preserved when text unchanged

---

### Phase 5: Inline Formatting Display
**Goal:** Notion'dan gelen inline formatting'i görsel render (render-markdown.nvim stili)

**Yaklaşım:** Anti-conceal - cursor satırında marker'lar görünür, diğer satırlarda temiz unicode gösterim

**Kararlar:**
| Karar | Seçim |
|-------|-------|
| Display mode | Anti-conceal (cursor satırında raw) |
| Custom syntax | HTML-like: `<u>text</u>`, `<c:red>text</c>` |
| Icons | Nerd Font default, ASCII fallback |
| Provider | Notion syntax (ileride Markdown eklenebilir) |

**Yeni Modüller:**
```
lua/neotion/
├── render/                      # Rendering system
│   ├── init.lua                 # Render orchestrator, autocmds
│   ├── anti_conceal.lua         # Cursor-aware show/hide
│   ├── extmarks.lua             # Extmark helpers
│   ├── highlight.lua            # Highlight group definitions
│   └── icons.lua                # Icon presets (nerd/ascii)
│
├── format/                      # Format provider system
│   ├── init.lua                 # Provider registry
│   ├── types.lua                # RichTextSegment, Annotation types
│   ├── notion.lua               # Notion syntax (default)
│   └── markdown.lua             # Phase 5.5+
│
└── model/
    └── rich_text.lua            # RichTextSegment class
```

**Core Types:**
```lua
---@class neotion.Annotation
---@field bold boolean
---@field italic boolean
---@field strikethrough boolean
---@field underline boolean
---@field code boolean
---@field color string  -- 'default'|'red'|'blue'|...

---@class neotion.RichTextSegment
---@field text string
---@field annotations neotion.Annotation
---@field href? string
---@field start_col integer
---@field end_col integer
```

**Notion Syntax:**
| Format | Buffer Markers | Rendered |
|--------|----------------|----------|
| Bold | `**text**` | **text** |
| Italic | `*text*` | *text* |
| Strikethrough | `~text~` | ~~text~~ |
| Code | `` `text` `` | `text` |
| Underline | `<u>text</u>` | underlined |
| Color | `<c:red>text</c>` | colored text |

**Icon Presets:**
```lua
-- Nerd Font (default)
heading = { '󰲡 ', '󰲣 ', '󰲥 ' }
bullet = { '●', '○', '◆', '◇' }
checkbox = { unchecked = '󰄱 ', checked = '󰱒 ' }

-- ASCII fallback
heading = { '# ', '## ', '### ' }
bullet = { '-', '*', '+', '-' }
checkbox = { unchecked = '[ ]', checked = '[x]' }
```

**Config:**
```lua
render = {
  enabled = true,
  anti_conceal = true,
  icons = 'nerd',  -- 'nerd' | 'ascii' | false
  syntax = 'notion',
}
```

**Checklist:**
- [x] `lua/neotion/format/types.lua` - Type definitions (40 test)
- [x] `lua/neotion/model/rich_text.lua` - RichTextSegment utilities (28 test)
- [x] `lua/neotion/render/highlight.lua` - Highlight groups (26 test)
- [x] `lua/neotion/render/icons.lua` - Icon presets (36 test)
- [x] `lua/neotion/format/init.lua` - Provider registry (13 test)
- [x] `lua/neotion/format/notion.lua` - Notion syntax renderer (40 test)
- [x] `lua/neotion/render/init.lua` - Render orchestrator (21 test)
- [x] `lua/neotion/render/extmarks.lua` - Extmark helpers (20 test)
- [x] `lua/neotion/render/anti_conceal.lua` - Anti-conceal logic (22 test)
- [x] Block integration (paragraph.lua, heading.lua)
- [ ] `lua/neotion/commands/formatting.lua` - `:Neotion bold/italic/color`
- [ ] Config güncellemesi + health check
- [x] Unit testler (226+ yeni test)

**Known Issues (Phase 5):**
- [x] ~~**Adjacent segment merging:** Fixed with smart marker optimization~~
- [ ] **Background color:** `red_background` only changes background, text color stays default
  - Need to add foreground color for background variants or use different highlight approach

---

### Phase 5.5: Inline Formatting Input ✅ COMPLETE
**Goal:** Marker yazarak formatting ekleme, bidirectional formatting (write direction)

**Kararlar:**
| Karar | Seçim |
|-------|-------|
| Normal mode | Operator-pending (primary) + toggle word + visual |
| Insert mode | Pair insertion (`**\|**`) |
| Scope | Core only, genişletilebilir altyapı (`/` ve `@` için) |
| Link syntax | Markdown style `[text](url)` |

**Data Flow (Bidirectional):**
```
Notion API rich_text[]
       ↓ render()                    ↑ parse_to_api()
Buffer: "**bold** [link](url)"
       ↓ extmarks                    ↑ serialize()
Screen: **bold** link (styled)      User edits buffer
```

**Yeni/Değişen Modüller:**
```
lua/neotion/
├── format/
│   └── notion.lua          # ADD: parse_to_api(), link syntax
├── input/                   # NEW DIRECTORY
│   ├── init.lua            # Input system orchestrator
│   ├── shortcuts.lua       # Operator-pending + toggle + visual
│   └── triggers.lua        # Extensible trigger registry (for future / @)
├── model/blocks/
│   ├── paragraph.lua       # MODIFY: use parse_to_api() in serialize()
│   └── heading.lua         # MODIFY: same
└── commands/
    └── formatting.lua      # NEW: :Neotion bold/italic/color
```

**Syntax (Updated):**
| Syntax | Result |
|--------|--------|
| `**text**` | bold |
| `*text*` | italic |
| `~text~` | strikethrough |
| `` `text` `` | code |
| `<u>text</u>` | underline |
| `<c:red>text</c>` | color |
| `[text](url)` | link |

**Plug Mappings:**
```lua
-- Operator-pending (normal mode primary)
<Plug>(NeotionBold)           -- g@{motion} = bold motion
<Plug>(NeotionItalic)
<Plug>(NeotionStrikethrough)
<Plug>(NeotionCode)
<Plug>(NeotionUnderline)
<Plug>(NeotionColor)          -- opens color picker, then g@{motion}

-- Toggle word (normal mode secondary)
<Plug>(NeotionToggleBold)     -- toggle word under cursor
<Plug>(NeotionToggleItalic)
...

-- Visual mode
<Plug>(NeotionVisualBold)     -- format selection
<Plug>(NeotionVisualItalic)
...

-- Insert mode pair
<Plug>(NeotionBoldPair)       -- inserts **|**
<Plug>(NeotionItalicPair)
...
```

**Config:**
```lua
input = {
  shortcuts = {
    enabled = true,
    bold = true,
    italic = true,
    -- ...
  },
  triggers = {
    enabled = false,  -- Phase 8: enable for / and @
  },
},
```

**Checklist:**
- [x] `format/notion.lua` - `parse_to_api()` + link syntax + tests
- [x] `model/blocks/paragraph.lua` - use parser in `serialize()`
- [x] `model/blocks/heading.lua` - same
- [x] `input/shortcuts.lua` - operator-pending + visual + toggle
- [x] `input/init.lua` - orchestrator
- [x] `input/triggers.lua` - registry stub for future `/` and `@`
- [x] `commands/formatting.lua` - `:Neotion bold/italic/color`
- [x] `plugin/neotion.lua` - register Plug mappings
- [x] `config.lua` - input options
- [x] Bug fix: `vim.NIL` href handling in `types.lua` and `notion.lua`
- [x] Bug fix: API callback error logging in `client.lua`

**Acceptance Criteria:**
- [x] `**text**` yazıp kaydet → Notion'da bold olarak görünsün
- [x] `[link](url)` yazıp kaydet → Notion'da clickable link olsun
- [x] `<Plug>(NeotionBold)iw` → cursor altındaki word bold olsun
- [x] Visual select + `<Plug>(NeotionVisualBold)` → selection bold olsun
- [x] Mevcut formatting korunsun (text değişmediyse)

**Not:** Default keymap'ler (`<C-b>` vb.) ve real-time rendering Phase 5.6'da.

---

### Phase 5.6: Real-time Rendering + gf Navigation ✅ COMPLETE
**Goal:** Marker yazınca anında render, link navigation ile Vim-native UX

**Complexity:** M (Medium)

**Scope:**
1. **gf Navigation** (non-negotiable Vim pattern)
2. **Real-time rendering** (immediate visual feedback)
3. **Default keymaps** (optional, configurable)

**gf Navigation:**
- [x] `lua/neotion/navigation/init.lua` - Link detection + goto
- [x] `M.goto_link()` implementasyonu in `init.lua`
- [x] `[text](url)` ve internal Notion link desteği
- [x] `gf` override in `ftplugin/neotion.lua`
- [x] `<Plug>(NeotionGotoLink)` mapping

**Real-time Rendering:**
- [x] `lua/neotion/render/init.lua` - TextChanged/InsertLeave autocmds
- [x] InsertLeave autocmd - Insert mode'dan çıkınca parse & render
- [x] TextChanged autocmd - Normal mode'da değişiklik olunca re-render
- [x] Debounce mechanism (configurable via `render.debounce_ms`, default 100ms)
- [x] Anti-conceal cursor tracking for real-time marker visibility

**Default Keymaps (opsiyonel, config ile kapatılabilir):**
```lua
-- Normal mode (operator-pending)
<C-b>     → <Plug>(NeotionBold)
<C-i>     → <Plug>(NeotionItalic)  -- dikkat: Tab ile çakışabilir
<C-u>     → <Plug>(NeotionUnderline)
<C-s>     → <Plug>(NeotionStrikethrough)
<C-`>     → <Plug>(NeotionCode)

-- Visual mode
<C-b>     → <Plug>(NeotionVisualBold)
...

-- Insert mode
<C-b>     → <Plug>(NeotionBoldPair)
...
```

**Files (implemented):**
```
lua/neotion/
├── render/init.lua           # Real-time rendering with debounce
├── navigation/init.lua       # Link detection + goto_link()
└── input/keymaps.lua         # Default keymap definitions
```

**Config:**
```lua
input = {
  shortcuts = {
    enabled = true,
    default_keymaps = false,  -- enable default keymaps
  },
},
render = {
  enabled = true,
  debounce_ms = 100,  -- debounce delay for re-rendering
},
```

**Checklist:**
- [x] gf navigation with link parsing (existing parser in `format/notion.lua`)
- [x] Real-time rendering with InsertLeave/TextChanged
- [x] Debounce mechanism (configurable via `render.debounce_ms`)
- [x] Default keymap registration (buffer-local, neotion filetype only)
- [x] Config option for default keymaps (`input.shortcuts.default_keymaps`)
- [x] Handle keymap conflicts (M-i alternative for C-i)
- [x] Unit tests for navigation and debounce modules (751 tests total)

---

### Phase 5.7: Basic Block Types
**Goal:** Görsel zenginlik, real-time rendering test, Phase 9'a zemin

**Complexity:** S-M (Small-Medium)

**Block Set (Minimal 4):**
| Block | Editable | Display | Input Parse |
|-------|----------|---------|-------------|
| `divider` | No | `────────` | `---` |
| `quote` | Yes | `│ ` (box drawing) | `| ` (pipe) |
| `bulleted_list_item` | Yes | `• ` (nerd) / `- ` (ascii) | `-`, `*`, `+` |
| `code` | Yes | ` ```lang ` | ` ``` ` (markdown) |

**Syntax Decisions:**
- Quote: `| ` input → `│ ` display (Notion-native, `>` reserved for toggle)
- Bullet: All markdown chars (`-`, `*`, `+`) accepted, display per icon preset
- Code: Markdown-compatible, language tag preserved, no syntax highlight yet
- Divider: Read-only, no content

**New Files:**
```
lua/neotion/model/blocks/
├── divider.lua           # Simplest block, read-only
├── quote.lua             # | prefix, rich text support
├── bulleted_list.lua     # Flat only, rich text support
└── code.lua              # Multi-line, language metadata
```

**Modify:** `lua/neotion/model/registry.lua` - Register new block types

**Checklist:**
- [x] `divider.lua` - Read-only, `---` render
- [x] `quote.lua` - `| ` prefix, editable with rich text
- [x] `bulleted_list.lua` - Flat (no nesting), `-`/`*`/`+` parse
- [x] `code.lua` - Multi-line, language preserved, plain text
- [x] Register all in `registry.lua`
- [x] Icon presets for bullet/quote (defined in icons.lua, not yet used as extmark overlay)
- [x] Unit tests for each block type

**Known Limitations (TODO for Phase 9):**
- [ ] List nesting support (indent levels)
- [ ] Code block syntax highlighting (treesitter)
- [ ] Numbered list sequence tracking
- [ ] Divider indent support (dividers can be nested inside list items)

**Reserved Characters:**
- `>` → toggle block (Phase 9)
- `[ ]` / `[x]` → to_do (Phase 9)

---

### Phase 6: Rate Limiting + Request Queue ✅ COMPLETE
**Goal:** Notion API koruması (3 req/s limiti)

**Complexity:** M (Medium)

**Rationale:** Tüm gelecek phase'ler daha fazla API çağrısı yapacak. Rate limiting erken gelmeli.

**Scope:**
1. Token bucket rate limiter (3 tokens/s, burst 10)
2. FIFO request queue
3. HTTP 429 handling with `Retry-After` header
4. Exponential backoff retry
5. Request cancellation (superseded searches için)

**New Files:**
```
lua/neotion/api/throttle.lua    # Token bucket + queue
```

**Modify:** `lua/neotion/api/pages.lua`, `lua/neotion/api/blocks.lua` - use throttle instead of client

**Checklist:**
- [x] `lua/neotion/api/throttle.lua` - Token bucket implementation
- [x] Request queue with FIFO processing
- [x] HTTP 429 handling with `Retry-After` header
- [x] Exponential backoff (1s, 2s, 4s, 8s max, 3 retries)
- [x] Request cancellation for outdated requests
- [x] Integration with pages.lua and blocks.lua
- [x] Unit tests for throttle module (48 tests)
- [x] Config options (`throttle = { tokens_per_second, burst_size, ... }`)
- [x] Health check integration (`:checkhealth neotion`)
- [x] Statusline component (`M.statusline()`)

**UX Feedback Design:**
| Scenario | Channel | Behavior |
|----------|---------|----------|
| Queue > 5 requests | Statusline | `⏳5` |
| Pause >= 3s | Statusline | `⏸ 8s` countdown |
| Pause >= 10s | vim.notify WARN | "Rate limited. Resuming in 12s..." |
| Error (exhausted) | vim.notify ERROR | "Sync failed" |

**Statusline Usage (lualine):**
```lua
require('lualine').setup({
  sections = {
    lualine_x = {
      function()
        local ok, throttle = pcall(require, 'neotion.api.throttle')
        return ok and throttle.statusline() or ''
      end
    }
  }
})
```

**Config:**
```lua
throttle = {
  enabled = true,
  tokens_per_second = 3,
  burst_size = 10,
  max_retries = 3,
  queue_warning_threshold = 5,
  pause_notify_threshold = 10,
}
```

---

### Phase 7: SQLite Cache + Metadata Store
**Goal:** Offline metadata erişimi, hızlı sayfa listesi, sync state persistence

**Complexity:** L (Large)

**Rationale:** Phase 10'dan öne alındı. `[[` completion ve live search için gerekli.

**Scope:**
1. SQLite integration (sqlite.lua library)
   - Page metadata cache (id, title, icon, parent, last_edited)
   - Sync state (local hash, remote hash, last_sync_time)
2. Background refresh on startup
3. TTL-based invalidation
4. Content hash per block for dirty detection

**New Files:**
```
lua/neotion/cache/
├── init.lua                  # Cache orchestrator
├── schema.lua                # SQLite schema definitions
├── pages.lua                 # Page metadata operations
└── sync_state.lua            # Sync state persistence
```

**Schema:**
```sql
CREATE TABLE pages (
  id TEXT PRIMARY KEY,
  title TEXT,
  icon TEXT,
  parent_type TEXT,
  parent_id TEXT,
  last_edited_time INTEGER,
  last_synced_time INTEGER,
  sync_status TEXT DEFAULT 'pending',
  content_hash TEXT
);

CREATE TABLE sync_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  page_id TEXT,
  operation TEXT,
  payload TEXT,
  attempts INTEGER DEFAULT 0
);
```

**Dependencies:** Phase 6 (rate limiting for background refresh)

**Checklist:**
- [x] SQLite schema design (Phase 7.1)
- [x] Page metadata CRUD operations (Phase 7.2)
- [x] Page content caching with JSON serialization (Phase 7.2)
- [x] Cache-first loading in M.open() (Phase 7.2)
- [x] Health check for cache status (Phase 7.2)
- [x] Sync state persistence (Phase 7.3)
- [x] Background refresh with hash comparison (Phase 7.3)
- [x] `:Neotion cache` command (stats/clear/vacuum/path)
- [x] Unit tests for cache modules (22+ tests)

**Phase 7.1 (Complete):** SQLite infrastructure - db.lua, schema.lua, hash.lua
**Phase 7.2 (Complete):** Page content caching - pages.lua, cache-first loading
**Phase 7.3 (Complete):** Sync state + BG refresh - sync_state.lua, bg_refresh_page()

---

### Phase 8: Live Search + Search Cache
**Goal:** Real-time Telescope search with search-driven caching

**Complexity:** M (Medium)

**Rationale:** Hızlı sayfa arama ve cache'i organik olarak doldurma.

**Notion API Search Facts:**
- POST /search sadece `last_edited_time` sort destekliyor
- Relevance sort yok - sort belirtilmezse Notion kendi algoritmasını kullanıyor
- Notion'ın sıralamasını korumak önemli

**Architecture: Search-Driven Cache**
```
User types query
       ↓ (instant)
Show cached results (frecency sorted)
       ↓ (300ms debounce)
API search → Cache results → Update display
       ↓
User continues typing → Cancel previous → Repeat
```

**Phase 8.1: Search Cache Layer**
```
cache/pages.lua eklemeleri:
├── calculate_frecency(open_count, last_opened_at)
├── search_cached(query, limit) - lokal LIKE arama
├── save_pages_batch(pages) - toplu kayıt
├── maybe_evict() - >1000 → en düşük frecency sil
└── increment_open_count(page_id) - frecency güncelle

api/pages.lua eklemeleri:
└── search_with_id(query, callback) - request_id döner (cancel için)
```

**Frecency Algorithm (Mozilla Firefox tarzı - Notion'ın değil):**
```lua
-- Frecency = Frequency + Recency (Mozilla 2007)
-- NOT Notion's algorithm - sadece cached results için kullanılıyor
score = open_count * 10 + time_decay
time_decay = max(0, 1 - age_days/30) * 100
-- Yeni açılan: ~100 puan bonus (30 günde 0'a düşer)
-- Her açılış: +10 kalıcı puan
```

**Sıralama Stratejisi:**
| Durum | Sıralama | Kaynak |
|-------|----------|--------|
| Cache'den (instant) | Frecency score | Bizim algoritma |
| API döndükten sonra | Notion'ın sıralaması | Notion relevance |
| Merge | API first, cached extras | Notion öncelikli |

**Not:** Notion'ın tam ranking algoritması bilinmiyor (kapalı kaynak).
Best matches: recently edited + title > content + popularity labels.

**Eviction Strategy:**
- Cache limit: 1000 pages (configurable)
- Dolunca: En düşük frecency score olanlar silinir
- Açılmamış eski entry'ler silinmez (API 404 dönene kadar)

**Phase 8.2: Live Telescope Search**
```
ui/live_search.lua (NEW):
├── current_request_id tracking
├── debounce_timer (300ms, configurable)
├── cancel_previous() - throttle.cancel() kullan
├── search(query, on_results) - orchestrator
└── merge_results(api, cached) - API first, cached extras

ui/picker.lua modifications:
├── Telescope: dynamic refresh on results
└── vim.ui.select: simple search (no live, just API)
```

**Hybrid Display Strategy:**
| Zaman | Gösterilen | Kaynak |
|-------|------------|--------|
| 0ms | Cached results (frecency) | SQLite |
| 300ms | Loading indicator | - |
| ~500ms | API results + cached extras | Merged |

**New Files:**
```
lua/neotion/ui/
└── live_search.lua      # Debounce + cancel orchestrator
```

**Modify:**
- `lua/neotion/cache/pages.lua` - frecency, search_cached, eviction
- `lua/neotion/api/pages.lua` - search_with_id
- `lua/neotion/ui/picker.lua` - live search integration

**Config Additions:**
```lua
cache = {
  max_pages = 1000,      -- Eviction threshold
},
search = {
  debounce_ms = 300,     -- Live search debounce
  show_cached = true,    -- Show cached results instantly
},
```

**Dependencies:** Phase 6 (rate limiting + cancel), Phase 7 (SQLite cache)

**Checklist:**
- [ ] Phase 8.1a: `search_with_id()` in pages.lua
- [ ] Phase 8.1b: Frecency calculation + `search_cached()` in cache/pages.lua
- [ ] Phase 8.1c: Eviction logic (`maybe_evict()`)
- [ ] Phase 8.1d: `save_pages_batch()` + `increment_open_count()`
- [ ] Phase 8.2a: `live_search.lua` - debounce + cancel
- [ ] Phase 8.2b: Telescope integration with hybrid display
- [ ] Phase 8.2c: vim.ui.select fallback (simple, no live)
- [ ] Unit tests for all modules

**NOT in Phase 8 (Deferred):**
- `[[` link completion → Phase 8.3
- `/` slash commands → Phase 9 (higher priority than `[[`)

---

### Phase 9: Slash Commands + Advanced Blocks
**Goal:** Block creation via `/`, daha fazla block tipi

**Complexity:** L (Large)

**Prerequisite:** `input/triggers.lua` altyapısı Phase 5.5'te hazırlandı

**Scope:**
1. **Slash command menu**
   - `/` at line start opens block picker
   - Fuzzy search: `/h1`, `/todo`, `/code`
   - Seçilen block tipini cursor pozisyonuna ekle

2. **New block types (8):**
   - `bulleted_list_item` - Bullet points
   - `numbered_list_item` - Numbered lists
   - `to_do` - Checkboxes `[ ]` / `[x]`
   - `quote` - Block quotes
   - `code` - Code blocks with language
   - `divider` - Horizontal rule
   - `toggle` - Collapsible sections (fold support)
   - `callout` - Callout boxes with icons

**New Files:**
```
lua/neotion/input/completions/slash_menu.lua
lua/neotion/model/blocks/
├── bulleted_list.lua
├── numbered_list.lua
├── todo.lua
├── quote.lua
├── code.lua
├── divider.lua
├── toggle.lua
└── callout.lua
```

**Dependencies:** Phase 8 (completion infrastructure)

**Checklist:**
- [ ] `/` trigger activation
- [ ] Slash menu picker with fuzzy search
- [ ] 8 new block type implementations
- [ ] Block type conversion commands
- [ ] Treesitter folding for toggle blocks
- [ ] Unit tests for each block type

---

### Phase 10: Full Lossless + Polish
**Goal:** Zero data loss garantisi, production-ready

**Complexity:** L (Large)

**Scope:**
1. **Full round-trip fidelity**
   - Tüm metadata preserved
   - Unknown block types: read-only with raw JSON fallback

2. **Conflict resolution**
   - Detect remote changes before push
   - 3-way merge UI
   - Manual conflict resolution picker

3. **Offline mode**
   - Queue changes when offline
   - Sync on reconnection
   - Visual indicator for offline state

4. **@ mentions**
   - `@user` mentions (display only)
   - `@date` mentions
   - `@page` mentions (alias for `[[`)

5. **Text objects + motions**
   - `ib` / `ab` - inner/around block
   - `]b` / `[b` - next/previous block

6. **Documentation**
   - Complete vimdoc
   - README examples

**New Files:**
```
lua/neotion/conflict/
├── init.lua                  # Conflict detection
├── merge.lua                 # 3-way merge
└── ui.lua                    # Resolution picker

lua/neotion/offline/
└── queue.lua                 # Offline change queue

lua/neotion/input/completions/
└── mentions.lua              # @ handler

lua/neotion/textobjects/
└── init.lua                  # Block text objects
```

**Checklist:**
- [ ] Full metadata round-trip
- [ ] Conflict detection and resolution
- [ ] Offline queue and reconnection sync
- [ ] @ mentions support
- [ ] Block text objects and motions
- [ ] Complete documentation

---

## API Design

### Public API (`lua/neotion/init.lua`)

```lua
-- Configuration (opsiyonel)
M.setup(opts)
M.get_config()

-- Pages
M.open(page_id)
M.create(title)
M.delete()
M.search()

-- Sync
M.sync()
M.push()
M.pull()

-- Navigation
M.goto_parent()
M.goto_link()

-- Blocks
M.block_move(direction)
M.block_indent()
M.block_dedent()
```

### Commands

```vim
:Neotion open <page_id>     " Phase 2
:Neotion create [title]     " Phase 3
:Neotion search             " Phase 5
:Neotion sync               " Phase 6
:Neotion push               " Phase 6
:Neotion pull               " Phase 6
:Neotion status             " Phase 1 ✅
```

### Keymaps (`<Plug>` mappings)

```lua
<Plug>(NeotionSync)
<Plug>(NeotionPush)
<Plug>(NeotionPull)
<Plug>(NeotionGotoParent)
<Plug>(NeotionGotoLink)
<Plug>(NeotionSearch)
<Plug>(NeotionBlockUp)
<Plug>(NeotionBlockDown)
<Plug>(NeotionBlockIndent)
<Plug>(NeotionBlockDedent)
```

## Buffer Format (Phase 6+)

```
§ page:83715d7703ee4b8699b5e659a4712dd8
§ parent:workspace
§ last_sync:2024-01-01T12:00:00Z

╔ heading_1:abc123
# Başlık
╚

╔ paragraph:def456 color=green
Bu bir ‹u›altı çizili‹/u› ve ‹c:red›kırmızı‹/c› metin.
╚

╔ toggle:jkl012
▶ Toggle başlığı
  ╔ paragraph:mno345
  Toggle içeriği
  ╚
╚
```

## Config Schema

```lua
---@class neotion.Config
---@field api_token? string
---@field sync_interval? integer (default: 2000)
---@field auto_sync? boolean (default: true)
---@field conceal_level? integer (default: 2)
---@field icons? neotion.Icons
---@field keymaps? neotion.Keymaps
---@field log_level? string

---@type neotion.Config|fun():neotion.Config|nil
vim.g.neotion = vim.g.neotion
```

## Best Practices Checklist

- [x] **Type Safety:** LuaCATS annotations
- [x] **Commands:** Subcommand pattern
- [x] **Keymaps:** `<Plug>` mappings
- [x] **Initialization:** `setup()` opsiyonel
- [x] **Lazy Loading:** `require()` fonksiyon içinde
- [x] **Configuration:** User vs internal config ayrımı
- [x] **Health:** `:checkhealth` desteği
- [x] **Documentation:** Vimdoc
- [x] **Testing:** 800+ test geçiyor
- [x] **Compatibility:** Lua 5.1 API

## Sonraki Adım: Phase 8.1

Phase 7 (SQLite Cache + Sync State) tamamlandı. Şimdi:
- **Phase 8.1:** Search cache layer - frecency, eviction, search_cached
- **Phase 8.2:** Live Telescope search - debounce, cancel, hybrid display

**Phase 8 Yaklaşımı: Search-Driven Cache**
- Arama yapıldıkça cache dolacak (önceden fetch yok)
- Frecency: `score = open_count * 10 + time_decay(30 gün)`
- Cache limit: 1000 pages, eviction by lowest frecency
- Hybrid display: cached first (instant) → API results (merged)

**Known Limitations:**
- Block links (`notion://block/id`) are not supported yet
- Nested list items (indentation) deferred to Phase 5.10
- Auto-continuation (Enter after list item adds prefix) deferred to Phase 5.9

## Roadmap Summary

| Phase | Goal | Complexity | Status |
|-------|------|------------|--------|
| 1-5.6 | Foundation + Formatting + Navigation | - | ✅ COMPLETE |
| 5.7 | Basic Blocks (divider, quote, bullet, code) | S-M | ✅ COMPLETE |
| 5.8 | Block Type Conversion (paragraph ↔ list/quote) | M | ✅ COMPLETE |
| 5.9 | Auto-continuation (list item Enter) | S | TODO |
| 5.10 | Nested blocks (indentation) | M | TODO |
| 6 | Rate Limiting | M | ✅ COMPLETE |
| 7.1-7.3 | SQLite Cache + Sync State | L | ✅ COMPLETE |
| 8.1 | Search Cache Layer (frecency, eviction) | M | 🔜 NEXT |
| 8.2 | Live Telescope Search | M | TODO |
| 8.3 | `[[` Link Completion | S | TODO |
| 9 | `/` Slash Commands | L | TODO |
| 10 | Full Lossless + Polish | L | TODO |

**Dependency Graph:**
```
7.3 → 8.1 → 8.2 → 8.3
              ↓
              9 (/ slash commands, higher priority than [[)
```

**Removed from Scope:** Daily notes, templates, database views (focused editor first)

---

## Commit Kuralları

- never add claude code bot messages to commit messages
- her commit oncesi code-reviewer agent'tan staged kodlar icin fikir al onun donusune gore commit at

---

## Architectural Learnings & Known Issues

### Extmark-Based Block Tracking (mapping.lua)

**Problem:** Neovim extmark'ları satır silindiğinde beklenmedik davranışlar sergiliyor.

**Kök Nedenler:**
1. **Extmark Collapse:** Bir satır silindiğinde, o satırdaki ve altındaki extmark'lar aynı satıra "collapse" oluyor
2. **Zero-width Extmarks:** Silinen satırın extmark'ı `start_row == end_row && start_col == end_col` durumuna düşüyor
3. **Overlapping Extmarks:** İki farklı block'un extmark'ları aynı satırı gösterebiliyor

**Çözüm Yaklaşımı (Three-Pass Algorithm):**
```lua
-- Pass 1: Collect extmark info for all blocks
-- Pass 2: Detect deleted blocks using multiple heuristics:
--   - Zero-width at content block position → deleted
--   - Zero-width with mismatched content → deleted (divider: line != '---')
--   - Empty line but originally had content → deleted
--   - Position beyond buffer bounds → deleted
-- Pass 3: Assign line ranges
```

**Özel Durumlar:**
- **Empty Paragraphs:** `original_text == ''` olan paragraph'lar zero-width olsa bile silinmiş sayılmamalı
- **Divider Blocks:** `get_text()` boş döner ama expected content `---` - özel kontrol gerekli
- **Block Type Specific Detection:** Her block tipi için content matching kuralları farklı olabilir

**Test Edilmesi Gereken Senaryolar:**
1. Divider satırını `dd` ile silme
2. Boş paragraph satırını silme
3. Birden fazla ardışık satır silme
4. Multiline block'ların bir kısmını silme

### vim.ui.select ve BufWriteCmd Context

**Problem:** `vim.ui.select` BufWriteCmd callback'i içinden çağrıldığında dialog donuyor.

**Kök Neden:** BufWriteCmd callback'i Neovim'in normal UI event loop'u dışında çalışıyor.

**Çözüm:**
```lua
-- YANLIŞ - Dialog donuyor
vim.api.nvim_create_autocmd('BufWriteCmd', {
  callback = function()
    vim.ui.select({ 'Yes', 'No' }, { prompt = 'Save?' }, function(choice)
      -- ...
    end)
  end
})

-- DOĞRU - vim.schedule ile sarmala
vim.api.nvim_create_autocmd('BufWriteCmd', {
  callback = function()
    vim.schedule(function()
      vim.ui.select({ 'Yes', 'No' }, { prompt = 'Save?' }, function(choice)
        -- ...
      end)
    end)
  end
})
```

**Kural:** Herhangi bir UI fonksiyonu (vim.ui.select, vim.ui.input, etc.) autocmd callback'lerinden çağrılırken `vim.schedule` kullanılmalı.

### Sync Confirmation Flow

**Neden Silme İşlemi Confirmation Gerektiriyor:**
1. Notion API'de silme işlemi geri alınamaz
2. Yanlışlıkla silinen block'lar kalıcı olarak kaybolur
3. Zero data loss prensibi gereği kullanıcı onayı kritik

**Config Seçenekleri:**
```lua
confirm_sync = 'on_ambiguity'  -- Default: Sadece silme/belirsizlik durumunda sor
confirm_sync = 'always'        -- Her sync'te sor
confirm_sync = 'never'         -- Hiç sorma (tehlikeli!)
```

### Debug Logging Best Practices

Block tracking sorunlarını debug ederken kullanışlı log noktaları:
- `refresh_line_ranges starting` - Kaç block ve extmark var
- `Block marked as deleted` - Hangi block'lar neden silindi
- `Block line range updated from extmark` - Güncel pozisyonlar
- `sync.plan` - Sync planı detayları

Log seviyesini DEBUG yapmak için:
```vim
:Neotion log level DEBUG
```

### Future Considerations

**Block Deletion Robustness:**
- [ ] Daha fazla block tipi için content matching kuralları ekle (toggle, callout, etc.)
- [ ] Undo/redo sonrası extmark tracking'i test et
- [ ] Visual mode ile çoklu satır silme senaryolarını test et

**Performance:**
- [ ] Büyük sayfalarda (100+ block) refresh_line_ranges performansını ölç
- [ ] Debounce TextChanged handler'ını optimize et

### Block Type Conversion (Phase 5.8 - ✅ COMPLETE)

**Implemented:** Bidirectional block type conversion based on content prefix.

**Desteklenen Dönüşümler:**
- `paragraph` → `bulleted_list_item` (prefix: `- `, `* `, `+`)
- `paragraph` → `quote` (prefix: `| `)
- `bulleted_list_item` → `paragraph` (prefix kaldırıldığında)
- `bulleted_list_item` → `quote` (prefix: `| `)
- `quote` → `paragraph` (prefix kaldırıldığında)
- `quote` → `bulleted_list_item` (prefix: `- `)

**Yeni Dosyalar:**
- `lua/neotion/model/blocks/detection.lua` - Prefix pattern detection
- `spec/unit/model/blocks/detection_spec.lua` - 42 test

**Güncellenmiş Dosyalar:**
- `paragraph.lua` - `target_type`, `type_changed()`, `get_type()`, `get_converted_content()`
- `bulleted_list.lua` - Aynı pattern
- `quote.lua` - Aynı pattern + backwards compat (`>` prefix existing quotes için kabul edilir)
- `sync/plan.lua` - `get_converted_content()` kullanımı

**Kararlar:**
- `>` prefix quote için trigger ETMİYOR (Phase 9 toggle için reserved)
- Sadece `| ` prefix quote trigger ediyor
- Multi-line paragraph conversion Phase 5.9/5.10'a ertelendi
- On-save conversion (real-time değil)