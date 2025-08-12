-- ops_queue.lua - Operation approval queue for CodingBuddy
-- Manages pending operations that require user approval before execution

local M = { queue = {}, counter = 0 }

function M.enqueue(kind, payload)
  M.counter = M.counter + 1
  local id = M.counter
  local item = { 
    id = id, 
    kind = kind, 
    payload = payload, 
    status = 'pending',
    timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
  }
  table.insert(M.queue, item)
  return item
end

function M.list()
  return M.queue
end

function M.get_operation(id)
  for _, it in ipairs(M.queue) do
    if it.id == id then
      return it
    end
  end
  return nil
end

function M.set_status(id, status)
  for _, it in ipairs(M.queue) do
    if it.id == id then
      it.status = status
      return true
    end
  end
  return false
end

function M.pop_approved()
  local approved = {}
  local remaining = {}
  for _, it in ipairs(M.queue) do
    if it.status == 'approved' then
      table.insert(approved, it)
    else
      table.insert(remaining, it)
    end
  end
  M.queue = remaining
  return approved
end

-- Clear all completed (approved/rejected) operations from the queue
function M.clear_completed()
  local remaining = {}
  local cleared_count = 0
  for _, it in ipairs(M.queue) do
    if it.status == 'pending' then
      table.insert(remaining, it)
    else
      cleared_count = cleared_count + 1
    end
  end
  M.queue = remaining
  return cleared_count
end

-- Helper function to format operation for display
function M.format_operation(item)
  local time_str = item.timestamp and item.timestamp:match('T(%d%d:%d%d)') or '??:??'
  local summary = ''
  
  -- Extract meaningful summary from payload based on operation kind
  if item.kind == 'write_file' and item.payload and item.payload.path then
    summary = 'Write to: ' .. item.payload.path
  elseif item.kind == 'apply_patch' and item.payload and item.payload.file then
    summary = 'Patch: ' .. item.payload.file
  elseif item.kind == 'run_terminal' and item.payload and item.payload.command then
    local cmd = item.payload.command
    if #cmd > 50 then
      cmd = cmd:sub(1, 47) .. '...'
    end
    summary = 'Run: ' .. cmd
  elseif item.payload and item.payload.summary then
    summary = item.payload.summary
  else
    summary = 'No details available'
  end
  
  return string.format('[%s] ID:%d %s - %s (%s)', 
    time_str, item.id, item.kind, summary, item.status:upper())
end

-- Get formatted list for display
function M.get_formatted_list()
  local lines = {}
  if #M.queue == 0 then
    table.insert(lines, 'No pending operations.')
  else
    table.insert(lines, 'Pending operations:')
    table.insert(lines, '')
    for _, item in ipairs(M.queue) do
      table.insert(lines, M.format_operation(item))
    end
    table.insert(lines, '')
    table.insert(lines, 'Use /approve <id> or /reject <id> to manage operations.')
  end
  return table.concat(lines, '\n')
end

return M
