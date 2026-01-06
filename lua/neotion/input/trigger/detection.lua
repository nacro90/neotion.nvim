---@class neotion.TriggerCandidate
---@field trigger string The trigger text (e.g., "/", "[[", "@")
---@field start_col integer Column where trigger starts (1-indexed)
---@field priority integer Higher priority = checked first

---@class neotion.TriggerPattern
---@field trigger string The trigger text
---@field pattern string Lua pattern to match at end of prefix
---@field priority integer Higher = checked first (multi-char > single-char)

local M = {}

--- Trigger patterns ordered by priority (longest/most specific first)
--- Priority ensures [[ is matched before considering [ alone
---@type neotion.TriggerPattern[]
local TRIGGER_PATTERNS = {
  { trigger = '[[', pattern = '%[%[$', priority = 100 },
  { trigger = '/', pattern = '/$', priority = 50 },
  { trigger = '@', pattern = '@$', priority = 50 },
}

--- Check if the position is valid for trigger activation
--- Trigger is valid at line start OR after whitespace
---@param line string Line content
---@param trigger_col integer Column where trigger starts (1-indexed)
---@return boolean
function M.is_valid_position(line, trigger_col)
  -- Line start is always valid
  if trigger_col <= 1 then
    return true
  end

  -- Check character before trigger position
  local char_before = line:sub(trigger_col - 1, trigger_col - 1)
  return char_before:match('%s') ~= nil
end

--- Detect trigger at the given position in the line
--- Looks for trigger patterns ending at or before the specified column
---@param line string Current line content
---@param col integer Column to check from (1-indexed, usually cursor position or end of typed text)
---@return neotion.TriggerCandidate? trigger Detected trigger or nil if none found
function M.detect_trigger(line, col)
  -- Get prefix up to the column we're checking
  local prefix = line:sub(1, col + 10) -- Include some lookahead for patterns

  for _, def in ipairs(TRIGGER_PATTERNS) do
    -- Find where the trigger would end in the prefix
    -- We need to find the trigger that could be at position `col`
    local trigger_len = #def.trigger

    -- Check if trigger exists starting at col
    local potential_trigger = line:sub(col, col + trigger_len - 1)
    if potential_trigger == def.trigger then
      -- Trigger found at col, validate position
      if M.is_valid_position(line, col) then
        return {
          trigger = def.trigger,
          start_col = col,
          priority = def.priority,
        }
      end
    end

    -- Also check if we're in the middle of typing (trigger already typed)
    -- Look backwards from col to find trigger
    for start_pos = math.max(1, col - trigger_len + 1), col do
      local substr = line:sub(start_pos, start_pos + trigger_len - 1)
      if substr == def.trigger then
        if M.is_valid_position(line, start_pos) then
          return {
            trigger = def.trigger,
            start_col = start_pos,
            priority = def.priority,
          }
        end
      end
    end
  end

  return nil
end

--- Extract the query text after the trigger
---@param line string Line content
---@param trigger string The trigger text
---@param start_col integer Column where trigger starts
---@return string query The text after the trigger
function M.extract_query(line, trigger, start_col)
  local query_start = start_col + #trigger
  local query = line:sub(query_start)
  return query or ''
end

--- Get all registered trigger patterns
---@return neotion.TriggerPattern[]
function M.get_trigger_patterns()
  -- Return a copy sorted by priority (highest first)
  local patterns = {}
  for _, p in ipairs(TRIGGER_PATTERNS) do
    table.insert(patterns, {
      trigger = p.trigger,
      pattern = p.pattern,
      priority = p.priority,
    })
  end
  table.sort(patterns, function(a, b)
    return a.priority > b.priority
  end)
  return patterns
end

return M
