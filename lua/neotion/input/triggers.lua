--- Trigger registry for neotion.nvim
--- Extensible system for future / and @ support
---@module 'neotion.input.triggers'

local M = {}

---@class neotion.Trigger
---@field char string Trigger character
---@field handler fun(bufnr: integer) Handler function
---@field enabled boolean Whether trigger is enabled
---@field description? string Optional description

--- Registered triggers
---@type table<string, neotion.Trigger>
M.triggers = {}

---@class neotion.TriggerOpts
---@field enabled? boolean Whether trigger is enabled (default: true)
---@field description? string Optional description

--- Register a trigger character with handler
---@param char string Trigger character (e.g., '/', '@')
---@param handler fun(bufnr: integer) Handler function
---@param opts? neotion.TriggerOpts Options
function M.register(char, handler, opts)
  opts = opts or {}
  M.triggers[char] = {
    char = char,
    handler = handler,
    enabled = opts.enabled ~= false,
    description = opts.description,
  }
end

--- Unregister a trigger character
---@param char string Trigger character
function M.unregister(char)
  M.triggers[char] = nil
end

--- Set up triggers for a buffer
--- This is a stub for future implementation
---@param bufnr integer Buffer number
---@param opts? table Options
function M.setup(bufnr, opts)
  opts = opts or {}

  -- Future: Set up InsertCharPre autocmd to detect triggers
  -- This will be implemented in Phase 8+ when we add slash commands
  --
  -- vim.api.nvim_create_autocmd('InsertCharPre', {
  --   buffer = bufnr,
  --   callback = function()
  --     local char = vim.v.char
  --     local trigger = M.triggers[char]
  --     if trigger and trigger.enabled then
  --       vim.schedule(function()
  --         trigger.handler(bufnr)
  --       end)
  --     end
  --   end,
  -- })
end

return M
