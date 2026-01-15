-- TODO(neotion:FEAT-13.13:LOW): Display row page icons in database view
-- Show page icons for each database row (like page blocks):
-- - Fetch icon from row's page properties
-- - Display in gutter or as first column
-- - Use icon_resolver from cache/icon module
-- - Fall back to default page icon if none set

---Database table renderer for Neotion
---Handles highlighting and extmarks for database buffer views
---@class neotion.render.database
local M = {}

local ns_id = vim.api.nvim_create_namespace('neotion_database')

---Apply highlights and extmarks to a database buffer
---@param bufnr integer
---@param database_view neotion.DatabaseView
function M.render(bufnr, database_view)
  -- Clear existing extmarks
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  -- Header line (title)
  vim.api.nvim_buf_add_highlight(bufnr, ns_id, 'NeotionDatabaseTitle', 0, 0, -1)

  -- Table header row (column names)
  local header_row = database_view.header_line_count - 2 -- 0-indexed, -2 for separator and header
  if header_row >= 0 then
    vim.api.nvim_buf_add_highlight(bufnr, ns_id, 'NeotionTableHeader', header_row, 0, -1)
  end

  -- Separator row
  local separator_row = database_view.header_line_count - 1 -- 0-indexed
  if separator_row >= 0 then
    vim.api.nvim_buf_add_highlight(bufnr, ns_id, 'NeotionTableSeparator', separator_row, 0, -1)
  end

  -- Data rows with alternating highlights
  for i, row in ipairs(database_view.rows) do
    local line_start, line_end = row:get_line_range()
    if line_start and line_end then
      for line = line_start, line_end do
        local hl_group = (i % 2 == 0) and 'NeotionTableRowEven' or 'NeotionTableRowOdd'
        vim.api.nvim_buf_add_highlight(bufnr, ns_id, hl_group, line - 1, 0, -1)
      end

      -- Add property-specific highlights (status colors, etc.)
      M.render_row_properties(bufnr, row, database_view, line_start - 1)
    end
  end
end

---Render property-specific highlights for a row
---@param bufnr integer
---@param row neotion.DatabaseRow
---@param database_view neotion.DatabaseView
---@param row_line integer 0-indexed line number
function M.render_row_properties(bufnr, row, database_view, row_line)
  -- Get line content
  local line_content = vim.api.nvim_buf_get_lines(bufnr, row_line, row_line + 1, false)[1]
  if not line_content then
    return
  end

  -- Track byte offset in line (for highlight API which uses byte offsets)
  -- Table format: '| cell1 | cell2 | cell3 |'
  local byte_offset = 2 -- After initial '| '

  for _, col in ipairs(database_view.columns) do
    local prop = row:get_property(col.name)

    -- Get actual cell content for this column to calculate byte length
    local cell_content = database_view:format_cell(row, col.name)
    -- Truncate like in format_data_row
    local display_width = vim.fn.strdisplaywidth(cell_content)
    if display_width > col.width then
      -- Content is truncated, use col.width
      display_width = col.width
    end

    -- Apply color highlighting for status/select columns
    if prop and (col.type == 'status' or col.type == 'select') then
      local value = prop.value
      if type(value) == 'table' and value.color then
        local color = value.color
        local color_hl = M.get_color_highlight(color)
        if color_hl then
          -- Highlight only the actual content, not padding
          -- For left-aligned cells, content starts at byte_offset
          local content_byte_len = #cell_content
          if display_width < vim.fn.strdisplaywidth(cell_content) then
            -- Content was truncated with "..."
            content_byte_len = col.width -- approximate, highlight full cell
          end
          local cell_end = math.min(byte_offset + content_byte_len, #line_content)
          vim.api.nvim_buf_add_highlight(bufnr, ns_id, color_hl, row_line, byte_offset, cell_end)
        end
      end
    end

    -- Checkbox styling
    if col.type == 'checkbox' and prop then
      local content_byte_len = prop.value and 3 or 3 -- '[x]' or '[ ]'
      local cell_end = math.min(byte_offset + content_byte_len, #line_content)
      local hl = prop.value and 'NeotionCheckboxChecked' or 'NeotionCheckboxUnchecked'
      vim.api.nvim_buf_add_highlight(bufnr, ns_id, hl, row_line, byte_offset, cell_end)
    end

    -- Move to next column: col.width (display width) + 3 for ' | '
    -- But we need byte offset, so calculate based on padded cell content
    -- Padded cell = content + padding spaces = col.width display characters
    -- For ASCII, display width = byte length, but for unicode we need to be careful
    -- Since padding is always ASCII spaces, byte length = original content bytes + padding bytes
    local cell_byte_len = #cell_content
    if display_width > col.width then
      -- Content was truncated
      cell_byte_len = col.width -- This is approximate for truncated content
    end
    local padding_bytes = col.width - display_width
    byte_offset = byte_offset + cell_byte_len + padding_bytes + 3 -- +3 for ' | '
  end
end

---Map Notion color to highlight group
---@param color string Notion color name
---@return string|nil
function M.get_color_highlight(color)
  local color_map = {
    default = nil,
    gray = 'NeotionStatusGray',
    brown = 'NeotionStatusBrown',
    orange = 'NeotionStatusOrange',
    yellow = 'NeotionStatusYellow',
    green = 'NeotionStatusGreen',
    blue = 'NeotionStatusBlue',
    purple = 'NeotionStatusPurple',
    pink = 'NeotionStatusPink',
    red = 'NeotionStatusRed',
  }
  return color_map[color]
end

---Setup highlight groups for database rendering
function M.setup_highlights()
  -- Table structure
  vim.api.nvim_set_hl(0, 'NeotionDatabaseTitle', { link = 'Title', default = true })
  vim.api.nvim_set_hl(0, 'NeotionTableHeader', { link = 'Bold', default = true })
  vim.api.nvim_set_hl(0, 'NeotionTableSeparator', { link = 'Comment', default = true })
  vim.api.nvim_set_hl(0, 'NeotionTableRowOdd', { default = true })
  vim.api.nvim_set_hl(0, 'NeotionTableRowEven', { link = 'CursorLine', default = true })

  -- Checkbox
  vim.api.nvim_set_hl(0, 'NeotionCheckboxChecked', { link = 'DiagnosticOk', default = true })
  vim.api.nvim_set_hl(0, 'NeotionCheckboxUnchecked', { link = 'Comment', default = true })

  -- Status colors (Notion palette)
  vim.api.nvim_set_hl(0, 'NeotionStatusGray', { fg = '#787774', default = true })
  vim.api.nvim_set_hl(0, 'NeotionStatusBrown', { fg = '#9F6B53', default = true })
  vim.api.nvim_set_hl(0, 'NeotionStatusOrange', { fg = '#D9730D', default = true })
  vim.api.nvim_set_hl(0, 'NeotionStatusYellow', { fg = '#CB912F', default = true })
  vim.api.nvim_set_hl(0, 'NeotionStatusGreen', { fg = '#448361', default = true })
  vim.api.nvim_set_hl(0, 'NeotionStatusBlue', { fg = '#337EA9', default = true })
  vim.api.nvim_set_hl(0, 'NeotionStatusPurple', { fg = '#9065B0', default = true })
  vim.api.nvim_set_hl(0, 'NeotionStatusPink', { fg = '#C14C8A', default = true })
  vim.api.nvim_set_hl(0, 'NeotionStatusRed', { fg = '#D44C47', default = true })
end

---Get namespace ID for database rendering
---@return integer
function M.get_namespace()
  return ns_id
end

---Clear all database rendering for a buffer
---@param bufnr integer
function M.clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
end

return M
