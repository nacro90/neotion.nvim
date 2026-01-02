---Integration tests for Neotion editing scenarios
---These tests verify the full editing workflow with mock API

describe('neotion editing integration', function()
  local mock_api = require('spec.helpers.mock_api')
  local neotion
  local model
  local buffer

  -- Valid 32-character hex page IDs
  local PAGE_ID_1 = 'aaaaaaaa111111112222222233333333'
  local PAGE_ID_2 = 'bbbbbbbb111111112222222233333333'
  local PAGE_ID_3 = 'cccccccc111111112222222233333333'
  local PAGE_ID_4 = 'dddddddd111111112222222233333333'
  local PAGE_ID_5 = 'eeeeeeee111111112222222233333333'
  local PAGE_ID_6 = 'ffffffff111111112222222233333333'

  before_each(function()
    -- Reset mock data
    mock_api.reset()

    -- Load modules fresh (including mapping which has module-level state)
    package.loaded['neotion'] = nil
    package.loaded['neotion.model'] = nil
    package.loaded['neotion.model.mapping'] = nil
    package.loaded['neotion.buffer'] = nil
    package.loaded['neotion.sync.plan'] = nil

    neotion = require('neotion')
    model = require('neotion.model')
    buffer = require('neotion.buffer')

    -- Install mock API
    mock_api.install()

    -- Clean up existing neotion buffers
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name:match('neotion://') then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  end)

  after_each(function()
    -- Uninstall mock
    mock_api.uninstall()

    -- Clean up neotion buffers
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name:match('neotion://') then
        model.clear(bufnr)
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  end)

  describe('Scenario 1: Paragraph editing', function()
    it('should open page and display paragraph content', function()
      -- Setup mock page with paragraph
      mock_api.add_page({
        id = PAGE_ID_1,
        title = 'Test Page',
        blocks = {
          mock_api.paragraph('para1block000000000000000000000', 'Hello world'),
        },
      })

      -- Open the page
      local opened = false
      neotion.open(PAGE_ID_1)

      -- Wait for async operations
      vim.wait(1000, function()
        local bufs = buffer.list()
        if #bufs > 0 then
          local data = buffer.get_data(bufs[1])
          opened = data and data.status == 'ready'
        end
        return opened
      end)

      assert.is_true(opened, 'Page should be opened and ready')

      -- Check buffer content
      local bufs = buffer.list()
      assert.are.equal(1, #bufs)

      local lines = vim.api.nvim_buf_get_lines(bufs[1], 0, -1, false)
      local content = table.concat(lines, '\n')
      assert.is_truthy(content:match('Hello world'), 'Buffer should contain paragraph text')
    end)

    it('should track paragraph text changes', function()
      -- Setup mock page
      mock_api.add_page({
        id = PAGE_ID_2,
        title = 'Edit Test',
        blocks = {
          mock_api.paragraph('para2block000000000000000000000', 'Original text'),
        },
      })

      -- Open the page
      neotion.open(PAGE_ID_2)

      -- Wait for page to load
      vim.wait(1000, function()
        local bufs = buffer.list()
        return #bufs > 0 and buffer.get_status(bufs[1]) == 'ready'
      end)

      local bufs = buffer.list()
      local bufnr = bufs[1]

      -- Find the paragraph line
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local para_line = nil
      for i, line in ipairs(lines) do
        if line:match('Original text') then
          para_line = i
          break
        end
      end

      assert.is_not_nil(para_line, 'Should find paragraph line')

      -- Modify the line
      vim.api.nvim_buf_set_lines(bufnr, para_line - 1, para_line, false, { 'Modified text' })

      -- Sync blocks from buffer
      model.sync_blocks_from_buffer(bufnr)

      -- Check if block is dirty
      local dirty_blocks = model.get_dirty_blocks(bufnr)
      assert.are.equal(1, #dirty_blocks, 'Should have one dirty block')
      assert.are.equal('Modified text', dirty_blocks[1]:get_text())
    end)
  end)

  describe('Scenario 2: Heading level changes', function()
    it('should update heading level when hash count changes', function()
      -- Setup mock page with heading
      mock_api.add_page({
        id = PAGE_ID_3,
        title = 'Heading Test',
        blocks = {
          mock_api.heading('head1block000000000000000000000', 'My Heading', 1),
        },
      })

      -- Open the page
      neotion.open(PAGE_ID_3)

      -- Wait for page to load
      vim.wait(1000, function()
        local bufs = buffer.list()
        return #bufs > 0 and buffer.get_status(bufs[1]) == 'ready'
      end)

      local bufs = buffer.list()
      local bufnr = bufs[1]

      -- Find the heading line (should start with # )
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local heading_line = nil
      for i, line in ipairs(lines) do
        if line:match('^# My Heading') then
          heading_line = i
          break
        end
      end

      assert.is_not_nil(heading_line, 'Should find heading line')

      -- Change from # to ## (level 1 to level 2)
      vim.api.nvim_buf_set_lines(bufnr, heading_line - 1, heading_line, false, { '## My Heading' })

      -- Sync blocks from buffer
      model.sync_blocks_from_buffer(bufnr)

      -- Check if heading level changed
      local block = model.get_block_at_line(bufnr, heading_line)
      assert.is_not_nil(block, 'Should find block at line')
      assert.are.equal('heading_2', block:get_type(), 'Block type should be heading_2')
      assert.are.equal(2, block.level, 'Heading level should be 2')

      -- Verify serialization
      local serialized = block:serialize()
      assert.are.equal('heading_2', serialized.type)
      assert.is_not_nil(serialized.heading_2)
      assert.is_nil(serialized.heading_1)
    end)
  end)

  describe('Scenario 3: Read-only block protection', function()
    it('should create blocks with correct editability', function()
      -- Setup mock page with mixed block types
      mock_api.add_page({
        id = PAGE_ID_4,
        title = 'Mixed Blocks',
        blocks = {
          mock_api.paragraph('para1mixed0000000000000000000', 'Editable paragraph'),
          mock_api.heading('head1mixed0000000000000000000', 'Editable heading', 1),
          mock_api.toggle('toggle1mixed000000000000000000', 'Read-only toggle'),
          mock_api.code('code1mixed00000000000000000000', 'print("read-only")'),
          mock_api.quote('quote1mixed0000000000000000000', 'Read-only quote'),
        },
      })

      -- Open the page
      neotion.open(PAGE_ID_4)

      -- Wait for page to load
      vim.wait(1000, function()
        local bufs = buffer.list()
        return #bufs > 0 and buffer.get_status(bufs[1]) == 'ready'
      end)

      local bufs = buffer.list()
      local bufnr = bufs[1]

      -- Get all blocks
      local blocks = model.get_blocks(bufnr)
      assert.are.equal(5, #blocks, 'Should have 5 blocks')

      -- Check editability
      local editable_count = 0
      local readonly_count = 0

      for _, block in ipairs(blocks) do
        if block:is_editable() then
          editable_count = editable_count + 1
          assert.is_truthy(
            block:get_type() == 'paragraph' or block:get_type():match('^heading_'),
            'Only paragraph and heading should be editable'
          )
        else
          readonly_count = readonly_count + 1
          assert.is_truthy(
            block:get_type() == 'toggle' or block:get_type() == 'code' or block:get_type() == 'quote',
            'Toggle, code, quote should be read-only'
          )
        end
      end

      assert.are.equal(2, editable_count, 'Should have 2 editable blocks')
      assert.are.equal(3, readonly_count, 'Should have 3 read-only blocks')
    end)

    it('should protect header lines', function()
      -- Setup mock page
      mock_api.add_page({
        id = PAGE_ID_5,
        title = 'Header Test',
        blocks = {
          mock_api.paragraph('para1header0000000000000000000', 'Content'),
        },
      })

      -- Open the page
      neotion.open(PAGE_ID_5)

      -- Wait for page to load
      vim.wait(1000, function()
        local bufs = buffer.list()
        return #bufs > 0 and buffer.get_status(bufs[1]) == 'ready'
      end)

      local bufs = buffer.list()
      local bufnr = bufs[1]

      -- Get header line count
      local data = buffer.get_data(bufnr)
      local header_line_count = data.header_line_count

      assert.is_truthy(header_line_count > 0, 'Should have header lines')

      -- Try to find block at header line (should be nil)
      for line = 1, header_line_count do
        local block = model.get_block_at_line(bufnr, line)
        assert.is_nil(block, 'Should not find block in header area at line ' .. line)
      end
    end)
  end)

  describe('Block line tracking', function()
    it('should correctly map lines to blocks', function()
      -- Setup mock page
      mock_api.add_page({
        id = PAGE_ID_6,
        title = 'Line Tracking',
        blocks = {
          mock_api.paragraph('para1tracking00000000000000000', 'First paragraph'),
          mock_api.paragraph('para2tracking00000000000000000', 'Second paragraph'),
          mock_api.heading('head1tracking00000000000000000', 'A Heading', 2),
        },
      })

      -- Open the page
      neotion.open(PAGE_ID_6)

      -- Wait for page to load
      vim.wait(1000, function()
        local bufs = buffer.list()
        return #bufs > 0 and buffer.get_status(bufs[1]) == 'ready'
      end)

      local bufs = buffer.list()
      local bufnr = bufs[1]

      -- Get all blocks
      local blocks = model.get_blocks(bufnr)
      assert.are.equal(3, #blocks)

      -- Each block should have a valid line range
      for _, block in ipairs(blocks) do
        local start_line, end_line = block:get_line_range()
        assert.is_not_nil(start_line, 'Block should have start line: ' .. block:get_id())
        assert.is_not_nil(end_line, 'Block should have end line: ' .. block:get_id())
        assert.is_true(start_line <= end_line, 'Start should be <= end')

        -- Should be able to find block at its line
        local found = model.get_block_at_line(bufnr, start_line)
        assert.is_not_nil(found, 'Should find block at its start line')
        assert.are.equal(block:get_id(), found:get_id())
      end
    end)
  end)

  describe('Sync plan creation', function()
    local plan_module

    before_each(function()
      -- Reset mock and modules (outer before_each handles install)
      package.loaded['neotion.sync.plan'] = nil
      plan_module = require('neotion.sync.plan')
    end)

    it('should create empty plan when no changes', function()
      -- Setup mock page
      mock_api.add_page({
        id = 'nochange1111111122222222333333aa',
        title = 'No Changes',
        blocks = {
          mock_api.paragraph('para1nochange00000000000000000a', 'Unchanged text'),
        },
      })

      -- Open the page
      neotion.open('nochange1111111122222222333333aa')

      -- Wait for page to load
      vim.wait(1000, function()
        local bufs = buffer.list()
        return #bufs > 0 and buffer.get_status(bufs[1]) == 'ready'
      end)

      local bufs = buffer.list()
      local bufnr = bufs[1]

      -- Create plan without any changes
      local plan = plan_module.create(bufnr)

      -- Should be empty
      assert.is_true(plan_module.is_empty(plan), 'Plan should be empty when no changes')
      assert.are.equal(0, #plan.updates)
      assert.are.equal(0, #plan.type_changes)
      assert.is_false(plan.has_changes)
    end)

    it('should detect paragraph text changes', function()
      -- Setup mock page with unique ID
      local page_id = 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6'
      mock_api.add_page({
        id = page_id,
        title = 'Text Changes',
        blocks = {
          mock_api.paragraph('para1txchg000000000000000000000', 'Original'),
        },
      })

      -- Open the page
      neotion.open(page_id)

      -- Wait for page to load
      local loaded = vim.wait(2000, function()
        local bufs = buffer.list()
        return #bufs > 0 and buffer.get_status(bufs[1]) == 'ready'
      end)

      assert.is_true(loaded, 'Page should load within 2 seconds')

      local bufs = buffer.list()
      assert.is_true(#bufs > 0, 'Should have at least one buffer')
      local bufnr = bufs[1]

      -- Find and modify the paragraph
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      for i, line in ipairs(lines) do
        if line:match('Original') then
          vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, { 'Modified' })
          break
        end
      end

      -- Create plan
      local plan = plan_module.create(bufnr)

      -- Should have one update
      assert.is_false(plan_module.is_empty(plan), 'Plan should not be empty')
      assert.are.equal(1, #plan.updates, 'Should have 1 update')
      assert.are.equal(0, #plan.type_changes, 'Should have 0 type changes')
      assert.are.equal('Modified', plan.updates[1].content)
    end)

    it('should detect heading level change as type_change', function()
      -- Setup mock page with heading
      mock_api.add_page({
        id = 'aabbccdd11111111222222223333333c',
        title = 'Level Change',
        blocks = {
          mock_api.heading('aadd1aabbcc0000000000000000000c', 'My Title', 1),
        },
      })

      -- Open the page
      neotion.open('aabbccdd11111111222222223333333c')

      -- Wait for page to load
      vim.wait(1000, function()
        local bufs = buffer.list()
        return #bufs > 0 and buffer.get_status(bufs[1]) == 'ready'
      end)

      local bufs = buffer.list()
      local bufnr = bufs[1]

      -- Find the heading line and change level
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      for i, line in ipairs(lines) do
        if line:match('^# My Title') then
          vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, { '## My Title' })
          break
        end
      end

      -- Create plan
      local plan = plan_module.create(bufnr)

      -- Should have type change, not update
      assert.is_false(plan_module.is_empty(plan), 'Plan should not be empty')
      assert.are.equal(0, #plan.updates, 'Should have 0 updates')
      assert.are.equal(1, #plan.type_changes, 'Should have 1 type change')
      assert.are.equal('heading_1', plan.type_changes[1].old_type)
      assert.are.equal('heading_2', plan.type_changes[1].new_type)
    end)

    it('should detect heading text change without level change as update', function()
      -- Setup mock page with heading
      mock_api.add_page({
        id = 'aabbccee1111111122222222333333ad',
        title = 'Text Only Change',
        blocks = {
          mock_api.heading('aadd1aabbcce00000000000000000ad', 'Original Title', 2),
        },
      })

      -- Open the page
      neotion.open('aabbccee1111111122222222333333ad')

      -- Wait for page to load
      vim.wait(1000, function()
        local bufs = buffer.list()
        return #bufs > 0 and buffer.get_status(bufs[1]) == 'ready'
      end)

      local bufs = buffer.list()
      local bufnr = bufs[1]

      -- Find the heading line and change only text (keep ##)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      for i, line in ipairs(lines) do
        if line:match('^## Original Title') then
          vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, { '## New Title' })
          break
        end
      end

      -- Create plan
      local plan = plan_module.create(bufnr)

      -- Should be update, not type change
      assert.is_false(plan_module.is_empty(plan), 'Plan should not be empty')
      assert.are.equal(1, #plan.updates, 'Should have 1 update')
      assert.are.equal(0, #plan.type_changes, 'Should have 0 type changes')
      assert.are.equal('New Title', plan.updates[1].content)
    end)

    it('should handle multiple dirty blocks', function()
      -- Setup mock page
      mock_api.add_page({
        id = 'aabbccff1111111122222222333333ae',
        title = 'Multiple Dirty',
        blocks = {
          mock_api.paragraph('aaa1aabbccff0000000000000000ae', 'First'),
          mock_api.paragraph('aaa2aabbccff0000000000000000ae', 'Second'),
          mock_api.heading('aad1aabbccff0000000000000000ae', 'Title', 1),
        },
      })

      -- Open the page
      neotion.open('aabbccff1111111122222222333333ae')

      -- Wait for page to load
      vim.wait(1000, function()
        local bufs = buffer.list()
        return #bufs > 0 and buffer.get_status(bufs[1]) == 'ready'
      end)

      local bufs = buffer.list()
      local bufnr = bufs[1]

      -- Modify all blocks (modify individual lines to preserve line tracking)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      for i, line in ipairs(lines) do
        if line:match('^First') then
          vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, { 'First Modified' })
        elseif line:match('^Second') then
          vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, { 'Second Modified' })
        elseif line:match('^# Title') then
          vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, { '## Title' }) -- Level change
        end
      end

      -- Create plan
      local plan = plan_module.create(bufnr)

      -- Should have 2 updates and 1 type change
      assert.is_false(plan_module.is_empty(plan))
      assert.are.equal(2, #plan.updates, 'Should have 2 updates')
      assert.are.equal(1, #plan.type_changes, 'Should have 1 type change')
    end)

    it('should count type changes as 2 operations', function()
      -- Setup mock page
      mock_api.add_page({
        id = 'aabbccaa1111111122222222333333af',
        title = 'Op Count',
        blocks = {
          mock_api.paragraph('aaa1aabbccaa0000000000000000af', 'Para'),
          mock_api.heading('aad1aabbccaa0000000000000000af', 'Title', 1),
        },
      })

      -- Open the page
      neotion.open('aabbccaa1111111122222222333333af')

      -- Wait for page to load
      vim.wait(1000, function()
        local bufs = buffer.list()
        return #bufs > 0 and buffer.get_status(bufs[1]) == 'ready'
      end)

      local bufs = buffer.list()
      local bufnr = bufs[1]

      -- Modify paragraph and change heading level
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local new_lines = {}
      for _, line in ipairs(lines) do
        if line:match('^Para') then
          table.insert(new_lines, 'Para Modified')
        elseif line:match('^# Title') then
          table.insert(new_lines, '## Title')
        else
          table.insert(new_lines, line)
        end
      end
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)

      -- Create plan
      local plan = plan_module.create(bufnr)

      -- 1 update + 1 type change (counted as 2) = 3 operations
      local op_count = plan_module.get_operation_count(plan)
      assert.are.equal(3, op_count, 'Should count type change as 2 operations')
    end)
  end)

  describe('Dirty state management', function()
    it('should clear dirty state after mark_all_clean', function()
      -- Setup mock page
      mock_api.add_page({
        id = 'aabbccbb111111122222222333333333',
        title = 'Dirty State',
        blocks = {
          mock_api.paragraph('aaa1aabbcc000000000000000000333a', 'Original'),
        },
      })

      -- Open the page
      neotion.open('aabbccbb111111122222222333333333')

      -- Wait for page to load
      vim.wait(1000, function()
        local bufs = buffer.list()
        return #bufs > 0 and buffer.get_status(bufs[1]) == 'ready'
      end)

      local bufs = buffer.list()
      local bufnr = bufs[1]

      -- Modify the paragraph
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      for i, line in ipairs(lines) do
        if line:match('Original') then
          vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, { 'Modified' })
          break
        end
      end

      -- Sync and verify dirty
      model.sync_blocks_from_buffer(bufnr)
      local dirty_before = model.get_dirty_blocks(bufnr)
      assert.are.equal(1, #dirty_before, 'Should have 1 dirty block before clean')

      -- Mark all clean
      model.mark_all_clean(bufnr)

      -- Verify no longer dirty
      local dirty_after = model.get_dirty_blocks(bufnr)
      assert.are.equal(0, #dirty_after, 'Should have 0 dirty blocks after clean')
    end)

    it('should preserve dirty state when text changes again', function()
      -- Setup mock page
      mock_api.add_page({
        id = 'aabbcccc1111111222222223333333b0',
        title = 'Dirty Preserve',
        blocks = {
          mock_api.paragraph('aaa1aabbccc0000000000000003333b0', 'Original'),
        },
      })

      -- Open the page
      neotion.open('aabbcccc1111111222222223333333b0')

      -- Wait for page to load
      vim.wait(1000, function()
        local bufs = buffer.list()
        return #bufs > 0 and buffer.get_status(bufs[1]) == 'ready'
      end)

      local bufs = buffer.list()
      local bufnr = bufs[1]

      -- First modification
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local para_line = nil
      for i, line in ipairs(lines) do
        if line:match('Original') then
          para_line = i
          vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, { 'First change' })
          break
        end
      end

      model.sync_blocks_from_buffer(bufnr)
      assert.are.equal(1, #model.get_dirty_blocks(bufnr))

      -- Second modification (should still be dirty)
      vim.api.nvim_buf_set_lines(bufnr, para_line - 1, para_line, false, { 'Second change' })
      model.sync_blocks_from_buffer(bufnr)

      local dirty = model.get_dirty_blocks(bufnr)
      assert.are.equal(1, #dirty)
      assert.are.equal('Second change', dirty[1]:get_text())
    end)
  end)
end)
