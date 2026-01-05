---@brief [[
---Configuration module for neotion.nvim
---
---Configuration can be provided in two ways:
---1. Via vim.g.neotion table (before plugin loads)
---2. Via require('neotion').setup(opts) (optional, only overrides defaults)
---@brief ]]

-- User-facing config type (all fields optional)
---@alias neotion.EditingMode 'markdown'|'notion'
---@alias neotion.ConfirmSync 'always'|'on_ambiguity'|'never'

---@class neotion.Config
---@field api_token? string Notion API integration token
---@field sync_interval? integer Debounce interval for auto-sync in milliseconds (default: 2000)
---@field auto_sync? boolean Enable automatic sync on buffer changes (default: true)
---@field conceal_level? integer Conceal level for block markers (0-3, default: 2)
---@field icons? neotion.Icons Icons used in the UI
---@field keymaps? neotion.Keymaps Keymap configuration (set to false to disable)
---@field log_level? string Log level: "trace", "debug", "info", "warn", "error" (default: "info")
---@field editing_mode? neotion.EditingMode Newline behavior: 'markdown' (double enter = new block) or 'notion' (enter = new block) (default: 'markdown')
---@field confirm_sync? neotion.ConfirmSync When to ask for sync confirmation: 'always', 'on_ambiguity', 'never' (default: 'on_ambiguity')
---@field input? neotion.InputConfig Input system configuration (shortcuts and triggers)
---@field render? neotion.RenderUserConfig Render system configuration
---@field throttle? neotion.ThrottleUserConfig Rate limiting configuration
---@field search? neotion.SearchConfig Search and picker configuration

---@class neotion.RenderUserConfig
---@field enabled? boolean Enable rendering (default: true)
---@field debounce_ms? integer Debounce delay for re-rendering in ms (default: 100)

---@class neotion.ThrottleUserConfig
---@field enabled? boolean Enable rate limiting (default: true)
---@field tokens_per_second? number Token refill rate (default: 3)
---@field burst_size? number Maximum burst tokens (default: 10)
---@field max_retries? number Maximum retry attempts for 5xx errors (default: 3)
---@field queue_warning_threshold? number Queue size to show in statusline (default: 5)

---@class neotion.Icons
---@field synced? string Icon for synced blocks (default: "✓")
---@field pending? string Icon for pending sync (default: "○")
---@field error? string Icon for sync errors (default: "✗")
---@field toggle_open? string Icon for open toggles (default: "▼")
---@field toggle_closed? string Icon for closed toggles (default: "▶")

---@class neotion.Keymaps
---@field sync? string|false Keymap for sync (default: "<leader>ns", false to disable)
---@field push? string|false Keymap for force push (default: "<leader>np")
---@field pull? string|false Keymap for force pull (default: "<leader>nl")
---@field goto_parent? string|false Keymap for navigating to parent (default: "<leader>nu")
---@field goto_link? string|false Keymap for following link under cursor (default: "<leader>ng")
---@field search? string|false Keymap for search (default: "<leader>nf")

---@class neotion.InputConfig
---@field shortcuts? neotion.ShortcutsConfig Keyboard shortcuts configuration
---@field triggers? neotion.TriggersConfig Trigger characters configuration (future / and @)

---@class neotion.ShortcutsConfig
---@field enabled? boolean Enable all shortcuts (default: true)
---@field default_keymaps? boolean Enable default keymaps like <C-b>, <C-i> (default: false)
---@field bold? boolean Enable bold shortcut (default: true)
---@field italic? boolean Enable italic shortcut (default: true)
---@field strikethrough? boolean Enable strikethrough shortcut (default: true)
---@field code? boolean Enable code shortcut (default: true)
---@field underline? boolean Enable underline shortcut (default: true)
---@field color? boolean Enable color shortcut (default: true)

---@class neotion.TriggersConfig
---@field enabled? boolean Enable trigger characters (default: false, future / and @ support)

---@class neotion.SearchConfig
---@field debounce_ms? integer Debounce delay for live search in ms (default: 300)
---@field show_cached? boolean Show cached results instantly before API response (default: true)
---@field live_search? boolean Enable live search in Telescope (default: true)
---@field limit? integer Maximum number of results to show (default: 50)
---@field query_cache_size? integer Maximum number of query cache entries (default: 500)

-- Allow vim.g.neotion to be set before plugin loads
---@type neotion.Config|fun():neotion.Config|nil
vim.g.neotion = vim.g.neotion

-- Internal config type (all fields required after merge)
---@class neotion.InternalConfig
---@field api_token string?
---@field sync_interval integer
---@field auto_sync boolean
---@field conceal_level integer
---@field icons neotion.InternalIcons
---@field keymaps neotion.InternalKeymaps
---@field log_level string
---@field editing_mode neotion.EditingMode
---@field confirm_sync neotion.ConfirmSync
---@field input neotion.InternalInputConfig
---@field render neotion.InternalRenderConfig
---@field throttle neotion.InternalThrottleConfig
---@field search neotion.InternalSearchConfig

