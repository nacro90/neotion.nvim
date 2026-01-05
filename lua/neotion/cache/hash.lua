--- Hash utilities for cache dirty detection
--- Uses djb2 algorithm for fast, deterministic hashing
---@class neotion.cache.Hash
local M = {}

--- djb2 hash algorithm
--- Fast, simple 32-bit hash function suitable for dirty detection
--- Note: 32-bit output has collision probability per birthday paradox
--- (~0.1% at 10k items), but this is acceptable for cache invalidation
--- @param str string The string to hash
--- @return string hash 8-character hex string
function M.djb2(str)
  if str == nil then
    str = ''
  end

  local hash = 5381

  for i = 1, #str do
    local byte = string.byte(str, i)
    -- hash * 33 + byte, keeping within 32-bit range
    -- Using modulo to prevent overflow in Lua 5.1
    hash = ((hash * 33) + byte) % 0x100000000
  end

  return string.format('%08x', hash)
end

--- Hash page content (array of blocks)
--- Serializes blocks to JSON-like string and hashes
--- @param blocks table[]? Array of block objects
--- @return string hash 8-character hex string
function M.page_content(blocks)
  if blocks == nil or #blocks == 0 then
    return M.djb2('[]')
  end

  -- Simple serialization: concatenate block representations
  local parts = {}
  for i, block in ipairs(blocks) do
    parts[i] = M._serialize_table(block)
  end

  local serialized = '[' .. table.concat(parts, ',') .. ']'
  return M.djb2(serialized)
end

--- Hash a single block
--- @param block table? Block object
--- @return string hash 8-character hex string
function M.block_content(block)
  if block == nil then
    return M.djb2('null')
  end

  local serialized = M._serialize_table(block)
  return M.djb2(serialized)
end

--- Compare two hashes
--- @param hash1 string?
--- @param hash2 string?
--- @return boolean equal True if hashes are equal
function M.compare(hash1, hash2)
  if hash1 == nil and hash2 == nil then
    return true
  end
  if hash1 == nil or hash2 == nil then
    return false
  end
  return hash1 == hash2
end

--- Serialize a table to a deterministic string representation
--- Simple JSON-like format for consistent hashing
--- @param tbl table
--- @return string
function M._serialize_table(tbl)
  if type(tbl) ~= 'table' then
    if type(tbl) == 'string' then
      -- Escape special characters for JSON-like format
      local escaped = tbl:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
      return '"' .. escaped .. '"'
    elseif type(tbl) == 'boolean' then
      return tbl and 'true' or 'false'
    elseif tbl == nil then
      return 'null'
    else
      return tostring(tbl)
    end
  end

  -- Check if array or object
  local is_array = #tbl > 0 or next(tbl) == nil

  if is_array and #tbl > 0 then
    -- Array
    local parts = {}
    for i, v in ipairs(tbl) do
      parts[i] = M._serialize_table(v)
    end
    return '[' .. table.concat(parts, ',') .. ']'
  else
    -- Object - sort keys for deterministic output
    local keys = {}
    for k in pairs(tbl) do
      if type(k) == 'string' then
        table.insert(keys, k)
      end
    end
    table.sort(keys)

    local parts = {}
    for _, k in ipairs(keys) do
      -- Escape key as well
      local escaped_key = k:gsub('\\', '\\\\'):gsub('"', '\\"')
      table.insert(parts, '"' .. escaped_key .. '":' .. M._serialize_table(tbl[k]))
    end
    return '{' .. table.concat(parts, ',') .. '}'
  end
end

return M
