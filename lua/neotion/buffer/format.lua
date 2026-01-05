---Block to text formatting for Neotion
---@class neotion.buffer.Format
local M = {}

---@class neotion.FormatOpts
---@field indent_size? integer Spaces per indent level (default: 2)

---Format a single block to text lines with inline formatting markers
---@param block neotion.api.Block
---@param indent integer Current indent level
---@param opts? neotion.FormatOpts
---@return string[]
function M.format_block(block, indent, opts)
  local blocks_api = require('neotion.api.blocks')
  local log = require('neotion.log').get_logger('buffer.format')
  opts = opts or {}
  local indent_size = opts.indent_size or 2
  local prefix = string.rep(' ', indent * indent_size)
  local lines = {}

  local block_type = block.type
  -- Use formatted text with Notion syntax markers for rendering
  local text = blocks_api.get_block_text_formatted(block)

  -- DEBUG: Log the formatted text
  log.debug('format_block called', {
    block_type = block_type,
    formatted_text = text,
    plain_text = blocks_api.get_block_text(block),
    has_rich_text = block[block_type] and block[block_type].rich_text ~= nil,
  })

  if block_type == 'paragraph' then
    if text ~= '' then
      table.insert(lines, prefix .. text)
    else
      table.insert(lines, '')
    end
  elseif block_type == 'heading_1' then
    table.insert(lines, prefix .. '# ' .. text)
  elseif block_type == 'heading_2' then
    table.insert(lines, prefix .. '## ' .. text)
  elseif block_type == 'heading_3' then
    table.insert(lines, prefix .. '### ' .. text)
  elseif block_type == 'bulleted_list_item' then
    table.insert(lines, prefix .. '- ' .. text)
  elseif block_type == 'numbered_list_item' then
    table.insert(lines, prefix .. '1. ' .. text)
  elseif block_type == 'to_do' then
    local block_data = block[block_type]
    local checkbox = block_data and block_data.checked and '[x]' or '[ ]'
    table.insert(lines, prefix .. '- ' .. checkbox .. ' ' .. text)
  elseif block_type == 'toggle' then
    table.insert(lines, prefix .. '▶ ' .. text)
  elseif block_type == 'quote' then
    table.insert(lines, prefix .. '> ' .. text)
  elseif block_type == 'callout' then
    local block_data = block[block_type]
    local icon = ''
    if block_data and block_data.icon then
      if block_data.icon.emoji then
        icon = block_data.icon.emoji .. ' '
      end
    end
    table.insert(lines, prefix .. '> ' .. icon .. text)
  elseif block_type == 'code' then
    local block_data = block[block_type]
    local lang = block_data and block_data.language or ''
    table.insert(lines, prefix .. '```' .. lang)
    -- Split code text by newlines
    for line in text:gmatch('[^\n]+') do
      table.insert(lines, prefix .. line)
    end
    if text == '' then
      table.insert(lines, prefix)
    end
    table.insert(lines, prefix .. '```')
  elseif block_type == 'divider' then
    table.insert(lines, prefix .. '---')
  elseif block_type == 'child_page' then
    table.insert(lines, prefix .. '📄 ' .. text)
  elseif block_type == 'child_database' then
    table.insert(lines, prefix .. '🗃️ ' .. text)
  elseif block_type == 'image' then
    table.insert(lines, prefix .. '🖼️ [image]')
  elseif block_type == 'bookmark' then
    local block_data = block[block_type]
    local url = block_data and block_data.url or ''
    table.insert(lines, prefix .. '🔗 ' .. url)
  else
    -- Unsupported block type, show as-is if has text
    if text ~= '' then
      table.insert(lines, prefix .. text)
    end
  end

  return lines
end

---Format array of blocks to plain text lines
---@param page_blocks neotion.api.Block[]
---@param opts? neotion.FormatOpts
---@return string[]
function M.format_blocks(page_blocks, opts)
  local lines = {}

  for _, block in ipairs(page_blocks) do
    local block_lines = M.format_block(block, 0, opts)
    vim.list_extend(lines, block_lines)
  end

  return lines
end

---Format page metadata as header lines
---@param page neotion.api.Page
---@return string[]
function M.format_header(page)
  local pages_api = require('neotion.api.pages')
  local title = pages_api.get_title(page)
  local parent_type, parent_id = pages_api.get_parent(page)

  return M.format_header_from_metadata(title, parent_type, parent_id)
end

---Format header lines from metadata (used for cache loading)
---@param title string Page title
---@param parent_type string? Parent type ('workspace', 'page', 'database')
---@param parent_id string? Parent ID
---@return string[]
function M.format_header_from_metadata(title, parent_type, parent_id)
  local lines = {
    '# ' .. (title or 'Untitled'),
    '',
  }

  -- Add parent info
  if parent_type == 'workspace' then
    table.insert(lines, '📍 Workspace')
  elseif parent_type == 'page' and parent_id then
    table.insert(lines, '📍 Sub-page of: ' .. parent_id:sub(1, 8) .. '...')
  elseif parent_type == 'database' and parent_id then
    table.insert(lines, '📍 Database: ' .. parent_id:sub(1, 8) .. '...')
  end

  table.insert(lines, '')
  table.insert(lines, '---')
  table.insert(lines, '')

  return lines
end

---Format complete page (header + blocks)
---@param page neotion.api.Page
---@param page_blocks neotion.api.Block[]
---@param opts? neotion.FormatOpts
---@return string[]
function M.format_page(page, page_blocks, opts)
  local lines = M.format_header(page)
  vim.list_extend(lines, M.format_blocks(page_blocks, opts))
  return lines
end

return M