---@class neotion.InternalRenderConfig
---@field enabled boolean
---@field debounce_ms integer

---@class neotion.InternalThrottleConfig
---@field enabled boolean
---@field tokens_per_second number
---@field burst_size number
---@field max_retries number
---@field queue_warning_threshold number

---@class neotion.InternalIcons
---@field synced string
---@field pending string
---@field error string
---@field toggle_open string
---@field toggle_closed string

---@class neotion.InternalKeymaps
---@field sync string|false
---@field push string|false
---@field pull string|false
---@field goto_parent string|false
---@field goto_link string|false
---@field search string|false

---@class neotion.InternalInputConfig
---@field shortcuts neotion.InternalShortcutsConfig
---@field triggers neotion.InternalTriggersConfig

---@class neotion.InternalShortcutsConfig
---@field enabled boolean
---@field default_keymaps boolean
---@field bold boolean
---@field italic boolean
---@field strikethrough boolean
---@field code boolean
---@field underline boolean
---@field color boolean

---@class neotion.InternalTriggersConfig
---@field enabled boolean

---@class neotion.InternalSearchConfig
---@field debounce_ms integer
---@field show_cached boolean
---@field live_search boolean
---@field limit integer
---@field query_cache_size integer

local M = {}

---@type neotion.InternalConfig
local default_config = {
  api_token = nil,
  sync_interval = 2000,
  auto_sync = true,
  conceal_level = 2,
  icons = {
    synced = '✓',
    pending = '○',
    error = '✗',
    toggle_open = '▼',
    toggle_closed = '▶',
  },
  keymaps = {
    sync = '<leader>ns',
    push = '<leader>np',
    pull = '<leader>nl',
    goto_parent = '<leader>nu',
    goto_link = '<leader>ng',
    search = '<leader>nf',
  },
  log_level = 'info',
  editing_mode = 'markdown', -- 'markdown' (double enter = new block) or 'notion' (enter = new block)
  confirm_sync = 'on_ambiguity', -- 'always', 'on_ambiguity', 'never'
  input = {
    shortcuts = {
      enabled = true,
      default_keymaps = false, -- Enable default keymaps (<C-b>, <C-i>, etc.)
      bold = true,
      italic = true,
      strikethrough = true,
      code = true,
      underline = true,
      color = true,
    },
    triggers = {
      enabled = false, -- Phase 8+: enable for / and @ support
    },
  },
  render = {
    enabled = true,
    debounce_ms = 100, -- Debounce delay for re-rendering (0 = no debounce)
  },
  throttle = {
    enabled = true,
    tokens_per_second = 3, -- Notion API rate limit
    burst_size = 10, -- Allow burst of requests
    max_retries = 3, -- Retry on 5xx errors
    queue_warning_threshold = 5, -- Show in statusline when queue > this
  },
  search = {
    debounce_ms = 300, -- Debounce delay for live search
    show_cached = true, -- Show cached results instantly
    live_search = true, -- Enable live search in Telescope
    limit = 100, -- Maximum results to show (Notion API returns max 100)
    query_cache_size = 500, -- Maximum query cache entries
  },
}

---@type neotion.InternalConfig
local config = vim.deepcopy(default_config)

---@type boolean
local initialized = false

