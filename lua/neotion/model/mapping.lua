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
    -- Note: We use end_right_gravity = false to prevent extmarks from expanding
    -- when text is inserted at the boundary between blocks
    if vim.api.nvim_buf_is_valid(bufnr) then
      local end_row = current_line + line_count - 1 - 1 -- 0-indexed end row
      local line_content = vim.api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1] or ''
      local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, current_line - 1, 0, {
        end_row = end_row,
        end_col = #line_content, -- End at last character of line
        right_gravity = false,
        end_right_gravity = false, -- Prevent expansion
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

return M
