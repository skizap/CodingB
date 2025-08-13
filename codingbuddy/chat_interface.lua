-- chat_interface.lua - Chat UI interface for CodingBuddy
-- Provides a chat-like interface using available GeanyLua capabilities

local geany = rawget(_G, 'geany')
local conversation_manager = require('conversation_manager')
local ai_connector = require('ai_connector')
local dialogs = require('dialogs')

local M = {}

-- Chat state
local chat_window_open = false
local current_input = ""
local chat_history_display = {}
local task_mode = false  -- Task mode state for approval workflow

-- Task mode tool wrapper - intercepts tools that require approval
local function wrap_tools_for_task_mode(tools)
  if not task_mode then
    return tools
  end
  
  local wrapped_tools = {}
  local ops_queue = require('ops_queue')
  
  for name, tool in pairs(tools) do
    if name == 'write_file' or name == 'apply_patch' or name == 'run_command' then
      -- These tools require approval in task mode
      wrapped_tools[name] = {
        description = tool.description .. ' (Task Mode: requires approval)',
        input_schema = tool.input_schema,
        handler = function(args)
          -- Enqueue operation for approval instead of executing
          local operation = ops_queue.enqueue(name, {
            path = args.rel_path or args.file or args.cwd_rel,
            content = args.content or args.patch_text,
            command = args.cmd,
            summary = string.format('%s operation', name:gsub('_', ' ')),
            original_args = args
          })
          
          return {
            pending = true,
            operation_id = operation.id,
            message = string.format('Operation %d (%s) has been queued for approval. Use /approve %d to execute or /reject %d to cancel.', 
                                  operation.id, name, operation.id, operation.id)
          }
        end
      }
    else
      -- Other tools execute normally
      wrapped_tools[name] = tool
    end
  end
  
  return wrapped_tools
end

-- Execute approved operations and collect results
local function execute_approved_operations()
  local ops_queue = require('ops_queue')
  local original_registry = require('tools.registry').get_registry()
  local approved_ops = ops_queue.pop_approved()
  local results = {}
  
  for _, op in ipairs(approved_ops) do
    local tool = original_registry[op.kind]
    if tool and tool.handler then
      local ok, result = pcall(tool.handler, op.payload.original_args or {})
      if ok then
        results[#results + 1] = {
          operation_id = op.id,
          kind = op.kind,
          result = result
        }
      else
        results[#results + 1] = {
          operation_id = op.id,
          kind = op.kind,
          result = { error = 'Execution failed: ' .. tostring(result) }
        }
      end
    end
  end
  
  return results
end

-- Since GeanyLua has limited GTK bindings, we'll use a hybrid approach:
-- 1. Use geany.message() for simple interactions
-- 2. Create a text-based interface that can be enhanced later
-- 3. Implement the chat logic that can work with better UI when available

local function format_message_for_display(message)
  local timestamp = message.timestamp or os.date('!%Y-%m-%dT%H:%M:%SZ')
  local time_str = timestamp:match('T(%d%d:%d%d)')  -- Extract HH:MM
  local role_prefix = message.role == 'user' and 'You' or 'Assistant'
  
  return string.format("[%s] %s: %s", time_str or '??:??', role_prefix, message.content)
end

