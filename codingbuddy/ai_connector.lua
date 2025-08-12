-- ai_connector.lua - OpenRouter client (Phase 1)
-- Requires: lua-socket; HTTPS recommended (luasec). If luasec is unavailable,
-- you can proxy via HTTP locally or accept insecure http to a local gateway.

local config = require('config')
local utils = require('utils')
-- local dialogs = require('dialogs')  -- not used here

-- Tool registry access (lazy loaded)
local tool_registry_mod = nil
local function get_tool_registry()
  if not tool_registry_mod then
    tool_registry_mod = require('tools.registry')
  end
  return tool_registry_mod.get_registry()
end

-- Phase 2 additions: multi-provider and fallback
-- Phase 3 additions: chat interface support with conversation context
-- Public API:
--   M.chat({ prompt=..., model=?, provider=? })
--   M.chat({ messages=..., system=..., provider=? })  -- Chat interface support
--   Uses config.get() for provider, fallback_chain, and API keys.

local M = {}

local has_https, https = pcall(require, 'ssl.https')
local has_http, http = pcall(require, 'socket.http')
local _, ltn12 = pcall(require, 'ltn12')

-- Safe JSON encoder and decoder selection
local function get_json_encoder()
  -- Try cjson first (fastest)
  local ok, cjson = pcall(require, 'cjson')
  if ok and cjson and cjson.encode then
    return cjson.encode
  end
  
  -- Try dkjson next (most compatible)
  local ok2, dkjson = pcall(require, 'dkjson')
  if ok2 and dkjson and dkjson.encode then
    return function(x) return dkjson.encode(x) end
  end
  
  -- Try our bundled JSON module
  local ok3, pj = pcall(require, 'codingbuddy.json')
  if ok3 and pj and pj.encode then
    return pj.encode
  end
  
  error('No JSON encoder available. Please install dkjson: sudo luarocks install dkjson')
end

local function get_json_decoder()
  -- Try cjson first (fastest)
  local ok, cjson = pcall(require, 'cjson')
  if ok and cjson and cjson.decode then
    return cjson.decode
  end
  
  -- Try dkjson next (most compatible)
  local ok2, dkjson = pcall(require, 'dkjson')
  if ok2 and dkjson and dkjson.decode then
    return function(str) return dkjson.decode(str) end
  end
  
  -- Try our bundled JSON module
  local ok3, pj = pcall(require, 'codingbuddy.json')
  if ok3 and pj and pj.decode then
    return pj.decode
  end
  
  error('No JSON decoder available. Please install dkjson: sudo luarocks install dkjson')
end

