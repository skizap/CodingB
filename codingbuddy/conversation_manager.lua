-- conversation_manager.lua - Manages chat conversations and history
-- Handles conversation state, history persistence, and session management

local utils = require('utils')
local config = require('config')

local M = {}

-- Current conversation state
local current_conversation = nil
local conversation_history = {}

-- Conversation structure:
-- {
--   id = "unique_conversation_id",
--   title = "Auto-generated or user-set title",
--   created_at = "2024-01-01T12:00:00Z",
--   updated_at = "2024-01-01T12:30:00Z",
--   messages = {
--     { role = "user", content = "Hello", timestamp = "...", tokens = {...} },
--     { role = "assistant", content = "Hi there!", timestamp = "...", tokens = {...} },
--     ...
--   },
--   metadata = {
--     total_tokens = 150,
--     total_cost = 0.001234,
--     model_used = "gpt-4",
--     provider = "openai"
--   }
-- }

local function get_conversations_dir()
  local home = os.getenv('HOME') or '.'
  return home .. '/.config/geany/plugins/geanylua/codingbuddy/conversations'
end

local function ensure_conversations_dir()
  local dir = get_conversations_dir()
  local ok = os.execute('mkdir -p "' .. dir .. '"')
  return ok == 0 or ok == true  -- Different Lua versions return different values
end

local function generate_conversation_id()
  -- Generate a unique ID based on timestamp and random component
  local timestamp = os.time()
  local random = math.random(1000, 9999)
  return string.format("conv_%d_%d", timestamp, random)
end

local function generate_conversation_title(first_message)
  -- Generate a title from the first user message
  if not first_message or not first_message.content then
    return "New Conversation"
  end
  
  local content = first_message.content
  -- Take first 50 characters and clean up
  local title = content:sub(1, 50):gsub('\n', ' '):gsub('%s+', ' ')
  if #content > 50 then
    title = title .. "..."
  end
  
  return title
end

function M.create_new_conversation()
  local conv_id = generate_conversation_id()
  local now = os.date('!%Y-%m-%dT%H:%M:%SZ')
  
  current_conversation = {
    id = conv_id,
    title = "New Conversation",
    created_at = now,
    updated_at = now,
    messages = {},
    metadata = {
      total_tokens = 0,
      total_cost = 0,
      model_used = nil,
      provider = nil
    }
  }
  
  return current_conversation
end

function M.get_current_conversation()
  if not current_conversation then
    M.create_new_conversation()
  end
  return current_conversation
end

function M.add_message(role, content, metadata)
  local conv = M.get_current_conversation()
  local now = os.date('!%Y-%m-%dT%H:%M:%SZ')
  
  local message = {
    role = role,  -- "user" or "assistant"
    content = content,
    timestamp = now,
    tokens = metadata and metadata.tokens or {},
    cost = metadata and metadata.cost or 0
  }
  
  table.insert(conv.messages, message)
  conv.updated_at = now
  
  -- Update conversation title if this is the first user message
  if role == "user" and #conv.messages == 1 then
    conv.title = generate_conversation_title(message)
  end
  
  -- Update metadata
  if metadata then
    if metadata.tokens and metadata.tokens.total then
      conv.metadata.total_tokens = conv.metadata.total_tokens + metadata.tokens.total
    end
    if metadata.cost then
      conv.metadata.total_cost = conv.metadata.total_cost + metadata.cost
    end
    if metadata.model then
      conv.metadata.model_used = metadata.model
    end
    if metadata.provider then
      conv.metadata.provider = metadata.provider
    end
  end
  
  -- Auto-save after adding message
  M.save_current_conversation()
  
  return message
end

