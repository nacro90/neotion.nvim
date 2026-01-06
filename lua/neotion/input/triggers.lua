--- Trigger registry for neotion.nvim
--- Handles /, [[, and @ triggers for inline completion
---@module 'neotion.input.triggers'

local log_module = require('neotion.log')
local log = log_module.get_logger('input.triggers')

local M = {}

---@class neotion.Trigger
---@field char string Trigger character(s)
---@field handler fun(bufnr: integer, ctx: neotion.TriggerContext, query: string, on_result: fun(result: neotion.TriggerResult)) Handler with async callback
---@field enabled boolean Whether trigger is enabled
---@field description? string Optional description

--- Registered triggers
---@type table<string, neotion.Trigger>
M.triggers = {}

--- Buffer-local state machines
---@type table<integer, table>
local buffer_states = {}

--- Namespace for trigger extmarks
local ns_id = vim.api.nvim_create_namespace('neotion_triggers')

---@class neotion.TriggerOpts
---@field enabled? boolean Whether trigger is enabled (default: true)
---@field description? string Optional description

--- Register a trigger character with handler
---@param char string Trigger character (e.g., '/', '[[', '@')
---@param handler fun(bufnr: integer, ctx: neotion.TriggerContext, query: string, on_result: fun(result: neotion.TriggerResult)) Handler with async callback
---@param opts? neotion.TriggerOpts Options
function M.register(char, handler, opts)
  opts = opts or {}
  M.triggers[char] = {
    char = char,
    handler = handler,
    enabled = opts.enabled ~= false,
    description = opts.description,
  }
end

--- Unregister a trigger character
---@param char string Trigger character
function M.unregister(char)
  M.triggers[char] = nil
end

--- Register default triggers
local function register_defaults()
  local slash = require('neotion.input.trigger.slash')
  local link = require('neotion.input.trigger.link')

  M.register('/', function(bufnr, ctx, query, on_result)
    slash.handle(ctx, query, on_result)
  end, { description = 'Slash commands' })

  M.register('[[', function(bufnr, ctx, query, on_result)
    link.handle(ctx, query, on_result)
  end, { description = 'Link to page' })

  -- Future: @ mention
  -- M.register('@', function(bufnr, ctx, query, on_result)
  --   mention.handle(ctx, query, on_result)
  -- end, { description = 'Mention' })
end

--- Apply the trigger result to the buffer
---@param bufnr integer Buffer number
---@param ctx neotion.TriggerContext Trigger context
---@param result neotion.TriggerResult Result from handler
local function apply_result(bufnr, ctx, result)
  if result.type == 'insert' and result.text then
    local line = vim.api.nvim_buf_get_lines(bufnr, ctx.line - 1, ctx.line, false)[1] or ''

    -- Calculate replacement range
    local start_col = ctx.trigger_start - 1 -- 0-indexed
    local end_col = ctx.col -- Current cursor position

    -- Build new content
    local before = line:sub(1, start_col)
    local after = line:sub(end_col + 1)

    -- Handle multi-line text (e.g., code block with ```\n)
    local text_lines = vim.split(result.text, '\n', { plain = true })
    local new_lines = {}
    local cursor_line = ctx.line
    local cursor_col = start_col

    if #text_lines == 1 then
      -- Single line - simple case
      new_lines[1] = before .. text_lines[1] .. after
      cursor_col = start_col + #text_lines[1]
      -- Apply cursor_offset if specified (negative = from end of inserted text)
      if result.cursor_offset then
        cursor_col = cursor_col + result.cursor_offset
      end
    else
      -- Multi-line: first line gets 'before', last line gets 'after'
      new_lines[1] = before .. text_lines[1]
      for i = 2, #text_lines - 1 do
        new_lines[i] = text_lines[i]
      end
      new_lines[#text_lines] = text_lines[#text_lines] .. after
      -- Cursor goes to end of last inserted line (before 'after')
      cursor_line = ctx.line + #text_lines - 1
      cursor_col = #text_lines[#text_lines]
      -- Apply cursor_offset if specified
      if result.cursor_offset then
        cursor_col = cursor_col + result.cursor_offset
      end
    end

    -- Replace line(s)
    vim.api.nvim_buf_set_lines(bufnr, ctx.line - 1, ctx.line, false, new_lines)

    -- Move cursor to end of inserted text
    vim.api.nvim_win_set_cursor(0, { cursor_line, cursor_col })

    -- Re-enter insert mode
    -- Use startinsert! (append) normally, but startinsert when cursor_offset
    -- is set (cursor is positioned inside the text, not at end)
    vim.schedule(function()
      if result.cursor_offset then
        vim.cmd('startinsert')
      else
        vim.cmd('startinsert!')
      end
    end)
  end
end

--- Handle trigger detection for a buffer
---@param bufnr integer Buffer number
---@param char string Character that was typed
local function handle_char(bufnr, char)
  local detection = require('neotion.input.trigger.detection')

  -- Get current line and cursor position BEFORE char is inserted
  -- InsertCharPre fires before the character is inserted
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_nr = cursor[1]
  local pre_insert_col = cursor[2] -- 0-indexed position before insertion

  -- Get line content (after char is inserted, use schedule)
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      log.debug('Buffer no longer valid', { bufnr = bufnr })
      return
    end

    local line = vim.api.nvim_buf_get_lines(bufnr, line_nr - 1, line_nr, false)[1] or ''
    -- The trigger starts where cursor was before insertion (convert to 1-indexed)
    -- For single char: trigger at pre_insert_col + 1
    -- For [[: first [ at pre_insert_col, second [ at pre_insert_col + 1
    local trigger_start_col = pre_insert_col + 1
    if char == '[[' then
      -- For [[, the first [ was already there, second [ just inserted
      trigger_start_col = pre_insert_col -- First [ is one position back
    end

    log.debug('Checking trigger position', { line = line, trigger_start_col = trigger_start_col, char = char })

    -- Detect trigger at the position where it starts
    local trigger_info = detection.detect_trigger(line, trigger_start_col)

    if trigger_info then
      log.debug('Trigger info found', { trigger = trigger_info.trigger, start_col = trigger_info.start_col })
      local trigger_def = M.triggers[trigger_info.trigger]
      if trigger_def and trigger_def.enabled then
        -- Extract query (text after trigger)
        local query = detection.extract_query(line, trigger_info.trigger, trigger_info.start_col)

        log.debug('Calling trigger handler', { trigger = trigger_info.trigger, query = query })

        -- Build context
        -- col is cursor position after trigger (end of typed content)
        local current_col = vim.api.nvim_win_get_cursor(0)[2] + 1
        local ctx = {
          bufnr = bufnr,
          line = line_nr,
          col = current_col,
          line_content = line,
          trigger_start = trigger_info.start_col,
          trigger_text = trigger_info.trigger,
        }

        -- Call handler with callback for async result
        trigger_def.handler(bufnr, ctx, query, function(result)
          if result then
            log.debug('Handler returned result', { result_type = result.type })
            apply_result(bufnr, ctx, result)
          end
        end)
      else
        log.debug('Trigger not found or disabled', { trigger = trigger_info.trigger })
      end
    else
      log.debug('No trigger detected at position', { line = line, trigger_start_col = trigger_start_col })
    end
  end)
end

--- Set up triggers for a buffer
---@param bufnr integer Buffer number
---@param opts? table Options
function M.setup(bufnr, opts)
  opts = opts or {}

  log.debug('Setting up triggers for buffer', { bufnr = bufnr, opts = opts })

  -- Register default triggers if not already registered
  if vim.tbl_isempty(M.triggers) then
    register_defaults()
    log.debug('Registered default triggers', { triggers = vim.tbl_keys(M.triggers) })
  end

  -- Store buffer state
  buffer_states[bufnr] = {
    last_char = '',
    active_trigger = nil,
  }

  -- Set up InsertCharPre autocmd to detect triggers
  vim.api.nvim_create_autocmd('InsertCharPre', {
    buffer = bufnr,
    callback = function()
      local char = vim.v.char
      local state = buffer_states[bufnr]

      if not state then
        log.debug('No buffer state found', { bufnr = bufnr })
        return
      end

      -- Check for single-char triggers
      if char == '/' or char == '@' then
        log.debug('Single-char trigger detected', { char = char, bufnr = bufnr })
        handle_char(bufnr, char)
      end

      -- Check for multi-char trigger [[
      if char == '[' and state.last_char == '[' then
        log.debug('Multi-char trigger detected', { trigger = '[[', bufnr = bufnr })
        handle_char(bufnr, '[[')
      end

      -- Update state
      state.last_char = char
    end,
  })

  -- Reset state on mode change
  vim.api.nvim_create_autocmd('InsertLeave', {
    buffer = bufnr,
    callback = function()
      if buffer_states[bufnr] then
        buffer_states[bufnr].last_char = ''
        buffer_states[bufnr].active_trigger = nil
      end
    end,
  })

  -- Cleanup on buffer delete
  vim.api.nvim_create_autocmd('BufDelete', {
    buffer = bufnr,
    callback = function()
      buffer_states[bufnr] = nil
    end,
  })

  log.info('Triggers setup complete for buffer', { bufnr = bufnr })
end

--- Clear all buffer states (for testing)
function M._reset()
  buffer_states = {}
  M.triggers = {}
end

return M
