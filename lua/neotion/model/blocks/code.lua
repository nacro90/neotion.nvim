---Code Block handler for Neotion
---Editable multi-line code block with language metadata
---@class neotion.model.blocks.Code
local M = {}

-- TODO(neotion:FEAT-12.5:MEDIUM): Conceal code block fence lines
-- Hide ``` fence lines like render-markdown.nvim does - the fence lines
-- should be visually hidden but preserved in buffer for editing.

local base = require('neotion.model.block')
local Block = base.Block

---@class neotion.CodeBlock : neotion.Block
---@field code_text string The actual code content (without fences)
---@field language string Programming language (e.g., 'lua', 'javascript')
---@field rich_text table[] Original rich_text array (preserved for round-trip)
---@field caption table[] Caption array (preserved for round-trip)
---@field original_text string Text at creation (for change detection)
---@field original_language string Language at creation (for change detection)
local CodeBlock = setmetatable({}, { __index = Block })
CodeBlock.__index = CodeBlock

---Extract plain text from rich_text array
---@param rich_text table[]
---@return string
local function rich_text_to_plain(rich_text)
  if not rich_text or type(rich_text) ~= 'table' then
    return ''
  end
  local parts = {}
  for _, text in ipairs(rich_text) do
    if text.plain_text then
      table.insert(parts, text.plain_text)
    end
  end
  return table.concat(parts)
end

---Create a new CodeBlock from Notion API JSON
---@param raw table Notion API block JSON
---@return neotion.CodeBlock
function CodeBlock.new(raw)
  local self = setmetatable(Block.new(raw), CodeBlock)

  -- Extract content from code block
  local block_data = raw.code or {}
  self.rich_text = block_data.rich_text or {}
  self.language = block_data.language or 'plain text'
  self.caption = block_data.caption or {}

  -- Extract code content from rich_text
  self.code_text = rich_text_to_plain(self.rich_text)
  self.original_text = self.code_text
  self.original_language = self.language
  self.editable = true

  return self
end

---Format code block to buffer lines (with fences)
---@param opts? {indent?: integer, indent_size?: integer}
---@return string[]
function CodeBlock:format(opts)
  local lines = {}

  -- Opening fence with language
  local lang_tag = self.language
  if lang_tag == 'plain text' then
    lang_tag = '' -- Show as empty for plain text
  end
  table.insert(lines, '```' .. lang_tag)

  -- Code content (split by newlines)
  if self.code_text == '' then
    table.insert(lines, '')
  else
    for line in (self.code_text .. '\n'):gmatch('([^\n]*)\n') do
      table.insert(lines, line)
    end
  end

  -- Closing fence
  table.insert(lines, '```')

  return lines
end

---Serialize code block to Notion API JSON
---@return table Notion API block JSON
function CodeBlock:serialize()
  local text_changed = self.code_text ~= self.original_text
  local language_changed = self.language ~= self.original_language

  local result = vim.deepcopy(self.raw)

  -- Ensure code key exists
  result.code = result.code or {}

  if text_changed then
    -- Text changed: create new rich_text
    result.code.rich_text = {
      {
        type = 'text',
        text = { content = self.code_text },
        plain_text = self.code_text,
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
  else
    -- Text unchanged: preserve original rich_text
    result.code.rich_text = self.rich_text
  end

  -- Always update language (whether changed or not)
  result.code.language = self.language

  -- Preserve caption
  if self.caption then
    result.code.caption = self.caption
  end

  return result
end

---Update code block from buffer lines
---Parses fence syntax and extracts code content
---@param lines string[]
function CodeBlock:update_from_lines(lines)
  if #lines == 0 then
    return
  end

  local first_line = lines[1] or ''
  local last_line = lines[#lines] or ''

  -- Check for opening fence
  local has_opening_fence = first_line:match('^```')
  local has_closing_fence = #lines > 1 and last_line:match('^```$')

  local new_language = self.language
  local code_lines = {}

  if has_opening_fence then
    -- Extract language from opening fence
    local lang = first_line:match('^```(.*)$')
    if lang and lang ~= '' then
      new_language = lang
    elseif lang == '' then
      new_language = 'plain text'
    end

    -- Extract code content (skip opening fence, optionally skip closing fence)
    local start_idx = 2
    local end_idx = #lines

    if has_closing_fence then
      end_idx = #lines - 1
    end

    for i = start_idx, end_idx do
      table.insert(code_lines, lines[i])
    end
  else
    -- No opening fence - treat all lines as content (minus closing fence if present)
    local end_idx = #lines
    if has_closing_fence then
      end_idx = #lines - 1
    end

    for i = 1, end_idx do
      table.insert(code_lines, lines[i])
    end
  end

  local new_text = table.concat(code_lines, '\n')

  -- Update language if changed
  if new_language ~= self.language then
    self.language = new_language
    self.dirty = true
  end

  -- Update code text if changed
  if new_text ~= self.code_text then
    self.code_text = new_text
    self.dirty = true
  end
end

---Get current code content (without fences)
---@return string
function CodeBlock:get_text()
  return self.code_text
end

---Check if content matches given lines
---@param lines string[]
---@return boolean
function CodeBlock:matches_content(lines)
  if #lines == 0 then
    return self.code_text == ''
  end

  -- Parse the lines the same way update_from_lines would
  local first_line = lines[1] or ''
  local last_line = lines[#lines] or ''

  local has_opening_fence = first_line:match('^```')
  local has_closing_fence = #lines > 1 and last_line:match('^```$')

  local code_lines = {}

  if has_opening_fence then
    local start_idx = 2
    local end_idx = #lines

    if has_closing_fence then
      end_idx = #lines - 1
    end

    for i = start_idx, end_idx do
      table.insert(code_lines, lines[i])
    end
  else
    local end_idx = #lines
    if has_closing_fence then
      end_idx = #lines - 1
    end

    for i = 1, end_idx do
      table.insert(code_lines, lines[i])
    end
  end

  local text = table.concat(code_lines, '\n')
  return text == self.code_text
end

---Render code block (uses default text-based rendering for now)
---Syntax highlighting deferred to Phase 9+
---@param ctx neotion.RenderContext
---@return boolean handled
function CodeBlock:render(ctx)
  -- Code block uses default text rendering for now
  -- Syntax highlighting with treesitter is deferred to Phase 9+
  return false
end

---Check if block has children
---@return boolean
function CodeBlock:has_children()
  return false
end

---Get the gutter icon for this code block
---@return string code icon
function CodeBlock:get_gutter_icon()
  return '<>'
end

-- Module interface for registry
M.new = CodeBlock.new
M.is_editable = function()
  return true
end
M.CodeBlock = CodeBlock

return M
