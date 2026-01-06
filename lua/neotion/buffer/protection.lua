--- Buffer protection for read-only blocks
--- Prevents editing of non-editable blocks (divider, callout, etc.)
---@module 'neotion.buffer.protection'

local log = require('neotion.log').get_logger('buffer.protection')

local M = {}

--- Buffer-local state for protection
---@type table<integer, {enabled: boolean, last_content: table<integer, string>}>
local buffer_state = {}

--- Check if a block's content matches expected content
---@param block neotion.Block
---@param lines string[]
---@return boolean
local function content_matches(block, lines)
  -- For divider, expected content is exactly '---'
  if block:get_type() == 'divider' then
    return #lines == 1 and lines[1] == '---'
  end

  -- For other non-editable blocks, use matches_content if available
  if block.matches_content then
    return block:matches_content(lines)
  end

  return true
end

--- Store content of read-only blocks for comparison
---@param bufnr integer
local function snapshot_readonly_content(bufnr)
  local mapping = require('neotion.model.mapping')

  if not buffer_state[bufnr] then
    buffer_state[bufnr] = { enabled = true, last_content = {} }
  end

  -- Refresh line ranges from extmarks to ensure we snapshot at correct positions
  mapping.refresh_line_ranges(bufnr)

  local blocks = mapping.get_blocks(bufnr)
  buffer_state[bufnr].last_content = {}

  local snapshot_count = 0
  for i, block in ipairs(blocks) do
    if not block:is_editable() then
      local start_line, end_line = block:get_line_range()
      if start_line and end_line then
        local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
        local content = table.concat(lines, '\n')
        buffer_state[bufnr].last_content[i] = content
        snapshot_count = snapshot_count + 1

        log.debug('Snapshot read-only block', {
          index = i,
          block_type = block:get_type(),
          line_range = { start_line, end_line },
          content_preview = content:sub(1, 40),
        })
      end
    end
  end

  log.debug('Snapshot complete', {
    bufnr = bufnr,
    readonly_blocks_snapshotted = snapshot_count,
  })
end

--- Check and restore read-only blocks if modified
---@param bufnr integer
---@return boolean was_restored
local function check_and_restore(bufnr)
  local mapping = require('neotion.model.mapping')

  local state = buffer_state[bufnr]
  if not state or not state.enabled then
    log.debug('check_and_restore: protection disabled or no state', { bufnr = bufnr })
    return false
  end

  -- CRITICAL: Refresh line ranges from extmarks BEFORE checking
  -- This ensures we check the correct lines after edits shift block positions
  mapping.refresh_line_ranges(bufnr)

  local blocks = mapping.get_blocks(bufnr)
  local readonly_count = 0

  for i, block in ipairs(blocks) do
    if not block:is_editable() then
      readonly_count = readonly_count + 1
      local start_line, end_line = block:get_line_range()

      if start_line and end_line then
        local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
        local current_content = table.concat(lines, '\n')
        local expected_content = state.last_content[i]

        -- Log comparison for debugging
        log.debug('Checking read-only block', {
          index = i,
          block_type = block:get_type(),
          block_id = block:get_id(),
          line_range = { start_line, end_line },
          current_preview = current_content:sub(1, 40),
          expected_preview = expected_content and expected_content:sub(1, 40) or '(nil)',
          content_match = expected_content == current_content,
        })

        if expected_content and current_content ~= expected_content then
          log.warn('Read-only block MODIFIED, restoring with undo', {
            block_type = block:get_type(),
            block_id = block:get_id(),
            line_range = { start_line, end_line },
            expected = expected_content:sub(1, 50),
            got = current_content:sub(1, 50),
          })

          -- Restore content - use undo
          vim.cmd('silent! undo')
          vim.notify('Read-only block cannot be modified', vim.log.levels.WARN)
          return true
        end
      else
        log.debug('Read-only block has nil line range (deleted)', {
          index = i,
          block_type = block:get_type(),
        })
      end
    end
  end

  log.debug('check_and_restore complete', {
    bufnr = bufnr,
    readonly_blocks_checked = readonly_count,
    restored = false,
  })

  return false
end

--- Setup protection for a buffer
---@param bufnr integer
function M.setup(bufnr)
  log.debug('Setting up buffer protection', { bufnr = bufnr })

  -- Initialize state
  buffer_state[bufnr] = { enabled = true, last_content = {} }

  -- Take initial snapshot
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      snapshot_readonly_content(bufnr)
    end
  end)

  -- TextChanged autocmd for protection
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    buffer = bufnr,
    callback = function()
      if not buffer_state[bufnr] or not buffer_state[bufnr].enabled then
        return
      end

      local restored = check_and_restore(bufnr)
      if not restored then
        -- Update snapshot after valid change
        snapshot_readonly_content(bufnr)
      end
    end,
  })

  -- Cleanup on buffer delete
  vim.api.nvim_create_autocmd('BufDelete', {
    buffer = bufnr,
    callback = function()
      buffer_state[bufnr] = nil
    end,
  })

  log.info('Buffer protection setup complete', { bufnr = bufnr })
end

--- Temporarily disable protection (for programmatic edits)
---@param bufnr integer
function M.disable(bufnr)
  if buffer_state[bufnr] then
    buffer_state[bufnr].enabled = false
    log.debug('Buffer protection disabled', { bufnr = bufnr })
  end
end

--- Re-enable protection
---@param bufnr integer
function M.enable(bufnr)
  if buffer_state[bufnr] then
    buffer_state[bufnr].enabled = true
    snapshot_readonly_content(bufnr)
    log.debug('Buffer protection enabled', { bufnr = bufnr })
  end
end

--- Check if protection is enabled
---@param bufnr integer
---@return boolean
function M.is_enabled(bufnr)
  return buffer_state[bufnr] and buffer_state[bufnr].enabled or false
end

--- Refresh protection snapshot (call after block changes)
---@param bufnr integer
function M.refresh(bufnr)
  if buffer_state[bufnr] then
    snapshot_readonly_content(bufnr)
  end
end

--- Clear protection state (for testing)
function M._reset()
  buffer_state = {}
end

return M
