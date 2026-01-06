describe('neotion.input.trigger.state', function()
  local state

  before_each(function()
    package.loaded['neotion.input.trigger.state'] = nil
    state = require('neotion.input.trigger.state')
  end)

  describe('TriggerState', function()
    it('exports state constants', function()
      assert.are.equal('idle', state.IDLE)
      assert.are.equal('detecting', state.DETECTING)
      assert.are.equal('triggered', state.TRIGGERED)
      assert.are.equal('completing', state.COMPLETING)
    end)
  end)

  describe('create', function()
    it('creates a new state machine in idle state', function()
      local sm = state.create()
      assert.is_not_nil(sm)
      assert.are.equal(state.IDLE, sm:get_state())
    end)

    it('creates with no active trigger', function()
      local sm = state.create()
      assert.is_nil(sm:get_trigger())
    end)

    it('creates with empty query', function()
      local sm = state.create()
      assert.are.equal('', sm:get_query())
    end)
  end)

  describe('state machine transitions', function()
    local sm

    before_each(function()
      sm = state.create()
    end)

    describe('idle -> triggered', function()
      it('transitions to triggered on trigger_detected', function()
        sm:trigger_detected('/', 1)
        assert.are.equal(state.TRIGGERED, sm:get_state())
      end)

      it('stores trigger info on trigger_detected', function()
        sm:trigger_detected('[[', 5)
        assert.are.equal('[[', sm:get_trigger())
        assert.are.equal(5, sm:get_trigger_col())
      end)
    end)

    describe('triggered -> completing', function()
      it('transitions to completing on show_completion', function()
        sm:trigger_detected('/', 1)
        sm:show_completion()
        assert.are.equal(state.COMPLETING, sm:get_state())
      end)
    end)

    describe('completing -> idle', function()
      it('transitions to idle on confirm', function()
        sm:trigger_detected('/', 1)
        sm:show_completion()
        sm:confirm()
        assert.are.equal(state.IDLE, sm:get_state())
      end)

      it('clears trigger info on confirm', function()
        sm:trigger_detected('/', 1)
        sm:show_completion()
        sm:confirm()
        assert.is_nil(sm:get_trigger())
      end)

      it('transitions to idle on cancel', function()
        sm:trigger_detected('/', 1)
        sm:show_completion()
        sm:cancel()
        assert.are.equal(state.IDLE, sm:get_state())
      end)

      it('clears trigger info on cancel', function()
        sm:trigger_detected('/', 1)
        sm:show_completion()
        sm:cancel()
        assert.is_nil(sm:get_trigger())
      end)
    end)

    describe('completing -> triggered (transform)', function()
      it('transitions to triggered on transform', function()
        sm:trigger_detected('/', 1)
        sm:show_completion()
        sm:transform('[[')
        assert.are.equal(state.TRIGGERED, sm:get_state())
      end)

      it('updates trigger on transform', function()
        sm:trigger_detected('/', 1)
        sm:show_completion()
        sm:transform('[[')
        assert.are.equal('[[', sm:get_trigger())
      end)
    end)

    describe('any state -> idle', function()
      it('resets from triggered state', function()
        sm:trigger_detected('/', 1)
        sm:reset()
        assert.are.equal(state.IDLE, sm:get_state())
        assert.is_nil(sm:get_trigger())
      end)

      it('resets from completing state', function()
        sm:trigger_detected('/', 1)
        sm:show_completion()
        sm:reset()
        assert.are.equal(state.IDLE, sm:get_state())
      end)
    end)
  end)

  describe('query management', function()
    local sm

    before_each(function()
      sm = state.create()
    end)

    it('updates query text', function()
      sm:trigger_detected('/', 1)
      sm:set_query('head')
      assert.are.equal('head', sm:get_query())
    end)

    it('appends to query', function()
      sm:trigger_detected('/', 1)
      sm:set_query('head')
      sm:append_query('ing')
      assert.are.equal('heading', sm:get_query())
    end)

    it('removes from query (backspace)', function()
      sm:trigger_detected('/', 1)
      sm:set_query('heading')
      sm:backspace_query()
      assert.are.equal('headin', sm:get_query())
    end)

    it('clears query on reset', function()
      sm:trigger_detected('/', 1)
      sm:set_query('test')
      sm:reset()
      assert.are.equal('', sm:get_query())
    end)

    it('clears query on confirm', function()
      sm:trigger_detected('/', 1)
      sm:show_completion()
      sm:set_query('test')
      sm:confirm()
      assert.are.equal('', sm:get_query())
    end)
  end)

  describe('is_active', function()
    local sm

    before_each(function()
      sm = state.create()
    end)

    it('returns false when idle', function()
      assert.is_false(sm:is_active())
    end)

    it('returns true when triggered', function()
      sm:trigger_detected('/', 1)
      assert.is_true(sm:is_active())
    end)

    it('returns true when completing', function()
      sm:trigger_detected('/', 1)
      sm:show_completion()
      assert.is_true(sm:is_active())
    end)
  end)

  describe('callbacks', function()
    local sm
    local callback_log

    before_each(function()
      sm = state.create()
      callback_log = {}
    end)

    it('calls on_state_change callback', function()
      sm:on_state_change(function(old_state, new_state)
        table.insert(callback_log, { old = old_state, new = new_state })
      end)

      sm:trigger_detected('/', 1)

      assert.are.equal(1, #callback_log)
      assert.are.equal(state.IDLE, callback_log[1].old)
      assert.are.equal(state.TRIGGERED, callback_log[1].new)
    end)

    it('calls on_query_change callback', function()
      sm:on_query_change(function(old_query, new_query)
        table.insert(callback_log, { old = old_query, new = new_query })
      end)

      sm:trigger_detected('/', 1)
      sm:set_query('test')

      assert.are.equal(1, #callback_log)
      assert.are.equal('', callback_log[1].old)
      assert.are.equal('test', callback_log[1].new)
    end)
  end)
end)
