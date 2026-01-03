--- Notion syntax format provider for neotion.nvim
--- Parses and renders Notion-style inline formatting
---@module 'neotion.format.notion'

local types = require('neotion.format.types')

---@class neotion.NotionFormatProvider: neotion.FormatProvider
local M = {}

M.name = 'notion'

--- Marker constants for Notion syntax
M.MARKERS = {
  bold = '**',
  italic = '*',
  strikethrough = '~',
  code = '`',
  underline_open = '<u>',
  underline_close = '</u>',
  color_open = '<c:',
  color_close = '</c>',
}

--- Characters that need escaping in plain text
local ESCAPE_CHARS = { '*', '~', '`', '<', '\\' }

--- Escape special characters in text
---@param text string
---@return string
local function escape_text(text)
  local result = text

  -- Escape backslashes first
  result = result:gsub('\\', '\\\\')

  -- Escape markers
  result = result:gsub('%*', '\\*')
  result = result:gsub('~', '\\~')
  result = result:gsub('`', '\\`')

  return result
end

--- Unescape special characters
---@param text string
---@return string
local function unescape_text(text)
  local result = text

  result = result:gsub('\\%*', '*')
  result = result:gsub('\\~', '~')
  result = result:gsub('\\`', '`')
  result = result:gsub('\\\\', '\\')

  return result
end

--- Check if text contains characters that need escaping
---@param text string
---@return boolean
local function needs_escaping(text)
  return text:match('[*~`<\\]') ~= nil
end

---@class neotion.ConcealRegion
---@field start_col integer 0-indexed start column (in original text)
---@field end_col integer 0-indexed end column (in original text, exclusive)
---@field replacement string|nil Optional replacement character

---@class ParseState
---@field text string Original text
---@field pos integer Current position (1-indexed)
---@field segments neotion.RichTextSegment[] Parsed segments
---@field current_col integer Current column for output (0-indexed)
---@field original_col integer Current column in original text (0-indexed)
---@field conceal_regions neotion.ConcealRegion[] Regions to conceal

--- Create a new parse state
---@param text string
---@return ParseState
local function new_parse_state(text)
  return {
    text = text,
    pos = 1,
    segments = {},
    current_col = 0,
    original_col = 0,
    conceal_regions = {},
  }
end

--- Add a conceal region to the parse state
---@param state ParseState
---@param start_col integer 0-indexed start column
---@param end_col integer 0-indexed end column
---@param replacement? string Optional replacement character
local function add_conceal_region(state, start_col, end_col, replacement)
  table.insert(state.conceal_regions, {
    start_col = start_col,
    end_col = end_col,
    replacement = replacement or '',
  })
end

--- Add a segment to the parse state
---@param state ParseState
---@param text string
---@param annotations neotion.Annotation
local function add_segment(state, text, annotations)
  if text == '' then
    return
  end

  local segment = types.RichTextSegment.new(text, {
    annotations = annotations,
    start_col = state.current_col,
  })

  table.insert(state.segments, segment)
  state.current_col = segment.end_col
end

--- Try to match a pattern at current position
---@param state ParseState
---@param pattern string Lua pattern
---@return string|nil match
---@return integer|nil end_pos
local function try_match(state, pattern)
  local match_start, match_end, capture = state.text:find(pattern, state.pos)

  if match_start == state.pos then
    return capture or state.text:sub(match_start, match_end), match_end
  end

  return nil, nil
end

--- Parse bold formatting (**text**)
--- Handles nested italic that ends with *** (e.g., **bold *italicbold***)
---@param state ParseState
---@param base_annotations neotion.Annotation
---@return boolean matched
local function parse_bold(state, base_annotations)
  local content, end_pos = try_match(state, '^%*%*(.-)%*%*')

  if content then
    -- Check if there's a trailing * (making it ***) and content has an unclosed *
    local next_char = state.text:sub(end_pos + 1, end_pos + 1)

    if next_char == '*' and content:match('%*') then
      -- Content has * and there's trailing * after **
      -- This is *** ending pattern: italic inside bold ends together
      -- Find the last unescaped * in content that starts italic
      local last_star_pos = nil
      local i = 1
      while i <= #content do
        local char = content:sub(i, i)
        if char == '\\' then
          i = i + 2 -- Skip escaped char
        elseif char == '*' then
          last_star_pos = i
          i = i + 1
        else
          i = i + 1
        end
      end

      if last_star_pos then
        local before_star = content:sub(1, last_star_pos - 1)
        local italic_part = content:sub(last_star_pos + 1)

        -- Create bold annotation
        local bold_ann = base_annotations:clone()
        bold_ann.bold = true

        -- Add before_star as bold only (recursively parse for other formatting)
        if before_star ~= '' then
          local before_segments = M.parse_with_annotations(before_star, bold_ann)
          for _, seg in ipairs(before_segments) do
            seg.start_col = seg.start_col + state.current_col
            seg.end_col = seg.end_col + state.current_col
            table.insert(state.segments, seg)
          end
          state.current_col = state.current_col + #before_star
        end

        -- Add italic_part as bold+italic
        local bold_italic_ann = bold_ann:clone()
        bold_italic_ann.italic = true
        if italic_part ~= '' then
          local italic_segments = M.parse_with_annotations(italic_part, bold_italic_ann)
          for _, seg in ipairs(italic_segments) do
            seg.start_col = seg.start_col + state.current_col
            seg.end_col = seg.end_col + state.current_col
            table.insert(state.segments, seg)
          end
          state.current_col = state.current_col + #italic_part
        end

        state.pos = end_pos + 2 -- +1 for the trailing * after **
        return true
      end
    end

    -- Regular bold processing
    local annotations = base_annotations:clone()
    annotations.bold = true

    -- Recursively parse content for nested formatting
    local inner_segments = M.parse_with_annotations(content, annotations)
    for _, seg in ipairs(inner_segments) do
      seg.start_col = seg.start_col + state.current_col
      seg.end_col = seg.end_col + state.current_col
      table.insert(state.segments, seg)
    end
    state.current_col = state.current_col + #content

    state.pos = end_pos + 1
    return true
  end

  return false
