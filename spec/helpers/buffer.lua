---Test helper for buffer operations
---@class neotion.test.BufferHelper
local M = {}

---Create a test buffer with given lines
---@param lines string[]
---@return integer bufnr
function M.create(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_current_buf(bufnr)
  return bufnr
end

---Set cursor position in current window
---@param line integer 1-indexed line
---@param col integer 0-indexed column
function M.set_cursor(line, col)
  vim.api.nvim_win_set_cursor(0, { line, col })
end

---Get cursor position
---@return integer line, integer col
function M.get_cursor()
  local pos = vim.api.nvim_win_get_cursor(0)
  return pos[1], pos[2]
end

---Delete test buffer
---@param bufnr integer
function M.delete(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---Get extmarks in buffer for a namespace
---@param bufnr integer
---@param ns_name string
---@param line? integer 0-indexed line (nil for all)
---@return table[] marks
function M.get_extmarks(bufnr, ns_name, line)
  local ns = vim.api.nvim_create_namespace(ns_name)
  if line then
    return vim.api.nvim_buf_get_extmarks(bufnr, ns, { line, 0 }, { line, -1 }, { details = true })
  end
  return vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
end

---Assert extmarks with conceal exist on a line
---@param bufnr integer
---@param ns_name string
---@param line integer 0-indexed
---@param expected_count integer
function M.assert_conceal_marks(bufnr, ns_name, line, expected_count)
  local marks = M.get_extmarks(bufnr, ns_name, line)
  local conceal_count = 0
  for _, mark in ipairs(marks) do
    local details = mark[4]
    if details and details.conceal then
      conceal_count = conceal_count + 1
    end
  end
  assert.are.equal(
    expected_count,
    conceal_count,
    string.format('Expected %d conceal marks on line %d, got %d', expected_count, line, conceal_count)
  )
end

return M
