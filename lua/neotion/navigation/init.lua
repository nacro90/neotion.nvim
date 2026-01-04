---Navigation module for link detection and navigation
---@class neotion.navigation
local M = {}

local log = require('neotion.log').get_logger('navigation')

---@class neotion.Link
---@field text string Display text of the link
---@field url string Raw URL
---@field type 'external'|'notion_page'|'unsupported'|'unknown'
---@field page_id? string Extracted page ID for notion_page type
---@field reason? string Reason for unsupported links
---@field start_col integer 1-indexed start column of link in line
---@field end_col integer 1-indexed end column of link in line (after closing paren)

---Pattern for matching markdown links: [text](url)
local LINK_PATTERN = '%[(.-)%]%(([^%)]+)%)'

---Classify a URL and extract metadata
---@param url string
---@return 'external'|'notion_page'|'unsupported'|'unknown' type
---@return table|nil meta Additional metadata (page_id, reason)
function M.classify_url(url)
  if not url or url == '' then
    return 'unknown', nil
  end

  -- notion://page/id format
  local page_id = url:match('^notion://page/([a-zA-Z0-9]+)$')
  if page_id then
    return 'notion_page', { page_id = page_id }
  end

  -- notion://block/id format - not supported yet, treat as unsupported
  if url:match('^notion://block/') then
    return 'unsupported', { reason = 'Block links are not supported yet' }
  end

  -- notion.so URLs: https://notion.so/Page-Title-abc123... or https://www.notion.so/workspace/Page-abc123...
  -- Page ID is the last 32 hex chars before any query string
  local notion_page_id = url:match('notion%.so/.-%-([a-f0-9]+)$')
    or url:match('notion%.so/.-%-([a-f0-9]+)%?')
    or url:match('notion%.so/([a-f0-9]+)$')
    or url:match('notion%.so/([a-f0-9]+)%?')
  if notion_page_id and #notion_page_id >= 24 then
    return 'notion_page', { page_id = notion_page_id }
  end

  -- External URLs: http://, https://, mailto:
  if url:match('^https?://') or url:match('^mailto:') then
    return 'external', nil
  end

  -- Everything else is unknown (relative paths, file://, etc.)
  return 'unknown', nil
end

---Find all links in a line
---@param line string
---@return neotion.Link[]
function M.find_links_in_line(line)
  local links = {}
  local search_start = 1

  while true do
    -- Find next link starting from search_start
    local match_start, match_end, text, url = line:find(LINK_PATTERN, search_start)
    if not match_start then
      break
    end

    local link_type, meta = M.classify_url(url)

    ---@type neotion.Link
    local link = {
      text = text,
      url = url,
      type = link_type,
      start_col = match_start,
      end_col = match_end,
    }

    -- Add metadata if present
    if meta then
      if meta.page_id then
        link.page_id = meta.page_id
      end
      if meta.block_id then
        link.block_id = meta.block_id
      end
    end

    table.insert(links, link)
    search_start = match_end + 1
  end

  return links
end

---Parse link at a specific position in a buffer
---@param bufnr integer Buffer number
---@param line integer 1-indexed line number
---@param col integer 0-indexed column number
---@return neotion.Link|nil
function M.parse_link_at_position(bufnr, line, col)
  local lines = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)
  if #lines == 0 then
    return nil
  end

  local line_text = lines[1]
  if line_text == '' then
    return nil
  end

  local links = M.find_links_in_line(line_text)

  -- Find link that contains the cursor position
  -- col is 0-indexed, start_col/end_col are 1-indexed
  local cursor_col_1indexed = col + 1

  for _, link in ipairs(links) do
    if cursor_col_1indexed >= link.start_col and cursor_col_1indexed <= link.end_col then
      return link
    end
  end

  return nil
end

---Get link at current cursor position
---@return neotion.Link|nil
function M.get_link_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]
  local col = cursor[2]

  return M.parse_link_at_position(bufnr, line, col)
end

---Navigate to a link
---@param link neotion.Link
---@param opts? {open_page?: fun(page_id: string)}
function M.goto_link(link, opts)
  opts = opts or {}

  log.debug('Navigating to link', { type = link.type, url = link.url })

  if link.type == 'external' then
    -- Open external URL in browser
    local ok, err = pcall(function()
      if vim.ui.open then
        vim.ui.open(link.url)
      else
        -- Fallback for older Neovim versions
        local cmd
        if vim.fn.has('mac') == 1 then
          cmd = { 'open', link.url }
        elseif vim.fn.has('unix') == 1 then
          cmd = { 'xdg-open', link.url }
        elseif vim.fn.has('win32') == 1 then
          cmd = { 'cmd', '/c', 'start', '', link.url }
        end
        if cmd then
          vim.fn.jobstart(cmd, { detach = true })
        end
      end
    end)
    if not ok then
      log.error('Failed to open external link', { error = err })
      vim.notify('Failed to open link: ' .. tostring(err), vim.log.levels.ERROR)
    end
  elseif link.type == 'notion_page' then
    -- Open Notion page
    if opts.open_page then
      opts.open_page(link.page_id)
    else
      -- Use neotion.open if available
      local neotion = require('neotion')
      if neotion.open then
        neotion.open(link.page_id)
      else
        vim.notify('Cannot open Notion page: neotion.open not available', vim.log.levels.WARN)
      end
    end
  elseif link.type == 'unsupported' then
    local reason = link.reason or 'Link type not supported'
    vim.notify(reason, vim.log.levels.INFO)
    log.info('Unsupported link', { url = link.url, reason = reason })
  else
    vim.notify('Unknown link type: ' .. link.url, vim.log.levels.WARN)
  end
end

---Navigate to link at current cursor position
---@param opts? {open_page?: fun(page_id: string)}
function M.goto_link_at_cursor(opts)
  local link = M.get_link_at_cursor()
  if not link then
    vim.notify('No link under cursor', vim.log.levels.INFO)
    return
  end
  M.goto_link(link, opts)
end

return M
