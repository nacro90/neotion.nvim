---@diagnostic disable: undefined-global
describe('neotion.render.gutter_icons', function()
  local gutter_icons

  before_each(function()
    package.loaded['neotion.render.gutter_icons'] = nil
    gutter_icons = require('neotion.render.gutter_icons')
  end)

  describe('ICONS', function()
    it('should have icon mapping for heading_1', function()
      assert.are.equal('H1', gutter_icons.ICONS.heading_1)
    end)

    it('should have icon mapping for heading_2', function()
      assert.are.equal('H2', gutter_icons.ICONS.heading_2)
    end)

    it('should have icon mapping for heading_3', function()
      assert.are.equal('H3', gutter_icons.ICONS.heading_3)
    end)

    it('should have icon mapping for bulleted_list_item', function()
      assert.are.equal('•', gutter_icons.ICONS.bulleted_list_item)
    end)

    it('should have icon mapping for numbered_list_item', function()
      assert.are.equal('#', gutter_icons.ICONS.numbered_list_item)
    end)

    it('should have icon mapping for quote', function()
      assert.are.equal('│', gutter_icons.ICONS.quote)
    end)

    it('should have icon mapping for code', function()
      assert.are.equal('<>', gutter_icons.ICONS.code)
    end)

    it('should have icon mapping for divider', function()
      assert.are.equal('──', gutter_icons.ICONS.divider)
    end)

    it('should NOT have icon mapping for paragraph', function()
      assert.is_nil(gutter_icons.ICONS.paragraph)
    end)
  end)

  describe('CONTINUATION_MARKER', function()
    it('should be vertical bar for multi-line continuation', function()
      assert.are.equal('│', gutter_icons.CONTINUATION_MARKER)
    end)
  end)

  describe('get_icon', function()
    it('should return icon for known block type', function()
      assert.are.equal('H1', gutter_icons.get_icon('heading_1'))
      assert.are.equal('•', gutter_icons.get_icon('bulleted_list_item'))
      assert.are.equal('<>', gutter_icons.get_icon('code'))
    end)

    it('should return nil for paragraph', function()
      assert.is_nil(gutter_icons.get_icon('paragraph'))
    end)

    it('should return nil for unknown block type', function()
      assert.is_nil(gutter_icons.get_icon('unknown_block'))
    end)
  end)

  describe('get_highlight_group', function()
    it('should return treesitter-linked group for heading_1', function()
      assert.are.equal('NeotionGutterH1', gutter_icons.get_highlight_group('heading_1'))
    end)

    it('should return treesitter-linked group for heading_2', function()
      assert.are.equal('NeotionGutterH2', gutter_icons.get_highlight_group('heading_2'))
    end)

    it('should return treesitter-linked group for heading_3', function()
      assert.are.equal('NeotionGutterH3', gutter_icons.get_highlight_group('heading_3'))
    end)

    it('should return appropriate group for list items', function()
      assert.are.equal('NeotionGutterList', gutter_icons.get_highlight_group('bulleted_list_item'))
      assert.are.equal('NeotionGutterList', gutter_icons.get_highlight_group('numbered_list_item'))
    end)

    it('should return appropriate group for quote', function()
      assert.are.equal('NeotionGutterQuote', gutter_icons.get_highlight_group('quote'))
    end)

    it('should return appropriate group for code', function()
      assert.are.equal('NeotionGutterCode', gutter_icons.get_highlight_group('code'))
    end)

    it('should return appropriate group for divider', function()
      assert.are.equal('NeotionGutterDivider', gutter_icons.get_highlight_group('divider'))
    end)

    it('should return default group for unknown type', function()
      assert.are.equal('NeotionGutterDefault', gutter_icons.get_highlight_group('unknown'))
    end)
  end)
end)

describe('Block:get_gutter_icon integration', function()
  local block_module
  local heading_module
  local paragraph_module
  local bulleted_list_module
  local numbered_list_module
  local quote_module
  local code_module
  local divider_module

  before_each(function()
    -- Clear all cached modules
    package.loaded['neotion.model.block'] = nil
    package.loaded['neotion.model.blocks.heading'] = nil
    package.loaded['neotion.model.blocks.paragraph'] = nil
    package.loaded['neotion.model.blocks.bulleted_list'] = nil
    package.loaded['neotion.model.blocks.numbered_list'] = nil
    package.loaded['neotion.model.blocks.quote'] = nil
    package.loaded['neotion.model.blocks.code'] = nil
    package.loaded['neotion.model.blocks.divider'] = nil

    block_module = require('neotion.model.block')
    heading_module = require('neotion.model.blocks.heading')
    paragraph_module = require('neotion.model.blocks.paragraph')
    bulleted_list_module = require('neotion.model.blocks.bulleted_list')
    numbered_list_module = require('neotion.model.blocks.numbered_list')
    quote_module = require('neotion.model.blocks.quote')
    code_module = require('neotion.model.blocks.code')
    divider_module = require('neotion.model.blocks.divider')
  end)

  describe('base Block', function()
    it('should return nil for unsupported block', function()
      local block = block_module.Block.new({ id = 'test', type = 'unsupported' })
      assert.is_nil(block:get_gutter_icon())
    end)
  end)

  describe('HeadingBlock', function()
    it('should return H1 for heading_1', function()
      local block = heading_module.new({
        id = 'h1',
        type = 'heading_1',
        heading_1 = { rich_text = {} },
      })
      assert.are.equal('H1', block:get_gutter_icon())
    end)

    it('should return H2 for heading_2', function()
      local block = heading_module.new({
        id = 'h2',
        type = 'heading_2',
        heading_2 = { rich_text = {} },
      })
      assert.are.equal('H2', block:get_gutter_icon())
    end)

    it('should return H3 for heading_3', function()
      local block = heading_module.new({
        id = 'h3',
        type = 'heading_3',
        heading_3 = { rich_text = {} },
      })
      assert.are.equal('H3', block:get_gutter_icon())
    end)
  end)

  describe('ParagraphBlock', function()
    it('should return nil (no icon)', function()
      local block = paragraph_module.new({
        id = 'p1',
        type = 'paragraph',
        paragraph = { rich_text = {} },
      })
      assert.is_nil(block:get_gutter_icon())
    end)
  end)

  describe('BulletedListBlock', function()
    it('should return bullet icon', function()
      local block = bulleted_list_module.new({
        id = 'bl1',
        type = 'bulleted_list_item',
        bulleted_list_item = { rich_text = {} },
      })
      assert.are.equal('•', block:get_gutter_icon())
    end)
  end)

  describe('NumberedListBlock', function()
    it('should return numbered icon', function()
      local block = numbered_list_module.new({
        id = 'nl1',
        type = 'numbered_list_item',
        numbered_list_item = { rich_text = {} },
      })
      assert.are.equal('#', block:get_gutter_icon())
    end)
  end)

  describe('QuoteBlock', function()
    it('should return quote icon', function()
      local block = quote_module.new({
        id = 'q1',
        type = 'quote',
        quote = { rich_text = {} },
      })
      assert.are.equal('│', block:get_gutter_icon())
    end)
  end)

  describe('CodeBlock', function()
    it('should return code icon', function()
      local block = code_module.new({
        id = 'c1',
        type = 'code',
        code = { rich_text = {}, language = 'lua' },
      })
      assert.are.equal('<>', block:get_gutter_icon())
    end)
  end)

  describe('DividerBlock', function()
    it('should return divider icon', function()
      local block = divider_module.new({
        id = 'd1',
        type = 'divider',
        divider = {},
      })
      assert.are.equal('──', block:get_gutter_icon())
    end)
  end)
end)
