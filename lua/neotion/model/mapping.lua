---Line-to-Block Mapping for Neotion
---Tracks which buffer lines belong to which blocks using extmarks
---@class neotion.model.Mapping
local M = {}

---@type table<integer, neotion.Block[]>
local buffer_blocks = {} -- bufnr -> Block[]

---@type table<integer, table<integer, integer>>
local block_extmarks = {} -- bufnr -> { block_index -> extmark_id }

---@type integer
local ns_id = vim.api.nvim_create_namespace('neotion_blocks')

---@type integer
local readonly_ns_id = vim.api.nvim_create_namespace('neotion_readonly')

---Setup block mapping for a buffer
---@param bufnr integer Buffer number
---@param blocks neotion.Block[] Blocks to map
function M.setup(bufnr, blocks)
  buffer_blocks[bufnr] = blocks
  block_extmarks[bufnr] = {}

  -- Clear existing extmarks
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, readonly_ns_id, 0, -1)
end

---Update line ranges and extmarks after content is set
---@param bufnr integer
---@param header_lines integer Number of header lines to skip
function M.setup_extmarks(bufnr, header_lines)
  local blocks = buffer_blocks[bufnr]
  if not blocks then
    return
  end

  -- Clear existing extmarks
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, readonly_ns_id, 0, -1)
  block_extmarks[bufnr] = {}

  local current_line = header_lines + 1 -- 1-indexed, after header

  for i, block in ipairs(blocks) do
    local block_lines = block:format({})
    local line_count = #block_lines

    -- Set line range on block
    block:set_line_range(current_line, current_line + line_count - 1)

    -- Create extmark at block start
    -- right_gravity = true: Insertions at block START stay BEFORE the block (not absorbed)
    -- end_right_gravity = false: Insertions at block END stay AFTER the block (not absorbed)
    if vim.api.nvim_buf_is_valid(bufnr) then
      local end_row = current_line + line_count - 1 - 1 -- 0-indexed end row
      local line_content = vim.api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1] or ''
      local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, current_line - 1, 0, {
        end_row = end_row,
        end_col = #line_content, -- End at last character of line
        right_gravity = true, -- Insertions at start stay before block
        end_right_gravity = false, -- Insertions at end stay after block
      })
      block_extmarks[bufnr][i] = extmark_id

      -- Add read-only highlighting for non-editable blocks
      if not block:is_editable() then
        for line = current_line, current_line + line_count - 1 do
          -- Use line_hl_group for full line highlighting
          vim.api.nvim_buf_set_extmark(bufnr, readonly_ns_id, line - 1, 0, {
            line_hl_group = 'NeotionReadOnly',
            priority = 100,
          })
        end
      end
    end

    current_line = current_line + line_count
  end
end

---Get block at a specific line
---@param bufnr integer
---@param line integer 1-indexed line number
---@return neotion.Block|nil
function M.get_block_at_line(bufnr, line)
  local blocks = buffer_blocks[bufnr]
  if not blocks then
    return nil
  end

  for _, block in ipairs(blocks) do
    if block:contains_line(line) then
      return block
    end
  end

  return nil
end

---Get block by ID
---@param bufnr integer
---@param block_id string
---@return neotion.Block|nil
function M.get_block_by_id(bufnr, block_id)
  local blocks = buffer_blocks[bufnr]
  if not blocks then
    return nil
  end

  for _, block in ipairs(blocks) do
    if block:get_id() == block_id then
      return block
    end
  end

  return nil
end

---Get all blocks for a buffer
---@param bufnr integer
---@return neotion.Block[]
function M.get_blocks(bufnr)
  return buffer_blocks[bufnr] or {}
end

---Get only dirty (modified) blocks
---@param bufnr integer
---@return neotion.Block[]
function M.get_dirty_blocks(bufnr)
  local blocks = buffer_blocks[bufnr]
  if not blocks then
    return {}
  end

  local dirty = {}
  for _, block in ipairs(blocks) do
    if block:is_dirty() then
      table.insert(dirty, block)
    end
  end
  return dirty
end

---Get only editable blocks
---@param bufnr integer
---@return neotion.Block[]
function M.get_editable_blocks(bufnr)
  local blocks = buffer_blocks[bufnr]
  if not blocks then
    return {}
  end

  local editable = {}
  for _, block in ipairs(blocks) do
    if block:is_editable() then
      table.insert(editable, block)
    end
  end
  return editable