end

--- Find the closing * for italic, skipping over ** pairs (bold)
--- Returns the position of the closing * and the content, or nil if not found
---@param text string The text after the opening *
---@return string|nil content The content between * markers
---@return integer|nil end_pos The position of the closing * (1-indexed, in original text from state.pos)
local function find_italic_close(text)
  local i = 1
  local bold_depth = 0

  while i <= #text do
    local char = text:sub(i, i)
    local next_char = text:sub(i + 1, i + 1)

    if char == '\\' then
      -- Skip escaped char
      i = i + 2
    elseif char == '*' and next_char == '*' then
      -- Found **, toggle bold
      if bold_depth == 0 then
        bold_depth = 1
      else
        bold_depth = 0
      end
      i = i + 2
    elseif char == '*' and bold_depth == 0 then
      -- Found closing * for italic (not inside bold)
      return text:sub(1, i - 1), i
    else
      i = i + 1
    end
  end

  -- Check if we ended with unclosed bold that could close with ***
  -- i.e., bold_depth == 1 means there's an unclosed ** that needs closing
  if bold_depth == 1 then
    -- Return the whole text, indicating *** ending pattern
    return text, #text + 1
  end

  return nil, nil
end

--- Parse italic formatting (*text*)
--- Handles nested bold that ends with *** (e.g., *italic **bolditalic***)
---@param state ParseState
---@param base_annotations neotion.Annotation
---@return boolean matched
local function parse_italic(state, base_annotations)
  -- Don't match if it's actually bold (**) or bold+italic (***)
  if state.text:sub(state.pos, state.pos + 1) == '**' then
    return false
  end

  -- Check if this is an italic marker
  if state.text:sub(state.pos, state.pos) ~= '*' then
    return false
  end

  -- Find the closing * using smart search that skips ** pairs
  local after_open = state.text:sub(state.pos + 1)
  local content, close_pos = find_italic_close(after_open)

  if not content then
    return false
  end

  -- Check if we have *** ending (bold inside italic)
  local actual_close_pos = state.pos + close_pos -- Position of closing * in original text
  local next_two = state.text:sub(actual_close_pos + 1, actual_close_pos + 2)

  if next_two == '**' and content:match('%*%*') then
    -- *** ending pattern: bold inside italic ends together
    -- Find the last ** in content that starts bold
    local last_double_star_pos = nil
    local i = 1
    while i <= #content - 1 do
      local char = content:sub(i, i)
      if char == '\\' then
        i = i + 2 -- Skip escaped char
      elseif content:sub(i, i + 1) == '**' then
        last_double_star_pos = i
        i = i + 2
      else
        i = i + 1
      end
    end

    if last_double_star_pos then
      local before_stars = content:sub(1, last_double_star_pos - 1)
      local bold_part = content:sub(last_double_star_pos + 2)

      -- Create italic annotation
      local italic_ann = base_annotations:clone()
      italic_ann.italic = true

      -- Add before_stars as italic only
      if before_stars ~= '' then
        local before_segments = M.parse_with_annotations(before_stars, italic_ann)
        for _, seg in ipairs(before_segments) do
          seg.start_col = seg.start_col + state.current_col
          seg.end_col = seg.end_col + state.current_col
          table.insert(state.segments, seg)
        end
        state.current_col = state.current_col + #before_stars
      end

      -- Add bold_part as bold+italic
      local bold_italic_ann = italic_ann:clone()
      bold_italic_ann.bold = true
      if bold_part ~= '' then
        local bold_segments = M.parse_with_annotations(bold_part, bold_italic_ann)
        for _, seg in ipairs(bold_segments) do
          seg.start_col = seg.start_col + state.current_col
          seg.end_col = seg.end_col + state.current_col
          table.insert(state.segments, seg)
        end
        state.current_col = state.current_col + #bold_part
      end

      state.pos = actual_close_pos + 3 -- Skip closing * and trailing **
      return true
    end
  end

  -- Regular italic processing
  local annotations = base_annotations:clone()
  annotations.italic = true

  local inner_segments = M.parse_with_annotations(content, annotations)
  for _, seg in ipairs(inner_segments) do
    seg.start_col = seg.start_col + state.current_col
    seg.end_col = seg.end_col + state.current_col
    table.insert(state.segments, seg)
  end
  state.current_col = state.current_col + #content

  state.pos = actual_close_pos + 1
  return true
