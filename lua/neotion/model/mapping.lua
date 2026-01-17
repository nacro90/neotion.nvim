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
  local log = require('neotion.log').get_logger('mapping')
  local blocks = buffer_blocks[bufnr]
  if not blocks then
    return
  end

  -- Debug: count total blocks including children
  local function count_blocks_recursive(block_list)
    local count = 0
    for _, b in ipairs(block_list) do
      count = count + 1
      count = count + count_blocks_recursive(b:get_children())
    end
    return count
  end
  local total_blocks = count_blocks_recursive(blocks)
  log.debug('setup_extmarks starting', {
    top_level_blocks = #blocks,
    total_blocks_with_children = total_blocks,
    header_lines = header_lines,
  })

  -- Clear existing extmarks
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, readonly_ns_id, 0, -1)
  block_extmarks[bufnr] = {}

  local current_line = header_lines + 1 -- 1-indexed, after header
  local extmark_index = 0

  ---Setup extmarks for a block and its children recursively
  ---@param block neotion.Block
  ---@param depth integer Current nesting depth
  ---@return integer Next available line number
  local function setup_block_extmarks(block, depth)
    local format_opts = { indent = depth }
    local block_lines = block:format(format_opts)
    local line_count = #block_lines
    local children_count = #block:get_children()

    log.debug('setup_block_extmarks processing', {
      block_id = block:get_id(),
      block_type = block:get_type(),
      depth = depth,
      line_count = line_count,
      children_count = children_count,
      current_line = current_line,
    })

    -- Set line range on block (just for this block's own content, not children)
    local block_start = current_line
    local block_end = current_line + line_count - 1
    block:set_line_range(block_start, block_end)

    -- Create extmark at block start
    if vim.api.nvim_buf_is_valid(bufnr) then
      local end_row = block_end - 1 -- 0-indexed end row
      local line_content = vim.api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1] or ''
      extmark_index = extmark_index + 1
      local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, block_start - 1, 0, {
        end_row = end_row,
        end_col = #line_content,
        right_gravity = true,
        end_right_gravity = false,
      })
      block_extmarks[bufnr][extmark_index] = extmark_id

      -- Add read-only highlighting for non-editable blocks
      if not block:is_editable() then
        for line = block_start, block_end do
          vim.api.nvim_buf_set_extmark(bufnr, readonly_ns_id, line - 1, 0, {
            line_hl_group = 'NeotionReadOnly',
            priority = 100,
          })
        end
      end
    end

    current_line = current_line + line_count

    -- Recursively setup extmarks for children
    local children = block:get_children()
    for _, child in ipairs(children) do
      setup_block_extmarks(child, depth + 1)
    end
  end

  -- Process all top-level blocks
  for _, block in ipairs(blocks) do
    setup_block_extmarks(block, 0)
  end

  log.debug('setup_extmarks completed', {
    total_extmarks = extmark_index,
    top_level_blocks = #blocks,
  })
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

  ---Search for block at line recursively
  ---@param block neotion.Block
  ---@return neotion.Block|nil
  local function find_block_at_line(block)
    -- Check this block first
    if block:contains_line(line) then
      return block
    end

    -- Check children recursively
    for _, child in ipairs(block:get_children()) do
      local found = find_block_at_line(child)
      if found then
        return found
      end
    end

    return nil
  end

  -- Search through all top-level blocks
  for _, block in ipairs(blocks) do
    local found = find_block_at_line(block)
    if found then
      return found
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

  ---Search for block by ID recursively
  ---@param block neotion.Block
  ---@return neotion.Block|nil
  local function find_block_by_id(block)
    if block:get_id() == block_id then
      return block
    end

    -- Search children recursively
    for _, child in ipairs(block:get_children()) do
      local found = find_block_by_id(child)
      if found then
        return found
      end
    end

    return nil
  end

  for _, block in ipairs(blocks) do
    local found = find_block_by_id(block)
    if found then
      return found
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

  ---Collect dirty blocks recursively
  ---@param block neotion.Block
  local function collect_dirty(block)
    if block:is_dirty() then
      table.insert(dirty, block)
    end
    for _, child in ipairs(block:get_children()) do
      collect_dirty(child)
    end
  end

  for _, block in ipairs(blocks) do
    collect_dirty(block)
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

  ---Collect editable blocks recursively
  ---@param block neotion.Block
  local function collect_editable(block)
    if block:is_editable() then
      table.insert(editable, block)
    end
    for _, child in ipairs(block:get_children()) do
      collect_editable(child)
    end
  end

  for _, block in ipairs(blocks) do
    collect_editable(block)
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

  -- Build flat list of all blocks (including children) in same order as setup_extmarks
  -- This ensures extmark indices match block indices
  ---@type neotion.Block[]
  local all_blocks = {}

  ---Recursively collect blocks in extmark order (parent first, then children)
  ---@param block neotion.Block
  local function collect_blocks(block)
    table.insert(all_blocks, block)
    local children = block:get_children()
    for _, child in ipairs(children) do
      collect_blocks(child)
    end
  end

  for _, block in ipairs(blocks) do
    collect_blocks(block)
  end

  log.debug('refresh_line_ranges starting', {
    block_count = #blocks,
    all_blocks_count = #all_blocks,
    extmark_count = vim.tbl_count(extmarks),
  })

  -- Get total line count to validate positions
  local total_lines = vim.api.nvim_buf_line_count(bufnr)

  -- First pass: collect extmark info for all blocks (including children)
  ---@type table<integer, {start_row: integer, end_row: integer, start_col: integer, end_col: integer, is_zero_width: boolean}>
  local extmark_info = {}

  for i, _ in ipairs(all_blocks) do
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
    local block = all_blocks[i]
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
        block_type = all_blocks[i]:get_type(),
      })
    end
  end

  -- Third pass: assign line ranges for all blocks (including children)
  for i, block in ipairs(all_blocks) do
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
---@param after_block_id string|nil ID of block this block should come after (for siblings)
---@param parent_block_id string|nil ID of parent block (for children)
function M.add_block(bufnr, block, start_line, end_line, after_block_id, parent_block_id)
  local log = require('neotion.log').get_logger('mapping')
  local blocks = buffer_blocks[bufnr]

  if not blocks then
    log.warn('Cannot add block: no blocks array for buffer', { bufnr = bufnr })
    return
  end

  -- Set line range on block
  block:set_line_range(start_line, end_line)

  -- If parent_block_id is provided, add as child of parent
  if parent_block_id then
    -- Find parent block recursively
    local parent = M.get_block_by_id(bufnr, parent_block_id)
    if parent and type(parent.add_child) == 'function' then
      parent:add_child(block)
      log.debug('Block added as child of parent', {
        block_id = block:get_id(),
        block_type = block:get_type(),
        parent_id = parent_block_id,
        start_line = start_line,
        end_line = end_line,
      })
    else
      log.warn('Parent block not found or does not support children', {
        parent_block_id = parent_block_id,
        block_id = block:get_id(),
      })
      -- Fallback: add as top-level block
      table.insert(blocks, block)
    end
  else
    -- Add as top-level sibling
    local insert_index = #blocks + 1 -- Default: append at end

    if after_block_id then
      for i, b in ipairs(blocks) do
        if b:get_id() == after_block_id then
          insert_index = i + 1
          break
        end
      end
    end

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
  end

  -- Recreate extmarks and re-render visual elements
  -- This ensures proper extmark ordering and virtual lines positioning after insertion
  if vim.api.nvim_buf_is_valid(bufnr) then
    M.rebuild_extmarks(bufnr)

    -- Re-apply virtual lines and gutter icons (Bug 11.3 fix)
    -- rebuild_extmarks only handles block extmarks, not visual elements
    local extmarks = require('neotion.render.extmarks')
    local render = require('neotion.render.init')
    extmarks.clear_virtual_lines(bufnr)
    extmarks.clear_gutter_icons(bufnr)
    render.apply_block_spacing(bufnr)
    render.apply_gutter_icons(bufnr)
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
  local extmark_index = 0

  ---Rebuild extmarks for a block and its children recursively
  ---@param block neotion.Block
  local function rebuild_block_extmarks(block)
    local start_line, end_line = block:get_line_range()

    if start_line and end_line and start_line <= total_lines then
      local end_row = math.min(end_line, total_lines) - 1 -- 0-indexed
      local line_content = vim.api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1] or ''

      extmark_index = extmark_index + 1
      local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, start_line - 1, 0, {
        end_row = end_row,
        end_col = #line_content,
        right_gravity = true,
        end_right_gravity = false,
      })
      block_extmarks[bufnr][extmark_index] = extmark_id

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

    -- Recursively rebuild extmarks for children
    local children = block:get_children()
    for _, child in ipairs(children) do
      rebuild_block_extmarks(child)
    end
  end

  -- Process all top-level blocks and their children
  for _, block in ipairs(blocks) do
    rebuild_block_extmarks(block)
  end

  log.debug('Extmarks rebuilt', {
    bufnr = bufnr,
    block_count = #blocks,
    extmark_count = extmark_index,
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

-- TODO(neotion:FEAT-15:MEDIUM): Make indent size configurable via config.indent_size
-- Currently hardcoded as 2 spaces. Should read from vim.bo.shiftwidth or config option.
-- Also update input/editing.lua which has hardcoded '  ' indent strings.

---@type integer
local INDENT_SIZE = 2 -- 2 spaces per indent level

---Detect the indent level of a line based on leading spaces
---@param line string Line content
---@return integer Indent level (0 for no indent, 1 for 2 spaces, etc.)
function M.detect_indent_level(line)
  if not line or line == '' then
    return 0
  end

  -- Count leading spaces
  local leading_spaces = 0
  for i = 1, #line do
    if line:sub(i, i) == ' ' then
      leading_spaces = leading_spaces + 1
    else
      break
    end
  end

  -- Calculate indent level: floor(spaces / INDENT_SIZE)
  return math.floor(leading_spaces / INDENT_SIZE)
end

---Strip leading indent from a line
---@param line string Line content
---@param indent_level integer Indent level to strip
---@return string Stripped line
local function strip_indent(line, indent_level)
  if not line or indent_level <= 0 then
    return line or ''
  end

  local spaces_to_strip = indent_level * INDENT_SIZE
  if #line >= spaces_to_strip then
    return line:sub(spaces_to_strip + 1)
  end
  return line
end

---Find potential parent block for an indented orphan line
---Looks backwards from the orphan line to find a block at lower indent that supports children
---@param bufnr integer Buffer number
---@param orphan_line integer 1-indexed line number of the orphan
---@param orphan_indent integer Indent level of the orphan
---@return string|nil Parent block ID if found, nil otherwise
function M.find_parent_by_indent(bufnr, orphan_line, orphan_indent)
  -- Non-indented lines can't have parents
  if orphan_indent <= 0 then
    return nil
  end

  local blocks = buffer_blocks[bufnr] or {}
  if #blocks == 0 then
    return nil
  end

  -- We need to find a block that:
  -- 1. Ends before orphan_line
  -- 2. Is at a lower indent level (orphan_indent - 1 or less)
  -- 3. supports_children() returns true
  -- 4. Is the closest such block to the orphan

  -- First, find all candidate blocks that end before the orphan line
  ---@type table<integer, {block: neotion.Block, end_line: integer}>
  local candidates = {}

  for _, block in ipairs(blocks) do
    local block_start, block_end = block:get_line_range()
    if block_start and block_end and block_end < orphan_line then
      -- Check if block supports children
      local supports = false
      if type(block.supports_children) == 'function' then
        supports = block:supports_children()
      end

      if supports then
        table.insert(candidates, {
          block = block,
          end_line = block_end,
          start_line = block_start,
        })
      end
    end
  end

  if #candidates == 0 then
    return nil
  end

  -- Sort by end_line descending (closest to orphan first)
  table.sort(candidates, function(a, b)
    return a.end_line > b.end_line
  end)

  -- Find the closest block that is at a lower indent level
  -- For now, we use a simple heuristic: the closest block that supports children
  -- and is between the orphan and any intervening non-indented line

  for _, candidate in ipairs(candidates) do
    -- Check if there's a non-indented block between candidate and orphan
    -- If there is, candidate can't be the parent
    local is_valid_parent = true

    -- Check all blocks between candidate and orphan
    for _, other_block in ipairs(blocks) do
      local other_start, other_end = other_block:get_line_range()
      if other_start and other_end then
        -- Check if other_block is between candidate and orphan
        if other_start > candidate.end_line and other_end < orphan_line then
          -- There's a block between - check if it's at indent 0 (sibling level)
          -- If it's at indent 0, it breaks the parent chain
          -- For simplicity, we check if it doesn't support children (likely a sibling)
          local other_supports = false
          if type(other_block.supports_children) == 'function' then
            other_supports = other_block:supports_children()
          end
          if not other_supports then
            is_valid_parent = false
            break
          end
        end
      end
    end

    if is_valid_parent then
      return candidate.block:get_id()
    end
  end

  return nil
end

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

  -- Build set of owned lines (including children recursively)
  ---@type table<integer, neotion.Block>
  local line_to_block = {}

  ---Add block and its children to line_to_block map recursively
  ---@param block neotion.Block
  local function add_block_lines(block)
    local block_start, block_end = block:get_line_range()
    if block_start and block_end then
      for line = block_start, block_end do
        line_to_block[line] = block
      end
    end
    -- Recursively add children
    local children = block:get_children()
    for _, child in ipairs(children) do
      add_block_lines(child)
    end
  end

  for _, block in ipairs(blocks) do
    add_block_lines(block)
  end

  -- Find orphan ranges, grouping by indent level
  ---@type neotion.OrphanLineRange[]
  local orphans = {}
  local current_orphan = nil
  local last_block_id = nil
  local current_indent = nil

  for line = start_line, total_lines do
    local owner = line_to_block[line]
    if owner then
      -- Line is owned by a block
      if current_orphan then
        -- End current orphan range
        table.insert(orphans, current_orphan)
        current_orphan = nil
        current_indent = nil
      end
      -- Only update last_block_id for top-level blocks (depth 0)
      -- Child blocks should not be used as after_block_id for page-level orphans
      if owner.depth == 0 then
        last_block_id = owner:get_id()
      end
    else
      -- Line is orphan - get content and detect indent
      local line_content = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1] or ''
      local line_indent = M.detect_indent_level(line_content)

      if not current_orphan then
        -- Start new orphan range
        local stripped_content = strip_indent(line_content, line_indent)
        local parent_id = M.find_parent_by_indent(bufnr, line, line_indent)

        current_orphan = {
          start_line = line,
          end_line = line,
          content = { stripped_content },
          after_block_id = parent_id and nil or last_block_id,
          parent_block_id = parent_id,
          indent_level = line_indent,
        }
        current_indent = line_indent

        -- For indented lines (children), each line is a separate block
        -- Commit immediately and reset
        if line_indent > 0 then
          table.insert(orphans, current_orphan)
          current_orphan = nil
          current_indent = nil
        end
      elseif line_indent ~= current_indent then
        -- Indent changed - end current orphan and start new one
        table.insert(orphans, current_orphan)

        local stripped_content = strip_indent(line_content, line_indent)
        local parent_id = M.find_parent_by_indent(bufnr, line, line_indent)

        current_orphan = {
          start_line = line,
          end_line = line,
          content = { stripped_content },
          after_block_id = parent_id and nil or last_block_id,
          parent_block_id = parent_id,
          indent_level = line_indent,
        }
        current_indent = line_indent

        -- For indented lines (children), each line is a separate block
        if line_indent > 0 then
          table.insert(orphans, current_orphan)
          current_orphan = nil
          current_indent = nil
        end
      elseif line_indent > 0 then
        -- Same indent but indented (child) - each line is separate block
        table.insert(orphans, current_orphan)

        local stripped_content = strip_indent(line_content, line_indent)
        local parent_id = M.find_parent_by_indent(bufnr, line, line_indent)

        current_orphan = {
          start_line = line,
          end_line = line,
          content = { stripped_content },
          after_block_id = parent_id and nil or last_block_id,
          parent_block_id = parent_id,
          indent_level = line_indent,
        }
        table.insert(orphans, current_orphan)
        current_orphan = nil
        current_indent = nil
      else
        -- Same indent at top level (indent 0) - extend current orphan range
        current_orphan.end_line = line
        local stripped_content = strip_indent(line_content, line_indent)
        table.insert(current_orphan.content, stripped_content)
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
