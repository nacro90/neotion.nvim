--- Rate limiting and request queue for Notion API
--- Implements token bucket algorithm with 429 handling and exponential backoff
---@module neotion.api.throttle

---@class neotion.ThrottleConfig
---@field tokens_per_second number Rate of token refill (default: 3)
---@field burst_size number Maximum tokens (default: 10)
---@field max_retries number Maximum retry attempts for 5xx/network errors (default: 3)
---@field base_retry_delay_ms number Base delay for exponential backoff (default: 1000)
---@field max_retry_delay_ms number Maximum backoff delay (default: 8000)
---@field max_queue_size number Maximum pending requests (default: 100)
---@field queue_warning_threshold number Queue size to show in statusline (default: 5)
---@field pause_notify_threshold number Pause duration to notify user (default: 10)

---@class neotion.QueuedRequest
---@field id string Unique request ID
---@field endpoint string API endpoint
---@field token string Auth token
---@field opts table Request options
---@field callback function Response callback
---@field attempt number Current attempt (1-based)
---@field created_at number hrtime timestamp in seconds
---@field cancelled boolean Whether request was cancelled

---@class neotion.ThrottleStats
---@field queue_length number Current queue size
---@field available_tokens number Current available tokens
---@field requests_in_flight number Requests currently executing
---@field total_requests number Total requests made
---@field total_retries number Total retry attempts
---@field total_cancelled number Total cancelled requests
---@field paused boolean Whether bucket is paused
---@field pause_remaining number|nil Seconds until resume (nil if not paused)

---@class neotion.ThrottleResult
---@field status number HTTP status code (0 for network error)
---@field body table|nil Parsed JSON response
---@field error string|nil Error message
---@field cancelled boolean|nil True if request was cancelled
---@field request_id string|nil Request ID (for cancelled requests)

local M = {}

-- Default configuration
---@type neotion.ThrottleConfig
local default_config = {
  tokens_per_second = 3,
  burst_size = 10,
  max_retries = 3,
  base_retry_delay_ms = 1000,
  max_retry_delay_ms = 8000,
  max_queue_size = 100,
  queue_warning_threshold = 5,
  pause_notify_threshold = 10,
}

-- Active configuration
---@type neotion.ThrottleConfig
local config = vim.deepcopy(default_config)

-- Token bucket state
---@class neotion.TokenBucket
---@field tokens number Current available tokens
---@field last_refill number Last refill timestamp (seconds)
---@field paused_until number|nil Pause end time (seconds)
local bucket = {
  tokens = default_config.burst_size,
  last_refill = 0,
  paused_until = nil,
}

-- Request queue (FIFO)
---@type neotion.QueuedRequest[]
local queue = {}

-- In-flight requests
---@type table<string, neotion.QueuedRequest>
local in_flight = {}

-- Queue processing timer
---@type uv_timer_t|nil
local queue_timer = nil

-- Statistics
---@type {total_requests: number, total_retries: number, total_cancelled: number, error: boolean}
local stats = {
  total_requests = 0,
  total_retries = 0,
  total_cancelled = 0,
  error = false,
}

-- Request ID counter
local request_counter = 0

-- Logger (lazy loaded)
---@type neotion.Logger|nil
local logger = nil

---@return neotion.Logger
local function get_logger()
  if not logger then
    local log = require('neotion.log')
    logger = log.get_logger('api.throttle')
  end
  return logger
end

--- Safely call a callback, catching and logging errors
--- Errors are logged but not re-thrown to prevent queue/timer crashes
---@param callback function
---@param ... any
local function safe_callback(callback, ...)
  local ok, err = pcall(callback, ...)
  if not ok then
    get_logger().error('Callback error', { error = err })
    -- Don't re-throw - silently fail after logging to prevent queue crashes
  end
end

--- Get current time in seconds (high resolution)
---@return number
local function now_seconds()
  return vim.loop.hrtime() / 1e9
end