end

--- Parse bold italic formatting (***text***)
---@param state ParseState
---@param base_annotations neotion.Annotation
---@return boolean matched
local function parse_bold_italic(state, base_annotations)
  local content, end_pos = try_match(state, '^%*%*%*(.-)%*%*%*')

  if content then
    local annotations = base_annotations:clone()
    annotations.bold = true
    annotations.italic = true

    local inner_segments = M.parse_with_annotations(content, annotations)
    for _, seg in ipairs(inner_segments) do
      seg.start_col = seg.start_col + state.current_col
      seg.end_col = seg.end_col + state.current_col
      table.insert(state.segments, seg)
    end
    state.current_col = state.current_col + #content

    state.pos = end_pos + 1
    return true
  end

  return false
end

--- Parse strikethrough formatting (~text~)
---@param state ParseState
---@param base_annotations neotion.Annotation
---@return boolean matched
local function parse_strikethrough(state, base_annotations)
  local content, end_pos = try_match(state, '^~(.-)~')

  if content then
    local annotations = base_annotations:clone()
    annotations.strikethrough = true

    local inner_segments = M.parse_with_annotations(content, annotations)
    for _, seg in ipairs(inner_segments) do
      seg.start_col = seg.start_col + state.current_col
      seg.end_col = seg.end_col + state.current_col
      table.insert(state.segments, seg)
    end
    state.current_col = state.current_col + #content

    state.pos = end_pos + 1
    return true
  end

  return false
end

--- Parse code formatting (`text`)
---@param state ParseState
---@param base_annotations neotion.Annotation
---@return boolean matched
local function parse_code(state, base_annotations)
  local content, end_pos = try_match(state, '^`(.-)`')

  if content then
    local annotations = base_annotations:clone()
    annotations.code = true

    -- Code doesn't have nested formatting
    add_segment(state, content, annotations)

    state.pos = end_pos + 1
    return true
  end

  return false
end

--- Parse underline formatting (<u>text</u>)
---@param state ParseState
---@param base_annotations neotion.Annotation
---@return boolean matched
local function parse_underline(state, base_annotations)
  local content, end_pos = try_match(state, '^<u>(.-)</u>')

  if content then
    local annotations = base_annotations:clone()
    annotations.underline = true

    local inner_segments = M.parse_with_annotations(content, annotations)
    for _, seg in ipairs(inner_segments) do
      seg.start_col = seg.start_col + state.current_col
      seg.end_col = seg.end_col + state.current_col
      table.insert(state.segments, seg)
    end
    state.current_col = state.current_col + #content

    state.pos = end_pos + 1
    return true
  end

  return false
end

--- Parse color formatting (<c:color>text</c>)
---@param state ParseState
---@param base_annotations neotion.Annotation
---@return boolean matched
local function parse_color(state, base_annotations)
  local color, content, end_pos = state.text:match('^<c:([%w_]+)>(.-)</c>()', state.pos)

  if color and content then
    local annotations = base_annotations:clone()
    annotations.color = color

    local inner_segments = M.parse_with_annotations(content, annotations)
    for _, seg in ipairs(inner_segments) do
      seg.start_col = seg.start_col + state.current_col
      seg.end_col = seg.end_col + state.current_col
      table.insert(state.segments, seg)
    end
    state.current_col = state.current_col + #content

    state.pos = end_pos
    return true
  end

  return false
end

--- Parse escaped character
---@param state ParseState
---@param base_annotations neotion.Annotation
---@return boolean matched
local function parse_escape(state, base_annotations)
  if state.text:sub(state.pos, state.pos) == '\\' then
    local next_char = state.text:sub(state.pos + 1, state.pos + 1)

    if next_char:match('[*~`<\\%[%]]') then
      add_segment(state, next_char, base_annotations)
      state.pos = state.pos + 2
      return true
    end
  end

  return false
end

--- Parse markdown-style link [text](url)
---@param state ParseState
---@param base_annotations neotion.Annotation
---@return boolean matched
local function parse_link(state, base_annotations)
  -- Pattern: [text](url) where url cannot contain )
  -- Match from current position
  local link_text, url, end_pos = state.text:match('^%[(.-)%]%(([^%)]+)%)()', state.pos)

  if link_text and url then
    -- Create segment with href
    local annotations = base_annotations:clone()

    -- For links, we need to create a segment directly with href
    -- The text inside may have formatting, so parse recursively
    if link_text == '' then
      -- Empty link text - create single empty segment with href
      local segment = types.RichTextSegment.new('', {
        annotations = annotations,
        href = url,
        start_col = state.current_col,
      })
      table.insert(state.segments, segment)
    else
      -- Parse inner text for formatting, then attach href to each segment
      local inner_segments = M.parse_with_annotations(link_text, annotations)
      for _, seg in ipairs(inner_segments) do
        seg.start_col = seg.start_col + state.current_col
        seg.end_col = seg.end_col + state.current_col
        seg.href = url
        table.insert(state.segments, seg)
      end
    end
    state.current_col = state.current_col + #link_text

    state.pos = end_pos
    return true
  end

  return false