---Validate a configuration table
---@param opts table Configuration options to validate
---@return boolean ok Whether the configuration is valid
---@return string? error Error message if validation failed
local function validate(opts)
  local ok, err = pcall(vim.validate, {
    api_token = { opts.api_token, { 'string', 'nil' }, 'string or nil' },
    sync_interval = {
      opts.sync_interval,
      function(v)
        return v == nil or (type(v) == 'number' and v >= 100 and v <= 60000)
      end,
      'number between 100 and 60000',
    },
    auto_sync = { opts.auto_sync, { 'boolean', 'nil' }, 'boolean or nil' },
    conceal_level = {
      opts.conceal_level,
      function(v)
        return v == nil or (type(v) == 'number' and v >= 0 and v <= 3)
      end,
      'number between 0 and 3',
    },
    icons = { opts.icons, { 'table', 'nil' }, 'table or nil' },
    keymaps = { opts.keymaps, { 'table', 'nil' }, 'table or nil' },
    log_level = {
      opts.log_level,
      function(v)
        if v == nil then
          return true
        end
        local valid_levels = { debug = true, info = true, warn = true, error = true, off = true }
        return valid_levels[v:lower()] ~= nil
      end,
      'one of: debug, info, warn, error, off',
    },
    editing_mode = {
      opts.editing_mode,
      function(v)
        if v == nil then
          return true
        end
        return v == 'markdown' or v == 'notion'
      end,
      'one of: markdown, notion',
    },
    confirm_sync = {
      opts.confirm_sync,
      function(v)
        if v == nil then
          return true
        end
        return v == 'always' or v == 'on_ambiguity' or v == 'never'
      end,
      'one of: always, on_ambiguity, never',
    },
  })

  if not ok then
    return false, err
  end

  -- Validate nested icons table if provided
  if opts.icons then
    local icons_ok, icons_err = pcall(vim.validate, {
      ['icons.synced'] = { opts.icons.synced, { 'string', 'nil' }, 'string or nil' },
      ['icons.pending'] = { opts.icons.pending, { 'string', 'nil' }, 'string or nil' },
      ['icons.error'] = { opts.icons.error, { 'string', 'nil' }, 'string or nil' },
      ['icons.toggle_open'] = { opts.icons.toggle_open, { 'string', 'nil' }, 'string or nil' },
      ['icons.toggle_closed'] = { opts.icons.toggle_closed, { 'string', 'nil' }, 'string or nil' },
    })
    if not icons_ok then
      return false, icons_err
    end
  end

  -- Validate nested keymaps table if provided
  if opts.keymaps then
    local keymaps_ok, keymaps_err = pcall(vim.validate, {
      ['keymaps.sync'] = { opts.keymaps.sync, { 'string', 'nil', 'boolean' }, 'string, nil, or false' },
      ['keymaps.push'] = { opts.keymaps.push, { 'string', 'nil', 'boolean' }, 'string, nil, or false' },
      ['keymaps.pull'] = { opts.keymaps.pull, { 'string', 'nil', 'boolean' }, 'string, nil, or false' },
      ['keymaps.goto_parent'] = { opts.keymaps.goto_parent, { 'string', 'nil', 'boolean' }, 'string, nil, or false' },
      ['keymaps.goto_link'] = { opts.keymaps.goto_link, { 'string', 'nil', 'boolean' }, 'string, nil, or false' },
      ['keymaps.search'] = { opts.keymaps.search, { 'string', 'nil', 'boolean' }, 'string, nil, or false' },
    })
    if not keymaps_ok then
      return false, keymaps_err
    end
  end

  -- Validate nested input table if provided
  if opts.input then
    local input_ok, input_err = pcall(vim.validate, {
      ['input.shortcuts'] = { opts.input.shortcuts, { 'table', 'nil' }, 'table or nil' },
      ['input.triggers'] = { opts.input.triggers, { 'table', 'nil' }, 'table or nil' },
    })
    if not input_ok then
      return false, input_err
    end

    -- Validate shortcuts if provided
    if opts.input.shortcuts then
      local shortcuts_ok, shortcuts_err = pcall(vim.validate, {
        ['input.shortcuts.enabled'] = { opts.input.shortcuts.enabled, { 'boolean', 'nil' }, 'boolean or nil' },
        ['input.shortcuts.bold'] = { opts.input.shortcuts.bold, { 'boolean', 'nil' }, 'boolean or nil' },
        ['input.shortcuts.italic'] = { opts.input.shortcuts.italic, { 'boolean', 'nil' }, 'boolean or nil' },
        ['input.shortcuts.strikethrough'] = {
          opts.input.shortcuts.strikethrough,
          { 'boolean', 'nil' },
          'boolean or nil',
        },
        ['input.shortcuts.code'] = { opts.input.shortcuts.code, { 'boolean', 'nil' }, 'boolean or nil' },
        ['input.shortcuts.underline'] = { opts.input.shortcuts.underline, { 'boolean', 'nil' }, 'boolean or nil' },
        ['input.shortcuts.color'] = { opts.input.shortcuts.color, { 'boolean', 'nil' }, 'boolean or nil' },
      })
      if not shortcuts_ok then
        return false, shortcuts_err
      end
    end

    -- Validate triggers if provided
    if opts.input.triggers then
      local triggers_ok, triggers_err = pcall(vim.validate, {
        ['input.triggers.enabled'] = { opts.input.triggers.enabled, { 'boolean', 'nil' }, 'boolean or nil' },
      })
      if not triggers_ok then
        return false, triggers_err
      end
    end
  end

  -- Validate nested render table if provided
  if opts.render then
    local render_ok, render_err = pcall(vim.validate, {
      ['render.enabled'] = { opts.render.enabled, { 'boolean', 'nil' }, 'boolean or nil' },
      ['render.debounce_ms'] = {
        opts.render.debounce_ms,
        function(v)
          return v == nil or (type(v) == 'number' and v >= 0 and v <= 1000)
        end,
        'number between 0 and 1000',
      },
    })
    if not render_ok then
      return false, render_err
    end
  end

  -- Validate nested throttle table if provided
  if opts.throttle then
    local throttle_ok, throttle_err = pcall(vim.validate, {
      ['throttle.enabled'] = { opts.throttle.enabled, { 'boolean', 'nil' }, 'boolean or nil' },
      ['throttle.tokens_per_second'] = {
        opts.throttle.tokens_per_second,
        function(v)
          return v == nil or (type(v) == 'number' and v >= 1 and v <= 10)
        end,
        'number between 1 and 10',
      },
      ['throttle.burst_size'] = {
        opts.throttle.burst_size,
        function(v)
          return v == nil or (type(v) == 'number' and v >= 1 and v <= 100)
        end,
        'number between 1 and 100',
      },
      ['throttle.max_retries'] = {
        opts.throttle.max_retries,
        function(v)
          return v == nil or (type(v) == 'number' and v >= 0 and v <= 10)
        end,
        'number between 0 and 10',
      },
      ['throttle.queue_warning_threshold'] = {
        opts.throttle.queue_warning_threshold,
        function(v)
          return v == nil or (type(v) == 'number' and v >= 1 and v <= 100)
        end,
        'number between 1 and 100',
      },
    })
    if not throttle_ok then
      return false, throttle_err
    end
  end

  -- Validate nested search table if provided
  if opts.search then
    local search_ok, search_err = pcall(vim.validate, {
      ['search.debounce_ms'] = {
        opts.search.debounce_ms,
        function(v)
          return v == nil or (type(v) == 'number' and v >= 0 and v <= 5000)
        end,
        'number between 0 and 5000',
      },
      ['search.show_cached'] = { opts.search.show_cached, { 'boolean', 'nil' }, 'boolean or nil' },
      ['search.live_search'] = { opts.search.live_search, { 'boolean', 'nil' }, 'boolean or nil' },
      ['search.limit'] = {
        opts.search.limit,
        function(v)
          return v == nil or (type(v) == 'number' and v >= 1 and v <= 200)
        end,
        'number between 1 and 200',
      },
    })
    if not search_ok then
      return false, search_err
    end
  end

  return true, nil