--- Refill tokens based on elapsed time
local function refill_tokens()
  local now = now_seconds()
  local elapsed = now - bucket.last_refill
  local new_tokens = elapsed * config.tokens_per_second
  bucket.tokens = math.min(config.burst_size, bucket.tokens + new_tokens)
  bucket.last_refill = now
end

--- Try to acquire a token from the bucket
---@return boolean success
local function try_acquire()
  -- Check if paused
  if bucket.paused_until then
    local now = now_seconds()
    if now < bucket.paused_until then
      return false
    end
    -- Pause ended, reset
    bucket.paused_until = nil
    get_logger().info('Rate limit pause ended')
  end

  refill_tokens()

  if bucket.tokens >= 1 then
    bucket.tokens = bucket.tokens - 1
    return true
  end

  return false
end

--- Calculate exponential backoff delay
---@param attempt number Current attempt (1-based)
---@return number delay_ms
local function calculate_backoff(attempt)
  local delay = config.base_retry_delay_ms * math.pow(2, attempt - 1)
  return math.min(delay, config.max_retry_delay_ms)
end

--- Check if result should trigger retry
---@param result neotion.ThrottleResult
---@return boolean
local function should_retry(result)
  return result.status >= 500 or result.status == 0
end

-- Forward declarations
local execute_request
local process_queue
local start_queue_timer
local stop_queue_timer

--- Stop the queue processing timer
stop_queue_timer = function()
  if queue_timer then
    if not queue_timer:is_closing() then
      queue_timer:stop()
      queue_timer:close()
    end
    queue_timer = nil
  end
end

--- Start the queue processing timer
start_queue_timer = function()
  if queue_timer then
    return
  end

  queue_timer = vim.loop.new_timer()
  if not queue_timer then
    get_logger().error('Failed to create queue timer')
    return
  end

  -- Track in global for plugin reload cleanup
  _G._neotion_throttle_timer = queue_timer

  queue_timer:start(
    0,
    50,
    vim.schedule_wrap(function()
      process_queue()
      if #queue == 0 and vim.tbl_isempty(in_flight) then
        stop_queue_timer()
      end
    end)
  )
end