end

---Refresh line ranges based on extmark positions
---Uses extmarks to track block positions accurately even after edits
---@param bufnr integer
function M.refresh_line_ranges(bufnr)
  local log = require('neotion.log').get_logger('mapping')
  local blocks = buffer_blocks[bufnr]
  local extmarks = block_extmarks[bufnr]

  if not blocks or not extmarks then
    return
  end

  log.debug('refresh_line_ranges starting', {
    block_count = #blocks,
    extmark_count = vim.tbl_count(extmarks),
  })

  -- Get total line count to validate positions
  local total_lines = vim.api.nvim_buf_line_count(bufnr)

  -- First pass: collect extmark info for all blocks
  ---@type table<integer, {start_row: integer, end_row: integer, start_col: integer, end_col: integer, is_zero_width: boolean}>
  local extmark_info = {}

  for i, _ in ipairs(blocks) do
    local extmark_id = extmarks[i]
    if extmark_id then
      local mark = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns_id, extmark_id, { details = true })

      if mark and #mark >= 3 then
        local start_row = mark[1]
        local details = mark[3]
        local end_row = details and details.end_row or start_row
        local start_col = mark[2]
        local end_col = details and details.end_col or 0

        extmark_info[i] = {
          start_row = start_row,
          end_row = end_row,
          start_col = start_col,
          end_col = end_col,
          is_zero_width = (start_row == end_row) and (start_col == end_col),
        }
      end
    end
  end

  -- Second pass: determine which blocks are deleted vs valid
  -- A block is deleted if:
  -- 1. Its extmark is zero-width AND at the same position as another block's extmark
  -- 2. Its extmark overlaps with another block AND the line content doesn't match this block
  -- 3. Its extmark is beyond buffer bounds
  local deleted_blocks = {} -- block index -> true

  -- Build a map of which blocks claim each row
  ---@type table<integer, integer[]> row -> list of block indices
  local row_to_blocks = {}
  for i, info in pairs(extmark_info) do
    local row = info.start_row
    if not row_to_blocks[row] then
      row_to_blocks[row] = {}
    end
    table.insert(row_to_blocks[row], i)
  end

  for i, info in pairs(extmark_info) do
    local block = blocks[i]
    local block_type = block:get_type()

    if info.is_zero_width then
      -- Check if there's another block (with content) at the same position
      local found_content_block = false
      for j, other_info in pairs(extmark_info) do
        if i ~= j and not other_info.is_zero_width then
          -- Check if the zero-width extmark is at the start of a content block
          if info.start_row == other_info.start_row and info.start_col == other_info.start_col then
            found_content_block = true
            break
          end
        end
      end

      if found_content_block then
        deleted_blocks[i] = true
        log.debug('Block marked as deleted (zero-width at content block position)', {
          index = i,
          block_type = block_type,
        })
      else
        -- Zero-width but no other block at same position
        -- Check if the line has content (block content may still exist)
        local line_content = ''
        if info.start_row < total_lines then
          local lines_at_row = vim.api.nvim_buf_get_lines(bufnr, info.start_row, info.start_row + 1, false)
          line_content = lines_at_row[1] or ''
        end

        -- Special handling for divider blocks
        -- Divider's get_text() returns '' but its expected content is '---'
        if block_type == 'divider' then
          if line_content ~= '---' then
            deleted_blocks[i] = true
            log.debug('Block marked as deleted (divider content mismatch)', {
              index = i,
              block_type = block_type,
              line_content = line_content:sub(1, 30),
            })
          else
            log.debug('Divider block still present', {
              index = i,
              block_type = block_type,
            })
          end
        else
          -- Get the block's original text to compare
          local original_text = block.original_text or block:get_text() or ''

          if #line_content == 0 and #original_text > 0 then
            -- Line is empty but block originally had content - block was deleted
            deleted_blocks[i] = true
            log.debug('Block marked as deleted (zero-width with empty line, had content)', {
              index = i,
              block_type = block_type,
              original_text_preview = original_text:sub(1, 20),
            })
          elseif #line_content == 0 and #original_text == 0 then
            -- Line is empty and block was originally empty - NOT deleted, just empty
            log.debug('Block is empty but not deleted (originally empty)', {
              index = i,
              block_type = block_type,
            })
          end
        end
      end
    else
      -- Non-zero-width extmark, but check for overlapping blocks on same row
      local blocks_on_row = row_to_blocks[info.start_row] or {}
      if #blocks_on_row > 1 then
        -- Multiple blocks claim this row - need to check which one actually owns it
        local line_content = ''
        if info.start_row < total_lines then
          local lines_at_row = vim.api.nvim_buf_get_lines(bufnr, info.start_row, info.start_row + 1, false)
          line_content = lines_at_row[1] or ''
        end

        -- For divider blocks, check if the line is actually '---'
        if block_type == 'divider' then
          if line_content ~= '---' then
            deleted_blocks[i] = true
            log.debug('Block marked as deleted (divider at non-divider line)', {
              index = i,
              block_type = block_type,
              line_content = line_content:sub(1, 30),
            })
          end
        end
        -- For other single-line read-only blocks, similar checks could be added
      end
    end
  end

  -- Also check for extmark positions beyond buffer bounds
  for i, info in pairs(extmark_info) do
    if info.start_row >= total_lines then
      deleted_blocks[i] = true
      log.debug('Block marked as deleted (beyond buffer bounds)', {
        index = i,
        block_type = blocks[i]:get_type(),
      })
    end
  end

  -- Third pass: assign line ranges
  for i, block in ipairs(blocks) do
    local info = extmark_info[i]

    if not info then
      -- No extmark info - block was deleted or never tracked
      block:set_line_range(nil, nil)
      log.debug('Block marked as deleted (no extmark)', {
        index = i,
        block_type = block:get_type(),
      })
    elseif deleted_blocks[i] then
      block:set_line_range(nil, nil)
    else
      -- Valid block - set line range from extmark
      local start_line = info.start_row + 1
      local end_line = info.end_row + 1

      if start_line <= end_line then
        block:set_line_range(start_line, end_line)
        log.debug('Block line range updated from extmark', {
          index = i,
          block_type = block:get_type(),
          start_line = start_line,
          end_line = end_line,
        })
      else
        block:set_line_range(nil, nil)
        log.debug('Block marked as deleted (invalid range)', {
          index = i,
          block_type = block:get_type(),
        })
      end
    end
  end
