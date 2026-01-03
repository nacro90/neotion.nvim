--- Rich text utilities for neotion.nvim
--- Provides functions to work with RichTextSegment arrays
---@module 'neotion.model.rich_text'

local types = require('neotion.format.types')

local M = {}

--- Convert Notion API rich_text array to RichTextSegment array
---@param api_rich_text? table[] Notion API rich_text array
---@return neotion.RichTextSegment[]
function M.from_api(api_rich_text)
  if not api_rich_text then
    return {}
  end

  local segments = {}
  local current_col = 0

  for _, item in ipairs(api_rich_text) do
    local segment = types.RichTextSegment.from_api(item, current_col)
    table.insert(segments, segment)
    current_col = segment.end_col
  end

  return segments
end

--- Convert RichTextSegment array to Notion API format
---@param segments neotion.RichTextSegment[]
---@return table[]
function M.to_api(segments)
  local result = {}

  for _, segment in ipairs(segments) do
    table.insert(result, segment:to_api())
  end

  return result
end

--- Convert RichTextSegment array to plain text
---@param segments neotion.RichTextSegment[]
---@return string
function M.to_plain(segments)
  local parts = {}

  for _, segment in ipairs(segments) do
    table.insert(parts, segment.text)
  end

  return table.concat(parts)
end

--- Create RichTextSegment array from plain text
---@param text? string
---@return neotion.RichTextSegment[]
function M.from_plain(text)
  if not text or text == '' then
    return {}
  end

  return { types.RichTextSegment.new(text) }
end

--- Check if two segment arrays are equal
---@param a neotion.RichTextSegment[]
---@param b neotion.RichTextSegment[]
---@return boolean
function M.equals(a, b)
  if #a ~= #b then
    return false
  end

  for i, seg_a in ipairs(a) do
    local seg_b = b[i]

    if seg_a.text ~= seg_b.text then
      return false
    end

    if not seg_a.annotations:equals(seg_b.annotations) then
      return false
    end

    if seg_a.href ~= seg_b.href then
      return false
    end
  end

  return true
end

--- Merge adjacent segments with the same formatting
---@param segments neotion.RichTextSegment[]
---@return neotion.RichTextSegment[]
function M.merge_adjacent(segments)
  if #segments == 0 then
    return {}
  end

  local result = {}
  local current = segments[1]
  local merged_text = current.text
  local start_col = current.start_col

  for i = 2, #segments do
    local next_seg = segments[i]

    -- Check if can merge: same annotations and no href differences
    local can_merge = current.annotations:equals(next_seg.annotations) and current.href == next_seg.href

    if can_merge then
      -- Merge text
      merged_text = merged_text .. next_seg.text
    else
      -- Save current merged segment
      table.insert(
        result,
        types.RichTextSegment.new(merged_text, {
          annotations = current.annotations,
          href = current.href,
          start_col = start_col,
        })
      )

      -- Start new segment
      current = next_seg
      merged_text = next_seg.text
      start_col = next_seg.start_col
    end
  end

  -- Don't forget the last segment
  table.insert(
    result,
    types.RichTextSegment.new(merged_text, {
      annotations = current.annotations,
      href = current.href,
      start_col = start_col,
    })
  )

  -- Recalculate positions
  local current_col = 0
  for _, seg in ipairs(result) do
    seg.start_col = current_col
    seg.end_col = current_col + #seg.text
    current_col = seg.end_col
  end

  return result
end

--- Get the segment at a given column position
---@param segments neotion.RichTextSegment[]
---@param col integer 0-indexed column
---@return neotion.RichTextSegment|nil segment
---@return integer|nil index
function M.get_segment_at(segments, col)
  for i, segment in ipairs(segments) do
    if col >= segment.start_col and col < segment.end_col then
      return segment, i
    end
  end

  return nil, nil
end

--- Get total length of all segments
---@param segments neotion.RichTextSegment[]
---@return integer
function M.total_length(segments)
  local total = 0

  for _, segment in ipairs(segments) do
    total = total + segment:length()
  end

  return total
end

return M
