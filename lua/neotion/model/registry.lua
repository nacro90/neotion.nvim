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
  code = 'code',
  -- Phase 9+
  -- numbered_list_item = 'numbered_list',
  -- to_do = 'todo',
  -- toggle = 'toggle',
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
  local handler = M.get_handler(raw.type)
  if handler then
    return handler.new(raw)
  end

  -- Fallback: base Block (read-only)
  local base = require('neotion.model.block')
  return base.Block.new(raw)
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
