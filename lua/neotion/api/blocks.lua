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
---@field _children? neotion.api.Block[] Children blocks (populated by get_all_children)

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
  local throttle = require('neotion.api.throttle')

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

  throttle.get(endpoint, token_result.token, function(response)
    if response.cancelled then
      callback({ blocks = {}, has_more = false, error = 'Request cancelled' })
      return
    end
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

---Get all children blocks recursively (handles pagination and nested children)
---Blocks with has_children=true will have their children fetched and stored in _children field
---@param block_id string Block or Page ID
---@param callback fun(result: neotion.api.BlocksResult)
---@param opts? {max_depth?: number, _current_depth?: number} Options (max_depth defaults to 3)
function M.get_all_children(block_id, callback, opts)
  opts = opts or {}
  local max_depth = opts.max_depth or 3
  local current_depth = opts._current_depth or 0

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
        -- All blocks for this level fetched, now fetch nested children
        M._fetch_nested_children(all_blocks, max_depth, current_depth, function(err)
          if err then
            callback({ blocks = all_blocks, has_more = false, error = err })
          else
            callback({ blocks = all_blocks, has_more = false, error = nil })
          end
        end)
      end
    end, cursor)
  end

  fetch_page(nil)
end

---Recursively fetch children for blocks that have children
---@param blocks neotion.api.Block[] Blocks to process
---@param max_depth number Maximum nesting depth
---@param current_depth number Current depth level
---@param callback fun(error: string|nil) Called when all nested children are fetched
---@private
function M._fetch_nested_children(blocks, max_depth, current_depth, callback)
  -- Don't go deeper than max_depth
  if current_depth >= max_depth then
    callback(nil)
    return
  end

  -- Find blocks that have children
  local blocks_with_children = {}
  for _, block in ipairs(blocks) do
    if block.has_children then
      table.insert(blocks_with_children, block)
    end
  end

  -- No blocks with children, we're done
  if #blocks_with_children == 0 then
    callback(nil)
    return
  end

  -- Fetch children for each block sequentially to avoid rate limiting
  local pending = #blocks_with_children
  local first_error = nil

  for _, block in ipairs(blocks_with_children) do
    M.get_all_children(block.id, function(result)
      if result.error and not first_error then
        first_error = result.error
      end

      -- Store children in the block's _children field
      if not result.error and #result.blocks > 0 then
        block._children = result.blocks
      end

      pending = pending - 1
      if pending == 0 then
        callback(first_error)
      end
    end, { max_depth = max_depth, _current_depth = current_depth + 1 })
  end
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

---Convert Notion API rich text array to Notion syntax (with formatting markers)
---@param rich_text neotion.api.RichText[]
---@return string
function M.rich_text_to_notion_syntax(rich_text)
  if not rich_text or type(rich_text) ~= 'table' then
    return ''
  end

  local types = require('neotion.format.types')
  local notion = require('neotion.format.notion')

  -- Convert API rich text to RichTextSegment array
  local segments = {}
  local col = 0
  for _, text in ipairs(rich_text) do
    local segment = types.RichTextSegment.from_api(text, col)
    table.insert(segments, segment)
    col = segment.end_col
  end

  -- Render segments to Notion syntax
  return notion.render(segments)
end

---Get the text content of a block (plain text without formatting)
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

---Get the text content of a block with Notion syntax formatting markers
---@param block neotion.api.Block
---@return string
function M.get_block_text_formatted(block)
  if not block or not block.type then
    return ''
  end

  local block_data = block[block.type]
  if not block_data then
    return ''
  end

  -- Most block types have a rich_text field
  if block_data.rich_text then
    return M.rich_text_to_notion_syntax(block_data.rich_text)
  end

  -- Special cases - these don't have formatting
  if block.type == 'child_page' then
    return block_data.title or ''
  elseif block.type == 'child_database' then
    return block_data.title or ''
  end

  return ''
end

---@class neotion.api.UpdateResult
---@field error string|nil Error message if update failed
---@field block neotion.api.Block|nil Updated block data

---Update a block's content
---@param block_id string Block ID to update
---@param block_json table Block data in Notion API format
---@param callback fun(result: neotion.api.UpdateResult)
function M.update(block_id, block_json, callback)
  local auth = require('neotion.api.auth')
  local throttle = require('neotion.api.throttle')

  local token_result = auth.get_token()
  if not token_result.token then
    callback({ error = token_result.error })
    return
  end

  local normalized_id = block_id:gsub('-', '')

  -- Remove read-only fields that can't be updated
  local body = vim.deepcopy(block_json)
  body.id = nil
  body.created_time = nil
  body.last_edited_time = nil
  body.created_by = nil
  body.last_edited_by = nil
  body.has_children = nil
  body.archived = nil
  body.in_trash = nil
  body.parent = nil
  body.object = nil

  throttle.patch('/blocks/' .. normalized_id, token_result.token, body, function(response)
    if response.cancelled then
      callback({ error = 'Request cancelled' })
      return
    end
    if response.error then
      callback({ error = response.error })
      return
    end

    callback({
      error = nil,
      block = response.body,
    })
  end)
end

---@class neotion.api.AppendResult
---@field error string|nil Error message if append failed
---@field blocks neotion.api.Block[]|nil Created blocks

---Append new blocks to a parent (page or block)
---@param parent_id string Parent page or block ID
---@param children table[] Array of block objects to append
---@param callback fun(result: neotion.api.AppendResult)
---@param after_block_id string|nil Optional block ID to insert after (for positioning)
function M.append(parent_id, children, callback, after_block_id)
  local auth = require('neotion.api.auth')
  local throttle = require('neotion.api.throttle')
  local log = require('neotion.log').get_logger('api.blocks')

  local token_result = auth.get_token()
  if not token_result.token then
    callback({ error = token_result.error, blocks = {} })
    return
  end

  local normalized_id = parent_id:gsub('-', '')

  local body = {
    children = children,
  }

  -- Add after parameter for positioned insert
  if after_block_id then
    body.after = after_block_id:gsub('-', '')
  end

  throttle.patch('/blocks/' .. normalized_id .. '/children', token_result.token, body, function(response)
    if response.cancelled then
      callback({ error = 'Request cancelled', blocks = {} })
      return
    end
    if response.error then
      callback({ error = response.error, blocks = {} })
      return
    end

    callback({
      error = nil,
      blocks = response.body.results or {},
    })
  end)
end

---@class neotion.api.DeleteResult
---@field error string|nil Error message if delete failed

---Delete (archive) a block
---@param block_id string Block ID to delete
---@param callback fun(result: neotion.api.DeleteResult)
function M.delete(block_id, callback)
  local auth = require('neotion.api.auth')
  local throttle = require('neotion.api.throttle')

  local token_result = auth.get_token()
  if not token_result.token then
    callback({ error = token_result.error })
    return
  end

  local normalized_id = block_id:gsub('-', '')

  -- Notion API uses DELETE method to archive blocks
  throttle.request('/blocks/' .. normalized_id, token_result.token, { method = 'DELETE' }, function(response)
    if response.cancelled then
      callback({ error = 'Request cancelled' })
      return
    end
    if response.error then
      callback({ error = response.error })
      return
    end

    callback({ error = nil })
  end)
end

return M
