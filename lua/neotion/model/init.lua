---Model Layer Public API for Neotion
---Provides block abstraction for zero data loss editing
---@class neotion.Model
local M = {}

local log = require('neotion.log').get_logger('model')

---Deserialize blocks from Notion API JSON
---@param raw_blocks table[] Raw Notion API blocks
---@return neotion.Block[]
function M.deserialize_blocks(raw_blocks)
  local registry = require('neotion.model.registry')
  return registry.deserialize_all(raw_blocks)
end

---Setup buffer with blocks and extmark mapping
---@param bufnr integer Buffer number
---@param blocks neotion.Block[] Deserialized blocks
---@param header_lines integer Number of header lines to skip
function M.setup_buffer(bufnr, blocks, header_lines)
  local mapping = require('neotion.model.mapping')
  mapping.setup(bufnr, blocks)
  mapping.setup_extmarks(bufnr, header_lines)
end

---Format blocks to buffer lines
---@param blocks neotion.Block[]
---@param opts? {indent_size?: integer}
---@return string[]
function M.format_blocks(blocks, opts)
  opts = opts or {}
  local lines = {}

  for _, block in ipairs(blocks) do
    local block_lines = block:format(opts)
    vim.list_extend(lines, block_lines)
  end

  return lines
end

---Get block at a specific line
---@param bufnr integer
---@param line integer 1-indexed line number
---@return neotion.Block|nil
function M.get_block_at_line(bufnr, line)
  local mapping = require('neotion.model.mapping')
  return mapping.get_block_at_line(bufnr, line)
end

---Get all blocks for a buffer
---@param bufnr integer
---@return neotion.Block[]
function M.get_blocks(bufnr)
  local mapping = require('neotion.model.mapping')
  return mapping.get_blocks(bufnr)
end

---Get only dirty (modified) blocks
---@param bufnr integer
---@return neotion.Block[]
function M.get_dirty_blocks(bufnr)
  local mapping = require('neotion.model.mapping')
  return mapping.get_dirty_blocks(bufnr)
end

---Get only editable blocks
---@param bufnr integer
---@return neotion.Block[]
function M.get_editable_blocks(bufnr)
  local mapping = require('neotion.model.mapping')
  return mapping.get_editable_blocks(bufnr)
end

---Sync blocks from buffer content (detect changes)
---@param bufnr integer
function M.sync_blocks_from_buffer(bufnr)
  local mapping = require('neotion.model.mapping')

  log.debug('sync_blocks_from_buffer called', { bufnr = bufnr })

  -- Refresh line ranges from extmarks
  mapping.refresh_line_ranges(bufnr)

  local blocks = mapping.get_blocks(bufnr)
  log.debug('Total blocks in buffer', { count = #blocks })

  for i, block in ipairs(blocks) do
    if block:is_editable() then
      local start_line, end_line = block:get_line_range()
      if start_line and end_line then
        local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

        local was_dirty = block:is_dirty()
        local old_text = block:get_text()

        block:update_from_lines(lines)

        local is_dirty_now = block:is_dirty()
        local new_text = block:get_text()

        if is_dirty_now and not was_dirty then
          log.debug('Block became dirty', {
            index = i,
            block_id = block:get_id(),
            block_type = block:get_type(),
            old_text_preview = old_text:sub(1, 30),
            new_text_preview = new_text:sub(1, 30),
            line_range = { start_line, end_line },
          })
        elseif is_dirty_now then
          log.debug('Block is dirty', {
            index = i,
            block_id = block:get_id(),
            block_type = block:get_type(),
          })
        end
      else
        log.warn('Block has no line range', {
          index = i,
          block_id = block:get_id(),
          block_type = block:get_type(),
        })
      end
    end
  end
end

---Serialize a single block to Notion API JSON
---@param block neotion.Block
---@return table Notion API JSON
function M.serialize_block(block)
  return block:serialize()
end

---Check if a page is fully editable
---@param blocks neotion.Block[]
---@return boolean is_fully_editable
---@return string[] unsupported_types
function M.check_editability(blocks)
  local registry = require('neotion.model.registry')
  return registry.check_editability(blocks)
end

---Check if a block type is supported
---@param block_type string
---@return boolean
function M.is_supported(block_type)
  local registry = require('neotion.model.registry')
  return registry.is_supported(block_type)
end

---Clear all block data for a buffer
---@param bufnr integer
function M.clear(bufnr)
  local mapping = require('neotion.model.mapping')
  mapping.clear(bufnr)
end

---Check if buffer has block mapping
---@param bufnr integer
---@return boolean
function M.has_blocks(bufnr)
  local mapping = require('neotion.model.mapping')
  return mapping.has_blocks(bufnr)
end

---Mark all blocks as clean (after successful sync)
---@param bufnr integer
function M.mark_all_clean(bufnr)
  local mapping = require('neotion.model.mapping')
  local blocks = mapping.get_blocks(bufnr)

  for _, block in ipairs(blocks) do
    block:set_dirty(false)
  end
end

---Get block by ID
---@param bufnr integer
---@param block_id string
---@return neotion.Block|nil
function M.get_block_by_id(bufnr, block_id)
  local mapping = require('neotion.model.mapping')
  return mapping.get_block_by_id(bufnr, block_id)
end

return M
