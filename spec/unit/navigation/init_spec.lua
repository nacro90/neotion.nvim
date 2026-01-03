---Navigation module tests
---@diagnostic disable: undefined-field

local buffer_helper = require('spec.helpers.buffer')

describe('navigation', function()
  local navigation

  before_each(function()
    navigation = require('neotion.navigation')
  end)

  after_each(function()
    -- Clean up any test buffers
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        local name = vim.api.nvim_buf_get_name(bufnr)
        if name == '' or name:match('^test') then
          pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
        end
      end
    end
    package.loaded['neotion.navigation'] = nil
  end)

  describe('parse_link_at_position', function()
    it('should return nil when not on a link', function()
      local bufnr = buffer_helper.create({ 'Just plain text here' })
      buffer_helper.set_cursor(1, 5)

      local link = navigation.parse_link_at_position(bufnr, 1, 5)

      assert.is_nil(link)
      buffer_helper.delete(bufnr)
    end)

    it('should return nil for empty line', function()
      local bufnr = buffer_helper.create({ '' })
      buffer_helper.set_cursor(1, 0)

      local link = navigation.parse_link_at_position(bufnr, 1, 0)

      assert.is_nil(link)
      buffer_helper.delete(bufnr)
    end)

    it('should detect markdown link when cursor on text', function()
      local bufnr = buffer_helper.create({ 'Check this [link](https://example.com) here' })
      buffer_helper.set_cursor(1, 13) -- On 'link' word

      local link = navigation.parse_link_at_position(bufnr, 1, 13)

      assert.is_not_nil(link)
      assert.are.equal('link', link.text)
      assert.are.equal('https://example.com', link.url)
      assert.are.equal('external', link.type)
      buffer_helper.delete(bufnr)
    end)

    it('should detect markdown link when cursor on brackets', function()
      local bufnr = buffer_helper.create({ 'Check this [link](https://example.com) here' })
      buffer_helper.set_cursor(1, 11) -- On '[' bracket

      local link = navigation.parse_link_at_position(bufnr, 1, 11)

      assert.is_not_nil(link)
      assert.are.equal('link', link.text)
      buffer_helper.delete(bufnr)
    end)

    it('should detect markdown link when cursor on URL', function()
      local bufnr = buffer_helper.create({ 'Check this [link](https://example.com) here' })
      buffer_helper.set_cursor(1, 25) -- On URL

      local link = navigation.parse_link_at_position(bufnr, 1, 25)

      assert.is_not_nil(link)
      assert.are.equal('https://example.com', link.url)
      buffer_helper.delete(bufnr)
    end)

    it('should detect notion page link', function()
      local bufnr = buffer_helper.create({ 'See [Page](notion://page/abc123def456789012345678) for details' })
      buffer_helper.set_cursor(1, 5)

      local link = navigation.parse_link_at_position(bufnr, 1, 5)

      assert.is_not_nil(link)
      assert.are.equal('notion_page', link.type)
      assert.are.equal('abc123def456789012345678', link.page_id)
      buffer_helper.delete(bufnr)
    end)

    it('should detect notion block link', function()
      local bufnr = buffer_helper.create({ 'See [Block](notion://block/def456abc123789012345678) here' })
      buffer_helper.set_cursor(1, 5)

      local link = navigation.parse_link_at_position(bufnr, 1, 5)

      assert.is_not_nil(link)
      assert.are.equal('notion_block', link.type)
      assert.are.equal('def456abc123789012345678', link.block_id)
      buffer_helper.delete(bufnr)
    end)

    it('should handle empty link text', function()
      local bufnr = buffer_helper.create({ 'Empty [](https://example.com) link' })
      buffer_helper.set_cursor(1, 7)

      local link = navigation.parse_link_at_position(bufnr, 1, 7)

      assert.is_not_nil(link)
      assert.are.equal('', link.text)
      assert.are.equal('https://example.com', link.url)
      buffer_helper.delete(bufnr)
    end)

    it('should handle link at start of line', function()
      local bufnr = buffer_helper.create({ '[Link](https://start.com) at start' })
      buffer_helper.set_cursor(1, 0)

      local link = navigation.parse_link_at_position(bufnr, 1, 0)

      assert.is_not_nil(link)
      assert.are.equal('Link', link.text)
      buffer_helper.delete(bufnr)
    end)

    it('should handle link at end of line', function()
      local bufnr = buffer_helper.create({ 'End link [here](https://end.com)' })
      buffer_helper.set_cursor(1, 15)

      local link = navigation.parse_link_at_position(bufnr, 1, 15)

      assert.is_not_nil(link)
      assert.are.equal('here', link.text)
      buffer_helper.delete(bufnr)
    end)

    it('should handle multiple links on same line - first link', function()
      local bufnr = buffer_helper.create({ '[One](https://one.com) and [Two](https://two.com)' })
      buffer_helper.set_cursor(1, 1)

      local link = navigation.parse_link_at_position(bufnr, 1, 1)

      assert.is_not_nil(link)
      assert.are.equal('One', link.text)
      assert.are.equal('https://one.com', link.url)
      buffer_helper.delete(bufnr)
    end)

    it('should handle multiple links on same line - second link', function()
      local bufnr = buffer_helper.create({ '[One](https://one.com) and [Two](https://two.com)' })
      buffer_helper.set_cursor(1, 28)

      local link = navigation.parse_link_at_position(bufnr, 1, 28)

      assert.is_not_nil(link)
      assert.are.equal('Two', link.text)
      assert.are.equal('https://two.com', link.url)
      buffer_helper.delete(bufnr)
    end)

    it('should return nil for text between links', function()
      local bufnr = buffer_helper.create({ '[One](https://one.com) and [Two](https://two.com)' })
      buffer_helper.set_cursor(1, 24) -- On 'and'

      local link = navigation.parse_link_at_position(bufnr, 1, 24)

      assert.is_nil(link)
      buffer_helper.delete(bufnr)
    end)

    it('should classify http URL as external', function()
      local bufnr = buffer_helper.create({ '[HTTP](http://example.com)' })
      buffer_helper.set_cursor(1, 1)

      local link = navigation.parse_link_at_position(bufnr, 1, 1)

      assert.are.equal('external', link.type)
      buffer_helper.delete(bufnr)
    end)

    it('should classify mailto URL as external', function()
      local bufnr = buffer_helper.create({ '[Email](mailto:test@example.com)' })
      buffer_helper.set_cursor(1, 1)

      local link = navigation.parse_link_at_position(bufnr, 1, 1)

      assert.are.equal('external', link.type)
      buffer_helper.delete(bufnr)
    end)

    it('should classify relative path as unknown', function()
      local bufnr = buffer_helper.create({ '[File](./path/to/file.md)' })
      buffer_helper.set_cursor(1, 1)

      local link = navigation.parse_link_at_position(bufnr, 1, 1)

      assert.are.equal('unknown', link.type)
      buffer_helper.delete(bufnr)
    end)
  end)

  describe('get_link_at_cursor', function()
    it('should use current cursor position', function()
      local bufnr = buffer_helper.create({ '[Link](https://example.com)' })
      buffer_helper.set_cursor(1, 1)

      local link = navigation.get_link_at_cursor()

      assert.is_not_nil(link)
      assert.are.equal('Link', link.text)
      buffer_helper.delete(bufnr)
    end)

    it('should return nil when not on link', function()
      local bufnr = buffer_helper.create({ 'No link here' })
      buffer_helper.set_cursor(1, 0)

      local link = navigation.get_link_at_cursor()

      assert.is_nil(link)
      buffer_helper.delete(bufnr)
    end)
  end)

  describe('classify_url', function()
    it('should classify https as external', function()
      local type, meta = navigation.classify_url('https://example.com')
      assert.are.equal('external', type)
      assert.is_nil(meta)
    end)

    it('should classify http as external', function()
      local type, meta = navigation.classify_url('http://example.com')
      assert.are.equal('external', type)
    end)

    it('should classify notion://page/ as notion_page', function()
      local type, meta = navigation.classify_url('notion://page/abc123def456')
      assert.are.equal('notion_page', type)
      assert.are.equal('abc123def456', meta.page_id)
    end)

    it('should classify notion://block/ as notion_block', function()
      local type, meta = navigation.classify_url('notion://block/abc123def456')
      assert.are.equal('notion_block', type)
      assert.are.equal('abc123def456', meta.block_id)
    end)

    it('should classify mailto as external', function()
      local type = navigation.classify_url('mailto:test@example.com')
      assert.are.equal('external', type)
    end)

    it('should classify file:// as unknown', function()
      local type = navigation.classify_url('file:///path/to/file')
      assert.are.equal('unknown', type)
    end)

    it('should classify relative path as unknown', function()
      local type = navigation.classify_url('./relative/path')
      assert.are.equal('unknown', type)
    end)

    it('should classify empty string as unknown', function()
      local type = navigation.classify_url('')
      assert.are.equal('unknown', type)
    end)

    it('should handle notion.so URL as notion_page', function()
      -- notion.so/Page-Title-abc123def456789012345678901234
      local type, meta = navigation.classify_url('https://notion.so/Page-Title-abc123def456789012345678901234')
      assert.are.equal('notion_page', type)
      assert.are.equal('abc123def456789012345678901234', meta.page_id)
    end)

    it('should handle www.notion.so URL as notion_page', function()
      local type, meta = navigation.classify_url('https://www.notion.so/workspace/Page-abc123def456789012345678901234')
      assert.are.equal('notion_page', type)
    end)
  end)

  describe('goto_link', function()
    it('should call vim.ui.open for external links', function()
      local called_with = nil
      local original_ui_open = vim.ui.open
      vim.ui.open = function(url)
        called_with = url
      end

      local link = {
        text = 'Example',
        url = 'https://example.com',
        type = 'external',
        start_col = 1,
        end_col = 30,
      }

      navigation.goto_link(link)

      assert.are.equal('https://example.com', called_with)

      vim.ui.open = original_ui_open
    end)

    it('should call open_page callback for notion_page links', function()
      local called_with = nil
      local link = {
        text = 'My Page',
        url = 'notion://page/abc123def456',
        type = 'notion_page',
        page_id = 'abc123def456',
        start_col = 1,
        end_col = 40,
      }

      navigation.goto_link(link, {
        open_page = function(page_id)
          called_with = page_id
        end,
      })

      assert.are.equal('abc123def456', called_with)
    end)

    it('should not error when vim.ui.open is nil', function()
      local original_ui_open = vim.ui.open
      vim.ui.open = nil

      local link = {
        text = 'Example',
        url = 'https://example.com',
        type = 'external',
        start_col = 1,
        end_col = 30,
      }

      assert.has_no_error(function()
        navigation.goto_link(link)
      end)

      vim.ui.open = original_ui_open
    end)
  end)

  describe('find_links_in_line', function()
    it('should return empty table for line without links', function()
      local links = navigation.find_links_in_line('Just plain text')
      assert.are.equal(0, #links)
    end)

    it('should find single link', function()
      local links = navigation.find_links_in_line('[Link](https://example.com)')
      assert.are.equal(1, #links)
      assert.are.equal('Link', links[1].text)
      assert.are.equal('https://example.com', links[1].url)
      assert.are.equal(1, links[1].start_col) -- 1-indexed
      assert.are.equal(27, links[1].end_col)
    end)

    it('should find multiple links', function()
      local links = navigation.find_links_in_line('[One](https://one.com) [Two](https://two.com)')
      assert.are.equal(2, #links)
      assert.are.equal('One', links[1].text)
      assert.are.equal('Two', links[2].text)
    end)

    it('should calculate correct positions', function()
      local links = navigation.find_links_in_line('Prefix [Link](https://url.com) suffix')
      assert.are.equal(1, #links)
      assert.are.equal(8, links[1].start_col) -- 1-indexed, position of '['
      assert.are.equal(30, links[1].end_col) -- position after ')'
    end)
  end)
end)