end

---Clear mapping for a buffer
---@param bufnr integer
function M.clear(bufnr)
  buffer_blocks[bufnr] = nil
  block_extmarks[bufnr] = nil

  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    vim.api.nvim_buf_clear_namespace(bufnr, readonly_ns_id, 0, -1)
  end
end

---Check if buffer has blocks mapped
---@param bufnr integer
---@return boolean
function M.has_blocks(bufnr)
  return buffer_blocks[bufnr] ~= nil and #buffer_blocks[bufnr] > 0
end

---Get block count
---@param bufnr integer
---@return integer
function M.get_block_count(bufnr)
  local blocks = buffer_blocks[bufnr]
  return blocks and #blocks or 0
end

---Get namespace ID for external use
---@return integer
function M.get_namespace()
  return ns_id
end

---Get read-only namespace ID
---@return integer
function M.get_readonly_namespace()
  return readonly_ns_id
end

---Add a newly created block to the model with extmark
---Called after sync successfully creates a block in Notion
---Bug #10.4 fix: Prevents orphan re-detection on subsequent syncs
---@param bufnr integer Buffer number
---@param block neotion.Block Block to add
---@param start_line integer 1-indexed start line in buffer
---@param end_line integer 1-indexed end line in buffer
---@param after_block_id string|nil ID of block this block should come after
function M.add_block(bufnr, block, start_line, end_line, after_block_id)
  local log = require('neotion.log').get_logger('mapping')
  local blocks = buffer_blocks[bufnr]

  if not blocks then
    log.warn('Cannot add block: no blocks array for buffer', { bufnr = bufnr })
    return
  end

  -- Find insertion index based on after_block_id
  local insert_index = #blocks + 1 -- Default: append at end

  if after_block_id then
    for i, b in ipairs(blocks) do
      if b:get_id() == after_block_id then
        insert_index = i + 1
        break
      end
    end
  end

  -- Set line range on block
  block:set_line_range(start_line, end_line)

  -- Insert block at correct position
  table.insert(blocks, insert_index, block)

  log.debug('Block added to model', {
    block_id = block:get_id(),
    block_type = block:get_type(),
    insert_index = insert_index,
    start_line = start_line,
    end_line = end_line,
    after_block_id = after_block_id,
  })

  -- Recreate extmarks for all blocks (simplest approach for now)
  -- This ensures proper extmark ordering after insertion
  if vim.api.nvim_buf_is_valid(bufnr) then
    M.rebuild_extmarks(bufnr)
  end
