---Notion Blocks API
---@class neotion.api.Blocks
local M = {}

---@alias neotion.BlockType
---| 'paragraph'
---| 'heading_1'
---| 'heading_2'
---| 'heading_3'
---| 'bulleted_list_item'
---| 'numbered_list_item'
---| 'to_do'
---| 'toggle'
---| 'code'
---| 'quote'
---| 'callout'
---| 'divider'
---| 'image'
---| 'bookmark'
---| 'child_page'
---| 'child_database'
---| 'unsupported'

---@class neotion.api.RichText
---@field type string 'text' | 'mention' | 'equation'
---@field plain_text string
---@field annotations table
---@field href string|nil

---@class neotion.api.Block
---@field id string Block ID
---@field type neotion.BlockType
---@field created_time string
---@field last_edited_time string
---@field has_children boolean
---@field archived boolean
---@field parent table
---@field [string] table Block type specific data

---@class neotion.api.BlocksResult
---@field blocks neotion.api.Block[]
---@field has_more boolean
---@field next_cursor string|nil
---@field error string|nil

---Get children blocks of a block (or page)
---@param block_id string Block or Page ID
---@param callback fun(result: neotion.api.BlocksResult)
---@param cursor? string Pagination cursor
function M.get_children(block_id, callback, cursor)
  local auth = require('neotion.api.auth')
  local client = require('neotion.api.client')

  local token_result = auth.get_token()
  if not token_result.token then
    callback({ blocks = {}, has_more = false, error = token_result.error })
    return
  end

  local normalized_id = block_id:gsub('-', '')
  local endpoint = '/blocks/' .. normalized_id .. '/children?page_size=100'
  if cursor then
    endpoint = endpoint .. '&start_cursor=' .. cursor
  end

  client.get(endpoint, token_result.token, function(response)
    if response.error then
      callback({ blocks = {}, has_more = false, error = response.error })
      return
    end

    callback({
      blocks = response.body.results or {},
      has_more = response.body.has_more or false,
      next_cursor = response.body.next_cursor,
      error = nil,
    })
  end)
end

---Get all children blocks recursively (handles pagination)
---@param block_id string
---@param callback fun(result: neotion.api.BlocksResult)
function M.get_all_children(block_id, callback)
  local all_blocks = {}

  local function fetch_page(cursor)
    M.get_children(block_id, function(result)
      if result.error then
        callback({ blocks = all_blocks, has_more = false, error = result.error })
        return
      end

      vim.list_extend(all_blocks, result.blocks)

      if result.has_more and result.next_cursor then
        fetch_page(result.next_cursor)
      else
        callback({ blocks = all_blocks, has_more = false, error = nil })
      end
    end, cursor)
  end

  fetch_page(nil)
end

---Extract plain text from rich text array
---@param rich_text neotion.api.RichText[]
---@return string
function M.rich_text_to_plain(rich_text)
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

---Get the text content of a block
---@param block neotion.api.Block
---@return string
function M.get_block_text(block)
  if not block or not block.type then
    return ''
  end

  local block_data = block[block.type]
  if not block_data then
    return ''
  end

  -- Most block types have a rich_text field
  if block_data.rich_text then
    return M.rich_text_to_plain(block_data.rich_text)
  end

  -- Special cases
  if block.type == 'child_page' then
    return block_data.title or ''
  elseif block.type == 'child_database' then
    return block_data.title or ''
  end

  return ''
end

return M