function M.get_conversation_context(max_messages)
  local conv = M.get_current_conversation()
  max_messages = max_messages or 20  -- Default to last 20 messages
  
  local messages = conv.messages
  local start_idx = math.max(1, #messages - max_messages + 1)
  
  local context = {}
  for i = start_idx, #messages do
    table.insert(context, {
      role = messages[i].role,
      content = messages[i].content
    })
  end
  
  return context
end

function M.save_current_conversation()
  if not current_conversation then
    return false, "No current conversation to save"
  end
  
  if not ensure_conversations_dir() then
    return false, "Could not create conversations directory"
  end
  
  local home = os.getenv('HOME') or '.'
  local dir = home .. '/.config/geany/plugins/geanylua/codingbuddy/conversations'
  local filepath = dir .. '/' .. current_conversation.id .. '.json'
  
  -- Serialize conversation to JSON
  local json_str
  local ok, dkjson = pcall(require, 'dkjson')
  if ok and dkjson then
    json_str = dkjson.encode(current_conversation, { indent = true })
  else
    -- Fallback: create simple JSON manually
    json_str = utils.simple_json_encode(current_conversation)
  end
  
  if not json_str then
    return false, "Could not encode conversation to JSON"
  end
  
  -- Write plain text to temporary file first
  local tmp_plain = filepath .. '.plain'
  local okw, werr = utils.safe_write_all(tmp_plain, json_str)
  if not okw then 
    return false, werr 
  end
  
  -- Check if encryption is enabled
  local cfg = config.get()
  if cfg.conversation_encryption then
    -- Encrypt the file
    local crypto = require('crypto')
    local ok_enc, eerr = crypto.encrypt_file(tmp_plain, filepath .. '.enc')
    os.remove(tmp_plain) -- Always clean up temporary plaintext file
    if not ok_enc then 
      return false, eerr 
    end
    
    -- Remove any existing unencrypted file
    os.remove(filepath)
    
    utils.log_debug('Conversation saved with encryption: ' .. current_conversation.id)
  else
    -- Move temporary file to final location (no encryption)
    local move_cmd
    if os.getenv('OS') == 'Windows_NT' then
      move_cmd = 'move "' .. tmp_plain .. '" "' .. filepath .. '"'
    else
      move_cmd = 'mv "' .. tmp_plain:gsub('"', '\\"') .. '" "' .. filepath:gsub('"', '\\"') .. '"'
    end
    
    local result = os.execute(move_cmd)
    local success = (type(result) == 'boolean') and result or (result == 0)
    
    if not success then
      os.remove(tmp_plain)
      return false, 'failed to move temporary file to final location'
    end
    
    -- Remove any existing encrypted file
    os.remove(filepath .. '.enc')
    
    utils.log_debug('Conversation saved without encryption: ' .. current_conversation.id)
  end
  
  return true
end

function M.load_conversation(conversation_id)
  local home = os.getenv('HOME') or '.'
  local dir = home .. '/.config/geany/plugins/geanylua/codingbuddy/conversations'
  local encpath = dir .. '/' .. conversation_id .. '.json.enc'
  local plainpath = dir .. '/' .. conversation_id .. '.json'
  
  local content
  
  -- Try to load from plaintext file first
  local f = io.open(plainpath, 'rb')
  if f then
    content = f:read('*all')
    f:close()
    utils.log_debug('Loaded conversation from plaintext file: ' .. conversation_id)
  else
    -- Try to load and decrypt encrypted file
    local enc_f = io.open(encpath, 'rb')
    if not enc_f then
      return nil, "Could not find conversation file (neither " .. plainpath .. " nor " .. encpath .. " exists)"
    end
    enc_f:close()
    
    -- Decrypt the file
    local crypto = require('crypto')
    local tmp = encpath .. '.dec.' .. tostring(os.time()) .. '.' .. math.random(1000, 9999)
    local ok, derr = crypto.decrypt_file(encpath, tmp)
    if not ok then 
      return nil, derr 
    end
    
    -- Read decrypted content
    local tf = io.open(tmp, 'rb')
    if not tf then 
      os.remove(tmp)
      return nil, 'cannot open decrypted temporary file' 
    end
    content = tf:read('*all')
    tf:close()
    os.remove(tmp) -- Always clean up temporary decrypted file
    
    utils.log_debug('Loaded conversation from encrypted file: ' .. conversation_id)
  end
  
  if not content or content == '' then
    return nil, "Empty conversation file"
  end
  
  -- Try to parse JSON
  local conversation
  local ok, dkjson = pcall(require, 'dkjson')
  if ok and dkjson then
    local err
    conversation, err = dkjson.decode(content)
    if not conversation then
      return nil, "JSON decode error: " .. tostring(err)
    end
  else
    -- Fallback: try simple JSON parsing
    conversation = utils.simple_json_decode(content)
    if not conversation then
      return nil, "Could not parse JSON (no dkjson available)"
    end
  end
  
  current_conversation = conversation
  return conversation
end

function M.list_conversations()
  if not ensure_conversations_dir() then
    return {}
  end
  
  local conversations = {}
  local dir = get_conversations_dir()
  local seen_ids = {}
  
  -- List both .json and .json.enc files
  local patterns = {'*.json', '*.json.enc'}
  
  for _, pattern in ipairs(patterns) do
    local handle = io.popen('ls "' .. dir .. '"/' .. pattern .. ' 2>/dev/null')
    if handle then
      for filepath in handle:lines() do
        local filename = filepath:match('([^/]+)$')
        local conv_id
        
        -- Extract conversation ID from filename
        if filename:match('%.json%.enc$') then
          conv_id = filename:match('(.+)%.json%.enc$')
        elseif filename:match('%.json$') then
          conv_id = filename:match('(.+)%.json$')
        end
        
        if conv_id and not seen_ids[conv_id] then
          seen_ids[conv_id] = true
          
          -- Try to extract metadata without fully loading/decrypting the conversation
          local content
          local is_encrypted = filename:match('%.json%.enc$') ~= nil
          
          if is_encrypted then
            -- For encrypted files, we need to decrypt temporarily to get metadata
            -- This is less efficient but necessary for listing
            local crypto = require('crypto')
            local tmp = filepath .. '.list_tmp.' .. tostring(os.time()) .. '.' .. math.random(1000, 9999)
            local ok, derr = crypto.decrypt_file(filepath, tmp)
            
            if ok then
              local tf = io.open(tmp, 'rb')
              if tf then
                content = tf:read('*all')
                tf:close()
              end
              os.remove(tmp) -- Clean up temporary file
            else
              utils.log_warning('Failed to decrypt conversation for listing: ' .. conv_id .. ' (' .. tostring(derr) .. ')')
            end
          else
            -- For plaintext files, read directly
            local file = io.open(filepath, 'r')
            if file then
              content = file:read('*all')
              file:close()
            end
          end
          
          if content then
            -- Try to extract just the metadata we need using pattern matching
            local title = content:match('"title"%s*:%s*"([^"]*)"')
            local created_at = content:match('"created_at"%s*:%s*"([^"]*)"')
            local updated_at = content:match('"updated_at"%s*:%s*"([^"]*)"')
            
            if title and created_at then
              table.insert(conversations, {
                id = conv_id,
                title = title,
                created_at = created_at,
                updated_at = updated_at or created_at,
                encrypted = is_encrypted
              })
            end
          end
        end
      end
      handle:close()
    end
  end
  
  -- Sort by updated_at (most recent first)
  table.sort(conversations, function(a, b)
    return (a.updated_at or '') > (b.updated_at or '')
  end)
  
  return conversations
end

function M.delete_conversation(conversation_id)
  local dir = get_conversations_dir()
  local plainpath = dir .. '/' .. conversation_id .. '.json'
  local encpath = dir .. '/' .. conversation_id .. '.json.enc'
  
  -- Try to remove both the plain and encrypted versions
  local plain_removed = os.remove(plainpath)
  local enc_removed = os.remove(encpath)
  
  -- Consider successful if we removed at least one file
  local success = plain_removed or enc_removed
  
  -- If this was the current conversation, clear it
  if current_conversation and current_conversation.id == conversation_id then
    current_conversation = nil
  end
  
  if success then
    utils.log_debug('Deleted conversation: ' .. conversation_id)
  else
    utils.log_warning('Failed to delete conversation (file not found): ' .. conversation_id)
  end
  
  return success
end

function M.get_conversation_stats()
  local conv = M.get_current_conversation()
  return {
    message_count = #conv.messages,
    total_tokens = conv.metadata.total_tokens,
    total_cost = conv.metadata.total_cost,
    created_at = conv.created_at,
    updated_at = conv.updated_at
  }
end

-- Initialize random seed
math.randomseed(os.time())

return M
