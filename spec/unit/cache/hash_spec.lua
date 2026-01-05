---@diagnostic disable: undefined-field
local hash = require('neotion.cache.hash')

describe('neotion.cache.hash', function()
  describe('djb2', function()
    it('should return a hex string', function()
      local result = hash.djb2('hello')
      assert.is_string(result)
      assert.matches('^%x+$', result)
    end)

    it('should return 8 character hex string', function()
      local result = hash.djb2('hello')
      assert.are.equal(8, #result)
    end)

    it('should handle empty string', function()
      local result = hash.djb2('')
      assert.is_string(result)
      assert.are.equal(8, #result)
      -- djb2 of empty string starts with 5381 (0x1505)
      assert.are.equal('00001505', result)
    end)

    it('should be deterministic (same input = same output)', function()
      local input = 'test string for hashing'
      local result1 = hash.djb2(input)
      local result2 = hash.djb2(input)
      assert.are.equal(result1, result2)
    end)

    it('should produce different hashes for different inputs', function()
      local hash1 = hash.djb2('hello')
      local hash2 = hash.djb2('world')
      local hash3 = hash.djb2('hello!')
      assert.are_not.equal(hash1, hash2)
      assert.are_not.equal(hash1, hash3)
      assert.are_not.equal(hash2, hash3)
    end)

    it('should handle unicode strings', function()
      local result = hash.djb2('merhaba dünya')
      assert.is_string(result)
      assert.are.equal(8, #result)
    end)

    it('should handle newlines and special characters', function()
      local result = hash.djb2('line1\nline2\ttab')
      assert.is_string(result)
      assert.are.equal(8, #result)
    end)

    it('should handle large strings', function()
      local large_string = string.rep('a', 10000)
      local result = hash.djb2(large_string)
      assert.is_string(result)
      assert.are.equal(8, #result)
    end)

    it('should handle JSON-like content', function()
      local json = '{"type":"paragraph","content":[{"text":"Hello"}]}'
      local result = hash.djb2(json)
      assert.is_string(result)
      assert.are.equal(8, #result)
    end)
  end)

  describe('page_content', function()
    it('should hash an array of blocks', function()
      local blocks = {
        { id = 'block1', type = 'paragraph', content = 'Hello' },
        { id = 'block2', type = 'heading_1', content = 'World' },
      }
      local result = hash.page_content(blocks)
      assert.is_string(result)
      assert.are.equal(8, #result)
    end)

    it('should return consistent hash for same blocks', function()
      local blocks = {
        { id = 'abc', type = 'paragraph' },
      }
      local result1 = hash.page_content(blocks)
      local result2 = hash.page_content(blocks)
      assert.are.equal(result1, result2)
    end)

    it('should return different hash when block order changes', function()
      local blocks1 = {
        { id = 'a', type = 'paragraph' },
        { id = 'b', type = 'heading_1' },
      }
      local blocks2 = {
        { id = 'b', type = 'heading_1' },
        { id = 'a', type = 'paragraph' },
      }
      local result1 = hash.page_content(blocks1)
      local result2 = hash.page_content(blocks2)
      assert.are_not.equal(result1, result2)
    end)

    it('should return different hash when block content changes', function()
      local blocks1 = {
        { id = 'a', type = 'paragraph', text = 'hello' },
      }
      local blocks2 = {
        { id = 'a', type = 'paragraph', text = 'world' },
      }
      local result1 = hash.page_content(blocks1)
      local result2 = hash.page_content(blocks2)
      assert.are_not.equal(result1, result2)
    end)

    it('should handle empty blocks array', function()
      local result = hash.page_content({})
      assert.is_string(result)
      assert.are.equal(8, #result)
    end)

    it('should handle nil input gracefully', function()
      local result = hash.page_content(nil)
      assert.is_string(result)
      assert.are.equal(8, #result)
    end)
  end)

  describe('block_content', function()
    it('should hash a single block', function()
      local block = {
        id = 'block123',
        type = 'paragraph',
        paragraph = {
          rich_text = { { text = { content = 'Hello world' } } },
        },
      }
      local result = hash.block_content(block)
      assert.is_string(result)
      assert.are.equal(8, #result)
    end)

    it('should return consistent hash for same block', function()
      local block = { id = 'test', type = 'divider' }
      local result1 = hash.block_content(block)
      local result2 = hash.block_content(block)
      assert.are.equal(result1, result2)
    end)

    it('should return different hash for different blocks', function()
      local block1 = { id = 'a', type = 'paragraph' }
      local block2 = { id = 'b', type = 'paragraph' }
      local result1 = hash.block_content(block1)
      local result2 = hash.block_content(block2)
      assert.are_not.equal(result1, result2)
    end)

    it('should handle nil input gracefully', function()
      local result = hash.block_content(nil)
      assert.is_string(result)
    end)

    it('should handle block with nested content', function()
      local block = {
        id = 'nested',
        type = 'bulleted_list_item',
        bulleted_list_item = {
          rich_text = {
            { text = { content = 'Item' }, annotations = { bold = true } },
          },
        },
      }
      local result = hash.block_content(block)
      assert.is_string(result)
      assert.are.equal(8, #result)
    end)
  end)

  describe('_serialize_table', function()
    it('should escape quotes in strings', function()
      local result = hash._serialize_table('hello "world"')
      assert.are.equal('"hello \\"world\\""', result)
    end)

    it('should escape backslashes in strings', function()
      local result = hash._serialize_table('path\\to\\file')
      assert.are.equal('"path\\\\to\\\\file"', result)
    end)

    it('should escape newlines in strings', function()
      local result = hash._serialize_table('line1\nline2')
      assert.are.equal('"line1\\nline2"', result)
    end)

    it('should escape tabs in strings', function()
      local result = hash._serialize_table('col1\tcol2')
      assert.are.equal('"col1\\tcol2"', result)
    end)

    it('should escape carriage returns in strings', function()
      local result = hash._serialize_table('line1\rline2')
      assert.are.equal('"line1\\rline2"', result)
    end)

    it('should escape quotes in object keys', function()
      local result = hash._serialize_table({ ['key"name'] = 'value' })
      assert.matches('key\\"name', result)
    end)

    it('should handle complex nested structures', function()
      local data = {
        text = 'hello "world"',
        nested = {
          content = 'line1\nline2',
        },
      }
      local result = hash._serialize_table(data)
      assert.is_string(result)
      -- Should contain escaped quotes and newlines
      assert.matches('\\"', result)
      assert.matches('\\n', result)
    end)
  end)

  describe('compare', function()
    it('should return true for identical hashes', function()
      local h1 = hash.djb2('test')
      local h2 = hash.djb2('test')
      assert.is_true(hash.compare(h1, h2))
    end)

    it('should return false for different hashes', function()
      local h1 = hash.djb2('test1')
      local h2 = hash.djb2('test2')
      assert.is_false(hash.compare(h1, h2))
    end)

    it('should handle nil values', function()
      local h1 = hash.djb2('test')
      assert.is_false(hash.compare(h1, nil))
      assert.is_false(hash.compare(nil, h1))
      assert.is_true(hash.compare(nil, nil))
    end)
  end)
end)
