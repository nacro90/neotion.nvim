---Mock API client for Neotion integration tests
---@class neotion.test.MockAPI
local M = {}

---@class neotion.test.MockPage
---@field id string
---@field title string
---@field icon? {type: string, emoji?: string}
---@field parent {type: string, workspace?: boolean, page_id?: string}
---@field blocks neotion.test.MockBlock[]

---@class neotion.test.MockBlock
---@field id string
---@field type string
---@field has_children boolean
---@field [string] table Block content (paragraph, heading_1, etc.)

-- Mock data store
local mock_pages = {}
local mock_blocks = {}

---Reset all mock data
function M.reset()
  mock_pages = {}
  mock_blocks = {}
end

---Add a mock page
---@param page neotion.test.MockPage
function M.add_page(page)
  mock_pages[page.id] = page
  mock_blocks[page.id] = page.blocks or {}
end

---Create a mock paragraph block
---@param id string
---@param text string
---@return table
function M.paragraph(id, text)
  return {
    id = id,
    type = 'paragraph',
    has_children = false,
    paragraph = {
      rich_text = {
        {
          type = 'text',
          text = { content = text, link = nil },
          plain_text = text,
          href = nil,
          annotations = {
            bold = false,
            italic = false,
            strikethrough = false,
            underline = false,
            code = false,
            color = 'default',
          },
        },
      },
      color = 'default',
    },
  }
end

---Create a mock heading block
---@param id string
---@param text string
---@param level integer 1, 2, or 3
---@return table
function M.heading(id, text, level)
  local block_type = 'heading_' .. level
  return {
    id = id,
    type = block_type,
    has_children = false,
    [block_type] = {
      rich_text = {
        {
          type = 'text',
          text = { content = text, link = nil },
          plain_text = text,
          href = nil,
          annotations = {
            bold = false,
            italic = false,
            strikethrough = false,
            underline = false,
            code = false,
            color = 'default',
          },
        },
      },
      color = 'default',
      is_toggleable = false,
    },
  }
end

---Create a mock toggle block
---@param id string
---@param text string
---@param children? table[]
---@return table
function M.toggle(id, text, children)
  return {
    id = id,
    type = 'toggle',
    has_children = children and #children > 0 or false,
    toggle = {
      rich_text = {
        {
          type = 'text',
          text = { content = text, link = nil },
          plain_text = text,
          href = nil,
          annotations = {
            bold = false,
            italic = false,
            strikethrough = false,
            underline = false,
            code = false,
            color = 'default',
          },
        },
      },
      color = 'default',
    },
    children = children or {},
  }
end

---Create a mock code block
---@param id string
---@param code string
---@param language? string
---@return table
function M.code(id, code, language)
  return {
    id = id,
    type = 'code',
    has_children = false,
    code = {
      rich_text = {
        {
          type = 'text',
          text = { content = code, link = nil },
          plain_text = code,
          href = nil,
          annotations = {
            bold = false,
            italic = false,
            strikethrough = false,
            underline = false,
            code = false,
            color = 'default',
          },
        },
      },
      language = language or 'plain text',
      caption = {},
    },
  }
end

---Create a mock quote block
---@param id string
---@param text string
---@return table
function M.quote(id, text)
  return {
    id = id,
    type = 'quote',
    has_children = false,
    quote = {
      rich_text = {
        {
          type = 'text',
          text = { content = text, link = nil },
          plain_text = text,
          href = nil,
          annotations = {
            bold = false,
            italic = false,
            strikethrough = false,
            underline = false,
            code = false,
            color = 'default',
          },
        },
      },
      color = 'default',
    },
  }
end

---Create a mock divider block
---@param id string
---@return table
function M.divider(id)
  return {
    id = id,
    type = 'divider',
    has_children = false,
    divider = {},
  }
end

