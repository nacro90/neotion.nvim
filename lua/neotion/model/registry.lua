---Block Type Registry for Neotion
---Maps block types to their handlers
---Provides deserialization dispatch
---@class neotion.model.Registry
local M = {}

---@class neotion.BlockHandler
---@field new fun(raw: table): neotion.Block
---@field is_editable fun(): boolean

---@type table<string, neotion.BlockHandler>
local handlers = {}

---@type table<string, string>
local type_to_module = {
  paragraph = 'paragraph',
  heading_1 = 'heading',
  heading_2 = 'heading',
  heading_3 = 'heading',
  -- Phase 5.7: Basic block types
  divider = 'divider',
  quote = 'quote',
  bulleted_list_item = 'bulleted_list',
  numbered_list_item = 'numbered_list',
  code = 'code',
  -- Phase 12: Navigation blocks
  child_page = 'child_page',
  -- Phase 13: Database blocks
  child_database = 'child_database',
  -- Toggle block (MVP: content only, children deferred)
  toggle = 'toggle',
  -- Phase 9+ (future)
  -- to_do = 'todo',
  -- callout = 'callout',
}

---Get handler for a block type
---@param block_type string
---@return neotion.BlockHandler|nil
function M.get_handler(block_type)
  -- Return cached handler
  if handlers[block_type] then
    return handlers[block_type]
  end

  -- Try to load handler module
  local module_name = type_to_module[block_type]
  if not module_name then
    return nil -- No handler for this type
  end

  local ok, handler = pcall(require, 'neotion.model.blocks.' .. module_name)
  if ok and handler then
    handlers[block_type] = handler
    return handler
  end

  return nil
end

---Check if a block type is supported (editable)
---@param block_type string
---@return boolean
function M.is_supported(block_type)
  return M.get_handler(block_type) ~= nil
end

---Deserialize a single block from Notion API JSON
---@param raw table Notion API block JSON
---@return neotion.Block
function M.deserialize(raw)
  local log = require('neotion.log').get_logger('registry')
  local handler = M.get_handler(raw.type)
  local block

  if handler then
    block = handler.new(raw)
  else
    -- Fallback: base Block (read-only)
    local base = require('neotion.model.block')
    block = base.Block.new(raw)
  end

  -- If raw has _children (populated by get_all_children), deserialize and add them
  if raw._children and #raw._children > 0 then
    log.debug('deserialize: block has _children', {
      block_id = raw.id,
      block_type = raw.type,
      children_count = #raw._children,
    })
    for _, child_raw in ipairs(raw._children) do
      local child_block = M.deserialize(child_raw)
      block:add_child(child_block)
    end
    log.debug('deserialize: children added', {
      block_id = raw.id,
      final_children_count = #block:get_children(),
    })
  end

  return block
end

---Deserialize array of blocks from Notion API JSON
---@param blocks table[] Raw Notion blocks
---@return neotion.Block[]
function M.deserialize_all(blocks)
  local result = {}
  for _, raw in ipairs(blocks) do
    table.insert(result, M.deserialize(raw))
  end
  return result
end

---Get list of all supported block types
---@return string[]
function M.get_supported_types()
  return vim.tbl_keys(type_to_module)
end

---Check if a page is fully editable (all blocks supported)
---@param blocks neotion.Block[]
---@return boolean is_fully_editable
---@return string[] unsupported_types List of unsupported types found
function M.check_editability(blocks)
  local unsupported = {}
  local seen = {}

  for _, block in ipairs(blocks) do
    if not block:is_editable() and not seen[block.type] then
      table.insert(unsupported, block.type)
      seen[block.type] = true
    end
  end

  return #unsupported == 0, unsupported
end

---Clear handler cache (for testing)
function M.clear_cache()
  handlers = {}
end

return M
