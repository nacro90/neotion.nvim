---Logging module for Neotion
---Provides structured logging with levels and file output
---@class neotion.Log
local M = {}

---@enum neotion.LogLevel
M.levels = {
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4,
  OFF = 5,
}

---@type table<string, neotion.LogLevel>
local level_names = {
  debug = M.levels.DEBUG,
  info = M.levels.INFO,
  warn = M.levels.WARN,
  error = M.levels.ERROR,
  off = M.levels.OFF,
}

---@type table<neotion.LogLevel, string>
local level_labels = {
  [M.levels.DEBUG] = 'DEBUG',
  [M.levels.INFO] = 'INFO',
  [M.levels.WARN] = 'WARN',
  [M.levels.ERROR] = 'ERROR',
}

---@type file*|nil
local log_file = nil

---@type neotion.LogLevel
local current_level = M.levels.INFO

---@type boolean
local initialized = false

---Get log file path
---@return string
function M.get_log_path()
  local log_dir = vim.fn.stdpath('log')
  ---@cast log_dir string
  return log_dir .. '/neotion.log'
end

---Initialize logging (called lazily)
local function init()
  if initialized then
    return
  end

  -- Get log level from config
  local config = require('neotion.config')
  local cfg = config.get()
  local level_str = cfg.log_level or 'info'
  current_level = level_names[level_str:lower()] or M.levels.INFO

  -- Only open file if logging is enabled
  if current_level < M.levels.OFF then
    local log_path = M.get_log_path()
    -- Ensure log directory exists
    local log_dir = vim.fn.fnamemodify(log_path, ':h')
    vim.fn.mkdir(log_dir, 'p')

    -- Open log file in append mode
    local err
    log_file, err = io.open(log_path, 'a')
    if not log_file then
      vim.notify('[neotion] Failed to open log file: ' .. (err or 'unknown error'), vim.log.levels.WARN)
    end
  end

  initialized = true
end

---Format log message with timestamp and context
---@param level neotion.LogLevel
---@param module string
---@param msg string
---@param data? table
---@return string
local function format_message(level, module, msg, data)
  local timestamp = os.date('%Y-%m-%d %H:%M:%S')
  local level_label = level_labels[level] or 'UNKNOWN'
  local formatted = string.format('[%s] [%s] [%s] %s', timestamp, level_label, module, msg)

  if data then
    local ok, encoded = pcall(vim.json.encode, data)
    if ok then
      formatted = formatted .. ' | ' .. encoded
    else
      formatted = formatted .. ' | [data encoding failed]'
    end
  end

  return formatted
end

---Write log entry
---@param level neotion.LogLevel
---@param module string
---@param msg string
---@param data? table
local function write_log(level, module, msg, data)
  init()

  if level < current_level then
    return
  end

  local formatted = format_message(level, module, msg, data)

  -- Write to file
  if log_file then
    log_file:write(formatted .. '\n')
    log_file:flush()
  end

  -- Also notify for errors (always) and warnings (if level allows)
  if level == M.levels.ERROR then
    vim.schedule(function()
      vim.notify('[neotion] ' .. msg, vim.log.levels.ERROR)
    end)
  end
end

---Create a logger for a specific module
---@param module_name string
---@return neotion.Logger
function M.get_logger(module_name)
  ---@class neotion.Logger
  ---@field debug fun(msg: string, data?: table)
  ---@field info fun(msg: string, data?: table)
  ---@field warn fun(msg: string, data?: table)
  ---@field error fun(msg: string, data?: table)
  return {
    debug = function(msg, data)
      write_log(M.levels.DEBUG, module_name, msg, data)
    end,
    info = function(msg, data)
      write_log(M.levels.INFO, module_name, msg, data)
    end,
    warn = function(msg, data)
      write_log(M.levels.WARN, module_name, msg, data)
    end,
    error = function(msg, data)
      write_log(M.levels.ERROR, module_name, msg, data)
    end,
  }
end

---Set log level programmatically
---@param level string|neotion.LogLevel
function M.set_level(level)
  init()
  if type(level) == 'string' then
    local resolved = level_names[level:lower()]
    if not resolved then
      vim.schedule(function()
        vim.notify('[neotion] Invalid log level: ' .. level .. ', using INFO', vim.log.levels.WARN)
      end)
      resolved = M.levels.INFO
    end
    current_level = resolved
  else
    current_level = level
  end
end

---Get current log level
---@return neotion.LogLevel
function M.get_level()
  init()
  return current_level
end

---Check if a level would be logged
---@param level neotion.LogLevel
---@return boolean
function M.is_enabled(level)
  init()
  return level >= current_level
end

---Close log file (for cleanup)
function M.close()
  if log_file then
    log_file:close()
    log_file = nil
  end
  initialized = false
end

---Clear log file
function M.clear()
  M.close()
  local log_path = M.get_log_path()
  local file = io.open(log_path, 'w')
  if file then
    file:close()
  end
  initialized = false
end

---Read last N lines from log file
---Note: This reads the entire file into memory. For very large log files,
---consider using M.clear() periodically.
---@param n? integer Number of lines (default 50)
---@return string[]
function M.tail(n)
  n = n or 50
  local log_path = M.get_log_path()
  local lines = {}

  local file = io.open(log_path, 'r')
  if not file then
    return lines
  end

  -- Read all lines
  for line in file:lines() do
    table.insert(lines, line)
  end
  file:close()

  -- Return last n lines
  if #lines <= n then
    return lines
  end

  local result = {}
  for i = #lines - n + 1, #lines do
    table.insert(result, lines[i])
  end
  return result
end

return M
