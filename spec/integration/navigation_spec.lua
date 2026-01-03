---Navigation integration tests
---Tests navigation module in realistic scenarios
---@diagnostic disable: undefined-field

local buffer_helper = require('spec.helpers.buffer')

describe('navigation integration', function()
  local navigation

  before_each(function()
    navigation = require('neotion.navigation')
  end)

  after_each(function()
    -- Clean up test buffers
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

  describe('real-world link scenarios', function()
    it('should handle formatted text with links', function()
      local bufnr = buffer_helper.create({
        'Check this **[bold link](https://example.com)** for info',
      })
      buffer_helper.set_cursor(1, 18) -- On 'bold link'

      local link = navigation.get_link_at_cursor()

      assert.is_not_nil(link)
      assert.are.equal('bold link', link.text)
      assert.are.equal('https://example.com', link.url)
      buffer_helper.delete(bufnr)
    end)

    it('should handle link with query parameters', function()
      local bufnr = buffer_helper.create({
        'Search [Google](https://google.com?q=test&lang=en)',
      })
      buffer_helper.set_cursor(1, 10)

      local link = navigation.get_link_at_cursor()

      assert.is_not_nil(link)
      assert.are.equal('https://google.com?q=test&lang=en', link.url)
      buffer_helper.delete(bufnr)
    end)

    it('should handle link with anchor', function()
      local bufnr = buffer_helper.create({
        'See [docs](https://docs.example.com/page#section)',
      })
      buffer_helper.set_cursor(1, 5)

      local link = navigation.get_link_at_cursor()

      assert.is_not_nil(link)
      assert.are.equal('https://docs.example.com/page#section', link.url)
      buffer_helper.delete(bufnr)
    end)

    it('should correctly identify notion.so page links', function()
      local bufnr = buffer_helper.create({
        'Open [My Page](https://www.notion.so/My-Project-abc123def456789012345678901234)',
      })
      buffer_helper.set_cursor(1, 8)

      local link = navigation.get_link_at_cursor()

      assert.is_not_nil(link)
      assert.are.equal('notion_page', link.type)
      assert.are.equal('abc123def456789012345678901234', link.page_id)
      buffer_helper.delete(bufnr)
    end)

    it('should handle internal notion:// links', function()
      local bufnr = buffer_helper.create({
        'Related: [Sub Page](notion://page/fedcba9876543210fedcba98)',
      })
      buffer_helper.set_cursor(1, 12)

      local link = navigation.get_link_at_cursor()

      assert.is_not_nil(link)
      assert.are.equal('notion_page', link.type)
      assert.are.equal('fedcba9876543210fedcba98', link.page_id)
      buffer_helper.delete(bufnr)
    end)

    it('should find multiple links in complex content', function()
      local content = 'Visit [Site A](https://a.com) or [Site B](https://b.com) for more'
      local links = navigation.find_links_in_line(content)

      assert.are.equal(2, #links)
      assert.are.equal('Site A', links[1].text)
      assert.are.equal('Site B', links[2].text)
    end)
  end)

  describe('anti-conceal edge cases', function()
    it('should not conceal regular text like k character', function()
      -- Bug: "kime *ital* kime **bold** belli degil" line'da 'k' conceal oluyor
      local content = 'kime *ital* kime **bold** belli degil'
      local bufnr = buffer_helper.create({ content })

      -- Attach render system
      local render = require('neotion.render.init')
      render.reset()
      render.attach(bufnr)

      -- Get extmarks
      local extmarks_mod = require('neotion.render.extmarks')
      local marks = extmarks_mod.get_line_marks(bufnr, 0)

      -- Check that no conceal mark starts at position 0 (the 'k' character)
      for _, mark in ipairs(marks) do
        local details = mark[4]
        if details and details.conceal then
          local start_col = mark[2]
          assert.is_true(start_col > 0, "Conceal should not start at position 0 where 'k' is")
        end
      end

      render.detach(bufnr)
      buffer_helper.delete(bufnr)
    end)

    it('should render italic and bold on same line without affecting regular text', function()
      local bufnr = buffer_helper.create({
        'plain *italic* plain **bold** plain',
      })

      local render = require('neotion.render.init')
      render.reset()
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      render.attach(bufnr)

      -- Verify the buffer content is unchanged
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)
      assert.are.equal('plain *italic* plain **bold** plain', lines[1])

      render.detach(bufnr)
      buffer_helper.delete(bufnr)
    end)
  end)

  describe('cursor position edge cases', function()
    it('should handle cursor at exact start of link', function()
      local bufnr = buffer_helper.create({
        '[Link](https://example.com)',
      })
      buffer_helper.set_cursor(1, 0) -- On '['

      local link = navigation.get_link_at_cursor()

      assert.is_not_nil(link)
      buffer_helper.delete(bufnr)
    end)

    it('should handle cursor at exact end of link', function()
      local bufnr = buffer_helper.create({
        '[Link](https://example.com)',
      })
      buffer_helper.set_cursor(1, 26) -- On ')'

      local link = navigation.get_link_at_cursor()

      assert.is_not_nil(link)
      buffer_helper.delete(bufnr)
    end)

    it('should return nil just after link ends', function()
      local bufnr = buffer_helper.create({
        '[Link](https://example.com) text',
      })
      buffer_helper.set_cursor(1, 27) -- On ' ' after ')'

      local link = navigation.get_link_at_cursor()

      assert.is_nil(link)
      buffer_helper.delete(bufnr)
    end)
  end)
end)