end

---Initialize config from vim.g.neotion and/or environment
---Called automatically on first access
local function ensure_initialized()
  if initialized then
    return
  end
  initialized = true

  -- Get user config from vim.g.neotion (can be table or function)
  local user_config = vim.g.neotion
  if type(user_config) == 'function' then
    user_config = user_config()
  end
  user_config = user_config or {}

  -- Validate user config
  local ok, err = validate(user_config)
  if not ok then
    vim.notify('[neotion] Invalid configuration: ' .. (err or 'unknown error'), vim.log.levels.ERROR)
    return
  end

  -- Merge with defaults
  config = vim.tbl_deep_extend('force', vim.deepcopy(default_config), user_config)

  -- Check for environment variable if no token provided
  if not config.api_token then
    local env_token = vim.env.NOTION_API_TOKEN
    if env_token and env_token ~= '' then
      config.api_token = env_token
    end
  end

  -- Initialize throttle module with user config (lazy require to avoid circular dependency)
  if config.throttle and config.throttle.enabled then
    vim.schedule(function()
      local throttle = require('neotion.api.throttle')
      throttle.setup({
        tokens_per_second = config.throttle.tokens_per_second,
        burst_size = config.throttle.burst_size,
        max_retries = config.throttle.max_retries,
        queue_warning_threshold = config.throttle.queue_warning_threshold,
      })
    end)
  end
end

---Configure neotion (optional, only overrides defaults)
---This function is optional. Configuration can also be done via vim.g.neotion
---@param opts neotion.Config? User configuration options
---@return boolean ok Whether setup succeeded
---@return string? error Error message if setup failed
function M.setup(opts)
  opts = opts or {}

  local ok, err = validate(opts)
  if not ok then
    return false, err
  end

  -- Merge with current config (which may already have vim.g.neotion merged)
  ensure_initialized()
  config = vim.tbl_deep_extend('force', config, opts)

  -- Check for environment variable if no token provided
  if not config.api_token then
    local env_token = vim.env.NOTION_API_TOKEN
    if env_token and env_token ~= '' then
      config.api_token = env_token
    end
  end

  return true, nil
end

---Get current configuration
---@return neotion.InternalConfig
function M.get()
  ensure_initialized()
  return config
end

---Validate configuration (exposed for health check)
---@param opts table Configuration options to validate
---@return boolean ok Whether the configuration is valid
---@return string? error Error message if validation failed
function M.validate(opts)
  return validate(opts)
end

---Reset configuration to defaults (mainly for testing)
function M.reset()
  config = vim.deepcopy(default_config)
  initialized = false
end

-- For backwards compatibility, expose defaults
M.defaults = default_config

return M
