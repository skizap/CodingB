-- ai_connector.lua - OpenRouter client (Phase 1)
-- Requires: lua-socket; HTTPS recommended (luasec). If luasec is unavailable,
-- you can proxy via HTTP locally or accept insecure http to a local gateway.

local config = require('codingbuddy.config')
local dialogs = require('codingbuddy.dialogs')

local M = {}

local has_https, https = pcall(require, 'ssl.https')
local has_http, http = pcall(require, 'socket.http')
local ltn12_ok, ltn12 = pcall(require, 'ltn12')

local function request(url, method, headers, body)
  method = method or 'POST'
  headers = headers or {}
  local resp = {}

  if has_https then
    headers['content-length'] = tostring(#(body or ''))
    local ok, code, resp_headers, status = https.request{
      url = url,
      method = method,
      headers = headers,
      source = body and ltn12.source.string(body) or nil,
      sink = ltn12.sink.table(resp),
      protocol = 'any',
      options = 'all',
    }
    return table.concat(resp), code or 0, resp_headers, status
  elseif has_http then
    -- not ideal: OpenRouter requires HTTPS; this will fail publicly
    headers['content-length'] = tostring(#(body or ''))
    local ok, code, resp_headers, status = http.request{
      url = url,
      method = method,
      headers = headers,
      source = body and ltn12.source.string(body) or nil,
      sink = ltn12.sink.table(resp),
    }
    return table.concat(resp), code or 0, resp_headers, status
  else
    return nil, 0, nil, 'No HTTP client available (socket/http or ssl/https)'
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

  local ok, cjson = pcall(require, 'cjson')
  local json_encode
  if ok and cjson then
    json_encode = cjson.encode
  else
    local ok2, dkjson = pcall(require, 'dkjson')
    if ok2 and dkjson then json_encode = function(x) return dkjson.encode(x) end end
  end
  if not json_encode then
    return nil, 'No JSON encoder (cjson or dkjson) available'
  end

  local body = json_encode(payload)
  local headers = {
    ['Content-Type'] = 'application/json',
    ['Authorization'] = 'Bearer '..api_key,
    ['HTTP-Referer'] = 'https://github.com/skizap/CodingBuddy',
    ['X-Title'] = 'CodingBuddy Geany Plugin'
  }

  local data, code, resp_headers, status = request(url, 'POST', headers, body)
  if tonumber(code) ~= 200 then
    return nil, 'HTTP '..tostring(code)..' '..tostring(status)..'\n'..tostring(data)
  end

  local okd, decoder = pcall(require, 'cjson')
  local decode
  if okd then decode = decoder.decode else
    local ok2, dkjson = pcall(require, 'dkjson')
    if ok2 then decode = dkjson.decode end
  end
  if not decode then return nil, 'No JSON decoder available' end

  local obj = decode(data)
  local text = obj and obj.choices and obj.choices[1] and obj.choices[1].message and obj.choices[1].message.content or nil
  if not text then return nil, 'Empty response' end
  return text
end

return M