local function get_conversation_display()
  local conv = conversation_manager.get_current_conversation()
  local lines = {}
  
  -- Add conversation title and stats
  table.insert(lines, "=== " .. conv.title .. " ===")
  local stats = conversation_manager.get_conversation_stats()
  table.insert(lines, string.format("Messages: %d | Tokens: %d | Cost: $%.4f", 
    stats.message_count, stats.total_tokens, stats.total_cost))
  table.insert(lines, "")
  
  -- Add recent messages (last 10 to keep display manageable)
  local messages = conv.messages
  local start_idx = math.max(1, #messages - 9)  -- Show last 10 messages
  
  if start_idx > 1 then
    table.insert(lines, "... (showing last 10 messages)")
    table.insert(lines, "")
  end
  
  for i = start_idx, #messages do
    table.insert(lines, format_message_for_display(messages[i]))
    table.insert(lines, "")  -- Add spacing between messages
  end
  
  return table.concat(lines, '\n')
end

local function show_chat_window()
  local display = get_conversation_display()
  local mode_indicator = task_mode and " [TASK MODE]" or ""
  local prompt = display .. "\n" .. string.rep("-", 50) .. "\n" .. 
                "What can I do for you?" .. mode_indicator .. "\n\n" ..
                "Commands:\n" ..
                "- Type your message and press OK to send\n" ..
                "- Type '/new' to start a new conversation\n" ..
                "- Type '/history' to see conversation list\n" ..
                "- Type '/task start' to enter task mode (requires approval)\n" ..
                "- Type '/task stop' to exit task mode\n" ..
                "- Type '/ops' to list pending operations\n" ..
                "- Type '/approve <id>' to approve an operation\n" ..
                "- Type '/reject <id>' to reject an operation\n" ..
                "- Type '/clear' to clear completed operations\n" ..
                "- Type '/usage [hours]' to show usage statistics\n" ..
                "- Type '/quit' to close chat\n\n" ..
                "Your message:"
  
  -- Use a simple input dialog for now
  -- In a full GTK implementation, this would be a proper chat window
  if geany and geany.input then
    return geany.input("CodingBuddy Chat", prompt)
  else
    -- Fallback for testing
    print(prompt)
    return io.read()
  end
end

local function process_chat_command(input)
  if not input or input:match('^%s*$') then
    return false  -- Empty input, continue chat
  end
  
  input = input:gsub('^%s+', ''):gsub('%s+$', '')  -- Trim whitespace
  
  if input == '/quit' or input == '/exit' then
    return true  -- Exit chat
  elseif input == '/new' then
    conversation_manager.create_new_conversation()
    dialogs.alert("CodingBuddy", "Started new conversation")
    return false
  elseif input == '/history' then
    local conversations = conversation_manager.list_conversations()
    local history_text = "Recent Conversations:\n\n"
    
    for i, conv in ipairs(conversations) do
      if i <= 10 then  -- Show last 10 conversations
        local date = conv.updated_at:match('(%d%d%d%d%-%d%d%-%d%d)')
        history_text = history_text .. string.format("%d. %s (%s)\n", i, conv.title, date or 'Unknown')
      end
    end
    
    if #conversations == 0 then
      history_text = history_text .. "No previous conversations found."
    end
    
    dialogs.show_text("Conversation History", history_text)
    return false
  elseif input:match('^/ops') then
    local ops_queue = require('ops_queue')
    local formatted_list = ops_queue.get_formatted_list()
    dialogs.show_text('Operations Queue', formatted_list)
    return false
  elseif input:match('^/approve%s+%d+') then
    local id = tonumber(input:match('^/approve%s+(%d+)'))
    local ops_queue = require('ops_queue')
    if ops_queue.set_status(id, 'approved') then
      dialogs.alert('CodingBuddy', 'Approved operation ' .. tostring(id))
    else
      dialogs.alert('CodingBuddy', 'Operation ' .. tostring(id) .. ' not found')
    end
    return false
  elseif input:match('^/reject%s+%d+') then
    local id = tonumber(input:match('^/reject%s+(%d+)'))
    local ops_queue = require('ops_queue')
    if ops_queue.set_status(id, 'rejected') then
      dialogs.alert('CodingBuddy', 'Rejected operation ' .. tostring(id))
    else
      dialogs.alert('CodingBuddy', 'Operation ' .. tostring(id) .. ' not found')
    end
    return false
  elseif input:match('^/clear') then
    local ops_queue = require('ops_queue')
    local cleared_count = ops_queue.clear_completed()
    if cleared_count > 0 then
      dialogs.alert('CodingBuddy', 'Cleared ' .. tostring(cleared_count) .. ' completed operations')
    else
      dialogs.alert('CodingBuddy', 'No completed operations to clear')
    end
    return false
  elseif input:match('^/task%s+start') then
    task_mode = true
    dialogs.alert('CodingBuddy', 'Task mode enabled. AI requests for file operations will require approval.')
    return false
  elseif input:match('^/task%s+stop') then
    task_mode = false
    dialogs.alert('CodingBuddy', 'Task mode disabled. AI requests will execute normally.')
    return false
  elseif input:match('^/usage') then
    -- Handle /usage command with optional time period
    local usage_analyzer = require('usage_analyzer')
    local hours_match = input:match('^/usage%s+(%d+)')
    local hours = hours_match and tonumber(hours_match) or nil
    
    local usage_summary
    if hours then
      usage_summary = usage_analyzer.get_session_summary(hours)
    else
      usage_summary = usage_analyzer.get_total_summary()
    end
    
    dialogs.show_text('CodingBuddy Usage Statistics', usage_summary)
    return false
  else
    -- Regular chat message
    return process_chat_message(input)
  end
end

function process_chat_message(user_input)
  -- Add user message to conversation
  conversation_manager.add_message('user', user_input)
  
  -- Check if we have approved operations to execute first
  local ops_queue = require('ops_queue')
  local pending_ops = ops_queue.list()
  local has_approved_ops = false
  
  for _, op in ipairs(pending_ops) do
    if op.status == 'approved' then
      has_approved_ops = true
      break
    end
  end
  
  if has_approved_ops then
    -- Execute approved operations and get results
    local execution_results = execute_approved_operations()
    
    if #execution_results > 0 then
      -- Build summary of executed operations
      local execution_summary = "Executed approved operations:\n"
      for _, result in ipairs(execution_results) do
        execution_summary = execution_summary .. string.format("- Operation %d (%s): %s\n", 
          result.operation_id, result.kind, 
          result.result.error and ("Error - " .. result.result.error) or "Success")
      end
      
      -- Add execution results to conversation context
      conversation_manager.add_message('system', execution_summary)
      
      -- Show summary to user
      dialogs.show_text('CodingBuddy Operations Executed', execution_summary)
    end
  end
  
  -- Get conversation context for AI
  local context = conversation_manager.get_conversation_context(10)  -- Last 10 messages
  
  -- Get tools from registry and wrap them for task mode if needed
  local original_tools = require('tools.registry').get_registry()
  local tools = wrap_tools_for_task_mode(original_tools)
  
  -- Prepare AI request using the enhanced ai_connector with tool support
  local ai_request = {
    provider = 'anthropic',
    system = task_mode and 
      'You are CodingBuddy, an AI coding assistant integrated into Geany. You are in TASK MODE - file operations will require user approval before execution.' or
      'You are CodingBuddy, an AI coding assistant integrated into Geany.',
    messages = context,
    return_structured = true,
    max_tokens = 2048,
    tools = tools,
    tool_choice = 'auto',
    auto_execute_tools = true,
    tool_registry = tools
  }

  -- Show loading indicator
  dialogs.alert("CodingBuddy", "Processing your request...")

  -- Make AI request
  local ok, response = pcall(ai_connector.chat, ai_request)

  if not ok then
    local error_msg = "Error communicating with AI: " .. tostring(response)
    conversation_manager.add_message('assistant', error_msg)
    dialogs.alert("CodingBuddy Error", error_msg)
    return false
  end

  -- Handle response
  local ai_text = response
  local metadata = {}

  if type(response) == 'table' then
    ai_text = response.text or response.content or "No response received"
    metadata = {
      tokens = response.usage,
      cost = response.cost,
      model = response.model,
      provider = ai_request.provider
    }
  end
  
  -- Add AI response to conversation
  conversation_manager.add_message('assistant', ai_text, metadata)
  
  -- Check for new pending operations and show summary
  if task_mode then
    local ops = ops_queue.list()
    local pending_ops_count = 0
    for _, op in ipairs(ops) do
      if op.status == 'pending' then
        pending_ops_count = pending_ops_count + 1
      end
    end
    
    if pending_ops_count > 0 then
      local lines = { 'Pending operations:' }
      for _, op in ipairs(ops) do
        if op.status == 'pending' then
          lines[#lines+1] = string.format('%d %s %s', op.id, op.kind, op.status)
        end
      end
      dialogs.show_text('CodingBuddy Pending Ops', table.concat(lines, '\n'))
    end
  end
  
  return false  -- Continue chat
end

function M.open_chat()
  if not geany then
    print("CodingBuddy Chat Interface")
    print("Running in CLI mode - limited functionality")
  end
  
  chat_window_open = true
  
  -- Main chat loop
  while chat_window_open do
    local user_input = show_chat_window()
    
    if not user_input then
      -- User cancelled or closed dialog
      break
    end
    
    local should_exit = process_chat_command(user_input)
    if should_exit then
      break
    end
  end
  
  chat_window_open = false
  dialogs.alert("CodingBuddy", "Chat session ended")
end

function M.quick_chat(message)
  -- Quick chat function for single interactions
  if not message or message:match('^%s*$') then
    return M.open_chat()
  end
  
  -- Process single message and show result
  conversation_manager.add_message('user', message)

  local context = conversation_manager.get_conversation_context(5)
  local ai_request = {
    provider = 'anthropic',
    system = 'You are CodingBuddy, a helpful coding assistant. Be concise.',
    messages = context,
    return_structured = true,
    max_tokens = 1024
  }

  local ok, response = pcall(ai_connector.chat, ai_request)

  if not ok then
    dialogs.alert("CodingBuddy Error", "Error: " .. tostring(response))
    return
  end

  local ai_text = response
  local metadata = {}
  if type(response) == 'table' then
    ai_text = response.text or response.content or "No response received"
    metadata = {
      tokens = response.usage,
      cost = response.cost,
      model = response.model,
      provider = 'anthropic'
    }
  end

  conversation_manager.add_message('assistant', ai_text, metadata)
  dialogs.show_text("CodingBuddy Response", ai_text)
end

function M.analyze_current_buffer_with_chat()
  -- Enhanced version of the original analyze function that uses chat interface
  local filename, text
  if geany then
    local buf = (geany.buffer and geany.buffer()) or (geany.fileinfo and geany.fileinfo())
    filename = (geany.filename and geany.filename()) or (buf and buf.name) or 'untitled'
    text = (geany.text and geany.text()) or ''
  else
    filename = 'untitled'
    text = ''
  end

  if text == '' then
    dialogs.alert("CodingBuddy", "No code to analyze in current buffer")
    return
  end

  local analysis_prompt = string.format(
    "Please analyze this code file:\n\nFilename: %s\n\nCode:\n```\n%s\n```\n\n" ..
    "Provide a concise analysis focusing on:\n" ..
    "- Code quality and potential issues\n" ..
    "- Suggestions for improvement\n" ..
    "- Any bugs or security concerns",
    filename, text
  )

  M.quick_chat(analysis_prompt)
end

function M.get_chat_status()
  local conv = conversation_manager.get_current_conversation()
  local stats = conversation_manager.get_conversation_stats()

  return {
    active = chat_window_open,
    conversation_id = conv and conv.id or nil,
    message_count = stats and stats.message_count or 0,
    total_tokens = stats and stats.total_tokens or 0,
    total_cost = stats and stats.total_cost or 0,
    task_mode = task_mode
  }
end

-- Task mode management functions
function M.is_task_mode()
  return task_mode
end

function M.set_task_mode(enabled)
  task_mode = enabled
end

function M.toggle_task_mode()
  task_mode = not task_mode
  return task_mode
end

return M
