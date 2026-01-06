--- Input system orchestrator for neotion.nvim
--- Coordinates shortcuts, triggers, and other input-related features
---@module 'neotion.input'

local M = {}

--- Lazily load shortcuts module
M.shortcuts = setmetatable({}, {
  __index = function(_, key)
    return require('neotion.input.shortcuts')[key]
  end,
})

--- Default options for input system
---@class neotion.InputOpts
---@field shortcuts? neotion.ShortcutsOpts Shortcuts configuration
---@field triggers? neotion.TriggersOpts Triggers configuration (future)

---@class neotion.ShortcutsOpts
---@field enabled? boolean Enable shortcuts (default: true)
---@field bold? boolean Enable bold shortcut (default: true)
---@field italic? boolean Enable italic shortcut (default: true)
---@field strikethrough? boolean Enable strikethrough shortcut (default: true)
---@field code? boolean Enable code shortcut (default: true)
---@field underline? boolean Enable underline shortcut (default: true)
---@field color? boolean Enable color shortcut (default: true)

---@class neotion.TriggersOpts
---@field enabled? boolean Enable triggers (default: true)

--- Set up input system for a buffer
---@param bufnr integer Buffer number
---@param opts? neotion.InputOpts Options
function M.setup(bufnr, opts)
  opts = opts or {}

  -- Set up shortcuts if enabled (default: enabled)
  local shortcuts_opts = opts.shortcuts or {}
  if shortcuts_opts.enabled ~= false then
    local shortcuts = require('neotion.input.shortcuts')
    shortcuts.setup(bufnr, shortcuts_opts)
  end

  -- Set up triggers for /, [[, and @ commands
  local triggers_opts = opts.triggers or {}
  if triggers_opts.enabled ~= false then
    local triggers = require('neotion.input.triggers')
    triggers.setup(bufnr, triggers_opts)
  end
end

return M
