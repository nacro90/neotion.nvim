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
  local numbered_list_counter = 0

  for _, block in ipairs(blocks) do
    -- Track numbered list sequence
    if block.type == 'numbered_list_item' then
      numbered_list_counter = numbered_list_counter + 1
      if block.set_number then
        block:set_number(numbered_list_counter)
      end
    else
      -- Reset counter when encountering non-numbered-list block
      numbered_list_counter = 0
    end

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

  -- Refresh line ranges - this also detects deleted blocks
  mapping.refresh_line_ranges(bufnr)

  local blocks = mapping.get_blocks(bufnr)
  log.debug('Total blocks in buffer', { count = #blocks })

  for i, block in ipairs(blocks) do
    local start_line, end_line = block:get_line_range()

    -- Skip blocks with nil line range (deleted from buffer)
    if not start_line or not end_line then
      log.debug('Block skipped (deleted from buffer)', {
        index = i,
        block_id = block:get_id(),
        block_type = block:get_type(),
      })
    elseif block:is_editable() then
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

---Resolve icons for child_page blocks asynchronously
---When icons are resolved, updates block and refreshes buffer line
---@param bufnr integer
---@param blocks neotion.Block[]
---@param header_line_count integer Number of header lines (for calculating block line positions)
function M.resolve_child_page_icons(bufnr, blocks, header_line_count)
  local icon_resolver = require('neotion.model.icon_resolver')

  -- Helper to update icon in buffer (surgical replacement preserves extmarks)
  local function update_buffer_icon(blk, icon, source)
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end
      local start_line, _ = blk:get_line_range()
      if not start_line then
        return
      end
      local current_line = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, start_line, false)[1]
      if not current_line then
        return
      end

      -- Find leading spaces
      local leading_spaces = current_line:match('^(%s*)') or ''
      local icon_start_col = #leading_spaces

      -- Find the old icon - it ends at the space before the title
      -- Pattern: {spaces}{icon} {title}
      local after_spaces = current_line:sub(icon_start_col + 1)
      local old_icon = after_spaces:match('^([^ ]+)')

      if old_icon and old_icon ~= icon then
        local icon_end_col = icon_start_col + #old_icon

        -- Preserve modified state (icon updates are cosmetic, not user edits)
        local was_modified = vim.bo[bufnr].modified

        -- Replace just the icon using nvim_buf_set_text (preserves extmarks)
        vim.api.nvim_buf_set_text(
          bufnr,
          start_line - 1, -- 0-indexed line
          icon_start_col, -- start col (byte)
          start_line - 1, -- end line
          icon_end_col, -- end col (byte)
          { icon }
        )

        -- Restore modified state
        vim.bo[bufnr].modified = was_modified

        log.debug('Child page icon updated', {
          page_id = blk:get_page_id(),
          line = start_line,
          icon = icon,
          source = source,
        })

        -- Refresh buffer protection snapshot so icon change isn't reverted
        local protection = require('neotion.buffer.protection')
        protection.refresh(bufnr)
      end
    end)
  end

  for _, block in ipairs(blocks) do
    if block.type == 'child_page' and block.set_icon and block.get_page_id then
      local page_id = block:get_page_id()

      -- Try to get cached icon first (sync)
      local cached = icon_resolver.get_cached(page_id)
      if cached then
        block:set_icon(cached)
        log.debug('Child page icon set from cache', { page_id = page_id, icon = cached })
        -- Also update buffer line (buffer was rendered with default icon)
        update_buffer_icon(block, cached, 'cache')
      else
        -- Start async resolve
        icon_resolver.resolve(page_id, function(icon)
          if icon then
            block:set_icon(icon)
            log.debug('Child page icon resolved from API', { page_id = page_id, icon = icon })
            update_buffer_icon(block, icon, 'api')
          end
        end)
      end
    end
  end
end

return M
