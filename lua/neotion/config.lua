---@brief [[
---Configuration module for neotion.nvim
---
---Configuration can be provided in two ways:
---1. Via vim.g.neotion table (before plugin loads)
---2. Via require('neotion').setup(opts) (optional, only overrides defaults)
---@brief ]]

-- User-facing config type (all fields optional)
---@class neotion.Config
---@field api_token? string Notion API integration token
---@field sync_interval? integer Debounce interval for auto-sync in milliseconds (default: 2000)
---@field auto_sync? boolean Enable automatic sync on buffer changes (default: true)
---@field conceal_level? integer Conceal level for block markers (0-3, default: 2)
---@field icons? neotion.Icons Icons used in the UI
---@field keymaps? neotion.Keymaps Keymap configuration (set to false to disable)
---@field log_level? string Log level: "trace", "debug", "info", "warn", "error" (default: "info")

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
        local valid_levels = { trace = true, debug = true, info = true, warn = true, error = true }
        return valid_levels[v] ~= nil
      end,
      'one of: trace, debug, info, warn, error',
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
