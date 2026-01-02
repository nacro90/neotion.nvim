---@brief [[
---neotion.nvim - Notion integration for Neovim
---
---Zero data loss Notion editing with full round-trip sync.
---Preserves block IDs, colors, mentions, toggles, and all rich metadata.
---
---Configuration (all methods are optional):
---
---1. Via vim.g.neotion (before plugin loads):
---   vim.g.neotion = { api_token = 'secret_xxx' }
---
---2. Via setup() (optional, only overrides):
---   require('neotion').setup({ api_token = 'secret_xxx' })
---
---3. Via environment variable:
---   export NOTION_API_TOKEN=secret_xxx
---@brief ]]

---@class Neotion
local M = {}

---Configure neotion (optional, only overrides defaults)
---Configuration can also be done via vim.g.neotion
---@param opts neotion.Config? Optional configuration table
function M.setup(opts)
  local config = require('neotion.config')
  local ok, err = config.setup(opts)

  if not ok then
    vim.notify('[neotion] Configuration error: ' .. (err or 'unknown'), vim.log.levels.ERROR)
  end
end

---Get current configuration
---@return neotion.InternalConfig
function M.get_config()
  return require('neotion.config').get()
end

-- Page Operations

---Open a Notion page in a new buffer
---@param page_id string Notion page ID
function M.open(page_id)
  vim.validate({
    page_id = { page_id, 'string' },
  })

  -- TODO: Implement page opening
  vim.notify('[neotion] open() not yet implemented', vim.log.levels.WARN)
end

---Create a new Notion page
---@param title string? Page title
function M.create(title)
  -- TODO: Implement page creation
  vim.notify('[neotion] create() not yet implemented', vim.log.levels.WARN)
end

---Delete the current Notion page
function M.delete()
  -- TODO: Implement page deletion
  vim.notify('[neotion] delete() not yet implemented', vim.log.levels.WARN)
end

-- Sync Operations

---Sync current buffer with Notion
function M.sync()
  -- TODO: Implement sync
  vim.notify('[neotion] sync() not yet implemented', vim.log.levels.WARN)
end

---Force push local changes to Notion
function M.push()
  -- TODO: Implement push
  vim.notify('[neotion] push() not yet implemented', vim.log.levels.WARN)
end

---Force pull remote changes from Notion
function M.pull()
  -- TODO: Implement pull
  vim.notify('[neotion] pull() not yet implemented', vim.log.levels.WARN)
end

-- Navigation

---Navigate to parent page
function M.goto_parent()
  -- TODO: Implement parent navigation
  vim.notify('[neotion] goto_parent() not yet implemented', vim.log.levels.WARN)
end

---Follow link under cursor
function M.goto_link()
  -- TODO: Implement link following
  vim.notify('[neotion] goto_link() not yet implemented', vim.log.levels.WARN)
end

---Search Notion pages
---@param opts table? Search options
function M.search(opts)
  -- TODO: Implement search
  vim.notify('[neotion] search() not yet implemented', vim.log.levels.WARN)
end

-- Block Operations

---Move block in specified direction
---@param direction "up"|"down" Direction to move
function M.block_move(direction)
  vim.validate({
    direction = {
      direction,
      function(v)
        return v == 'up' or v == 'down'
      end,
      'up or down',
    },
  })
  -- TODO: Implement block move
  vim.notify('[neotion] block_move() not yet implemented', vim.log.levels.WARN)
end

---Indent current block
function M.block_indent()
  -- TODO: Implement block indent
  vim.notify('[neotion] block_indent() not yet implemented', vim.log.levels.WARN)
end

---Dedent current block
function M.block_dedent()
  -- TODO: Implement block dedent
  vim.notify('[neotion] block_dedent() not yet implemented', vim.log.levels.WARN)
end

---Get sync status for current buffer
---@return table? status Sync status or nil if not a neotion buffer
function M.status()
  -- TODO: Implement status
  return nil
end

return M
