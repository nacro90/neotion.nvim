---Sync Module for Neotion
---Orchestrates the sync process between buffer and Notion
---@class neotion.Sync
local M = {}

local log = require('neotion.log').get_logger('sync')

---Execute a sync plan by calling Notion API
---@param bufnr integer
---@param plan neotion.SyncPlan
---@param callback fun(success: boolean, errors: string[])
function M.execute(bufnr, plan, callback)
  local blocks_api = require('neotion.api.blocks')
  local buffer = require('neotion.buffer')
  local model = require('neotion.model')

  log.info('Executing sync plan', {
    bufnr = bufnr,
    updates = #plan.updates,
    creates = #plan.creates,
    deletes = #plan.deletes,
    type_changes = #plan.type_changes,
  })

  local errors = {}
  -- Type changes count as 2 operations each (delete + create)
  local pending = #plan.updates + #plan.creates + #plan.deletes + (#plan.type_changes * 2)

  log.debug('Pending operations count', { pending = pending })

  -- Nothing to do
  if pending == 0 then
    log.info('No operations to execute')
    callback(true, {})
    return
  end

  buffer.set_status(bufnr, 'syncing')

  local function check_done()
    pending = pending - 1
    log.debug('Operation completed', { remaining = pending })
    if pending == 0 then
      vim.schedule(function()
        if #errors > 0 then
          log.error('Sync failed with errors', { error_count = #errors, errors = errors })
          buffer.set_status(bufnr, 'error')
          callback(false, errors)
        else
          log.info('Sync completed successfully')
          -- Mark all blocks as clean
          model.mark_all_clean(bufnr)

          -- Update buffer state
          buffer.update_data(bufnr, { last_sync = os.date('!%Y-%m-%dT%H:%M:%SZ') })
          buffer.set_status(bufnr, 'ready')

          -- Mark buffer as saved
          vim.bo[bufnr].modified = false

          callback(true, {})
        end
      end)
    end
  end

  -- Execute updates
  for _, update in ipairs(plan.updates) do
    local block_json = model.serialize_block(update.block)

    log.debug('Executing update', {
      block_id = update.block_id,
      block_type = update.block:get_type(),
      content_preview = update.content:sub(1, 50),
    })

    blocks_api.update(update.block_id, block_json, function(result)
      if result.error then
        log.error('Update failed', {
          block_id = update.block_id,
          error = result.error,
        })
        table.insert(errors, 'Update failed for block ' .. update.block_id:sub(1, 8) .. ': ' .. result.error)
      else
        log.debug('Update succeeded', { block_id = update.block_id })
        -- Update original_text to current text (for next change detection)
        update.block.original_text = update.block:get_text()
        update.block:set_dirty(false)
      end
      check_done()
    end)
  end

  -- Execute type changes (delete old block + create new block with new type)
  -- Notion API doesn't support changing block types, so we need this workaround
  local data = buffer.get_data(bufnr)
  local page_id = data and data.page_id or nil

  log.debug('Type changes context', { page_id = page_id, type_changes_count = #plan.type_changes })

  for _, tc in ipairs(plan.type_changes) do
    log.info('Executing type change', {
      block_id = tc.block_id,
      old_type = tc.old_type,
      new_type = tc.new_type,
      content_preview = tc.content:sub(1, 50),
    })

    -- Step 1: Delete the old block
    log.debug('Step 1: Deleting old block', { block_id = tc.block_id })
    blocks_api.delete(tc.block_id, function(delete_result)
      if delete_result.error then
        log.error('Delete step failed for type change', {
          block_id = tc.block_id,
          error = delete_result.error,
        })
        table.insert(errors, 'Delete failed for type change ' .. tc.block_id:sub(1, 8) .. ': ' .. delete_result.error)
        check_done()
        check_done() -- Count both operations as done
        return
      end

      log.debug('Delete step succeeded', { block_id = tc.block_id })
      check_done() -- Delete operation done

      -- Step 2: Create new block with new type
      -- We need to append to the page (this will add at the end)
      -- TODO: In Phase 5+, implement "insert after" to preserve position
      if not page_id then
        log.error('Cannot create block: page_id not found')
        table.insert(errors, 'Cannot create block: page_id not found')
        check_done()
        return
      end

      -- Create block JSON for the new type
      local new_block = {
        type = tc.new_type,
        [tc.new_type] = {
          rich_text = {
            {
              type = 'text',
              text = { content = tc.content, link = nil },
            },
          },
        },
      }

      log.debug('Step 2: Creating new block', {
        page_id = page_id,
        new_type = tc.new_type,
        content_preview = tc.content:sub(1, 50),
      })

      blocks_api.append(page_id, { new_block }, function(append_result)
        if append_result.error then
          log.error('Create step failed for type change', {
            block_id = tc.block_id,
            page_id = page_id,
            new_type = tc.new_type,
            error = append_result.error,
          })
          table.insert(errors, 'Create failed for type change ' .. tc.block_id:sub(1, 8) .. ': ' .. append_result.error)
        else
          log.info('Type change completed successfully', {
            old_block_id = tc.block_id,
            new_type = tc.new_type,
          })
          -- Update block's internal state
          tc.block.original_text = tc.block:get_text()
          -- Update original_level for heading blocks
          if tc.block.original_level then
            tc.block.original_level = tc.block.level
          end
          tc.block:set_dirty(false)

          -- Note: The block ID has changed! We should reload the page
          -- For now, just notify the user
          vim.schedule(function()
            vim.notify('[neotion] Block type changed - page may need reload for correct ordering', vim.log.levels.INFO)
          end)
        end
        check_done()
      end)
    end)
  end

  -- Execute creates (not implemented in Phase 4)
  for _, create in ipairs(plan.creates) do
    -- TODO: Implement block creation in Phase 4.5
    table.insert(errors, 'Block creation not yet implemented')
    check_done()
  end

  -- Execute deletes
  for _, delete in ipairs(plan.deletes) do
    log.info('Executing delete', {
      block_id = delete.block_id,
      original_content = (delete.original_content or ''):sub(1, 50),
    })

    blocks_api.delete(delete.block_id, function(result)
      if result.error then
        log.error('Delete failed', {
          block_id = delete.block_id,
          error = result.error,
        })
        table.insert(errors, 'Delete failed for block ' .. delete.block_id:sub(1, 8) .. ': ' .. result.error)
      else
        log.info('Delete succeeded', { block_id = delete.block_id })
      end
      check_done()
    end)
  end
end

---Push changes from buffer to Notion
---@param bufnr integer
---@param callback? fun(success: boolean, message: string)
function M.push(bufnr, callback)
  callback = callback or function() end

  local buffer = require('neotion.buffer')
  local plan_module = require('neotion.sync.plan')
  local confirm = require('neotion.sync.confirm')
  local config = require('neotion.config')

  log.info('Push requested', { bufnr = bufnr })

  -- Check if this is a neotion buffer
  if not buffer.is_neotion_buffer(bufnr) then
    log.warn('Push called on non-neotion buffer', { bufnr = bufnr })
    vim.notify('[neotion] Not a Neotion buffer', vim.log.levels.WARN)
    callback(false, 'Not a Neotion buffer')
    return
  end

  -- Create sync plan
  log.debug('Creating sync plan')
  local plan = plan_module.create(bufnr)

  log.debug('Sync plan created', {
    updates = #plan.updates,
    creates = #plan.creates,
    deletes = #plan.deletes,
    type_changes = #plan.type_changes,
    unmatched = #plan.unmatched,
    has_changes = plan.has_changes,
    needs_confirmation = plan.needs_confirmation,
  })

  -- Nothing to sync
  if plan_module.is_empty(plan) then
    log.info('No changes to sync')
    vim.notify('[neotion] No changes to sync', vim.log.levels.INFO)
    callback(true, 'No changes')
    return
  end

  -- Get config for confirmation behavior
  local cfg = config.get()
  local confirm_sync = cfg.confirm_sync or 'on_ambiguity'

  -- Determine if we need confirmation
  local needs_confirm = false
  if confirm_sync == 'always' then
    needs_confirm = true
  elseif confirm_sync == 'on_ambiguity' then
    needs_confirm = plan.needs_confirmation
  end
  -- confirm_sync == 'never' -> no confirmation

  local function do_sync()
    M.execute(bufnr, plan, function(success, errors)
      if success then
        confirm.show_sync_success(plan)
        callback(true, 'Sync complete')
      else
        confirm.show_sync_errors(errors)
        callback(false, errors[1] or 'Sync failed')
      end
    end)
  end

  if needs_confirm then
    confirm.show_sync_confirmation(plan, function(confirmed)
      if confirmed then
        do_sync()
      else
        vim.notify('[neotion] Sync cancelled', vim.log.levels.INFO)
        callback(false, 'Cancelled')
      end
    end)
  else
    do_sync()
  end
end

---Pull changes from Notion to buffer (force reload from API)
---@param bufnr integer
---@param callback? fun(success: boolean, message: string)
function M.pull(bufnr, callback)
  callback = callback or function() end

  local buffer = require('neotion.buffer')
  local pages_api = require('neotion.api.pages')
  local blocks_api = require('neotion.api.blocks')

  log.info('Pull requested', { bufnr = bufnr })

  -- Check if this is a neotion buffer
  if not buffer.is_neotion_buffer(bufnr) then
    log.warn('Pull called on non-neotion buffer', { bufnr = bufnr })
    vim.notify('[neotion] Not a Neotion buffer', vim.log.levels.WARN)
    callback(false, 'Not a Neotion buffer')
    return
  end

  local data = buffer.get_data(bufnr)
  if not data or not data.page_id then
    log.error('Pull failed: no page_id in buffer data')
    callback(false, 'No buffer data')
    return
  end

  local page_id = data.page_id
  log.info('Force pulling from API', { page_id = page_id })

  -- Set loading state
  buffer.set_status(bufnr, 'loading')

  -- Fetch page info from API
  pages_api.get(page_id, function(page_result)
    -- Check if buffer is still valid
    if not vim.api.nvim_buf_is_valid(bufnr) then
      log.debug('Buffer no longer valid during pull')
      callback(false, 'Buffer closed')
      return
    end

    if page_result.error then
      log.error('Pull failed: page fetch error', { error = page_result.error })
      buffer.set_status(bufnr, 'error')
      vim.notify('[neotion] Pull failed: ' .. page_result.error, vim.log.levels.ERROR)
      callback(false, page_result.error)
      return
    end

    local page = page_result.page

    -- Cache page metadata
    local cache = require('neotion.cache')
    if cache.is_initialized() then
      local cache_pages = require('neotion.cache.pages')
      cache_pages.save_page(page_id, page)
    end

    -- Fetch blocks from API
    blocks_api.get_all_children(page_id, function(blocks_result)
      -- Check if buffer is still valid
      if not vim.api.nvim_buf_is_valid(bufnr) then
        log.debug('Buffer no longer valid during pull')
        callback(false, 'Buffer closed')
        return
      end

      if blocks_result.error then
        log.error('Pull failed: blocks fetch error', { error = blocks_result.error })
        buffer.set_status(bufnr, 'error')
        vim.notify('[neotion] Pull failed: ' .. blocks_result.error, vim.log.levels.ERROR)
        callback(false, blocks_result.error)
        return
      end

      -- Cache blocks and update sync state
      if cache.is_initialized() then
        local cache_pages = require('neotion.cache.pages')
        cache_pages.save_content(page_id, blocks_result.blocks)

        local sync_state = require('neotion.cache.sync_state')
        local content_hash = cache.hash.page_content(blocks_result.blocks)
        sync_state.update_after_pull(page_id, content_hash)
      end

      -- Display content (force update)
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(bufnr) then
          log.debug('Pull: starting buffer update', { bufnr = bufnr })

          local ok, err = pcall(function()
            local format = require('neotion.buffer.format')
            local model = require('neotion.model')

            -- Get page info
            local title = pages_api.get_title(page)
            local parent_type, parent_id = pages_api.get_parent(page)
            local icon = pages_api.get_icon(page)

            log.debug('Pull: updating buffer data', { title = title })

            buffer.update_data(bufnr, {
              page_title = title,
              parent_type = parent_type,
              parent_id = parent_id,
            })

            -- Deserialize blocks
            local blocks = model.deserialize_blocks(blocks_result.blocks)
            log.debug('Pull: deserialized blocks', { count = #blocks })

            -- Format header and blocks
            local header_lines = format.format_header(page)
            local header_line_count = #header_lines
            local block_lines = model.format_blocks(blocks)

            log.debug('Pull: formatted content', { header_lines = header_line_count, block_lines = #block_lines })

            -- Combine header + blocks
            local lines = {}
            vim.list_extend(lines, header_lines)
            vim.list_extend(lines, block_lines)

            -- Set buffer content
            log.debug('Pull: setting buffer content', { total_lines = #lines })
            buffer.set_content(bufnr, lines)

            -- Setup model layer with extmarks
            log.debug('Pull: setting up model layer')
            model.setup_buffer(bufnr, blocks, header_line_count)

            -- Update buffer data
            buffer.update_data(bufnr, {
              last_sync = os.date('!%Y-%m-%dT%H:%M:%SZ'),
              header_line_count = header_line_count,
            })
            buffer.set_status(bufnr, 'ready')

            -- Add to recent pages
            buffer.add_recent(page_id, title, icon, parent_type)

            -- Mark buffer as unmodified
            vim.bo[bufnr].modified = false

            log.info('Pull completed successfully', { page_id = page_id, title = title })
            vim.notify('[neotion] Pulled: ' .. title, vim.log.levels.INFO)
            callback(true, 'Pull complete')
          end)

          if not ok then
            log.error('Pull: buffer update failed', { error = tostring(err) })
            buffer.set_status(bufnr, 'error')
            vim.notify('[neotion] Pull failed: ' .. tostring(err), vim.log.levels.ERROR)
            callback(false, tostring(err))
          end
        else
          log.debug('Pull: buffer no longer valid in vim.schedule')
          callback(false, 'Buffer closed')
        end
      end)
    end)
  end)
end

---Sync (bidirectional - push local changes, pull remote changes)
---For now, just pushes changes. Full bidirectional sync in Phase 6+.
---@param bufnr integer
---@param callback? fun(success: boolean, message: string)
function M.sync(bufnr, callback)
  -- For Phase 4, sync is just push
  M.push(bufnr, callback)
end

return M
