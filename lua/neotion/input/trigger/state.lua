--- Trigger state machine for managing completion lifecycle
---@class neotion.TriggerStateMachine
---@field private _state neotion.TriggerState
---@field private _trigger string|nil
---@field private _trigger_col integer|nil
---@field private _query string
---@field private _on_state_change fun(old: neotion.TriggerState, new: neotion.TriggerState)|nil
---@field private _on_query_change fun(old: string, new: string)|nil

local M = {}

-- State constants
M.IDLE = 'idle'
M.DETECTING = 'detecting'
M.TRIGGERED = 'triggered'
M.COMPLETING = 'completing'

---@alias neotion.TriggerState 'idle'|'detecting'|'triggered'|'completing'

---@class StateMachine
local StateMachine = {}
StateMachine.__index = StateMachine

--- Create a new state machine
---@return StateMachine
function M.create()
  local self = setmetatable({}, StateMachine)
  self._state = M.IDLE
  self._trigger = nil
  self._trigger_col = nil
  self._query = ''
  self._on_state_change = nil
  self._on_query_change = nil
  return self
end

--- Get the current state
---@return neotion.TriggerState
function StateMachine:get_state()
  return self._state
end

--- Get the active trigger text
---@return string|nil
function StateMachine:get_trigger()
  return self._trigger
end

--- Get the column where trigger starts
---@return integer|nil
function StateMachine:get_trigger_col()
  return self._trigger_col
end

--- Get the current query text
---@return string
function StateMachine:get_query()
  return self._query
end

--- Check if a trigger is active (not idle)
---@return boolean
function StateMachine:is_active()
  return self._state ~= M.IDLE
end

--- Set state change callback
---@param callback fun(old: neotion.TriggerState, new: neotion.TriggerState)
function StateMachine:on_state_change(callback)
  self._on_state_change = callback
end

--- Set query change callback
---@param callback fun(old: string, new: string)
function StateMachine:on_query_change(callback)
  self._on_query_change = callback
end

--- Internal: Change state with callback
---@param new_state neotion.TriggerState
---@private
function StateMachine:_set_state(new_state)
  local old_state = self._state
  if old_state ~= new_state then
    self._state = new_state
    if self._on_state_change then
      self._on_state_change(old_state, new_state)
    end
  end
end

--- Internal: Change query with callback
---@param new_query string
---@private
function StateMachine:_set_query(new_query)
  local old_query = self._query
  if old_query ~= new_query then
    self._query = new_query
    if self._on_query_change then
      self._on_query_change(old_query, new_query)
    end
  end
end

--- Transition: Trigger detected
--- IDLE -> TRIGGERED
---@param trigger string The trigger text (e.g., "/", "[[", "@")
---@param col integer Column where trigger starts
function StateMachine:trigger_detected(trigger, col)
  self._trigger = trigger
  self._trigger_col = col
  self:_set_state(M.TRIGGERED)
end

--- Transition: Show completion menu
--- TRIGGERED -> COMPLETING
function StateMachine:show_completion()
  if self._state == M.TRIGGERED then
    self:_set_state(M.COMPLETING)
  end
end

--- Transition: Confirm selection
--- COMPLETING -> IDLE
function StateMachine:confirm()
  self._trigger = nil
  self._trigger_col = nil
  self:_set_query('')
  self:_set_state(M.IDLE)
end

--- Transition: Cancel completion
--- COMPLETING -> IDLE
function StateMachine:cancel()
  self._trigger = nil
  self._trigger_col = nil
  self:_set_query('')
  self:_set_state(M.IDLE)
end

--- Transition: Transform to another trigger
--- COMPLETING -> TRIGGERED (with new trigger)
---@param new_trigger string The new trigger to transform to
function StateMachine:transform(new_trigger)
  self._trigger = new_trigger
  self:_set_query('')
  self:_set_state(M.TRIGGERED)
end

--- Reset to idle state
function StateMachine:reset()
  self._trigger = nil
  self._trigger_col = nil
  self:_set_query('')
  self:_set_state(M.IDLE)
end

--- Set the query text
---@param query string
function StateMachine:set_query(query)
  self:_set_query(query)
end

--- Append to the query text
---@param text string
function StateMachine:append_query(text)
  self:_set_query(self._query .. text)
end

--- Remove last character from query (backspace)
function StateMachine:backspace_query()
  if #self._query > 0 then
    self:_set_query(self._query:sub(1, -2))
  end
end

return M
