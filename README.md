# neotion.nvim

Notion integration for Neovim with **zero data loss** synchronization.

> [!WARNING]
> This plugin is in early development. Not ready for production use.

## Features

### Implemented
- **Zero data loss** - Unsupported block types are read-only
- **Block-level editing** - Edit paragraphs and headings directly
- **Inline formatting** - Use markers like `**bold**`, `*italic*`, `[link](url)`
- **Rich text display** - Anti-conceal rendering with extmarks
- **Rich text preservation** - Unchanged text keeps formatting
- **Extmark tracking** - Accurate block-to-line mapping through edits
- **Sync with confirmation** - Optional confirmation on ambiguous changes
- **Telescope integration** - Page search with Telescope (falls back to vim.ui.select)
- **Recent pages** - Quick access to recently opened pages

### Supported Block Types
| Type | Status |
|------|--------|
| Paragraph | Full editing |
| Heading 1/2/3 | Full editing |
| Toggle, Code, Quote, etc. | Read-only (preserved) |

### Inline Formatting Syntax
| Syntax | Result |
|--------|--------|
| `**text**` | **bold** |
| `*text*` | *italic* |
| `~text~` | ~~strikethrough~~ |
| `` `text` `` | `code` |
| `<u>text</u>` | underline |
| `<c:red>text</c>` | colored text |
| `[text](url)` | link |

### Roadmap

| Phase | Goal | Status |
|-------|------|--------|
| 1-5.5 | Foundation + Inline Formatting | ✅ Complete |
| 5.6 | Real-time rendering + `gf` navigation | 🔜 Next |
| 5.7 | Basic blocks (divider, quote, bullet, code) | Planned |
| 6 | Rate limiting (API protection) | Planned |
| 7 | SQLite cache (offline metadata) | Planned |
| 8 | Live search + `[[` completion | Planned |
| 9 | Slash commands + advanced blocks | Planned |
| 10 | Full lossless + conflict resolution | Planned |

### Coming Soon (Phase 5.6-5.7)
- **Real-time formatting** - Markers render as you type
- **Link navigation** - `gf` follows links under cursor
- **Default keymaps** - Optional `<C-b>` for bold, etc.
- **More block types** - Divider, quote, bullet list, code blocks

### Future Plans
- `[[` wiki-link completion for page linking
- `/` slash commands for block creation
- Advanced blocks: todos, toggles, callouts, numbered lists
- SQLite cache for offline metadata access
- Conflict resolution UI

## Requirements

- Neovim 0.10+
- Notion API token ([get one here](https://www.notion.so/my-integrations))
- curl

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'nacro90/neotion.nvim',
  -- No setup() call required! But you can use it to override defaults:
  opts = {
    api_token = vim.env.NOTION_API_TOKEN,
  },
}
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'nacro90/neotion.nvim',
  config = function()
    -- Optional: only call setup() if you need to override defaults
    require('neotion').setup({
      api_token = vim.env.NOTION_API_TOKEN,
    })
  end,
}
```

## Configuration

Configuration can be provided in multiple ways:

### 1. Via `vim.g.neotion` (before plugin loads)

```lua
vim.g.neotion = {
  api_token = vim.env.NOTION_API_TOKEN,
  sync_interval = 3000,
}
```

### 2. Via `setup()` (optional, only overrides defaults)

```lua
require('neotion').setup({
  api_token = vim.env.NOTION_API_TOKEN,
})
```

### 3. Via environment variable

```bash
export NOTION_API_TOKEN=secret_xxx
```

### All Options

```lua
{
  -- Notion API integration token (required for sync)
  api_token = nil,

  -- Debounce interval for auto-sync in milliseconds
  sync_interval = 2000,

  -- Enable automatic sync on buffer changes
  auto_sync = true,

  -- Conceal level for block markers (0-3)
  conceal_level = 2,

  -- Icons used in the UI
  icons = {
    synced = '✓',
    pending = '○',
    error = '✗',
    toggle_open = '▼',
    toggle_closed = '▶',
  },

  -- Keymap configuration (set to false to disable)
  keymaps = {
    sync = '<leader>ns',
    push = '<leader>np',
    pull = '<leader>nl',
    goto_parent = '<leader>nu',
    goto_link = '<leader>ng',
    search = '<leader>nf',
  },

  -- Log level: 'debug', 'info', 'warn', 'error', 'off'
  log_level = 'info',

  -- Newline behavior in edit mode:
  -- 'markdown' - Double enter creates new block (default, natural for markdown users)
  -- 'notion' - Single enter creates new block (like Notion app)
  editing_mode = 'markdown',

  -- When to ask for sync confirmation:
  -- 'always' - Always confirm before syncing
  -- 'on_ambiguity' - Only when there are unmatched changes or deletions (default)
  -- 'never' - Never ask for confirmation
  confirm_sync = 'on_ambiguity',
}
```

## Commands

| Command | Description |
|---------|-------------|
| `:Neotion open <page_id>` | Open a Notion page |
| `:Neotion sync` | Sync current buffer |
| `:Neotion push` | Force push local changes |
| `:Neotion pull` | Force pull remote changes |
| `:Neotion search` | Search Notion pages |
| `:Neotion status` | Show sync status |
| `:Neotion bold` | Toggle bold on word/selection |
| `:Neotion italic` | Toggle italic on word/selection |
| `:Neotion code` | Toggle code on word/selection |
| `:Neotion color <color>` | Apply color (red, blue, green, etc.) |
| `:Neotion unformat` | Remove all formatting from word/selection |

## Keymaps

The plugin provides `<Plug>` mappings. Add your preferred keymaps:

```lua
vim.keymap.set('n', '<leader>ns', '<Plug>(NeotionSync)')
vim.keymap.set('n', '<leader>np', '<Plug>(NeotionPush)')
vim.keymap.set('n', '<leader>nl', '<Plug>(NeotionPull)')
vim.keymap.set('n', '<leader>nf', '<Plug>(NeotionSearch)')
```

Available `<Plug>` mappings:

**Sync:**
- `<Plug>(NeotionSync)` - Sync current buffer
- `<Plug>(NeotionPush)` - Force push to Notion
- `<Plug>(NeotionPull)` - Force pull from Notion

**Navigation:**
- `<Plug>(NeotionGotoParent)` - Navigate to parent page
- `<Plug>(NeotionGotoLink)` - Follow link under cursor
- `<Plug>(NeotionSearch)` - Search pages

**Blocks:**
- `<Plug>(NeotionBlockUp)` - Move block up
- `<Plug>(NeotionBlockDown)` - Move block down
- `<Plug>(NeotionBlockIndent)` - Indent block
- `<Plug>(NeotionBlockDedent)` - Dedent block

**Formatting (operator-pending, use with motion like `iw`):**
- `<Plug>(NeotionBold)` - Bold
- `<Plug>(NeotionItalic)` - Italic
- `<Plug>(NeotionStrikethrough)` - Strikethrough
- `<Plug>(NeotionCode)` - Code
- `<Plug>(NeotionUnderline)` - Underline
- `<Plug>(NeotionColor)` - Color (opens color picker)

**Formatting (visual mode, same mappings work in visual):**
- `<Plug>(NeotionBold)` - Bold selection
- `<Plug>(NeotionItalic)` - Italic selection
- ... (similar for other formats)

**Formatting (toggle word under cursor):**
- `<Plug>(NeotionBoldToggle)` - Toggle bold on word
- `<Plug>(NeotionItalicToggle)` - Toggle italic on word
- ... (similar for other formats)

## Health Check

Run `:checkhealth neotion` to verify your setup.

## License

MIT
