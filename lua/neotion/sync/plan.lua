---Sync Plan Module for Neotion
---Creates sync plans by analyzing buffer changes
---@class neotion.sync.Plan
local M = {}

local log = require('neotion.log').get_logger('sync.plan')

---@class neotion.SyncPlanUpdate
---@field block neotion.Block Block to update
---@field block_id string Notion block ID
---@field content string New content

---@class neotion.SyncPlanCreate
---@field content string Content for new block
---@field block_type string Type of block to create
---@field after_block_id string|nil Insert after this block (nil = start of page)

---@class neotion.SyncPlanDelete
---@field block_id string Block ID to delete
---@field original_content string Content before deletion (for confirmation)

---@class neotion.SyncPlanTypeChange
---@field block neotion.Block Block with type change
---@field block_id string Notion block ID
---@field old_type string Original block type
---@field new_type string New block type
---@field content string Current content

---@class neotion.SyncPlanUnmatched
---@field content string Buffer content that couldn't be matched
---@field line_start integer Start line in buffer
---@field line_end integer End line in buffer
---@field possible_matches neotion.Block[] Possible matching blocks

---@class neotion.SyncPlan
---@field updates neotion.SyncPlanUpdate[] Blocks to update
---@field creates neotion.SyncPlanCreate[] New blocks to create
---@field deletes neotion.SyncPlanDelete[] Blocks to delete
---@field type_changes neotion.SyncPlanTypeChange[] Blocks with type changes (need delete+create)
---@field unmatched neotion.SyncPlanUnmatched[] Content needing user decision
---@field has_changes boolean Whether there are any changes
---@field needs_confirmation boolean Whether user confirmation is needed

---Create a sync plan for a buffer
---@param bufnr integer
---@return neotion.SyncPlan
function M.create(bufnr)
  local model = require('neotion.model')

  log.debug('Creating sync plan', { bufnr = bufnr })

  ---@type neotion.SyncPlan
  local plan = {
    updates = {},
    creates = {},
    deletes = {},
    type_changes = {},
    unmatched = {},
    has_changes = false,
    needs_confirmation = false,
  }

  -- Sync buffer content to blocks first
  log.debug('Syncing buffer content to blocks')
  model.sync_blocks_from_buffer(bufnr)

  -- Check for deleted blocks (line_range is nil)
  local all_blocks = model.get_blocks(bufnr)
  for _, block in ipairs(all_blocks) do
    local start_line, end_line = block:get_line_range()
    if start_line == nil or end_line == nil then
      -- Block was deleted from buffer
      local block_id = block:get_id()
      log.info('Block deleted from buffer', {
        block_id = block_id,
        block_type = block:get_type(),
      })
      table.insert(plan.deletes, {
        block_id = block_id,
        block = block,
        original_content = block:get_text() or '',
      })
    end
  end

  -- Get dirty blocks (changed content)
  local dirty_blocks = model.get_dirty_blocks(bufnr)
  log.debug('Found dirty blocks', { count = #dirty_blocks })

  for i, block in ipairs(dirty_blocks) do
    local block_id = block:get_id()
    local block_type = block:get_type()
    local original_type = block.raw and block.raw.type or 'unknown'
    local type_changed = block:type_changed()

    log.debug('Analyzing dirty block', {
      index = i,
      block_id = block_id,
      current_type = block_type,
      original_type = original_type,
      type_changed = type_changed,
      text_preview = block:get_text():sub(1, 30),
      original_text_preview = (block.original_text or ''):sub(1, 30),
    })

    -- Check if block type changed (e.g., heading level, paragraph→bullet)
    -- Notion API doesn't support type changes, so we need delete+create
    if type_changed then
      -- For type changes, get content without prefix if converting from paragraph
      -- get_converted_content() strips the prefix (e.g., "- " from "- item")
      local content = block.get_converted_content and block:get_converted_content() or block:get_text()

      log.info('Block type changed, will use delete+create', {
        block_id = block_id,
        old_type = original_type,
        new_type = block_type,
        content_preview = content:sub(1, 30),
      })
      table.insert(plan.type_changes, {
        block = block,
        block_id = block_id,
        old_type = original_type,
        new_type = block_type,
        content = content,
      })
    else
      log.debug('Block content changed, will update', {
        block_id = block_id,
        block_type = block_type,
      })
      table.insert(plan.updates, {
        block = block,
        block_id = block_id,
        content = block:get_text(),
      })
    end
  end

  -- Check for changes
  plan.has_changes = #plan.updates > 0 or #plan.creates > 0 or #plan.deletes > 0 or #plan.type_changes > 0

  -- Needs confirmation only if there are unmatched items or deletes
  plan.needs_confirmation = #plan.unmatched > 0 or #plan.deletes > 0

  log.info('Sync plan created', {
    has_changes = plan.has_changes,
    updates = #plan.updates,
    creates = #plan.creates,
    deletes = #plan.deletes,
    type_changes = #plan.type_changes,
    unmatched = #plan.unmatched,
  })

  return plan
end

---Get a summary of the sync plan for display
---@param plan neotion.SyncPlan
---@return string[]
function M.get_summary(plan)
  local lines = {}

  if #plan.updates > 0 then
    table.insert(lines, string.format('Updates: %d block(s)', #plan.updates))
    for _, update in ipairs(plan.updates) do
      local preview = update.content:sub(1, 40)
      if #update.content > 40 then
        preview = preview .. '...'
      end
      table.insert(lines, string.format('  - [%s] %s', update.block:get_type(), preview))
    end
  end

  if #plan.type_changes > 0 then
    table.insert(lines, string.format('Type changes: %d block(s) (delete+create)', #plan.type_changes))
    for _, tc in ipairs(plan.type_changes) do
      local preview = tc.content:sub(1, 30)
      if #tc.content > 30 then
        preview = preview .. '...'
      end
      table.insert(lines, string.format('  - [%s → %s] %s', tc.old_type, tc.new_type, preview))
    end
  end

  if #plan.creates > 0 then
    table.insert(lines, string.format('Creates: %d block(s)', #plan.creates))
  end

  if #plan.deletes > 0 then
    table.insert(lines, string.format('Deletes: %d block(s)', #plan.deletes))
  end

  if #plan.unmatched > 0 then
    table.insert(lines, string.format('Unmatched: %d region(s) - needs review', #plan.unmatched))
  end

  if #lines == 0 then
    table.insert(lines, 'No changes to sync')
  end

  return lines
end

---Check if plan is empty (no changes)
---@param plan neotion.SyncPlan
---@return boolean
function M.is_empty(plan)
  return not plan.has_changes
end

---Get total number of operations in plan
---@param plan neotion.SyncPlan
---@return integer
function M.get_operation_count(plan)
  -- Type changes count as 2 operations each (delete + create)
  return #plan.updates + #plan.creates + #plan.deletes + (#plan.type_changes * 2)
end

return M
