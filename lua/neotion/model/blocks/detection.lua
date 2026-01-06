-- Block type detection from content prefixes
-- Phase 5.8: Block Type Conversion

---@class neotion.Detection
local M = {}

---@class neotion.PrefixPattern
---@field pattern string Lua pattern to match
---@field prefix string The literal prefix string
---@field type string The block type this prefix indicates

---@type neotion.PrefixPattern[]
local PREFIX_PATTERNS = {
  -- Divider (exact match, no content)
  { pattern = '^(%-%-%-+)$', prefix = '---', type = 'divider' },
  -- Heading patterns (must come before bullets to not confuse with list)
  { pattern = '^(### )', prefix = '### ', type = 'heading_3' },
  { pattern = '^(## )', prefix = '## ', type = 'heading_2' },
  { pattern = '^(# )', prefix = '# ', type = 'heading_1' },
  -- Bullet list patterns (must start at line beginning, no indent)
  { pattern = '^(%- )', prefix = '- ', type = 'bulleted_list_item' },
  { pattern = '^(%* )', prefix = '* ', type = 'bulleted_list_item' },
  { pattern = '^(%+ )', prefix = '+ ', type = 'bulleted_list_item' },
  -- Quote pattern (only pipe, > is reserved for toggle)
  { pattern = '^(| )', prefix = '| ', type = 'quote' },
}

---@type table<string, string>
local TYPE_TO_PREFIX = {
  divider = '---',
  heading_1 = '# ',
  heading_2 = '## ',
  heading_3 = '### ',
  bulleted_list_item = '- ',
  quote = '| ',
}

--- Detect block type from line content
--- Returns the detected block type and the matched prefix, or nil if no prefix found
---@param line string? The line content to analyze
---@return string? block_type The detected block type, or nil for paragraph
---@return string? prefix The matched prefix (for stripping)
function M.detect_type(line)
  if not line or line == '' then
    return nil, nil
  end

  for _, pattern_info in ipairs(PREFIX_PATTERNS) do
    local match = line:match(pattern_info.pattern)
    if match then
      return pattern_info.type, pattern_info.prefix
    end
  end

  return nil, nil
end

--- Strip a known prefix from a line
---@param line string? The line to strip prefix from
---@param prefix string? The prefix to strip
---@return string content The content without prefix
function M.strip_prefix(line, prefix)
  if not line then
    return ''
  end

  if not prefix then
    return line
  end

  if line:sub(1, #prefix) == prefix then
    return line:sub(#prefix + 1)
  end

  return line
end

--- Get the canonical prefix for a block type
---@param block_type string? The block type
---@return string? prefix The prefix for this type, or nil if no prefix
function M.get_prefix_for_type(block_type)
  if not block_type then
    return nil
  end
  return TYPE_TO_PREFIX[block_type]
end

--- Check if a block with current_type containing content should convert to a different type
--- Handles bidirectional conversion:
--- - paragraph with "- text" -> bulleted_list_item
--- - bulleted_list_item without "- " prefix -> paragraph
--- - bullet with "| text" -> quote
---@param current_type string The block's current type
---@param content string? The block's text content (first line for multi-line)
---@return boolean should_convert Whether the block should convert
---@return string? target_type The target type to convert to, or nil if no conversion
function M.should_convert(current_type, content)
  if not content or content == '' then
    return false, nil
  end

  local detected_type, _ = M.detect_type(content)

  -- If content has a prefix that indicates a different type
  if detected_type then
    if detected_type ~= current_type then
      return true, detected_type
    else
      -- Same type, no conversion needed
      return false, nil
    end
  end

  -- No prefix detected - if current type expects a prefix, convert to paragraph
  local expected_prefix = M.get_prefix_for_type(current_type)
  if expected_prefix then
    -- This block type normally has a prefix, but content doesn't have one
    -- Convert to paragraph
    return true, 'paragraph'
  end

  -- Paragraph with no prefix stays paragraph
  return false, nil
end

return M
