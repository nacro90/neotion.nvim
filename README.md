# neotion.nvim

Notion integration for Neovim with **zero data loss** synchronization.

> [!WARNING]
> This plugin is in early development. Not ready for production use.

## Features (Planned)

- Full round-trip sync preserving all Notion metadata
- Block-level editing with concealed markers
- Real-time sync with conflict resolution
- Telescope/fzf-lua integration for page search
- nvim-cmp completion for `/`, `@`, and `[[` triggers

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

  -- Log level: 'trace', 'debug', 'info', 'warn', 'error'
  log_level = 'info',
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

## Keymaps

The plugin provides `<Plug>` mappings. Add your preferred keymaps:

```lua
vim.keymap.set('n', '<leader>ns', '<Plug>(NeotionSync)')
vim.keymap.set('n', '<leader>np', '<Plug>(NeotionPush)')
vim.keymap.set('n', '<leader>nl', '<Plug>(NeotionPull)')
vim.keymap.set('n', '<leader>nf', '<Plug>(NeotionSearch)')
```

Available `<Plug>` mappings:
- `<Plug>(NeotionSync)` - Sync current buffer
- `<Plug>(NeotionPush)` - Force push to Notion
- `<Plug>(NeotionPull)` - Force pull from Notion
- `<Plug>(NeotionGotoParent)` - Navigate to parent page
- `<Plug>(NeotionGotoLink)` - Follow link under cursor
- `<Plug>(NeotionSearch)` - Search pages
- `<Plug>(NeotionBlockUp)` - Move block up
- `<Plug>(NeotionBlockDown)` - Move block down
- `<Plug>(NeotionBlockIndent)` - Indent block
- `<Plug>(NeotionBlockDedent)` - Dedent block

## Health Check

Run `:checkhealth neotion` to verify your setup.

## License

MIT
