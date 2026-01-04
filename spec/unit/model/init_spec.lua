describe('neotion.model', function()
  local model

  before_each(function()
    -- Clear module cache
    package.loaded['neotion.model'] = nil
    package.loaded['neotion.model.registry'] = nil
    package.loaded['neotion.model.mapping'] = nil
    package.loaded['neotion.model.block'] = nil
    package.loaded['neotion.model.blocks.paragraph'] = nil
    package.loaded['neotion.model.blocks.heading'] = nil
    model = require('neotion.model')
  end)

  describe('deserialize_blocks', function()
    it('should deserialize array of blocks', function()
      local raw_blocks = {
        {
          id = 'para1',
          type = 'paragraph',
          paragraph = { rich_text = { { plain_text = 'Hello' } } },
        },
        {
          id = 'head1',
          type = 'heading_1',
          heading_1 = { rich_text = { { plain_text = 'Title' } } },
        },
      }

      local blocks = model.deserialize_blocks(raw_blocks)

      assert.are.equal(2, #blocks)
      assert.are.equal('para1', blocks[1]:get_id())
      assert.are.equal('head1', blocks[2]:get_id())
    end)

    it('should return empty array for empty input', function()
      local blocks = model.deserialize_blocks({})

      assert.are.equal(0, #blocks)
    end)

    it('should handle unsupported block types', function()
      local raw_blocks = {
        { id = 'toggle1', type = 'toggle', toggle = {} },
      }

      local blocks = model.deserialize_blocks(raw_blocks)

      assert.are.equal(1, #blocks)
      assert.is_false(blocks[1]:is_editable())
    end)
  end)

  describe('format_blocks', function()
    it('should format blocks to lines', function()
      local raw_blocks = {
        {
          id = 'para1',
          type = 'paragraph',
          paragraph = { rich_text = { { plain_text = 'Paragraph text' } } },
        },
        {
          id = 'head1',
          type = 'heading_1',
          heading_1 = { rich_text = { { plain_text = 'Heading' } } },
        },
      }
      local blocks = model.deserialize_blocks(raw_blocks)

      local lines = model.format_blocks(blocks)

      assert.are.equal(2, #lines)
      assert.are.equal('Paragraph text', lines[1])
      assert.are.equal('# Heading', lines[2])
    end)

    it('should return empty array for empty blocks', function()
      local lines = model.format_blocks({})

      assert.are.equal(0, #lines)
    end)
  end)

  describe('is_supported', function()
    it('should return true for paragraph', function()
      assert.is_true(model.is_supported('paragraph'))
    end)

    it('should return true for heading types', function()
      assert.is_true(model.is_supported('heading_1'))
      assert.is_true(model.is_supported('heading_2'))
      assert.is_true(model.is_supported('heading_3'))
    end)

    it('should return false for unsupported types', function()
      assert.is_false(model.is_supported('toggle'))
      assert.is_false(model.is_supported('numbered_list_item'))
      assert.is_false(model.is_supported('image'))
    end)
  end)

  describe('check_editability', function()
    it('should return true when all blocks editable', function()
      local raw_blocks = {
        { id = '1', type = 'paragraph', paragraph = { rich_text = {} } },
        { id = '2', type = 'heading_1', heading_1 = { rich_text = {} } },
      }
      local blocks = model.deserialize_blocks(raw_blocks)

      local is_editable, unsupported = model.check_editability(blocks)

      assert.is_true(is_editable)
      assert.are.equal(0, #unsupported)
    end)

    it('should return false when unsupported blocks present', function()
      local raw_blocks = {
        { id = '1', type = 'paragraph', paragraph = { rich_text = {} } },
        { id = '2', type = 'toggle', toggle = { rich_text = {} } },
      }
      local blocks = model.deserialize_blocks(raw_blocks)

      local is_editable, unsupported = model.check_editability(blocks)

      assert.is_false(is_editable)
      assert.are.equal(1, #unsupported)
      assert.are.equal('toggle', unsupported[1])
    end)
  end)

  describe('serialize_block', function()
    it('should serialize paragraph block', function()
      local raw = {
        id = 'para1',
        type = 'paragraph',
        paragraph = { rich_text = { { plain_text = 'Hello' } } },
      }
      local blocks = model.deserialize_blocks({ raw })
      local block = blocks[1]

      local serialized = model.serialize_block(block)

      assert.are.equal('para1', serialized.id)
      assert.are.equal('paragraph', serialized.type)
      assert.is_not_nil(serialized.paragraph)
    end)

    it('should serialize heading block', function()
      local raw = {
        id = 'head1',
        type = 'heading_2',
        heading_2 = { rich_text = { { plain_text = 'Section' } } },
      }
      local blocks = model.deserialize_blocks({ raw })
      local block = blocks[1]

      local serialized = model.serialize_block(block)

      assert.are.equal('head1', serialized.id)
      assert.are.equal('heading_2', serialized.type)
      assert.is_not_nil(serialized.heading_2)
    end)
  end)

  describe('buffer operations', function()
    local bufnr

    before_each(function()
      bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        'Header',
        '',
        'Paragraph 1',
        '',
        '# Heading',
      })
    end)

    after_each(function()
      if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        model.clear(bufnr)
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end)

    describe('setup_buffer', function()
      it('should setup blocks with extmarks', function()
        local raw_blocks = {
          { id = 'p1', type = 'paragraph', paragraph = { rich_text = { { plain_text = 'Para' } } } },
        }
        local blocks = model.deserialize_blocks(raw_blocks)

        model.setup_buffer(bufnr, blocks, 2)

        assert.is_true(model.has_blocks(bufnr))
      end)
    end)

    describe('has_blocks', function()
      it('should return false for buffer without blocks', function()
        assert.is_false(model.has_blocks(bufnr))
      end)

      it('should return true after setup', function()
        local blocks = model.deserialize_blocks({
          { id = 'p1', type = 'paragraph', paragraph = { rich_text = {} } },
        })

        model.setup_buffer(bufnr, blocks, 0)

        assert.is_true(model.has_blocks(bufnr))
      end)
    end)

    describe('get_blocks', function()
      it('should return blocks for buffer', function()
        local raw_blocks = {
          { id = 'p1', type = 'paragraph', paragraph = { rich_text = {} } },
          { id = 'p2', type = 'paragraph', paragraph = { rich_text = {} } },
        }
        local blocks = model.deserialize_blocks(raw_blocks)
        model.setup_buffer(bufnr, blocks, 0)

        local result = model.get_blocks(bufnr)

        assert.are.equal(2, #result)
      end)

      it('should return empty array for buffer without blocks', function()
        local result = model.get_blocks(bufnr)

        assert.are.equal(0, #result)
      end)
    end)

    describe('clear', function()
      it('should remove all blocks from buffer', function()
        local blocks = model.deserialize_blocks({
          { id = 'p1', type = 'paragraph', paragraph = { rich_text = {} } },
        })
        model.setup_buffer(bufnr, blocks, 0)

        model.clear(bufnr)

        assert.is_false(model.has_blocks(bufnr))
      end)
    end)

    describe('get_dirty_blocks', function()
      it('should return only dirty blocks', function()
        local blocks = model.deserialize_blocks({
          { id = 'p1', type = 'paragraph', paragraph = { rich_text = { { plain_text = 'Text 1' } } } },
          { id = 'p2', type = 'paragraph', paragraph = { rich_text = { { plain_text = 'Text 2' } } } },
        })
        model.setup_buffer(bufnr, blocks, 0)

        -- Mark one as dirty
        blocks[1]:set_dirty(true)

        local dirty = model.get_dirty_blocks(bufnr)

        assert.are.equal(1, #dirty)
        assert.are.equal('p1', dirty[1]:get_id())
      end)
    end)

    describe('mark_all_clean', function()
      it('should mark all blocks as not dirty', function()
        local blocks = model.deserialize_blocks({
          { id = 'p1', type = 'paragraph', paragraph = { rich_text = {} } },
          { id = 'p2', type = 'paragraph', paragraph = { rich_text = {} } },
        })
        model.setup_buffer(bufnr, blocks, 0)
        blocks[1]:set_dirty(true)
        blocks[2]:set_dirty(true)

        model.mark_all_clean(bufnr)

        local dirty = model.get_dirty_blocks(bufnr)
        assert.are.equal(0, #dirty)
      end)
    end)

    describe('get_block_by_id', function()
      it('should find block by ID', function()
        local blocks = model.deserialize_blocks({
          { id = 'p1', type = 'paragraph', paragraph = { rich_text = {} } },
          { id = 'p2', type = 'heading_1', heading_1 = { rich_text = {} } },
        })
        model.setup_buffer(bufnr, blocks, 0)

        local block = model.get_block_by_id(bufnr, 'p2')

        assert.is_not_nil(block)
        assert.are.equal('p2', block:get_id())
      end)

      it('should return nil for unknown ID', function()
        local blocks = model.deserialize_blocks({
          { id = 'p1', type = 'paragraph', paragraph = { rich_text = {} } },
        })
        model.setup_buffer(bufnr, blocks, 0)

        local block = model.get_block_by_id(bufnr, 'nonexistent')

        assert.is_nil(block)
      end)
    end)
  end)
end)