local function request(url, method, headers, body)
  method = method or 'POST'
  headers = headers or {}
  local resp = {}

  if has_https then
    headers['content-length'] = tostring(#(body or ''))
    local _, code, _, status = https.request{
      url = url,
      method = method,
      headers = headers,
      source = body and ltn12.source.string(body) or nil,
      sink = ltn12.sink.table(resp),
      protocol = 'any',
      options = 'all',
    }
    return table.concat(resp), code or 0, status
  elseif has_http then
    -- not ideal: OpenRouter requires HTTPS; this will fail publicly
    headers['content-length'] = tostring(#(body or ''))
    local _, code, _, status = http.request{
      url = url,
      method = method,
      headers = headers,
      source = body and ltn12.source.string(body) or nil,
      sink = ltn12.sink.table(resp),
    }
    return table.concat(resp), code or 0, status
  else
    return nil, 0, 'No HTTP client available (socket/http or ssl/https)'
  end
end

function M.chat(opts)
  -- opts: { model, prompt }
  local cfg = config.get()
  local api_key = cfg.openrouter_api_key
  if not api_key then
    return nil, 'Missing OpenRouter API key'
  end

  local model = opts.model or cfg.task_models.analysis or 'anthropic/claude-3.5-sonnet'
  local url = 'https://openrouter.ai/api/v1/chat/completions'

  -- Get JSON encoder once at the start
  local json_encode = get_json_encoder()


  -- Support provider override and fallback chain (simple)
  local provider = opts.provider or cfg.provider or 'openrouter'
  local function build_url_and_headers(p)
    if p == 'openrouter' then
      return 'https://openrouter.ai/api/v1/chat/completions', {
        ['Content-Type'] = 'application/json',
        ['Authorization'] = 'Bearer '..(cfg.openrouter_api_key or ''),
        ['HTTP-Referer'] = 'https://github.com/skizap/CodingBuddy',
        ['X-Title'] = 'CodingBuddy Geany Plugin'
      }
    elseif p == 'openai' then
      return 'https://api.openai.com/v1/chat/completions', {
        ['Content-Type'] = 'application/json',
        ['Authorization'] = 'Bearer '..(cfg.openai_api_key or '')
      }
    elseif p == 'anthropic' then
      return 'https://api.anthropic.com/v1/messages', {
        ['Content-Type'] = 'application/json',
        ['x-api-key'] = (cfg.anthropic_api_key or ''),
        ['anthropic-version'] = '2023-06-01'
      }
    elseif p == 'deepseek' then
      return 'https://api.deepseek.com/v1/chat/completions', {
        ['Content-Type'] = 'application/json',
        ['Authorization'] = 'Bearer '..(cfg.deepseek_api_key or '')
      }
    end
  end

  local function build_payload(p)
    local default_system = 'You are a helpful coding assistant that produces concise, actionable analysis.'
    
    -- OpenRouter provider handling - pass through to underlying model
    local actual_provider = p
    local model_override = nil
    
    if p == 'openrouter' and opts.model then
      -- OpenRouter uses model names like "anthropic/claude-3.5-sonnet" or "openai/gpt-4o"
      if opts.model:match('^anthropic/') then
        actual_provider = 'anthropic'
        model_override = opts.model:gsub('^anthropic/', '')
      elseif opts.model:match('^openai/') then
        actual_provider = 'openai' 
        model_override = opts.model:gsub('^openai/', '')
      else
        -- Generic OpenRouter model, use OpenAI-compatible format
        actual_provider = 'openai'
      end
    end
    
    if actual_provider == 'anthropic' then
      local m = model_override or opts.model or cfg.provider_models.anthropic
      local sys = (opts.system ~= nil) and opts.system or default_system
      local pl = {
        model = m,
        max_tokens = opts.max_tokens or 1024,
        messages = opts.messages or {
          { role = 'user', content = opts.prompt or '' }
        },
      }

      -- Anthropic system prompt: string, content array, or content blocks
      if type(sys) == 'string' then
        pl.system = sys
      elseif type(sys) == 'table' then
        -- Check if it's an array of content blocks or a simple array
        if sys[1] and type(sys[1]) == 'table' and sys[1].type then
          -- Array of content blocks: [{ type = "text", text = "..." }, ...]
          pl.system = sys
        elseif sys[1] and type(sys[1]) == 'string' then
          -- Simple string array, convert to content blocks
          local content_blocks = {}
          for i = 1, #sys do
            if type(sys[i]) == 'string' then
              table.insert(content_blocks, { type = 'text', text = sys[i] })
            end
          end
          pl.system = content_blocks
        else
          -- Assume it's already properly formatted content blocks
          pl.system = sys
        end
      end

      -- Convert registry to Anthropic tool format
      if opts.tools and type(opts.tools) == 'table' then
        local tools = {}
        for name, def in pairs(opts.tools) do
          tools[#tools+1] = {
            name = name,
            description = def.description,
            input_schema = def.input_schema
          }
        end
        pl.tools = tools
        if opts.tool_choice then pl.tool_choice = opts.tool_choice end
      end
      return pl
    else
      -- OpenAI-compatible format (includes OpenRouter and direct OpenAI)
      local m = model_override or opts.model or cfg.provider_models[p] or cfg.task_models.analysis
      local sys = (opts.system ~= nil) and opts.system or default_system
      -- For non-Anthropic providers, convert arrays to concatenated string
      if type(sys) == 'table' then
        if sys[1] and type(sys[1]) == 'table' and sys[1].text then
          -- Content blocks format, extract text
          local parts = {}
          for i = 1, #sys do
            if sys[i].text then table.insert(parts, sys[i].text) end
          end
          sys = table.concat(parts, '\n\n')
        elseif sys[1] and type(sys[1]) == 'string' then
          -- Simple string array
          sys = table.concat(sys, '\n\n')
        end
      end
      local messages = opts.messages or {
        { role = 'user', content = opts.prompt or '' }
      }

      -- Add system message if not already present and we have a system prompt
      if sys and sys ~= '' then
        local has_system = false
        for _, msg in ipairs(messages) do
          if msg.role == 'system' then
            has_system = true
            break
          end
        end
        if not has_system then
          table.insert(messages, 1, { role = 'system', content = sys })
        end
      end

      local payload = { model = m, messages = messages }
      
      -- Convert registry to OpenAI tool format for non-Anthropic providers
      if opts.tools and type(opts.tools) == 'table' then
        local tools = {}
        for name, def in pairs(opts.tools) do
          tools[#tools+1] = {
            type = 'function',
            ['function'] = {
              name = name,
              description = def.description,
              parameters = def.input_schema
            }
          }
        end
        payload.tools = tools
        if opts.tool_choice then payload.tool_choice = opts.tool_choice end
      end
      
      return payload
    end
  end -- build_payload

  local function extract_usage(p, obj, actual_provider)
    -- Normalize usage to {prompt_tokens=?, completion_tokens=?, total_tokens=?}
    if not obj then return nil end
    
    local u = obj.usage or obj.usage_info
    local usage_provider = actual_provider or p
    
    -- Handle OpenRouter's passthrough usage format
    if p == 'openrouter' then
      if u then
        -- Standard OpenAI-compatible format from OpenRouter
        local inp = u.prompt_tokens or u.input_tokens or 0
        local outp = u.completion_tokens or u.output_tokens or 0
        local tot = u.total_tokens or (inp + outp)
        return { prompt_tokens = inp, completion_tokens = outp, total_tokens = tot }
      else
        -- No usage data available
        return nil
      end
    elseif usage_provider == 'anthropic' or p == 'anthropic' then
      -- Anthropic format: input_tokens and output_tokens
      local inp = (u and (u.input_tokens or u.prompt_tokens)) or obj.input_tokens or 0
      local outp = (u and (u.output_tokens or u.completion_tokens)) or obj.output_tokens or 0
      local tot = (u and u.total_tokens) or (inp + outp)
      return { prompt_tokens = inp, completion_tokens = outp, total_tokens = tot }
    else
      -- OpenAI format: prompt_tokens and completion_tokens
      if u then
        local inp = u.prompt_tokens or u.input_tokens or 0
        local outp = u.completion_tokens or u.output_tokens or 0
        local tot = u.total_tokens or (inp + outp)
        return { prompt_tokens = inp, completion_tokens = outp, total_tokens = tot }
      else
        return nil
      end
    end
  end

  local function estimate_cost(p, usage)
    local prices = cfg.cost and cfg.cost.prices_per_1k and cfg.cost.prices_per_1k[p]
    if not prices or not usage then return nil end
    local pi = prices.default_input or 0
    local po = prices.default_output or 0
    local cost = ((usage.prompt_tokens or 0)/1000)*pi + ((usage.completion_tokens or 0)/1000)*po
    return cost
  end

  local function log_usage(p, model, usage, cost)
    if not (cfg.log_enabled and usage) then return end
    local entry = {
      timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
      provider = p,
      model = model,
      usage = usage,
      cost = cost,
      currency = (cfg.cost and cfg.cost.currency) or 'USD'
    }
    local ok, dkjson = pcall(require, 'dkjson')
    local line
    if ok and dkjson then
      line = dkjson.encode(entry)
    else
      line = string.format('{"timestamp":"%s","provider":"%s","model":"%s","prompt_tokens":%d,"completion_tokens":%d,"total_tokens":%d,"cost":%.6f}',
        entry.timestamp, p, tostring(model), usage.prompt_tokens or 0, usage.completion_tokens or 0, usage.total_tokens or 0, cost or 0)
    end
    local home = os.getenv('HOME') or '.'
    local log_path = home..'/.config/geany/plugins/geanylua/codingbuddy/logs/usage.jsonl'
    local f = io.open(log_path, 'a')
    if f then f:write(line..'\n'); f:close() end
  end

  -- Extract structured response with text and tool calls
  local function extract_response(p, obj)
    if p == 'anthropic' then
      local content = obj and obj.content
      local result = { text = nil, tool_calls = {}, raw_content = content }

      if type(content) == 'table' then
        for i = 1, #content do
          local block = content[i]
          if type(block) == 'table' then
            if block.type == 'text' and type(block.text) == 'string' then
              if not result.text then result.text = block.text end
            elseif block.type == 'tool_use' then
              local tool_call = {
                id = block.id,
                name = block.name,
                input = block.input
              }
              table.insert(result.tool_calls, tool_call)
            end
          end
        end
      end

      return result
    else
      -- OpenAI/OpenRouter format
      local message = obj and obj.choices and obj.choices[1] and obj.choices[1].message
      local result = { text = nil, tool_calls = {}, raw_content = message }

      if message then
        result.text = message.content
        if message.tool_calls and type(message.tool_calls) == 'table' then
          for i = 1, #message.tool_calls do
            local tc = message.tool_calls[i]
            if tc['function'] then
              local tool_call = {
                id = tc.id,
                name = tc['function'].name,
                input = tc['function'].arguments -- Note: this might be a JSON string
              }
              table.insert(result.tool_calls, tool_call)
            end
          end
        end
      end

      return result
    end
  end

  -- Backward compatible text extraction (for existing call sites)
  local function extract_text(p, obj)
    local response = extract_response(p, obj)
    return response and response.text
  end

  -- Execute tool calls using the registry handlers
  local function execute_tools(tool_calls, registry)
    local results = {}
    for i = 1, #tool_calls do
      local call = tool_calls[i]
      local handler = registry[call.name] and registry[call.name].handler
      if handler then
        local ok, res = pcall(handler, call.input or {})
        if ok then
          results[#results+1] = { tool_use_id = call.id, type = 'tool_result', content = res }
        else
          results[#results+1] = { tool_use_id = call.id, type = 'tool_result', content = { error = tostring(res) }, is_error = true }
        end
      else
        results[#results+1] = { tool_use_id = call.id, type = 'tool_result', content = { error = 'tool not found: ' .. tostring(call.name) }, is_error = true }
      end
    end
    return results
  end

  local function try_provider(p, conversation_messages)
    local url, headers = build_url_and_headers(p)
    if (p == 'openrouter' and not cfg.openrouter_api_key) or (p == 'openai' and not cfg.openai_api_key) or (p == 'anthropic' and not cfg.anthropic_api_key) then
      return nil, 'Missing API key for '..p
    end

    local payload = build_payload(p)
    
    -- Track actual provider for OpenRouter models
    local actual_provider = p
    if p == 'openrouter' and opts.model then
      if opts.model:match('^anthropic/') then
        actual_provider = 'anthropic'
      elseif opts.model:match('^openai/') then
        actual_provider = 'openai'
      end
    end

    -- If we have conversation messages (for tool execution), replace the messages
    if conversation_messages and type(conversation_messages) == 'table' then
      payload.messages = conversation_messages
    end

    -- Get JSON encoder and decoder
    local encoder = get_json_encoder()
    local decoder = get_json_decoder()

    local body = encoder(payload)
    local data, code, status = request(url, 'POST', headers, body)
    if tonumber(code) ~= 200 then return nil, 'HTTP '..tostring(code)..' '..tostring(status) end

    -- decode response
    local obj = decoder(data)

    -- Return structured response for tool handling
    local response = extract_response(actual_provider, obj)
    local usage = extract_usage(p, obj, actual_provider)
    local cost = estimate_cost(p, usage)
    local model_used = (payload and payload.model) or opts.model
    
    log_usage(p, model_used, usage, cost)

    if not response.text and #response.tool_calls == 0 then
      return nil, 'Empty response'
    end

    return response, usage, cost, model_used, p
  end

  -- Build deterministic provider chain respecting config fallback_chain
  local chain = {}
  
  -- Start with explicitly requested provider if not already in config chain
  local config_chain = cfg.fallback_chain or { 'openrouter', 'openai', 'anthropic', 'deepseek' }
  local provider_in_config = false
  for _, p in ipairs(config_chain) do
    if p == provider then
      provider_in_config = true
      break
    end
  end
  
  -- If provider not in config chain, try it first
  if not provider_in_config then
    chain[1] = provider
  end
  
  -- Add config fallback chain, maintaining order and uniqueness
  local seen = {}
  if not provider_in_config then
    seen[provider] = true
  end
  
  for _, p in ipairs(config_chain) do
    if not seen[p] then
      seen[p] = true
      chain[#chain + 1] = p
    end
  end
  
  local ordered = chain

  local last_err
  for _,p in ipairs(ordered) do
    local response, usage, cost, model_used, provider_used = try_provider(p)
    if response then
      -- Check if we should execute tools automatically
      if opts.auto_execute_tools and opts.tool_registry and #response.tool_calls > 0 then
        -- Execute tools and continue conversation
        local tool_results = execute_tools(response.tool_calls, opts.tool_registry)

        if #tool_results > 0 then
          -- Build conversation messages for follow-up
          local conversation = {}

          -- Add original user message
          table.insert(conversation, { role = 'user', content = opts.prompt or '' })

          -- Add assistant response with tool calls
          if p == 'anthropic' then
            table.insert(conversation, { role = 'assistant', content = response.raw_content })
            -- Add tool results
            for i = 1, #tool_results do
              table.insert(conversation, { role = 'user', content = { tool_results[i] } })
            end
          else
            -- OpenAI format - add assistant message with tool calls, then tool results
            local assistant_msg = { role = 'assistant', content = response.text }
            if #response.tool_calls > 0 then
              assistant_msg.tool_calls = {}
              for i = 1, #response.tool_calls do
                local tc = response.tool_calls[i]
                table.insert(assistant_msg.tool_calls, {
                  id = tc.id,
                  type = 'function',
                  ['function'] = { name = tc.name, arguments = tc.input }
                })
              end
            end
            table.insert(conversation, assistant_msg)

            -- Add tool results as tool messages
            for i = 1, #tool_results do
              table.insert(conversation, {
                role = 'tool',
                tool_call_id = tool_results[i].tool_use_id,
                content = type(tool_results[i].content) == 'table' and
                         (tool_results[i].content.error or 'Tool executed') or
                         tostring(tool_results[i].content)
              })
            end
          end

          -- Make follow-up request
          local final_response, final_usage, final_cost, final_model, final_provider = try_provider(p, conversation)
          if final_response then
            -- Return final response, but preserve tool execution info
            if opts.return_structured then
              return {
                text = final_response.text,
                tool_calls = response.tool_calls,
                tool_results = tool_results,
                raw_content = final_response.raw_content,
                usage = final_usage,
                cost = final_cost,
                model = final_model or model_used,
                provider = final_provider or provider_used
              }
            else
              return final_response.text -- Backward compatible
            end
          else
            last_err = 'Tool execution follow-up failed'
          end
        end
      end

      -- No tool execution or tools disabled, return response
      if opts.return_structured then
        return {
          text = response.text,
          tool_calls = response.tool_calls,
          raw_content = response.raw_content,
          usage = usage,
          cost = cost,
          model = model_used,
          provider = provider_used
        }
      else
        return response.text -- Backward compatible
      end
    else
      last_err = usage or 'Provider failed'
    end
  end
  return nil, last_err or 'All providers failed'

end

return M

