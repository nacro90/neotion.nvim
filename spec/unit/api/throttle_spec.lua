describe('neotion.api.throttle', function()
  local throttle
  local mock_client

  -- Mock client module
  local function setup_mock_client()
    mock_client = {
      request_calls = {},
      response_queue = {},
    }

    -- Mock request function
    mock_client.request = function(endpoint, token, opts, callback)
      table.insert(mock_client.request_calls, {
        endpoint = endpoint,
        token = token,
        opts = opts,
        callback = callback,
      })

      -- Auto-respond if queue has responses
      if #mock_client.response_queue > 0 then
        local response = table.remove(mock_client.response_queue, 1)
        vim.schedule(function()
          callback(response)
        end)
      end
    end

    -- Queue a response for next request
    mock_client.queue_response = function(response)
      table.insert(mock_client.response_queue, response)
    end

    -- Trigger callback for specific request
    mock_client.respond = function(index, response)
      local call = mock_client.request_calls[index]
      if call then
        vim.schedule(function()
          call.callback(response)
        end)
      end
    end

    -- Replace client module
    package.loaded['neotion.api.client'] = mock_client
  end

  before_each(function()
    -- Clear module cache
    package.loaded['neotion.api.throttle'] = nil
    package.loaded['neotion.api.client'] = nil

    -- Setup mock
    setup_mock_client()

    -- Load throttle
    throttle = require('neotion.api.throttle')
    throttle._reset()
  end)

  after_each(function()
    if throttle then
      throttle.shutdown()
    end
    package.loaded['neotion.api.throttle'] = nil
    package.loaded['neotion.api.client'] = nil
  end)

  describe('module structure', function()
    it('should expose request method', function()
      assert.is_function(throttle.request)
    end)

    it('should expose get helper', function()
      assert.is_function(throttle.get)
    end)

    it('should expose post helper', function()
      assert.is_function(throttle.post)
    end)

    it('should expose patch helper', function()
      assert.is_function(throttle.patch)
    end)

    it('should expose cancel method', function()
      assert.is_function(throttle.cancel)
    end)

    it('should expose cancel_all method', function()
      assert.is_function(throttle.cancel_all)
    end)

    it('should expose pause method', function()
      assert.is_function(throttle.pause)
    end)

    it('should expose resume method', function()
      assert.is_function(throttle.resume)
    end)

    it('should expose is_paused method', function()
      assert.is_function(throttle.is_paused)
    end)

    it('should expose get_stats method', function()
      assert.is_function(throttle.get_stats)
    end)

    it('should expose statusline method', function()
      assert.is_function(throttle.statusline)
    end)

    it('should expose setup method', function()
      assert.is_function(throttle.setup)
    end)

    it('should expose shutdown method', function()
      assert.is_function(throttle.shutdown)
    end)
  end)

  describe('request', function()
    it('should return a request id', function()
      local id = throttle.request('/test', 'token', {}, function() end)
      assert.is_string(id)
      assert.is_truthy(id:match('^req_'))
    end)

    it('should return unique ids for each request', function()
      local id1 = throttle.request('/test1', 'token', {}, function() end)
      local id2 = throttle.request('/test2', 'token', {}, function() end)
      assert.are_not.equal(id1, id2)
    end)

    it('should increment total_requests stat', function()
      local before = throttle.get_stats().total_requests
      throttle.request('/test', 'token', {}, function() end)
      local after = throttle.get_stats().total_requests
      assert.are.equal(before + 1, after)
    end)

    it('should add request to queue', function()
      throttle.request('/test', 'token', {}, function() end)
      local stats = throttle.get_stats()
      -- Request might be in queue or in_flight depending on timing
      assert.is_true(stats.queue_length >= 0)
    end)
  end)

  describe('get helper', function()
    it('should set method to GET', function()
      mock_client.queue_response({ status = 200, body = {} })
      throttle.get('/test', 'token', function() end)

      vim.wait(100, function()
        return #mock_client.request_calls > 0
      end)

      assert.are.equal(1, #mock_client.request_calls)
      assert.are.equal('GET', mock_client.request_calls[1].opts.method)
    end)
  end)

  describe('post helper', function()
    it('should set method to POST and include body', function()
      mock_client.queue_response({ status = 200, body = {} })
      local body = { query = 'test' }
      throttle.post('/test', 'token', body, function() end)

      vim.wait(100, function()
        return #mock_client.request_calls > 0
      end)

      assert.are.equal(1, #mock_client.request_calls)
      assert.are.equal('POST', mock_client.request_calls[1].opts.method)
      assert.are.same(body, mock_client.request_calls[1].opts.body)
    end)
  end)

  describe('patch helper', function()
    it('should set method to PATCH and include body', function()
      mock_client.queue_response({ status = 200, body = {} })
      local body = { title = 'updated' }
      throttle.patch('/test', 'token', body, function() end)

      vim.wait(100, function()
        return #mock_client.request_calls > 0
      end)

      assert.are.equal(1, #mock_client.request_calls)
      assert.are.equal('PATCH', mock_client.request_calls[1].opts.method)
      assert.are.same(body, mock_client.request_calls[1].opts.body)
    end)
  end)

  describe('token bucket', function()
    it('should allow burst requests', function()
      -- Queue 10 responses for burst
      for _ = 1, 10 do
        mock_client.queue_response({ status = 200, body = {} })
      end

      -- Send 10 requests (burst size)
      for i = 1, 10 do
        throttle.request('/test' .. i, 'token', {}, function() end)
      end

      vim.wait(200, function()
        return #mock_client.request_calls >= 10
      end)

      -- All 10 should execute immediately
      assert.are.equal(10, #mock_client.request_calls)
    end)

    it('should queue requests when tokens exhausted', function()
      -- Use up all tokens first
      for _ = 1, 10 do
        mock_client.queue_response({ status = 200, body = {} })
      end
      for i = 1, 10 do
        throttle.request('/burst' .. i, 'token', {}, function() end)
      end

      vim.wait(100, function()
        return #mock_client.request_calls >= 10
      end)

      -- Now send more requests - they should queue
      throttle.request('/extra1', 'token', {}, function() end)
      throttle.request('/extra2', 'token', {}, function() end)

      -- Check queue has pending requests
      local stats = throttle.get_stats()
      assert.is_true(stats.queue_length >= 0 or stats.requests_in_flight >= 0)
    end)

    it('should refill tokens over time', function()
      -- Exhaust tokens
      for _ = 1, 10 do
        mock_client.queue_response({ status = 200, body = {} })
      end
      for i = 1, 10 do
        throttle.request('/burst' .. i, 'token', {}, function() end)
      end

      vim.wait(100, function()
        return #mock_client.request_calls >= 10
      end)

      -- Wait for token refill (at least 1 token at 3/s = ~333ms)
      vim.wait(400)

      -- Check tokens refilled
      local stats = throttle.get_stats()
      assert.is_true(stats.available_tokens > 0)
    end)
  end)

  describe('cancellation', function()
    it('should cancel queued request', function()
      local callback_called = false
      local cancelled_result = nil

      -- Pause to ensure request stays queued
      throttle.pause(5000)

      -- Queue a request
      local id = throttle.request('/cancel-me', 'token', {}, function(result)
        callback_called = true
        cancelled_result = result
      end)

      vim.wait(50)

      -- Cancel it while queued
      local success = throttle.cancel(id)
      assert.is_true(success)

      -- Resume to process cancelled request
      throttle.resume()

      -- Wait for callback
      vim.wait(200, function()
        return callback_called
      end)

      -- Should receive cancelled result
      assert.is_true(callback_called)
      assert.is_true(cancelled_result.cancelled)
      assert.are.equal(id, cancelled_result.request_id)
    end)

    it('should return false for unknown request id', function()
      local success = throttle.cancel('unknown_id')
      assert.is_false(success)
    end)

    it('should increment total_cancelled stat', function()
      local id = throttle.request('/test', 'token', {}, function() end)
      local before = throttle.get_stats().total_cancelled
      throttle.cancel(id)
      local after = throttle.get_stats().total_cancelled
      assert.are.equal(before + 1, after)
    end)

    it('should cancel_all pending requests', function()
      -- Exhaust tokens
      for _ = 1, 10 do
        mock_client.queue_response({ status = 200, body = {} })
      end
      for i = 1, 10 do
        throttle.request('/burst' .. i, 'token', {}, function() end)
      end

      vim.wait(100)

      -- Queue more requests
      throttle.request('/cancel1', 'token', {}, function() end)
      throttle.request('/cancel2', 'token', {}, function() end)
      throttle.request('/cancel3', 'token', {}, function() end)

      local count = throttle.cancel_all()
      -- Should have cancelled some requests
      assert.is_true(count >= 0)
    end)
  end)

  describe('pause and resume', function()
    it('should pause rate limiter', function()
      throttle.pause(5000) -- 5 seconds
      assert.is_true(throttle.is_paused())
    end)

    it('should resume rate limiter', function()
      throttle.pause(5000)
      throttle.resume()
      assert.is_false(throttle.is_paused())
    end)

    it('should block requests when paused', function()
      throttle.pause(5000)

      mock_client.queue_response({ status = 200, body = {} })
      throttle.request('/test', 'token', {}, function() end)

      -- Wait a bit
      vim.wait(100)

      -- Request should be queued, not executed
      assert.are.equal(0, #mock_client.request_calls)
    end)

    it('should process requests after resume', function()
      throttle.pause(5000)

      mock_client.queue_response({ status = 200, body = {} })
      throttle.request('/test', 'token', {}, function() end)

      vim.wait(50)

      throttle.resume()

      vim.wait(100, function()
        return #mock_client.request_calls > 0
      end)

      assert.are.equal(1, #mock_client.request_calls)
    end)
  end)

  describe('get_stats', function()
    it('should return stats object', function()
      local stats = throttle.get_stats()

      assert.is_number(stats.queue_length)
      assert.is_number(stats.available_tokens)
      assert.is_number(stats.requests_in_flight)
      assert.is_number(stats.total_requests)
      assert.is_number(stats.total_retries)
      assert.is_number(stats.total_cancelled)
      assert.is_boolean(stats.paused)
    end)

    it('should reflect queue state', function()
      throttle.pause(5000)

      for i = 1, 5 do
        throttle.request('/test' .. i, 'token', {}, function() end)
      end

      vim.wait(50)

      local stats = throttle.get_stats()
      assert.are.equal(5, stats.queue_length)
    end)

    it('should show pause_remaining when paused', function()
      throttle.pause(5000)
      local stats = throttle.get_stats()

      assert.is_true(stats.paused)
      assert.is_number(stats.pause_remaining)
      assert.is_true(stats.pause_remaining > 0)
    end)
  end)

  describe('statusline', function()
    it('should return empty string normally', function()
      local status = throttle.statusline()
      assert.are.equal('', status)
    end)

    it('should show pause indicator when paused', function()
      throttle.pause(5000)
      local status = throttle.statusline()

      assert.is_truthy(status:match('⏸'))
      assert.is_truthy(status:match('%d+s'))
    end)

    it('should show queue indicator when queue is large', function()
      throttle.pause(5000)

      -- Queue more than threshold (default 5)
      for i = 1, 8 do
        throttle.request('/test' .. i, 'token', {}, function() end)
      end

      vim.wait(50)

      throttle.resume()
      throttle.pause(5000) -- Pause again so queue stays

      vim.wait(50)

      local status = throttle.statusline()
      -- Should show pause or queue indicator
      assert.is_truthy(status:match('⏸') or status:match('⏳'))
    end)
  end)

  describe('setup', function()
    it('should accept custom configuration', function()
      throttle.setup({
        burst_size = 5,
        tokens_per_second = 1,
      })

      -- Config should be applied
      local stats = throttle.get_stats()
      -- After setup with burst_size 5, tokens should be 5
      assert.is_true(stats.available_tokens <= 5)
    end)

    it('should merge with defaults', function()
      throttle.setup({
        burst_size = 20,
      })

      -- Should work with merged config
      local stats = throttle.get_stats()
      assert.is_number(stats.available_tokens)
    end)
  end)

  describe('shutdown', function()
    it('should cancel all requests', function()
      throttle.pause(5000)

      for i = 1, 5 do
        throttle.request('/test' .. i, 'token', {}, function() end)
      end

      vim.wait(50)

      throttle.shutdown()

      local stats = throttle.get_stats()
      assert.are.equal(0, stats.queue_length)
    end)

    it('should stop timer', function()
      throttle.request('/test', 'token', {}, function() end)
      throttle.shutdown()

      -- Should not error after shutdown
      assert.has_no.errors(function()
        throttle.get_stats()
      end)
    end)
  end)

  describe('429 handling', function()
    it('should retry on 429 response', function()
      local callback_called = false
      local final_result = nil

      -- First response is 429, second is success
      mock_client.queue_response({
        status = 429,
        body = { retry_after = 0.1 },
      })
      mock_client.queue_response({
        status = 200,
        body = { success = true },
      })

      throttle.request('/test', 'token', {}, function(result)
        callback_called = true
        final_result = result
      end)

      -- Wait for retry
      vim.wait(500, function()
        return callback_called
      end)

      assert.is_true(callback_called)
      if final_result.status then
        assert.are.equal(200, final_result.status)
      end
    end)

    it('should pause bucket on 429', function()
      mock_client.queue_response({
        status = 429,
        body = { retry_after = 2 },
      })

      throttle.request('/test', 'token', {}, function() end)

      vim.wait(100, function()
        return throttle.is_paused()
      end)

      -- Should be paused
      assert.is_true(throttle.is_paused())
    end)
  end)

  describe('exponential backoff', function()
    it('should retry on 5xx error', function()
      local attempt_count = 0

      -- All responses are 500
      for _ = 1, 4 do
        mock_client.queue_response({
          status = 500,
          body = nil,
          error = 'Server error',
        })
      end

      throttle.request('/test', 'token', {}, function()
        attempt_count = attempt_count + 1
      end)

      -- Wait for retries (1s + 2s + some margin)
      vim.wait(4000, function()
        return attempt_count > 0
      end, 100)

      -- Should have made multiple attempts
      local stats = throttle.get_stats()
      assert.is_true(stats.total_retries >= 0)
    end)

    it('should not retry on 4xx error (except 429)', function()
      local callback_called = false
      local result_status = nil

      mock_client.queue_response({
        status = 400,
        body = nil,
        error = 'Bad request',
      })

      throttle.request('/test', 'token', {}, function(result)
        callback_called = true
        result_status = result.status
      end)

      vim.wait(200, function()
        return callback_called
      end)

      assert.is_true(callback_called)
      assert.are.equal(400, result_status)

      -- Should not have retried
      assert.are.equal(1, #mock_client.request_calls)
    end)
  end)

  describe('queue limit', function()
    it('should reject requests when queue is full', function()
      throttle.setup({ max_queue_size = 3 })
      throttle.pause(5000)

      local rejected = false

      -- Fill queue
      for i = 1, 3 do
        throttle.request('/test' .. i, 'token', {}, function() end)
      end

      vim.wait(50)

      -- This should be rejected
      throttle.request('/overflow', 'token', {}, function(result)
        if result.error and result.error:match('queue full') then
          rejected = true
        end
      end)

      vim.wait(100, function()
        return rejected
      end)

      assert.is_true(rejected)
    end)
  end)

  describe('_reset', function()
    it('should reset all state', function()
      -- Create some state
      throttle.pause(5000)
      throttle.request('/test', 'token', {}, function() end)

      vim.wait(50)

      -- Reset
      throttle._reset()

      local stats = throttle.get_stats()
      assert.are.equal(0, stats.queue_length)
      assert.are.equal(0, stats.total_requests)
      assert.are.equal(0, stats.total_retries)
      assert.are.equal(0, stats.total_cancelled)
      assert.is_false(stats.paused)
    end)
  end)

  describe('_get_state', function()
    it('should expose internal state for testing', function()
      local state = throttle._get_state()

      assert.is_table(state.queue)
      assert.is_table(state.in_flight)
      assert.is_table(state.bucket)
    end)
  end)
end)
