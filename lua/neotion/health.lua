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
  local config = require('neotion.config')
  local token = config.get().api_token

  if token and token ~= '' then
    -- Mask the token for display
    local masked = string.sub(token, 1, 10) .. string.rep('*', #token - 14) .. string.sub(token, -4)
    vim.health.ok('Notion API token configured: ' .. masked)
    return true
  else
    vim.health.error('Notion API token not configured', {
      'Set api_token in setup(): require("neotion").setup({ api_token = "secret_xxx" })',
      'Or set NOTION_API_TOKEN environment variable',
      'Get your token from: https://www.notion.so/my-integrations',
    })
    return false
  end
end

---@return boolean
local function check_curl()
  local handle = io.popen('curl --version 2>/dev/null')
  if handle then
    local result = handle:read('*a')
    handle:close()
    if result and result ~= '' then
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

---Main health check function
function M.check()
  vim.health.start('neotion.nvim')

  vim.health.start('Required')
  check_neovim_version()
  check_curl()
  check_api_token()

  vim.health.start('Recommended')
  check_treesitter()

  vim.health.start('Optional integrations')
  check_optional_deps()
end

return M