end

---Rebuild extmarks for all blocks based on their current line ranges
---Used after adding new blocks to ensure proper extmark tracking
---@param bufnr integer Buffer number
function M.rebuild_extmarks(bufnr)
  local log = require('neotion.log').get_logger('mapping')
  local blocks = buffer_blocks[bufnr]

  if not blocks then
    return
  end

  -- Clear existing extmarks
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, readonly_ns_id, 0, -1)
  block_extmarks[bufnr] = {}

  local total_lines = vim.api.nvim_buf_line_count(bufnr)

  for i, block in ipairs(blocks) do
    local start_line, end_line = block:get_line_range()

    if start_line and end_line and start_line <= total_lines then
      local end_row = math.min(end_line, total_lines) - 1 -- 0-indexed
      local line_content = vim.api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1] or ''

      local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, start_line - 1, 0, {
        end_row = end_row,
        end_col = #line_content,
        right_gravity = true,
        end_right_gravity = false,
      })
      block_extmarks[bufnr][i] = extmark_id

      -- Add read-only highlighting for non-editable blocks
      if not block:is_editable() then
        for line = start_line, end_line do
          vim.api.nvim_buf_set_extmark(bufnr, readonly_ns_id, line - 1, 0, {
            line_hl_group = 'NeotionReadOnly',
            priority = 100,
          })
        end
      end
    end
  end

  log.debug('Extmarks rebuilt', {
    bufnr = bufnr,
    block_count = #blocks,
    extmark_count = vim.tbl_count(block_extmarks[bufnr] or {}),
  })
end

---@class neotion.OrphanLineRange
---@field start_line integer Start line (1-indexed)
---@field end_line integer End line (1-indexed)
---@field content string[] Line contents
---@field after_block_id string|nil ID of block before this orphan range

---Detect lines not owned by any block (orphan lines)
---These are lines created by user editing that don't belong to any existing block
---@param bufnr integer Buffer number
---@param header_lines integer Number of header lines to skip
---@return neotion.OrphanLineRange[] List of orphan line ranges
function M.detect_orphan_lines(bufnr, header_lines)
  local log = require('neotion.log').get_logger('mapping')
  local blocks = buffer_blocks[bufnr] or {}

  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  local start_line = header_lines + 1 -- First content line after header

  log.debug('detect_orphan_lines starting', {
    bufnr = bufnr,
    header_lines = header_lines,
    total_lines = total_lines,
    block_count = #blocks,
  })

  -- If no content lines exist, return empty
  if start_line > total_lines then
    return {}
  end

  -- Build set of owned lines
  ---@type table<integer, neotion.Block>
  local line_to_block = {}
  for _, block in ipairs(blocks) do
    local block_start, block_end = block:get_line_range()
    if block_start and block_end then
      for line = block_start, block_end do
        line_to_block[line] = block
      end
    end
  end

  -- Find orphan ranges
  ---@type neotion.OrphanLineRange[]
  local orphans = {}
  local current_orphan = nil
  local last_block_id = nil

  for line = start_line, total_lines do
    local owner = line_to_block[line]
    if owner then
      -- Line is owned by a block
      if current_orphan then
        -- End current orphan range
        table.insert(orphans, current_orphan)
        current_orphan = nil
      end
      last_block_id = owner:get_id()
    else
      -- Line is orphan
      if not current_orphan then
        -- Start new orphan range
        local content = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)
        current_orphan = {
          start_line = line,
          end_line = line,
          content = content,
          after_block_id = last_block_id,
        }
      else
        -- Extend current orphan range
        current_orphan.end_line = line
        local line_content = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)
        table.insert(current_orphan.content, line_content[1] or '')
      end
    end
  end

  -- Don't forget last orphan range
  if current_orphan then
    table.insert(orphans, current_orphan)
  end

  log.debug('detect_orphan_lines complete', {
    orphan_count = #orphans,
  })

  return orphans
end

return M
