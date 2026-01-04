describe('neotion.model.blocks.code', function()
  local code_module

  before_each(function()
    package.loaded['neotion.model.blocks.code'] = nil
    package.loaded['neotion.model.block'] = nil
    code_module = require('neotion.model.blocks.code')
  end)

  describe('CodeBlock.new', function()
    it('should create a code block from raw JSON', function()
      local raw = {
        id = 'code123',
        type = 'code',
        code = {
          rich_text = { { plain_text = 'const x = 1;' } },
          language = 'javascript',
          caption = {},
        },
      }

      local block = code_module.new(raw)

      assert.are.equal('code123', block:get_id())
      assert.are.equal('code', block:get_type())
    end)

    it('should be marked as editable', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = { rich_text = {}, language = 'plain text' },
      }

      local block = code_module.new(raw)

      assert.is_true(block:is_editable())
    end)

    it('should extract code content from rich_text', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = {
          rich_text = {
            { plain_text = 'line1\n' },
            { plain_text = 'line2' },
          },
          language = 'python',
        },
      }

      local block = code_module.new(raw)

      assert.are.equal('line1\nline2', block:get_text())
    end)

    it('should handle empty rich_text', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = { rich_text = {}, language = 'lua' },
      }

      local block = code_module.new(raw)

      assert.are.equal('', block:get_text())
    end)

    it('should handle missing code field', function()
      local raw = {
        id = 'test',
        type = 'code',
      }

      local block = code_module.new(raw)

      assert.are.equal('', block:get_text())
      assert.are.equal('plain text', block.language)
    end)

    it('should preserve language property', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = {
          rich_text = { { plain_text = 'code' } },
          language = 'rust',
        },
      }

      local block = code_module.new(raw)

      assert.are.equal('rust', block.language)
    end)

    it('should preserve caption array', function()
      local caption = { { plain_text = 'Example code' } }
      local raw = {
        id = 'test',
        type = 'code',
        code = {
          rich_text = { { plain_text = 'code' } },
          language = 'go',
          caption = caption,
        },
      }

      local block = code_module.new(raw)

      assert.are.same(caption, block.caption)
    end)
  end)

  describe('CodeBlock:format', function()
    it('should return multi-line with fences', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = {
          rich_text = { { plain_text = 'const x = 1;' } },
          language = 'javascript',
        },
      }

      local block = code_module.new(raw)
      local lines = block:format()

      assert.are.equal(3, #lines)
      assert.are.equal('```javascript', lines[1])
      assert.are.equal('const x = 1;', lines[2])
      assert.are.equal('```', lines[3])
    end)

    it('should handle multi-line code', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = {
          rich_text = { { plain_text = 'line1\nline2\nline3' } },
          language = 'python',
        },
      }

      local block = code_module.new(raw)
      local lines = block:format()

      assert.are.equal(5, #lines)
      assert.are.equal('```python', lines[1])
      assert.are.equal('line1', lines[2])
      assert.are.equal('line2', lines[3])
      assert.are.equal('line3', lines[4])
      assert.are.equal('```', lines[5])
    end)

    it('should handle empty code block', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = {
          rich_text = {},
          language = 'lua',
        },
      }

      local block = code_module.new(raw)
      local lines = block:format()

      assert.are.equal(3, #lines)
      assert.are.equal('```lua', lines[1])
      assert.are.equal('', lines[2])
      assert.are.equal('```', lines[3])
    end)

    it('should handle "plain text" language', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = {
          rich_text = { { plain_text = 'text' } },
          language = 'plain text',
        },
      }

      local block = code_module.new(raw)
      local lines = block:format()

      -- "plain text" should be shown as empty language
      assert.are.equal('```', lines[1])
    end)
  end)

  describe('CodeBlock:serialize', function()
    it('should return original raw when code unchanged', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = {
          rich_text = { { plain_text = 'code', text = { content = 'code' } } },
          language = 'lua',
          caption = {},
        },
      }

      local block = code_module.new(raw)
      local result = block:serialize()

      assert.are.equal('code', result.type)
      assert.is_not_nil(result.code)
    end)

    it('should update rich_text when code changed', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = {
          rich_text = { { plain_text = 'old' } },
          language = 'lua',
        },
      }

      local block = code_module.new(raw)
      block:update_from_lines({ '```lua', 'new code', '```' })
      local result = block:serialize()

      assert.is_not_nil(result.code.rich_text)
      assert.are.equal(1, #result.code.rich_text)
    end)

    it('should preserve language on serialization', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = {
          rich_text = { { plain_text = 'code' } },
          language = 'rust',
        },
      }

      local block = code_module.new(raw)
      local result = block:serialize()

      assert.are.equal('rust', result.code.language)
    end)

    it('should update language when fence language changes', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = {
          rich_text = { { plain_text = 'code' } },
          language = 'javascript',
        },
      }

      local block = code_module.new(raw)
      block:update_from_lines({ '```typescript', 'code', '```' })
      local result = block:serialize()

      assert.are.equal('typescript', result.code.language)
    end)

    it('should preserve caption on serialization', function()
      local caption = { { plain_text = 'Caption' } }
      local raw = {
        id = 'test',
        type = 'code',
        code = {
          rich_text = { { plain_text = 'code' } },
          language = 'lua',
          caption = caption,
        },
      }

      local block = code_module.new(raw)
      local result = block:serialize()

      assert.are.same(caption, result.code.caption)
    end)
  end)

  describe('CodeBlock:update_from_lines', function()
    it('should parse fence and update code', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = {
          rich_text = { { plain_text = 'old' } },
          language = 'lua',
        },
      }

      local block = code_module.new(raw)
      block:update_from_lines({ '```lua', 'new code', '```' })

      assert.are.equal('new code', block:get_text())
      assert.is_true(block:is_dirty())
    end)

    it('should update language from fence', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = {
          rich_text = { { plain_text = 'code' } },
          language = 'javascript',
        },
      }

      local block = code_module.new(raw)
      block:update_from_lines({ '```python', 'code', '```' })

      assert.are.equal('python', block.language)
    end)

    it('should handle multi-line code update', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = {
          rich_text = { { plain_text = 'old' } },
          language = 'lua',
        },
      }

      local block = code_module.new(raw)
      block:update_from_lines({ '```lua', 'line1', 'line2', 'line3', '```' })

      assert.are.equal('line1\nline2\nline3', block:get_text())
    end)

    it('should handle empty code block', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = {
          rich_text = { { plain_text = 'old' } },
          language = 'lua',
        },
      }

      local block = code_module.new(raw)
      block:update_from_lines({ '```lua', '```' })

      assert.are.equal('', block:get_text())
    end)

    it('should handle fence characters in code content', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = {
          rich_text = { { plain_text = 'old' } },
          language = 'ruby',
        },
      }

      local block = code_module.new(raw)
      block:update_from_lines({ '```ruby', 'puts "```"', '```' })

      assert.are.equal('puts "```"', block:get_text())
    end)

    it('should handle missing closing fence', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = {
          rich_text = { { plain_text = 'old' } },
          language = 'lua',
        },
      }

      local block = code_module.new(raw)
      block:update_from_lines({ '```lua', 'code without close' })

      -- Should still update
      assert.are.equal('code without close', block:get_text())
    end)

    it('should handle missing opening fence', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = {
          rich_text = { { plain_text = 'old' } },
          language = 'lua',
        },
      }

      local block = code_module.new(raw)
      block:update_from_lines({ 'just code', '```' })

      -- Should treat all as content (minus closing fence)
      assert.are.equal('just code', block:get_text())
    end)

    it('should not mark dirty if code unchanged', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = {
          rich_text = { { plain_text = 'same' } },
          language = 'lua',
        },
      }

      local block = code_module.new(raw)
      block:update_from_lines({ '```lua', 'same', '```' })

      assert.is_false(block:is_dirty())
    end)

    it('should handle empty lines', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = {
          rich_text = { { plain_text = 'old' } },
          language = 'lua',
        },
      }

      local block = code_module.new(raw)
      block:update_from_lines({})

      -- Should not crash
      assert.is_not_nil(block:get_text())
    end)
  end)

  describe('CodeBlock:get_text', function()
    it('should return code content without fences', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = {
          rich_text = { { plain_text = 'const x = 1;' } },
          language = 'javascript',
        },
      }

      local block = code_module.new(raw)

      assert.are.equal('const x = 1;', block:get_text())
    end)
  end)

  describe('CodeBlock:matches_content', function()
    it('should match when code is same', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = {
          rich_text = { { plain_text = 'code' } },
          language = 'lua',
        },
      }

      local block = code_module.new(raw)

      assert.is_true(block:matches_content({ '```lua', 'code', '```' }))
    end)

    it('should not match when code differs', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = {
          rich_text = { { plain_text = 'original' } },
          language = 'lua',
        },
      }

      local block = code_module.new(raw)

      assert.is_false(block:matches_content({ '```lua', 'different', '```' }))
    end)
  end)

  describe('CodeBlock:render', function()
    it('should return false (use default text rendering)', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = {
          rich_text = { { plain_text = 'code' } },
          language = 'lua',
        },
      }

      local block = code_module.new(raw)
      local mock_ctx = {}

      local handled = block:render(mock_ctx)

      -- Code block uses default rendering for now
      -- (syntax highlighting deferred to Phase 9+)
      assert.is_false(handled)
    end)
  end)

  describe('CodeBlock:has_children', function()
    it('should return false', function()
      local raw = {
        id = 'test',
        type = 'code',
        code = { rich_text = {}, language = 'lua' },
        has_children = false,
      }

      local block = code_module.new(raw)

      assert.is_false(block:has_children())
    end)
  end)

  describe('M.is_editable', function()
    it('should return true', function()
      assert.is_true(code_module.is_editable())
    end)
  end)
end)
