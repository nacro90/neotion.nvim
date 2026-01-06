describe('neotion.input.trigger.detection', function()
  local detection

  before_each(function()
    package.loaded['neotion.input.trigger.detection'] = nil
    detection = require('neotion.input.trigger.detection')
  end)

  describe('is_valid_position', function()
    it('returns true at line start (col 1)', function()
      local result = detection.is_valid_position('/', 1)
      assert.is_true(result)
    end)

    it('returns true after space', function()
      local result = detection.is_valid_position('hello /', 7)
      assert.is_true(result)
    end)

    it('returns true after tab', function()
      local result = detection.is_valid_position('hello\t/', 7)
      assert.is_true(result)
    end)

    it('returns false mid-word (no whitespace before)', function()
      local result = detection.is_valid_position('hello/', 6)
      assert.is_false(result)
    end)

    it('returns false after punctuation without space', function()
      local result = detection.is_valid_position('hello,/', 7)
      assert.is_false(result)
    end)

    it('returns true after opening parenthesis with space', function()
      local result = detection.is_valid_position('( /', 3)
      assert.is_true(result)
    end)
  end)

  describe('detect_trigger', function()
    describe('/ slash trigger', function()
      it('detects / at line start', function()
        local result = detection.detect_trigger('/', 1)
        assert.is_not_nil(result)
        assert.are.equal('/', result.trigger)
        assert.are.equal(1, result.start_col)
      end)

      it('detects / after space', function()
        local result = detection.detect_trigger('text /', 6)
        assert.is_not_nil(result)
        assert.are.equal('/', result.trigger)
        assert.are.equal(6, result.start_col)
      end)

      it('does not detect / mid-word', function()
        local result = detection.detect_trigger('text/', 5)
        assert.is_nil(result)
      end)

      it('detects / with query text after', function()
        local result = detection.detect_trigger('/head', 1)
        assert.is_not_nil(result)
        assert.are.equal('/', result.trigger)
        assert.are.equal(1, result.start_col)
      end)
    end)

    describe('[[ link trigger', function()
      it('detects [[ at line start', function()
        local result = detection.detect_trigger('[[', 1)
        assert.is_not_nil(result)
        assert.are.equal('[[', result.trigger)
        assert.are.equal(1, result.start_col)
      end)

      it('detects [[ after space', function()
        local result = detection.detect_trigger('text [[', 6)
        assert.is_not_nil(result)
        assert.are.equal('[[', result.trigger)
        assert.are.equal(6, result.start_col)
      end)

      it('does not detect [[ mid-word', function()
        local result = detection.detect_trigger('text[[', 5)
        assert.is_nil(result)
      end)

      it('does not detect single [', function()
        local result = detection.detect_trigger('[', 1)
        assert.is_nil(result)
      end)

      it('detects [[ with query text after', function()
        local result = detection.detect_trigger('[[meeting', 1)
        assert.is_not_nil(result)
        assert.are.equal('[[', result.trigger)
      end)
    end)

    describe('@ mention trigger', function()
      it('detects @ at line start', function()
        local result = detection.detect_trigger('@', 1)
        assert.is_not_nil(result)
        assert.are.equal('@', result.trigger)
        assert.are.equal(1, result.start_col)
      end)

      it('detects @ after space', function()
        local result = detection.detect_trigger('cc @', 4)
        assert.is_not_nil(result)
        assert.are.equal('@', result.trigger)
        assert.are.equal(4, result.start_col)
      end)

      it('does not detect @ mid-word (like email)', function()
        local result = detection.detect_trigger('user@', 5)
        assert.is_nil(result)
      end)

      it('detects @ with query text after', function()
        local result = detection.detect_trigger('@today', 1)
        assert.is_not_nil(result)
        assert.are.equal('@', result.trigger)
      end)
    end)

    describe('priority', function()
      it('prioritizes [[ over [ (longer match)', function()
        -- When we have [[, it should match [[ not just return nil for single [
        local result = detection.detect_trigger('[[', 1)
        assert.is_not_nil(result)
        assert.are.equal('[[', result.trigger)
      end)
    end)
  end)

  describe('extract_query', function()
    it('extracts query after / trigger', function()
      local query = detection.extract_query('/heading', '/', 1)
      assert.are.equal('heading', query)
    end)

    it('extracts query after [[ trigger', function()
      local query = detection.extract_query('[[meeting notes', '[[', 1)
      assert.are.equal('meeting notes', query)
    end)

    it('extracts query after @ trigger', function()
      local query = detection.extract_query('@today', '@', 1)
      assert.are.equal('today', query)
    end)

    it('returns empty string when no query', function()
      local query = detection.extract_query('/', '/', 1)
      assert.are.equal('', query)
    end)

    it('handles trigger mid-line', function()
      local query = detection.extract_query('text /cmd', '/', 6)
      assert.are.equal('cmd', query)
    end)
  end)

  describe('get_trigger_patterns', function()
    it('returns all registered trigger patterns', function()
      local patterns = detection.get_trigger_patterns()
      assert.is_table(patterns)
      assert.is_true(#patterns >= 3) -- At least /, [[, @
    end)

    it('patterns are ordered by priority (longest first)', function()
      local patterns = detection.get_trigger_patterns()
      -- [[ should come before / and @ since it's multi-char
      local found_bracket = false
      local found_slash = false
      local bracket_idx, slash_idx

      for i, p in ipairs(patterns) do
        if p.trigger == '[[' then
          found_bracket = true
          bracket_idx = i
        elseif p.trigger == '/' then
          found_slash = true
          slash_idx = i
        end
      end

      assert.is_true(found_bracket)
      assert.is_true(found_slash)
      assert.is_true(bracket_idx < slash_idx, '[[ should have higher priority than /')
    end)
  end)
end)
