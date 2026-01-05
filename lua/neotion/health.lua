---@brief Health check for neotion.nvim
---Run with :checkhealth neotion

local M = {}

---@return boolean
local function check_neovim_version()
  local version = vim.version()
  if version.major > 0 or version.minor >= 10 then
    vim.health.ok(string.format('Neovim version %d.%d.%d', version.major, version.minor, version.patch))
    return true
  else
    vim.health.error(
      string.format('Neovim 0.10+ required, found %d.%d.%d', version.major, version.minor, version.patch),
      { 'Upgrade Neovim to version 0.10 or higher' }
    )
    return false
  end
end

---@return boolean
local function check_treesitter()
  local ok, _ = pcall(require, 'nvim-treesitter')
  if ok then
    vim.health.ok('nvim-treesitter is installed')
    return true
  else
    vim.health.warn('nvim-treesitter is not installed', {
      'Install nvim-treesitter for enhanced syntax highlighting',
      'https://github.com/nvim-treesitter/nvim-treesitter',
    })
    return false
  end
end

---@return boolean
local function check_api_token()
  local auth = require('neotion.api.auth')
  local result = auth.get_token()

  if result.token then
    -- Validate token format
    local valid, format_err = auth.validate_token_format(result.token)
    if not valid then
      vim.health.warn('API token format may be invalid: ' .. (format_err or 'unknown'))
    end

    -- Mask the token for display (handle short tokens safely)
    local token = result.token
    local masked
    if #token <= 14 then
      masked = string.sub(token, 1, 4) .. string.rep('*', math.max(0, #token - 8)) .. string.sub(token, -4)
    else
      masked = string.sub(token, 1, 10) .. string.rep('*', #token - 14) .. string.sub(token, -4)
    end
    vim.health.ok('Notion API token configured via ' .. result.source .. ': ' .. masked)
    return true
  else
    vim.health.error('Notion API token not configured', {
      'Set api_token in setup(): require("neotion").setup({ api_token = "secret_xxx" })',
      'Or set vim.g.neotion = { api_token = "secret_xxx" }',
      'Or set NOTION_API_TOKEN environment variable',
      'Get your token from: https://www.notion.so/my-integrations',
    })
    return false
  end
end

---@return boolean
local function check_curl()
  -- Use vim.fn.executable for checking, vim.fn.system for version
  if vim.fn.executable('curl') == 1 then
    local result = vim.fn.system('curl --version 2>/dev/null')
    if vim.v.shell_error == 0 and result ~= '' then
      local version = result:match('curl ([%d%.]+)')
      vim.health.ok('curl is available: ' .. (version or 'unknown version'))
      return true
    end
  end

  vim.health.error('curl is not available', {
    'Install curl for Notion API communication',
  })
  return false
end

---@return boolean
local function check_optional_deps()
  local all_ok = true

  -- Check for telescope
  local has_telescope = pcall(require, 'telescope')
  if has_telescope then
    vim.health.ok('telescope.nvim is available (enhanced search)')
  else
    vim.health.info('telescope.nvim not found (optional, for enhanced search)')
  end

  -- Check for fzf-lua
  local has_fzf = pcall(require, 'fzf-lua')
  if has_fzf then
    vim.health.ok('fzf-lua is available (alternative picker)')
  else
    vim.health.info('fzf-lua not found (optional, alternative picker)')
  end

  -- Check for nvim-cmp
  local has_cmp = pcall(require, 'cmp')
  if has_cmp then
    vim.health.ok('nvim-cmp is available (completion support)')
  else
    vim.health.info('nvim-cmp not found (optional, for completion)')
  end

  return all_ok
end

---@return boolean
local function check_throttle()
  local ok, throttle = pcall(require, 'neotion.api.throttle')
  if not ok then
    vim.health.error('Throttle module failed to load')
    return false
  end

  local stats = throttle.get_stats()

  -- Check queue health
  if stats.queue_length > 50 then
    vim.health.warn(string.format('Large request queue: %d pending', stats.queue_length))
  elseif stats.queue_length > 0 then
    vim.health.ok(string.format('Request queue: %d pending', stats.queue_length))
  else
    vim.health.ok('Request queue: empty')
  end

  -- Check rate limit status
  if stats.paused then
    vim.health.warn(
      string.format('Rate limiter paused (%.1fs remaining)', stats.pause_remaining or 0),
      { 'Notion API rate limit reached, requests will resume automatically' }
    )
  else
    vim.health.ok(string.format('Rate limiter: %.1f tokens available (3/s refill)', stats.available_tokens))
  end

  -- Show statistics
  vim.health.info(
    string.format(
      'Throttle stats: %d requests, %d retries, %d cancelled',
      stats.total_requests,
      stats.total_retries,
      stats.total_cancelled
    )
  )

  return true
end

---@return boolean
local function check_cache()
  local ok, cache = pcall(require, 'neotion.cache')
  if not ok then
    vim.health.error('Cache module failed to load')
    return false
  end

  -- Check if sqlite.lua is available
  if cache.is_available() then
    vim.health.ok('sqlite.lua is installed (cache enabled)')

    -- Check if cache is initialized
    if cache.is_initialized() then
      local stats = cache.stats()
      vim.health.ok(string.format('Cache initialized: %d pages, %d contents', stats.page_count, stats.content_count))

      -- Show cache size
      if stats.size_bytes > 0 then
        local size_kb = stats.size_bytes / 1024
        if size_kb >= 1024 then
          vim.health.info(string.format('Cache size: %.1f MB', size_kb / 1024))
        else
          vim.health.info(string.format('Cache size: %.1f KB', size_kb))
        end
      end

      -- Show sync state info
      local sync_ok, sync_state = pcall(require, 'neotion.cache.sync_state')
      if sync_ok then
        local states = sync_state.get_all_states()
        if #states > 0 then
          local synced = 0
          local modified = 0
          for _, s in ipairs(states) do
            if s.sync_status == 'synced' then
              synced = synced + 1
            elseif s.sync_status == 'modified' then
              modified = modified + 1
            end
          end
          vim.health.info(string.format('Sync state: %d tracked (%d synced, %d modified)', #states, synced, modified))
        end
      end
    else
      vim.health.info('Cache not initialized (will init on first page open)')
    end

    return true
  else
    vim.health.warn('sqlite.lua not installed (cache disabled)', {
      'Install sqlite.lua for offline page caching',
      'lazy.nvim: { "kkharji/sqlite.lua" }',
      'packer: use "kkharji/sqlite.lua"',
    })
    return false
  end
end

---Main health check function
function M.check()
  vim.health.start('neotion.nvim')

  vim.health.start('Required')
  check_neovim_version()
  check_curl()
  check_api_token()

  vim.health.start('Recommended')
  check_treesitter()

  vim.health.start('Cache')
  check_cache()

  vim.health.start('Rate limiting')
  check_throttle()

  vim.health.start('Optional integrations')
  check_optional_deps()
end

return M
