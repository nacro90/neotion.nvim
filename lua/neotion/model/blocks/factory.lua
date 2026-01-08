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

  -- Find first non-empty line for type detection (Bug #10.1 fix)
  -- Scenario: User presses 'o', '<CR>', then types '## heading'
  -- Content = ['', '## heading', ''] - first line is empty
  local type_detection_line = nil
  local type_detection_index = nil
  for i, line in ipairs(lines) do
    if line ~= '' then
      type_detection_line = line
      type_detection_index = i
      break
    end
  end

  -- If all lines are empty, create empty paragraph (Bug #10.7.1 fix)
  -- Scenario: User presses 'o', then '<esc>' - creates empty orphan line
  -- Should sync as empty paragraph: { type: "paragraph", paragraph: { rich_text: [] } }
  if not type_detection_line then
    log.debug('Creating empty paragraph from empty orphan lines', { line_count = #lines })
    local raw = M.create_raw_block('paragraph', '', {})
    local registry = require('neotion.model.registry')
    local block = registry.deserialize(raw)
    if block then
      block.is_new = true
      block.after_block_id = after_block_id
      block.temp_id = generate_temp_id()
      log.info('Created empty paragraph block from orphan', {
        temp_id = block.temp_id,
        after_block_id = after_block_id,
      })
    end
    return block
  end

  -- Detect block type from first non-empty line content
  local detected_type, prefix = detection.detect_type(type_detection_line)
  local block_type = detected_type or 'paragraph'

  log.debug('Detected block type for orphan', {
    type_detection_line = type_detection_line:sub(1, 50),
    type_detection_index = type_detection_index,
    detected_type = detected_type,
    prefix = prefix,
    final_type = block_type,
  })

  -- Special handling for code blocks
  local language = nil
  if block_type == 'code' then
    -- Extract language from opening fence (e.g., "```lua" -> "lua")
    -- Sanitize by taking only first word (before any whitespace)
    local lang = type_detection_line:match('^```(.*)$')
    if lang and lang ~= '' then
      language = lang:gsub('^%s+', ''):gsub('%s.*$', '') -- Trim and take first word only
      if language == '' then
        language = 'plain text'
      end
    else
      language = 'plain text'
    end

    log.debug('Extracted language from code fence', {
      opening_fence = type_detection_line,
      language = language,
    })
  end

  -- Build content, trimming leading empty lines and stripping prefix from type line
  -- Content should start from the type detection line
  local content
  local content_lines = {}

  -- Start from type detection index, skip leading empty lines
  for i = type_detection_index, #lines do
    local line = lines[i]
    if i == type_detection_index then
      -- For code blocks, skip the opening fence entirely
      if block_type == 'code' then
        -- Don't add opening fence to content
      else
        -- Strip prefix from the type detection line
        table.insert(content_lines, detection.strip_prefix(line, prefix))
      end
    else
      -- Check if this is closing fence for code block
      if block_type == 'code' and line:match('^```$') then
        -- Don't add closing fence to content
      else
        table.insert(content_lines, line)
      end
    end
  end

  -- Trim trailing empty lines for cleaner content
  while #content_lines > 0 and content_lines[#content_lines] == '' do
    table.remove(content_lines)
  end

  content = table.concat(content_lines, '\n')

  -- Create minimal raw data structure for new block
  local raw = M.create_raw_block(block_type, content, { language = language })

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
---@param opts? {language?: string} Optional parameters (e.g., language for code blocks)
---@return table raw Notion API compatible raw block data
function M.create_raw_block(block_type, content, opts)
  opts = opts or {}

  -- Handle special block types
  if block_type == 'divider' then
    return {
      type = 'divider',
      id = nil,
      -- vim.empty_dict() ensures JSON encodes as {} (object) not [] (array)
      divider = vim.empty_dict(),
    }
  end

  -- Code block has different structure
  if block_type == 'code' then
    local rich_text = {
      {
        type = 'text',
        text = { content = content },
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

    return {
      type = 'code',
      id = nil,
      code = {
        rich_text = rich_text,
        language = opts.language or 'plain text',
        caption = {},
      },
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

--- Split orphan lines into segments by type boundaries
--- Different block types (quote, heading, bullet, divider, code) become separate blocks
--- Bug #10.2 fix: Prevents mixing different types into single block
--- Bug #10.4 fix: Track start_offset for each segment for model integration
---@param lines string[] Lines to split
---@return {lines: string[], type: string|nil, start_offset: integer}[] segments Split segments with offsets
local function split_orphan_by_type_boundaries(lines)
  local detection = require('neotion.model.blocks.detection')
  local segments = {}
  local current_segment = nil
  local in_code_block = false
  local code_block_start = nil

  for line_index, line in ipairs(lines) do
    local line_type = detection.detect_type(line)
    -- nil means paragraph (no special prefix)
    -- line_index is 1-based, offset should be 0-based
    local offset = line_index - 1

    -- Special handling for code blocks
    if in_code_block then
      -- Inside code block: accumulate lines until closing fence
      table.insert(current_segment.lines, line)

      -- Check for closing fence (exactly "```")
      if line:match('^```$') then
        -- End code block
        table.insert(segments, current_segment)
        current_segment = nil
        in_code_block = false
        code_block_start = nil
      end

    elseif line_type == 'code' then
      -- Start code block
      if current_segment then
        table.insert(segments, current_segment)
        current_segment = nil
      end

      current_segment = { type = 'code', lines = { line }, start_offset = offset }
      in_code_block = true
      code_block_start = offset

    -- Dividers are ALWAYS single-line blocks
    elseif line_type == 'divider' then
      if current_segment then
        table.insert(segments, current_segment)
        current_segment = nil
      end
      table.insert(segments, { type = 'divider', lines = { line }, start_offset = offset })

    -- List items are ALWAYS single-line blocks (each item is a separate Notion block)
    elseif line_type == 'bulleted_list_item' or line_type == 'numbered_list_item' then
      if current_segment then
        table.insert(segments, current_segment)
        current_segment = nil
      end
      table.insert(segments, { type = line_type, lines = { line }, start_offset = offset })

    -- Empty lines: end non-paragraph segments, accumulate in paragraph
    elseif line == '' then
      if current_segment then
        if current_segment.type ~= nil then
          -- End non-paragraph segment (heading, quote, bullet)
          table.insert(segments, current_segment)
          current_segment = nil
        else
          -- Paragraph can have empty lines (will be trimmed later)
          table.insert(current_segment.lines, line)
        end
      end
      -- Skip leading empty lines (no current segment)

      -- Type change: start new segment
    elseif current_segment and current_segment.type ~= line_type then
      table.insert(segments, current_segment)
      current_segment = { type = line_type, lines = { line }, start_offset = offset }

    -- Same type or new segment: continue/start
    else
      if not current_segment then
        current_segment = { type = line_type, lines = {}, start_offset = offset }
      end
      table.insert(current_segment.lines, line)
    end
  end

  -- Don't forget last segment (handles unclosed code blocks)
  -- Note: Unclosed code blocks (missing closing fence) will include all remaining lines
  -- This is intentional to preserve user content, but may need validation during sync
  if current_segment then
    table.insert(segments, current_segment)
  end

  -- Bug #10.7.1: If no segments created (all empty lines), create single paragraph segment
  -- Scenario: User presses 'o', then '<esc>' - orphan has only empty lines
  -- Should create one empty paragraph segment for sync
  if #segments == 0 and #lines > 0 then
    log.debug('Creating paragraph segment for all-empty orphan', {
      line_count = #lines,
    })
    table.insert(segments, { type = nil, lines = lines, start_offset = 0 })
  end

  log.debug('Split orphan into segments', {
    line_count = #lines,
    segment_count = #segments,
  })

  return segments
end

--- Create blocks from orphan line ranges
--- Now splits multi-line orphans by type boundaries (Bug #10.2 fix)
---@param orphans neotion.OrphanLineRange[] Orphan line ranges from mapping.detect_orphan_lines
---@return neotion.Block[] blocks New block instances
function M.create_from_orphans(orphans)
  local blocks = {}

  for _, orphan in ipairs(orphans) do
    -- Split orphan by type boundaries, getting line offsets for each segment
    local segments = split_orphan_by_type_boundaries(orphan.content)

    -- Track after_block_id for positioning - first block uses orphan's after_block_id
    -- subsequent blocks should be after the previous created block (handled by caller)
    local current_after_id = orphan.after_block_id

    for i, segment in ipairs(segments) do
      local block = M.create_from_lines(segment.lines, current_after_id)
      if block then
        -- Calculate actual line range within buffer
        -- Bug #10.4 fix: Use segment.start_offset for precise line ranges
        local segment_start = orphan.start_line + segment.start_offset
        local segment_end = segment_start + #segment.lines - 1

        block.orphan_start_line = segment_start
        block.orphan_end_line = segment_end
        block.segment_index = i

        log.debug('Block line range calculated', {
          segment_index = i,
          segment_start = segment_start,
          segment_end = segment_end,
          line_count = #segment.lines,
        })

        table.insert(blocks, block)

        -- Next block should be after this one (using temp_id)
        current_after_id = block.temp_id
      end
    end
  end

  log.debug('Created blocks from orphans', {
    orphan_count = #orphans,
    block_count = #blocks,
  })

  return blocks
end

return M
