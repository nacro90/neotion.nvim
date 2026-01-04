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

---Refresh line ranges from extmark positions
---Extmarks are automatically updated by Neovim when buffer content changes,
---so they reflect the true position of each block after edits like 'o' or 'dd'.
---@param bufnr integer
function M.refresh_line_ranges(bufnr)
  local blocks = buffer_blocks[bufnr]
  local extmarks = block_extmarks[bufnr]
  if not blocks or not extmarks then
    return
  end

  for i, block in ipairs(blocks) do
    local extmark_id = extmarks[i]
    if extmark_id then
      -- Get current extmark position (0-indexed)
      local mark = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns_id, extmark_id, { details = true })
      if mark and #mark >= 3 then
        local start_row = mark[1] -- 0-indexed
        local details = mark[3]
        local end_row = details and details.end_row or start_row

        -- Convert to 1-indexed line numbers
        block:set_line_range(start_row + 1, end_row + 1)
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
