--- Format provider registry for neotion.nvim
--- Manages parsing and rendering of inline formatting
---@module 'neotion.format.init'

local M = {}

---@class neotion.FormatProvider
---@field name string Provider name
---@field parse fun(text: string): neotion.RichTextSegment[] Parse text to segments
---@field render fun(segments: neotion.RichTextSegment[]): string Render segments to text
---@field render_segment? fun(segment: neotion.RichTextSegment): string Render single segment

--- Registered providers
---@type table<string, neotion.FormatProvider>
M._providers = {}

--- Default provider name
---@type string
M._default = 'notion'

--- Register a format provider
---@param provider neotion.FormatProvider
function M.register_provider(provider)
  if not provider.name then
    error('Provider must have a name')
  end

  if not provider.parse then
    error('Provider must have a parse function')
  end

  if not provider.render then
    error('Provider must have a render function')
  end

  M._providers[provider.name] = provider
end

--- Get a provider by name
---@param name string
---@return neotion.FormatProvider|nil
function M.get_provider(name)
  return M._providers[name]
end

--- Get the default provider
---@return neotion.FormatProvider
function M.get_default_provider()
  local provider = M._providers[M._default]

  if not provider then
    -- Lazy load notion provider
    local notion = require('neotion.format.notion')
    M.register_provider(notion)
    return notion
  end

  return provider
end

--- Set the default provider
---@param name string
function M.set_default_provider(name)
  if not M._providers[name] then
    error('Unknown provider: ' .. name)
  end

  M._default = name
end

--- Ensure a provider is loaded (lazy load if needed)
---@param name string
---@return neotion.FormatProvider
local function ensure_provider(name)
  local provider = M._providers[name]

  if not provider then
    -- Try to lazy load built-in providers
    if name == 'notion' then
      local notion = require('neotion.format.notion')
      M.register_provider(notion)
      return notion
    end
    error('Unknown provider: ' .. name)
  end

  return provider
end

--- Parse text to rich text segments using a provider
---@param text string
---@param provider_name? string Provider to use (default: default provider)
---@return neotion.RichTextSegment[]
function M.parse(text, provider_name)
  local provider

  if provider_name then
    provider = ensure_provider(provider_name)
  else
    provider = M.get_default_provider()
  end

  return provider.parse(text)
end

--- Render rich text segments to text using a provider
---@param segments neotion.RichTextSegment[]
---@param provider_name? string Provider to use (default: default provider)
---@return string
function M.render(segments, provider_name)
  local provider

  if provider_name then
    provider = ensure_provider(provider_name)
  else
    provider = M.get_default_provider()
  end

  return provider.render(segments)
end

--- List all registered provider names
---@return string[]
function M.list_providers()
  local names = {}

  for name, _ in pairs(M._providers) do
    table.insert(names, name)
  end

  return names
end

return M
