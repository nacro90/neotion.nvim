---Confirmation UI for Neotion Sync
---Shows sync plan and gets user confirmation
---@class neotion.sync.Confirm
local M = {}

---@class neotion.ConfirmResult
---@field confirmed boolean User confirmed the action
---@field modified_plan neotion.SyncPlan|nil Modified plan (if user made changes)

---Show confirmation dialog for unmatched content
---@param unmatched neotion.SyncPlanUnmatched
---@param callback fun(choice: 'match'|'create'|'skip', matched_block?: neotion.Block)
function M.show_unmatched_dialog(unmatched, callback)
  local items = {}

  -- Add possible matches
  for i, block in ipairs(unmatched.possible_matches) do
    table.insert(items, {
      label = string.format('[%d] Match: %s...', i, block:get_text():sub(1, 30)),
      action = 'match',
      block = block,
    })
  end

  -- Add create option
  table.insert(items, {
    label = '[C] Create as new block',
    action = 'create',
  })

  -- Add skip option
  table.insert(items, {
    label = '[S] Skip (do not sync)',
    action = 'skip',
  })

  local labels = vim.tbl_map(function(item)
    return item.label
  end, items)

  vim.ui.select(labels, {
    prompt = 'Unmatched content: "' .. unmatched.content:sub(1, 40) .. '..."',
  }, function(choice, idx)
    if not choice or not idx then
      callback('skip')
      return
    end

    local selected = items[idx]
    callback(selected.action, selected.block)
  end)
end

---Show summary and get confirmation for sync plan
---@param plan neotion.SyncPlan
---@param callback fun(confirmed: boolean)
function M.show_sync_confirmation(plan, callback)
  local plan_module = require('neotion.sync.plan')
  local summary = plan_module.get_summary(plan)

  -- Build confirmation message
  local msg = 'Neotion: Sync Plan\n' .. table.concat(summary, '\n') .. '\n\nProceed with sync?'

  vim.ui.select({ 'Yes, sync now', 'No, cancel' }, {
    prompt = msg,
  }, function(choice)
    callback(choice == 'Yes, sync now')
  end)
end

---Show simple notification of what will be synced
---@param plan neotion.SyncPlan
function M.show_sync_preview(plan)
  local plan_module = require('neotion.sync.plan')
  local summary = plan_module.get_summary(plan)

  vim.notify('[neotion] Sync preview:\n' .. table.concat(summary, '\n'), vim.log.levels.INFO)
end

---Show error when sync fails
---@param errors string[]
function M.show_sync_errors(errors)
  local msg = 'Sync failed:\n' .. table.concat(errors, '\n')
  vim.notify('[neotion] ' .. msg, vim.log.levels.ERROR)
end

---Show success message after sync
---@param plan neotion.SyncPlan
function M.show_sync_success(plan)
  local plan_module = require('neotion.sync.plan')
  local count = plan_module.get_operation_count(plan)

  if count == 0 then
    vim.notify('[neotion] No changes to sync', vim.log.levels.INFO)
  elseif count == 1 then
    vim.notify('[neotion] Synced 1 block', vim.log.levels.INFO)
  else
    vim.notify('[neotion] Synced ' .. count .. ' blocks', vim.log.levels.INFO)
  end
end

return M