---Create a mock bulleted list item block
---@param id string
---@param text string
---@return table
function M.bulleted_list_item(id, text)
  return {
    id = id,
    type = 'bulleted_list_item',
    has_children = false,
    bulleted_list_item = {
      rich_text = {
        {
          type = 'text',
          text = { content = text, link = nil },
          plain_text = text,
          href = nil,
          annotations = {
            bold = false,
            italic = false,
            strikethrough = false,
            underline = false,
            code = false,
            color = 'default',
          },
        },
      },
      color = 'default',
    },
  }
end

---Create a mock page with standard structure
---@param id string
---@param title string
---@param blocks? table[]
---@return table
function M.page(id, title, blocks)
  return {
    object = 'page',
    id = id,
    created_time = '2024-01-01T00:00:00.000Z',
    last_edited_time = '2024-01-01T00:00:00.000Z',
    created_by = { object = 'user', id = 'user-1' },
    last_edited_by = { object = 'user', id = 'user-1' },
    parent = { type = 'workspace', workspace = true },
    archived = false,
    in_trash = false,
    properties = {
      title = {
        id = 'title',
        type = 'title',
        title = {
          {
            type = 'text',
            text = { content = title, link = nil },
            plain_text = title,
            href = nil,
            annotations = {
              bold = false,
              italic = false,
              strikethrough = false,
              underline = false,
              code = false,
              color = 'default',
            },
          },
        },
      },
    },
    icon = nil,
    cover = nil,
    url = 'https://notion.so/' .. id,
    public_url = nil,
  }
end

---Install mock into the API modules
---Replaces actual API calls with mock implementations
function M.install()
  local pages_api = require('neotion.api.pages')
  local blocks_api = require('neotion.api.blocks')

  -- Store original functions
  M._original_pages_get = pages_api.get
  M._original_blocks_get_all_children = blocks_api.get_all_children
  M._original_blocks_update = blocks_api.update

  -- Mock pages.get
  pages_api.get = function(page_id, callback)
    vim.schedule(function()
      local page = mock_pages[page_id]
      if page then
        callback({ page = M.page(page.id, page.title, page.blocks), error = nil })
      else
        callback({ page = nil, error = 'Page not found: ' .. page_id })
      end
    end)
  end

  -- Mock blocks.get_all_children
  blocks_api.get_all_children = function(page_id, callback)
    vim.schedule(function()
      local blocks = mock_blocks[page_id]
      if blocks then
        callback({ blocks = blocks, has_more = false, error = nil })
      else
        callback({ blocks = {}, has_more = false, error = nil })
      end
    end)
  end

  -- Mock blocks.update
  blocks_api.update = function(block_id, block_data, callback)
    vim.schedule(function()
      -- Find and update the block in mock data
      for page_id, blocks in pairs(mock_blocks) do
        for i, block in ipairs(blocks) do
          if block.id == block_id then
            -- Merge the update
            mock_blocks[page_id][i] = vim.tbl_deep_extend('force', block, block_data)
            callback({ block = mock_blocks[page_id][i], error = nil })
            return
          end
        end
      end
      callback({ block = nil, error = 'Block not found: ' .. block_id })
    end)
  end
end

---Uninstall mock and restore original API functions
function M.uninstall()
  local pages_api = require('neotion.api.pages')
  local blocks_api = require('neotion.api.blocks')

  if M._original_pages_get then
    pages_api.get = M._original_pages_get
    M._original_pages_get = nil
  end

  if M._original_blocks_get_all_children then
    blocks_api.get_all_children = M._original_blocks_get_all_children
    M._original_blocks_get_all_children = nil
  end

  if M._original_blocks_update then
    blocks_api.update = M._original_blocks_update
    M._original_blocks_update = nil
  end
end

---Get blocks for a page (for assertions)
---@param page_id string
---@return table[]
function M.get_blocks(page_id)
  return mock_blocks[page_id] or {}
end

---Get a specific block by ID
---@param block_id string
---@return table|nil
function M.get_block(block_id)
  for _, blocks in pairs(mock_blocks) do
    for _, block in ipairs(blocks) do
      if block.id == block_id then
        return block
      end
    end
  end
  return nil
end

return M
