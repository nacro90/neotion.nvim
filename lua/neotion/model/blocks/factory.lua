--- Block factory for creating new blocks from buffer content
--- Handles orphan lines and type detection
---@module 'neotion.model.blocks.factory'

local log = require('neotion.log').get_logger('model.blocks.factory')

local M = {}

--- Generate a temporary local ID for new blocks
---@return string
local function generate_temp_id()
  return 'temp_' .. tostring(os.time()) .. '_' .. tostring(math.random(1000, 9999))
end

--- Create a new block from line content
---@param lines string[] Line contents (may be multiple for multi-line content)
---@param after_block_id string|nil ID of block after which this block should be inserted
---@return neotion.Block|nil block New block instance, or nil if content is empty/invalid
function M.create_from_lines(lines, after_block_id)
  if not lines or #lines == 0 then
    return nil
  end

  local detection = require('neotion.model.blocks.detection')
  local registry = require('neotion.model.registry')

  -- Get first line for type detection
  local first_line = lines[1] or ''

  -- Skip empty lines (they don't create blocks)
  local all_empty = true
  for _, line in ipairs(lines) do
    if line ~= '' then
      all_empty = false
      break
    end
  end

  if all_empty then
    log.debug('Skipping empty orphan lines', { line_count = #lines })
    return nil
  end

  -- Detect block type from first line content
  local detected_type, prefix = detection.detect_type(first_line)
  local block_type = detected_type or 'paragraph'

  log.debug('Detected block type for orphan', {
    first_line = first_line:sub(1, 50),
    detected_type = detected_type,
    prefix = prefix,
    final_type = block_type,
  })

  -- Strip prefix from content if needed
  local content
  if #lines == 1 then
    content = detection.strip_prefix(first_line, prefix)
  else
    -- Multi-line content: strip prefix from first line, join all
    local processed_lines = {}
    processed_lines[1] = detection.strip_prefix(lines[1], prefix)
    for i = 2, #lines do
      processed_lines[i] = lines[i]
    end
    content = table.concat(processed_lines, '\n')
  end

  -- Create minimal raw data structure for new block
  local raw = M.create_raw_block(block_type, content)

  -- Create block using registry deserialize
  local block = registry.deserialize(raw)

  if block then
    -- Mark as new block
    block.is_new = true
    block.after_block_id = after_block_id
    block.temp_id = generate_temp_id()

    log.info('Created new block from orphan lines', {
      temp_id = block.temp_id,
      block_type = block_type,
      after_block_id = after_block_id,
      content_preview = content:sub(1, 30),
    })
  end

  return block
end

--- Create raw block data for Notion API
---@param block_type string Block type
---@param content string Text content
---@return table raw Notion API compatible raw block data
function M.create_raw_block(block_type, content)
  -- Handle special block types
  if block_type == 'divider' then
    return {
      type = 'divider',
      id = nil,
      divider = {},
    }
  end

  -- Text-based blocks (paragraph, heading, bullet, quote, etc.)
  local rich_text = {
    {
      type = 'text',
      text = { content = content, link = nil },
      plain_text = content,
      annotations = {
        bold = false,
        italic = false,
        strikethrough = false,
        underline = false,
        code = false,
        color = 'default',
      },
    },
  }

  local raw = {
    type = block_type,
    id = nil,
    [block_type] = {
      rich_text = rich_text,
    },
  }

  -- Add special fields for certain block types
  if block_type == 'heading_1' or block_type == 'heading_2' or block_type == 'heading_3' then
    raw[block_type].is_toggleable = false
  end

  return raw
end

--- Create blocks from orphan line ranges
---@param orphans neotion.OrphanLineRange[] Orphan line ranges from mapping.detect_orphan_lines
---@return neotion.Block[] blocks New block instances
function M.create_from_orphans(orphans)
  local blocks = {}

  for _, orphan in ipairs(orphans) do
    local block = M.create_from_lines(orphan.content, orphan.after_block_id)
    if block then
      -- Store line range info for positioning
      block.orphan_start_line = orphan.start_line
      block.orphan_end_line = orphan.end_line
      table.insert(blocks, block)
    end
  end

  log.debug('Created blocks from orphans', {
    orphan_count = #orphans,
    block_count = #blocks,
  })

  return blocks
end

return M
