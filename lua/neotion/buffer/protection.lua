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
  local blocks = mapping.get_blocks(bufnr)

  if not buffer_state[bufnr] then
    buffer_state[bufnr] = { enabled = true, last_content = {} }
  end

  buffer_state[bufnr].last_content = {}

  for i, block in ipairs(blocks) do
    if not block:is_editable() then
      local start_line, end_line = block:get_line_range()
      if start_line and end_line then
        local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
        buffer_state[bufnr].last_content[i] = table.concat(lines, '\n')
      end
    end
  end
end

--- Check and restore read-only blocks if modified
---@param bufnr integer
---@return boolean was_restored
local function check_and_restore(bufnr)
  local mapping = require('neotion.model.mapping')
  local blocks = mapping.get_blocks(bufnr)
  local state = buffer_state[bufnr]

  if not state or not state.enabled then
    return false
  end

  for i, block in ipairs(blocks) do
    if not block:is_editable() then
      local start_line, end_line = block:get_line_range()
      if start_line and end_line then
        local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
        local current_content = table.concat(lines, '\n')
        local expected_content = state.last_content[i]

        if expected_content and current_content ~= expected_content then
          log.debug('Read-only block modified, restoring', {
            block_type = block:get_type(),
            block_id = block:get_id(),
          })

          -- Restore content - use undo
          vim.cmd('silent! undo')
          vim.notify('Read-only block cannot be modified', vim.log.levels.WARN)
          return true
        end
      end
    end
  end

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