--- Handle 429 rate limit response
---@param req neotion.QueuedRequest
---@param result neotion.ThrottleResult
local function handle_429(req, result)
  -- Parse Retry-After (default 1 second, cap at 60)
  local retry_after = 1
  if result.body and result.body.retry_after then
    retry_after = math.min(tonumber(result.body.retry_after) or 1, 60)
  end

  -- Pause bucket
  bucket.paused_until = now_seconds() + retry_after
  stats.total_retries = stats.total_retries + 1

  get_logger().warn('Rate limited, pausing', { seconds = retry_after })

  -- Notify user for long pauses
  if retry_after >= config.pause_notify_threshold then
    vim.schedule(function()
      vim.notify(string.format('Notion rate limited. Resuming in %ds...', retry_after), vim.log.levels.WARN)
    end)
  end

  -- Re-queue at front (don't increment attempt for 429)
  table.insert(queue, 1, req)
  start_queue_timer()
end

--- Schedule a retry with exponential backoff
---@param req neotion.QueuedRequest
local function schedule_retry(req)
  req.attempt = req.attempt + 1
  local delay = calculate_backoff(req.attempt)
  stats.total_retries = stats.total_retries + 1

  get_logger().info('Scheduling retry', { attempt = req.attempt, delay_ms = delay })

  vim.defer_fn(function()
    if not req.cancelled then
      table.insert(queue, req)
      start_queue_timer()
    end
  end, delay)
end

--- Execute a single request
---@param req neotion.QueuedRequest
execute_request = function(req)
  local client = require('neotion.api.client')

  client.request(req.endpoint, req.token, req.opts, function(result)
    -- Remove from in-flight
    in_flight[req.id] = nil

    -- Check cancellation
    if req.cancelled then
      safe_callback(req.callback, {
        status = 0,
        body = nil,
        error = nil,
        cancelled = true,
        request_id = req.id,
      })
      return
    end

    -- Handle 429 (rate limit)
    if result.status == 429 then
      handle_429(req, result)
      return
    end

    -- Handle 5xx or network error with retry
    if should_retry(result) and req.attempt < config.max_retries then
      schedule_retry(req)
      return
    end

    -- Track error state for statusline
    if result.error then
      stats.error = true
      vim.defer_fn(function()
        stats.error = false
      end, 5000) -- Clear error state after 5s
    end

    -- Final callback
    safe_callback(req.callback, result)
  end)
end

--- Process pending requests from queue
process_queue = function()
  while #queue > 0 and try_acquire() do
    local req = table.remove(queue, 1)

    if req.cancelled then
      safe_callback(req.callback, {
        status = 0,
        body = nil,
        error = nil,
        cancelled = true,
        request_id = req.id,
      })
    else
      in_flight[req.id] = req
      execute_request(req)
    end
  end
end

--- Generate a unique request ID
---@return string
local function generate_request_id()
  request_counter = request_counter + 1
  return string.format('req_%d_%d', request_counter, vim.loop.hrtime())
end

--- Queue a request for execution
---@param endpoint string API endpoint
---@param token string Auth token
---@param opts table|nil Request options
---@param callback fun(result: neotion.ThrottleResult) Response callback
---@return string request_id
function M.request(endpoint, token, opts, callback)
  opts = opts or {}

  -- Check queue size limit
  if #queue >= config.max_queue_size then
    get_logger().error('Request queue full', { max = config.max_queue_size })
    vim.schedule(function()
      safe_callback(callback, {
        status = 0,
        body = nil,
        error = 'Request queue full',
      })
    end)
    return ''
  end

  local request_id = generate_request_id()
  stats.total_requests = stats.total_requests + 1

  ---@type neotion.QueuedRequest
  local req = {
    id = request_id,
    endpoint = endpoint,
    token = token,
    opts = opts,
    callback = callback,
    attempt = 1,
    created_at = now_seconds(),
    cancelled = false,
  }

  table.insert(queue, req)
  start_queue_timer()

  get_logger().debug('Request queued', { id = request_id, endpoint = endpoint })

  return request_id
end

--- Queue a GET request
---@param endpoint string API endpoint
---@param token string Auth token
---@param callback fun(result: neotion.ThrottleResult) Response callback
---@return string request_id
function M.get(endpoint, token, callback)
  return M.request(endpoint, token, { method = 'GET' }, callback)
end

--- Queue a POST request
---@param endpoint string API endpoint
---@param token string Auth token
---@param body table Request body
---@param callback fun(result: neotion.ThrottleResult) Response callback
---@return string request_id
function M.post(endpoint, token, body, callback)
  return M.request(endpoint, token, { method = 'POST', body = body }, callback)
end

--- Queue a PATCH request
---@param endpoint string API endpoint
---@param token string Auth token
---@param body table Request body
---@param callback fun(result: neotion.ThrottleResult) Response callback
---@return string request_id
function M.patch(endpoint, token, body, callback)
  return M.request(endpoint, token, { method = 'PATCH', body = body }, callback)
end

--- Cancel a pending or in-flight request
---@param request_id string
---@return boolean success True if request was found and cancelled
function M.cancel(request_id)
  -- Check queue
  for _, req in ipairs(queue) do
    if req.id == request_id then
      req.cancelled = true
      stats.total_cancelled = stats.total_cancelled + 1
      get_logger().debug('Cancelled queued request', { id = request_id })
      return true
    end
  end

  -- Check in-flight
  if in_flight[request_id] then
    in_flight[request_id].cancelled = true
    stats.total_cancelled = stats.total_cancelled + 1
    get_logger().debug('Cancelled in-flight request', { id = request_id })
    return true
  end

  return false
end

--- Cancel all pending and in-flight requests
---@return number count Number of cancelled requests
function M.cancel_all()
  local count = 0

  for _, req in ipairs(queue) do
    if not req.cancelled then
      req.cancelled = true
      count = count + 1
    end
  end

  for _, req in pairs(in_flight) do
    if not req.cancelled then
      req.cancelled = true
      count = count + 1
    end
  end

  stats.total_cancelled = stats.total_cancelled + count
  get_logger().info('Cancelled all requests', { count = count })

  return count
end

--- Manually pause the rate limiter
---@param duration_ms number Pause duration in milliseconds
function M.pause(duration_ms)
  bucket.paused_until = now_seconds() + (duration_ms / 1000)
  get_logger().info('Manually paused', { duration_ms = duration_ms })
end

--- Resume the rate limiter if paused
function M.resume()
  if bucket.paused_until then
    bucket.paused_until = nil
    get_logger().info('Manually resumed')
    start_queue_timer()
  end
end

--- Check if rate limiter is paused
---@return boolean
function M.is_paused()
  if not bucket.paused_until then
    return false
  end
  return now_seconds() < bucket.paused_until
end

--- Get current throttle statistics
---@return neotion.ThrottleStats
function M.get_stats()
  refill_tokens()

  local pause_remaining = nil
  if bucket.paused_until then
    local remaining = bucket.paused_until - now_seconds()
    if remaining > 0 then
      pause_remaining = remaining
    end
  end

  return {
    queue_length = #queue,
    available_tokens = bucket.tokens,
    requests_in_flight = vim.tbl_count(in_flight),
    total_requests = stats.total_requests,
    total_retries = stats.total_retries,
    total_cancelled = stats.total_cancelled,
    paused = M.is_paused(),
    pause_remaining = pause_remaining,
  }
end

--- Get statusline component string
---@return string
function M.statusline()
  if stats.error then
    return '✗'
  end

  if bucket.paused_until then
    local remaining = math.ceil(bucket.paused_until - now_seconds())
    if remaining > 0 then
      return string.format('⏸ %ds', remaining)
    end
  end

  if #queue > config.queue_warning_threshold then
    return string.format('⏳%d', #queue)
  end

  return ''
end

--- Configure the throttle module
---@param opts neotion.ThrottleConfig|nil
function M.setup(opts)
  if opts then
    config = vim.tbl_deep_extend('force', default_config, opts)
  end

  -- Initialize bucket with configured burst size
  bucket.tokens = config.burst_size
  bucket.last_refill = now_seconds()
  bucket.paused_until = nil

  get_logger().debug('Throttle configured', { config = config })
end

--- Shutdown the throttle module (cleanup resources)
function M.shutdown()
  -- Cancel all pending requests
  M.cancel_all()

  -- Stop timer
  stop_queue_timer()

  -- Clear global reference
  _G._neotion_throttle_timer = nil

  -- Clear state
  queue = {}
  in_flight = {}

  get_logger().info('Throttle shutdown complete')
end

--- Reset the throttle module (for testing)
function M._reset()
  M.shutdown()

  -- Reset stats
  stats = {
    total_requests = 0,
    total_retries = 0,
    total_cancelled = 0,
    error = false,
  }

  -- Reset bucket
  bucket = {
    tokens = config.burst_size,
    last_refill = now_seconds(),
    paused_until = nil,
  }

  -- Reset counter
  request_counter = 0
end

--- Get internal state (for testing)
---@return {queue: neotion.QueuedRequest[], in_flight: table<string, neotion.QueuedRequest>, bucket: neotion.TokenBucket}
function M._get_state()
  return {
    queue = queue,
    in_flight = in_flight,
    bucket = bucket,
  }
end

-- Cleanup orphaned timer on module load (for plugin reload)
if _G._neotion_throttle_timer then
  local old_timer = _G._neotion_throttle_timer
  if not old_timer:is_closing() then
    old_timer:stop()
    old_timer:close()
  end
  _G._neotion_throttle_timer = nil
end

-- Initialize bucket time
bucket.last_refill = now_seconds()

return M
