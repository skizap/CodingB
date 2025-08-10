-- ai_connector.lua - OpenRouter client (Phase 1)
-- Requires: lua-socket; HTTPS recommended (luasec). If luasec is unavailable,
-- you can proxy via HTTP locally or accept insecure http to a local gateway.

local config = require('codingbuddy.config')
local utils = require('codingbuddy.utils')
-- local dialogs = require('codingbuddy.dialogs')  -- not used here

-- Phase 2 additions: multi-provider and fallback
-- Public API:
--   M.chat({ prompt=..., model=?, provider=? })
--   Uses config.get() for provider, fallback_chain, and API keys.

local M = {}

local has_https, https = pcall(require, 'ssl.https')
local has_http, http = pcall(require, 'socket.http')
local _, ltn12 = pcall(require, 'ltn12')

-- Minimal JSON fallback and helpers (unused helper removed to satisfy lints)



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

  local payload = {
    model = model,
    messages = {
      { role = 'system', content = 'You are a helpful coding assistant that produces concise, actionable analysis.' },
      { role = 'user', content = opts.prompt or '' },
    }
  }

  -- JSON encode with fallbacks (cjson, dkjson, pure lua module)
  local json_encode
  do
    local ok, cjson = pcall(require, 'cjson')
    if ok and cjson then
      json_encode = cjson.encode
    else
      local ok2, dkjson = pcall(require, 'dkjson')
      if ok2 and dkjson then
        json_encode = function(x) return dkjson.encode(x) end
      else
        local ok3, pj = pcall(require, 'codingbuddy.json')
        if ok3 and pj then
          json_encode = pj.encode
        else
          error('No JSON encoder available')
        end
      end
    end
  end


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
    if p == 'anthropic' then
      local m = opts.model or cfg.provider_models.anthropic
      return { model = m, max_tokens = 1024, messages = {
        { role = 'user', content = opts.prompt or '' }
      }}
    else
      local m = opts.model or cfg.provider_models[p] or cfg.task_models.analysis
      return { model = m, messages = {
        { role = 'system', content = 'You are a helpful coding assistant that produces concise, actionable analysis.' },
        { role = 'user', content = opts.prompt or '' },
      }}
    end
  end -- build_payload

  local function extract_usage(p, obj)
    -- Normalize usage to {prompt_tokens=?, completion_tokens=?, total_tokens=?}
    if not obj then return nil end
    local u = obj.usage or obj.usage_info
    if p == 'anthropic' then
      local inp = (u and (u.input_tokens or u.prompt_tokens)) or obj.input_tokens
      local outp = (u and (u.output_tokens or u.completion_tokens)) or obj.output_tokens
      local tot = (u and u.total_tokens) or ((inp or 0) + (outp or 0))
      return { prompt_tokens = inp, completion_tokens = outp, total_tokens = tot }
    else
      local inp = u and (u.prompt_tokens or u.input_tokens)
      local outp = u and (u.completion_tokens or u.output_tokens)
      local tot = u and (u.total_tokens or ((inp or 0) + (outp or 0)))
      return u and { prompt_tokens = inp, completion_tokens = outp, total_tokens = tot } or nil
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

  local function extract_text(p, obj)
    if p == 'anthropic' then
      local c = obj and obj.content and obj.content[1]
      return c and (c.text or c.content or c.value)
    else
      return obj and obj.choices and obj.choices[1] and obj.choices[1].message and obj.choices[1].message.content
    end
  end

  local function try_provider(p)
    local url, headers = build_url_and_headers(p)
    if (p == 'openrouter' and not cfg.openrouter_api_key) or (p == 'openai' and not cfg.openai_api_key) or (p == 'anthropic' and not cfg.anthropic_api_key) then
      return nil, 'Missing API key for '..p
    end

    local payload = build_payload(p)

    -- JSON encode
    local encoder
    do
      local ok, cjson = pcall(require, 'cjson'); if ok and cjson then encoder = cjson.encode end
      if not encoder then local ok2, dkjson = pcall(require, 'dkjson'); if ok2 and dkjson then encoder = function(x) return dkjson.encode(x) end end end
      if not encoder then encoder = function(x)
        -- fallback: reuse minimal encoder from above block (implement minimal here)
        local function esc(s) s=s:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t'); return '"'..s..'"' end
        local function is_array(t) local n=0 for k,_ in pairs(t) do if type(k)~='number' then return false end n=n+1 end for i=1,n do if t[i]==nil then return false end end return true end
        local function enc(v) local t=type(v); if t=='nil' then return 'null' elseif t=='boolean' then return v and 'true' or 'false' elseif t=='number' then return tostring(v) elseif t=='string' then return esc(v) elseif t=='table' then if is_array(v) then local parts={} for i=1,#v do parts[#parts+1]=enc(v[i]) end return '['..table.concat(parts,',')..']' else local parts={} for k,val in pairs(v) do parts[#parts+1]=esc(tostring(k))..':'..enc(val) end return '{'..table.concat(parts,',')..'}' end else return esc(tostring(v)) end end
        return enc(x)
      end end
    end

    local body = encoder(payload)
    local data, code, status = request(url, 'POST', headers, body)
    if tonumber(code) ~= 200 then return nil, 'HTTP '..tostring(code)..' '..tostring(status) end

    -- decode
    local decoder
    do
      local ok, cjson = pcall(require, 'cjson'); if ok and cjson then decoder = cjson.decode end
      if not decoder then local ok2, dkjson = pcall(require, 'dkjson'); if ok2 and dkjson then decoder = function(str) return dkjson.decode(str) end end end
      if not decoder then local ok3, pj = pcall(require, 'codingbuddy.json'); if ok3 and pj then decoder = pj.decode else decoder = function(_) return {} end end end
    end
    local obj = decoder(data)
    local text = extract_text(p, obj)
    local usage = extract_usage(p, obj)
    local cost = estimate_cost(p, usage)
    log_usage(p, (payload and payload.model) or opts.model, usage, cost)
    if not text then return nil, 'Empty response' end
    return text
  end

  -- Try requested provider then fallbacks
  local chain = {}
  if cfg.fallback_chain and #cfg.fallback_chain > 0 then
    for i=1,#cfg.fallback_chain do chain[#chain+1] = cfg.fallback_chain[i] end
  else
    chain = { 'openrouter', 'openai', 'anthropic' }
  end
  table.insert(chain, 1, provider)
  -- de-dup
  local seen, ordered = {}, {}
  for _,p in ipairs(chain) do if not seen[p] then seen[p]=true; ordered[#ordered+1]=p end end

  local last_err
  for _,p in ipairs(ordered) do
    local text, err = try_provider(p)
    if text then return text end
    last_err = err
  end
  return nil, last_err or 'All providers failed'

end

return M