end

--- Parse text with given base annotations
---@param text string
---@param base_annotations neotion.Annotation
---@return neotion.RichTextSegment[]
function M.parse_with_annotations(text, base_annotations)
  if text == '' then
    return {}
  end

  local state = new_parse_state(text)
  local plain_start = state.pos

  while state.pos <= #state.text do
    local matched = false

    -- Try each format parser
    -- Order matters: bold_italic before bold before italic
    -- Link should be early to handle [text](url) before [ is consumed
    matched = matched or parse_escape(state, base_annotations)
    matched = matched or parse_link(state, base_annotations)
    matched = matched or parse_bold_italic(state, base_annotations)
    matched = matched or parse_bold(state, base_annotations)
    matched = matched or parse_italic(state, base_annotations)
    matched = matched or parse_strikethrough(state, base_annotations)
    matched = matched or parse_code(state, base_annotations)
    matched = matched or parse_underline(state, base_annotations)
    matched = matched or parse_color(state, base_annotations)

    if matched then
      plain_start = state.pos
    else
      -- Consume one character as plain text
      local char = state.text:sub(state.pos, state.pos)
      add_segment(state, char, base_annotations)
      state.pos = state.pos + 1
      plain_start = state.pos
    end
  end

  -- Merge adjacent segments with same annotations
  return merge_adjacent_segments(state.segments)
end

--- Merge adjacent segments with identical annotations
---@param segments neotion.RichTextSegment[]
---@return neotion.RichTextSegment[]
function merge_adjacent_segments(segments)
  if #segments == 0 then
    return {}
  end

  local result = {}
  local current = segments[1]
  local merged_text = current.text

  for i = 2, #segments do
    local next_seg = segments[i]

    if current.annotations:equals(next_seg.annotations) and current.href == next_seg.href then
      merged_text = merged_text .. next_seg.text
    else
      table.insert(
        result,
        types.RichTextSegment.new(merged_text, {
          annotations = current.annotations,
          href = current.href,
          start_col = current.start_col,
        })
      )
      current = next_seg
      merged_text = next_seg.text
    end
  end

  table.insert(
    result,
    types.RichTextSegment.new(merged_text, {
      annotations = current.annotations,
      href = current.href,
      start_col = current.start_col,
    })
  )

  -- Recalculate positions
  local col = 0
  for _, seg in ipairs(result) do
    seg.start_col = col
    seg.end_col = col + #seg.text
    col = seg.end_col
  end

  return result
end

--- Parse text to rich text segments
---@param text string
---@return neotion.RichTextSegment[]
function M.parse(text)
  if text == '' then
    return {}
  end

  return M.parse_with_annotations(text, types.Annotation.new())
end

--- Parse text and convert to Notion API rich_text format
--- This is the inverse of render() - converts buffer text with markers to API format
---@param text string Buffer text with Notion syntax markers
---@return table[] Notion API rich_text array
function M.parse_to_api(text)
  if text == '' then
    return {}
  end

  local segments = M.parse(text)
  local result = {}

  for _, seg in ipairs(segments) do
    table.insert(result, seg:to_api())
  end

  return result
end

---@class neotion.ParseResult
---@field segments neotion.RichTextSegment[] Segments with original text positions
---@field conceal_regions neotion.ConcealRegion[] Regions to conceal (marker positions)

--- Parse text and return both segments with original positions and conceal regions
--- This is used for rendering where we need to know where markers are
---@param text string
---@return neotion.ParseResult
function M.parse_with_concealment(text)
  if text == '' then
    return { segments = {}, conceal_regions = {} }
  end

  local state = new_parse_state(text)
  local base_annotations = types.Annotation.new()

  while state.pos <= #state.text do
    local matched = false
    local start_original_col = state.pos - 1 -- 0-indexed

    -- Try escape first
    if state.text:sub(state.pos, state.pos) == '\\' then
      local next_char = state.text:sub(state.pos + 1, state.pos + 1)
      if next_char:match('[*~`<\\]') then
        -- Conceal the backslash
        add_conceal_region(state, start_original_col, start_original_col + 1)
        -- Add the escaped character as segment
        local seg = types.RichTextSegment.new(next_char, {
          annotations = base_annotations,
          start_col = start_original_col,
        })
        seg.end_col = start_original_col + 2 -- Include both \ and char in original
        table.insert(state.segments, seg)
        state.pos = state.pos + 2
        matched = true
      end
    end

    -- Bold italic (***text***)
    if not matched then
      local content, end_pos = try_match(state, '^%*%*%*(.-)%*%*%*')
      if content then
        local marker_len = 3
        -- Conceal opening markers
        add_conceal_region(state, start_original_col, start_original_col + marker_len)
        -- Add segment for content
        local annotations = base_annotations:clone()
        annotations.bold = true
        annotations.italic = true
        local seg = types.RichTextSegment.new(content, {
          annotations = annotations,
          start_col = start_original_col + marker_len,
        })
        seg.end_col = start_original_col + marker_len + #content
        table.insert(state.segments, seg)
        -- Conceal closing markers
        add_conceal_region(state, seg.end_col, seg.end_col + marker_len)
        state.pos = end_pos + 1
        matched = true
      end
    end

    -- Bold (**text**) - with support for *** ending (italic inside bold)
    if not matched then
      local content, end_pos = try_match(state, '^%*%*(.-)%*%*')
      if content and not content:match('^%*') then
        local marker_len = 2
        local next_char = state.text:sub(end_pos + 1, end_pos + 1)

        -- Check for *** ending with italic inside bold
        if next_char == '*' and content:match('%*') then
          -- Find the last * in content that starts italic
          local last_star_pos = nil
          local i = 1
          while i <= #content do
            local char = content:sub(i, i)
            if char == '\\' then
              i = i + 2
            elseif char == '*' then
              last_star_pos = i
              i = i + 1
            else
              i = i + 1
            end
          end

          if last_star_pos then
            local before_star = content:sub(1, last_star_pos - 1)
            local italic_part = content:sub(last_star_pos + 1)

            -- Conceal opening **
            add_conceal_region(state, start_original_col, start_original_col + marker_len)

            -- Add bold-only part
            if before_star ~= '' then
              local bold_ann = base_annotations:clone()
              bold_ann.bold = true
              local seg1 = types.RichTextSegment.new(before_star, {
                annotations = bold_ann,
                start_col = start_original_col + marker_len,
              })
              seg1.end_col = start_original_col + marker_len + #before_star
              table.insert(state.segments, seg1)
            end

            -- Conceal the * that starts italic
            local italic_star_col = start_original_col + marker_len + #before_star
            add_conceal_region(state, italic_star_col, italic_star_col + 1)

            -- Add bold+italic part
            if italic_part ~= '' then
              local bold_italic_ann = base_annotations:clone()
              bold_italic_ann.bold = true
              bold_italic_ann.italic = true
              local seg2 = types.RichTextSegment.new(italic_part, {
                annotations = bold_italic_ann,
                start_col = italic_star_col + 1,
              })
              seg2.end_col = italic_star_col + 1 + #italic_part
              table.insert(state.segments, seg2)
            end

            -- Conceal closing *** (includes the extra * for italic)
            local close_start = start_original_col + marker_len + #content
            add_conceal_region(state, close_start, close_start + 3)
            state.pos = end_pos + 2 -- +1 for trailing *
            matched = true
          end
        end

        if not matched then
          -- Regular bold processing
          add_conceal_region(state, start_original_col, start_original_col + marker_len)
          local annotations = base_annotations:clone()
          annotations.bold = true
          local seg = types.RichTextSegment.new(content, {
            annotations = annotations,
            start_col = start_original_col + marker_len,
          })
          seg.end_col = start_original_col + marker_len + #content
          table.insert(state.segments, seg)
          add_conceal_region(state, seg.end_col, seg.end_col + marker_len)
          state.pos = end_pos + 1
          matched = true
        end
      end
    end

    -- Italic (*text*) - with support for *** ending (bold inside italic)
    -- Check if current char is '*' AND either:
    --   1. Next char is not '*' (simple italic: *text*)
    --   2. Next two chars are '**' (this is ***, not **: italic containing bold)
    if not matched and state.text:sub(state.pos, state.pos) == '*' then
      local next_one = state.text:sub(state.pos + 1, state.pos + 1)
      local next_two = state.text:sub(state.pos + 1, state.pos + 2)
      -- Skip if it's exactly ** (not ***) - will be handled by bold parser
      local is_bold_not_bold_italic = (next_one == '*' and next_two ~= '**')

      if not is_bold_not_bold_italic then
        -- Use smart search that skips ** pairs
        local after_open = state.text:sub(state.pos + 1)
        local content, close_rel_pos = find_italic_close(after_open)

        if content then
          local marker_len = 1
          local actual_close_pos = state.pos + close_rel_pos
          local closing_chars = state.text:sub(actual_close_pos + 1, actual_close_pos + 2)

          -- Check for *** ending with bold inside italic
          if closing_chars == '**' and content:match('%*%*') then
            -- Find the last ** in content that starts bold
            local last_double_star_pos = nil
            local i = 1
            while i <= #content - 1 do
              local char = content:sub(i, i)
              if char == '\\' then
                i = i + 2
              elseif content:sub(i, i + 1) == '**' then
                last_double_star_pos = i
                i = i + 2
              else
                i = i + 1
              end
            end

            if last_double_star_pos then
              local before_stars = content:sub(1, last_double_star_pos - 1)
              local bold_part = content:sub(last_double_star_pos + 2)

              -- Conceal opening *
              add_conceal_region(state, start_original_col, start_original_col + marker_len)

              -- Add italic-only part
              if before_stars ~= '' then
                local italic_ann = base_annotations:clone()
                italic_ann.italic = true
                local seg1 = types.RichTextSegment.new(before_stars, {
                  annotations = italic_ann,
                  start_col = start_original_col + marker_len,
                })
                seg1.end_col = start_original_col + marker_len + #before_stars
                table.insert(state.segments, seg1)
              end

              -- Conceal the ** that starts bold
              local bold_star_col = start_original_col + marker_len + #before_stars
              add_conceal_region(state, bold_star_col, bold_star_col + 2)

              -- Add bold+italic part
              if bold_part ~= '' then
                local bold_italic_ann = base_annotations:clone()
                bold_italic_ann.bold = true
                bold_italic_ann.italic = true
                local seg2 = types.RichTextSegment.new(bold_part, {
                  annotations = bold_italic_ann,
                  start_col = bold_star_col + 2,
                })
                seg2.end_col = bold_star_col + 2 + #bold_part
                table.insert(state.segments, seg2)
              end

              -- Conceal closing *** (includes the extra ** for bold)
              local close_start = start_original_col + marker_len + #content
              add_conceal_region(state, close_start, close_start + 3)
              state.pos = actual_close_pos + 3
              matched = true
            end
          end

          if not matched then
            -- Check for ***bold** italic* pattern (bold+italic first, then italic only)
            local bold_content, after_bold = content:match('^%*%*(.-)%*%*(.*)')
            if bold_content then
              -- Conceal opening * (italic)
              add_conceal_region(state, start_original_col, start_original_col + marker_len)

              -- Conceal ** (bold start)
              local bold_start_col = start_original_col + marker_len
              add_conceal_region(state, bold_start_col, bold_start_col + 2)

              -- Add bold+italic segment
              local bold_italic_ann = base_annotations:clone()
              bold_italic_ann.bold = true
              bold_italic_ann.italic = true
              local seg1 = types.RichTextSegment.new(bold_content, {
                annotations = bold_italic_ann,
                start_col = bold_start_col + 2,
              })
              seg1.end_col = bold_start_col + 2 + #bold_content
              table.insert(state.segments, seg1)

              -- Conceal ** (bold end)
              add_conceal_region(state, seg1.end_col, seg1.end_col + 2)

              -- Add italic-only segment (if there's content after)
              if after_bold ~= '' then
                local italic_ann = base_annotations:clone()
                italic_ann.italic = true
                local seg2 = types.RichTextSegment.new(after_bold, {
                  annotations = italic_ann,
                  start_col = seg1.end_col + 2,
                })
                seg2.end_col = seg1.end_col + 2 + #after_bold
                table.insert(state.segments, seg2)
                add_conceal_region(state, seg2.end_col, seg2.end_col + marker_len)
              else
                add_conceal_region(state, seg1.end_col + 2, seg1.end_col + 2 + marker_len)
              end
              state.pos = actual_close_pos + 1
              matched = true
            end
          end

          if not matched then
            -- Regular italic processing (no nested bold)
            add_conceal_region(state, start_original_col, start_original_col + marker_len)
            local annotations = base_annotations:clone()
            annotations.italic = true
            local seg = types.RichTextSegment.new(content, {
              annotations = annotations,
              start_col = start_original_col + marker_len,
            })
            seg.end_col = start_original_col + marker_len + #content
            table.insert(state.segments, seg)
            add_conceal_region(state, seg.end_col, seg.end_col + marker_len)
            state.pos = actual_close_pos + 1
            matched = true
          end
        end
      end -- close is_bold_not_bold_italic check
    end

    -- Strikethrough (~text~)
    if not matched then
      local content, end_pos = try_match(state, '^~(.-)~')
      if content then
        local marker_len = 1
        add_conceal_region(state, start_original_col, start_original_col + marker_len)
        local annotations = base_annotations:clone()
        annotations.strikethrough = true
        local seg = types.RichTextSegment.new(content, {
          annotations = annotations,
          start_col = start_original_col + marker_len,
        })
        seg.end_col = start_original_col + marker_len + #content
        table.insert(state.segments, seg)
        add_conceal_region(state, seg.end_col, seg.end_col + marker_len)
        state.pos = end_pos + 1
        matched = true
      end
    end

    -- Code (`text`)
    if not matched then
      local content, end_pos = try_match(state, '^`(.-)`')
      if content then
        local marker_len = 1
        add_conceal_region(state, start_original_col, start_original_col + marker_len)
        local annotations = base_annotations:clone()
        annotations.code = true
        local seg = types.RichTextSegment.new(content, {
          annotations = annotations,
          start_col = start_original_col + marker_len,
        })
        seg.end_col = start_original_col + marker_len + #content
        table.insert(state.segments, seg)
        add_conceal_region(state, seg.end_col, seg.end_col + marker_len)
        state.pos = end_pos + 1
        matched = true
      end
    end

    -- Underline (<u>text</u>)
    if not matched then
      local content, end_pos = try_match(state, '^<u>(.-)</u>')
      if content then
        local open_len = 3 -- <u>
        local close_len = 4 -- </u>
        add_conceal_region(state, start_original_col, start_original_col + open_len)
        local annotations = base_annotations:clone()
        annotations.underline = true
        local seg = types.RichTextSegment.new(content, {
          annotations = annotations,
          start_col = start_original_col + open_len,
        })
        seg.end_col = start_original_col + open_len + #content
        table.insert(state.segments, seg)
        add_conceal_region(state, seg.end_col, seg.end_col + close_len)
        state.pos = end_pos + 1
        matched = true
      end
    end

    -- Color (<c:color>text</c>)
    if not matched then
      local color, content, end_pos_plus_1 = state.text:match('^<c:([%w_]+)>(.-)</c>()', state.pos)
      if color and content then
        local open_len = 4 + #color -- <c:color>
        local close_len = 4 -- </c>
        add_conceal_region(state, start_original_col, start_original_col + open_len)
        local annotations = base_annotations:clone()
        annotations.color = color
        local seg = types.RichTextSegment.new(content, {
          annotations = annotations,
          start_col = start_original_col + open_len,
        })
        seg.end_col = start_original_col + open_len + #content
        table.insert(state.segments, seg)
        add_conceal_region(state, seg.end_col, seg.end_col + close_len)
        state.pos = end_pos_plus_1
        matched = true
      end
    end

    -- Link ([text](url))
    if not matched then
      local link_text, url, end_pos_plus_1 = state.text:match('^%[(.-)%]%(([^%)]+)%)()', state.pos)
      if link_text and url then
        local open_len = 1 -- [
        local close_len = 3 + #url -- ](url)
        -- Conceal opening [
        add_conceal_region(state, start_original_col, start_original_col + open_len)
        local seg = types.RichTextSegment.new(link_text, {
          annotations = base_annotations,
          href = url,
          start_col = start_original_col + open_len,
        })
        seg.end_col = start_original_col + open_len + #link_text
        table.insert(state.segments, seg)
        -- Conceal ](url)
        add_conceal_region(state, seg.end_col, seg.end_col + close_len)
        state.pos = end_pos_plus_1
        matched = true
      end
    end

    -- Plain character
    if not matched then
      local char = state.text:sub(state.pos, state.pos)
      local seg = types.RichTextSegment.new(char, {
        annotations = base_annotations,
        start_col = start_original_col,
      })
      seg.end_col = start_original_col + 1
      table.insert(state.segments, seg)
      state.pos = state.pos + 1
    end
  end

  -- Merge adjacent segments with same annotations and href
  local merged = {}
  if #state.segments > 0 then
    local current = state.segments[1]
    for i = 2, #state.segments do
      local next_seg = state.segments[i]
      if
        current.annotations:equals(next_seg.annotations)
        and current.end_col == next_seg.start_col
        and current.href == next_seg.href
      then
        -- Extend current segment
        current = types.RichTextSegment.new(current.text .. next_seg.text, {
          annotations = current.annotations,
          href = current.href,
          start_col = current.start_col,
        })
        current.end_col = next_seg.end_col
      else
        table.insert(merged, current)
        current = next_seg
      end
    end
    table.insert(merged, current)
  end

  return {
    segments = merged,
    conceal_regions = state.conceal_regions,
  }
end

--- Render a single segment to text
---@param segment neotion.RichTextSegment
---@return string
function M.render_segment(segment)
  local text = segment.text
  local ann = segment.annotations
  local href = segment.href

  -- Normalize vim.NIL (userdata from JSON decode) to nil
  if href == vim.NIL then
    href = nil
  end

  -- Check if we need to escape the text
  local has_formatting = ann.bold
    or ann.italic
    or ann.strikethrough
    or ann.code
    or ann.underline
    or (ann.color and ann.color ~= 'default')
    or href

  if not has_formatting then
    -- Plain text - escape special characters
    if needs_escaping(text) then
      text = escape_text(text)
    end
    return text
  end

  -- Apply formatting markers
  local result = text

  -- Code is innermost (no nesting allowed)
  if ann.code then
    result = '`' .. result .. '`'
    -- Link wrapping for code
    if href then
      result = '[' .. result .. '](' .. href .. ')'
    end
    return result -- Code doesn't combine with other formatting
  end

  -- Link wrapping (innermost for non-code)
  if href then
    result = '[' .. result .. '](' .. href .. ')'
  end

  -- Color wrapping
  if ann.color and ann.color ~= 'default' then
    result = '<c:' .. ann.color .. '>' .. result .. '</c>'
  end

  -- Underline wrapping
  if ann.underline then
    result = '<u>' .. result .. '</u>'
  end

  -- Strikethrough wrapping
  if ann.strikethrough then
    result = '~' .. result .. '~'
  end

  -- Bold + Italic combined
  if ann.bold and ann.italic then
    result = '***' .. result .. '***'
  elseif ann.bold then
    result = '**' .. result .. '**'
  elseif ann.italic then
    result = '*' .. result .. '*'
  end

  return result
end

--- Check if annotation has a specific format
---@param ann neotion.Annotation|nil
---@param format string
---@return boolean
local function has_format(ann, format)
  if not ann then
    return false
  end
  if format == 'bold' then
    return ann.bold == true
  elseif format == 'italic' then
    return ann.italic == true
  elseif format == 'strikethrough' then
    return ann.strikethrough == true
  elseif format == 'code' then
    return ann.code == true
  elseif format == 'underline' then
    return ann.underline == true
  elseif format == 'color' then
    return ann.color and ann.color ~= 'default'
  end
  return false
end

--- Get color value from annotation
---@param ann neotion.Annotation|nil
---@return string|nil
local function get_color(ann)
  if ann and ann.color and ann.color ~= 'default' then
    return ann.color
  end
  return nil
end

--- Render rich text segments to text with smart marker optimization
--- This handles adjacent segments that share formatting to avoid duplicate markers
---@param segments neotion.RichTextSegment[]
---@return string
function M.render(segments)
  if #segments == 0 then
    return ''
  end

  -- For single segment or code segments, use simple rendering
  if #segments == 1 then
    return M.render_segment(segments[1])
  end

  local result = {}

  for i, segment in ipairs(segments) do
    local ann = segment.annotations
    local href = segment.href
    local prev_ann = i > 1 and segments[i - 1].annotations or nil
    local next_ann = i < #segments and segments[i + 1].annotations or nil

    -- Code is special - it doesn't nest and must be handled separately
    if ann.code then
      table.insert(result, M.render_segment(segment))
    else
      local text = segment.text

      -- Link wrapping (each segment with href gets its own link markers)
      if href then
        text = '[' .. text .. '](' .. href .. ')'
      end

      -- Escape text if it's plain (no formatting that would wrap it)
      local has_any_format = ann.bold
        or ann.italic
        or ann.strikethrough
        or ann.underline
        or (ann.color and ann.color ~= 'default')
        or href
      if not has_any_format and needs_escaping(text) then
        text = escape_text(text)
      end

      -- Build opening markers (formats that start here)
      local open = {}
      local close = {}

      -- Color: <c:color>...</c>
      local curr_color = get_color(ann)
      local prev_color = get_color(prev_ann)
      local next_color = get_color(next_ann)
      if curr_color and curr_color ~= prev_color then
        table.insert(open, '<c:' .. curr_color .. '>')
      end
      if curr_color and curr_color ~= next_color then
        table.insert(close, 1, '</c>')
      end

      -- Underline: <u>...</u>
      if has_format(ann, 'underline') and not has_format(prev_ann, 'underline') then
        table.insert(open, '<u>')
      end
      if has_format(ann, 'underline') and not has_format(next_ann, 'underline') then
        table.insert(close, 1, '</u>')
      end

      -- Strikethrough: ~...~
      if has_format(ann, 'strikethrough') and not has_format(prev_ann, 'strikethrough') then
        table.insert(open, '~')
      end
      if has_format(ann, 'strikethrough') and not has_format(next_ann, 'strikethrough') then
        table.insert(close, 1, '~')
      end

      -- Bold and Italic need special handling for combinations
      local curr_bold = has_format(ann, 'bold')
      local curr_italic = has_format(ann, 'italic')
      local prev_bold = has_format(prev_ann, 'bold')
      local prev_italic = has_format(prev_ann, 'italic')
      local next_bold = has_format(next_ann, 'bold')
      local next_italic = has_format(next_ann, 'italic')

      -- Opening bold/italic
      if curr_bold and curr_italic then
        -- Both bold and italic
        if not prev_bold and not prev_italic then
          -- Neither was active before
          table.insert(open, '***')
        elseif prev_bold and not prev_italic then
          -- Bold was active, italic starts
          table.insert(open, '*')
        elseif not prev_bold and prev_italic then
          -- Italic was active, bold starts
          table.insert(open, '**')
        end
        -- else: both were already active, no marker needed
      elseif curr_bold and not curr_italic then
        -- Only bold
        if not prev_bold then
          table.insert(open, '**')
        end
        -- If prev was bold+italic, we need to close italic first (handled in prev iteration)
      elseif curr_italic and not curr_bold then
        -- Only italic
        if not prev_italic then
          table.insert(open, '*')
        end
      end

      -- Closing bold/italic
      if curr_bold and curr_italic then
        if not next_bold and not next_italic then
          -- Both end here
          table.insert(close, 1, '***')
        elseif next_bold and not next_italic then
          -- Italic ends, bold continues
          table.insert(close, 1, '*')
        elseif not next_bold and next_italic then
          -- Bold ends, italic continues
          table.insert(close, 1, '**')
        end
        -- else: both continue, no marker needed
      elseif curr_bold and not curr_italic then
        if not next_bold then
          table.insert(close, 1, '**')
        end
      elseif curr_italic and not curr_bold then
        if not next_italic then
          table.insert(close, 1, '*')
        end
      end

      -- Combine: open + text + close
      table.insert(result, table.concat(open) .. text .. table.concat(close))
    end
  end

  return table.concat(result)
end

return M
