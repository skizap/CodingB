-- test_cli.lua - run CodingBuddy analyzer outside Geany
-- Usage examples:
--   OPENROUTER_API_KEY=... lua codingbuddy/test_cli.lua path/to/file.lua
--   OPENAI_API_KEY=... ANTHROPIC_API_KEY=... lua codingbuddy/test_cli.lua path/to/file.py provider=openai model=gpt-4o-mini

package.path = 'codingbuddy/?.lua;codingbuddy/?/init.lua;'..package.path

local analyzer = require('codingbuddy.analyzer')
local cfg = require('codingbuddy.config').get()

local args = {...}
local target = args[1]
if not target then
  io.stderr:write('Usage: lua codingbuddy/test_cli.lua <file> [provider=<name>] [model=<id>]\n')
  os.exit(1)
end

local provider, model
for i=2,#args do
  local k,v = args[i]:match('^([%w_]+)=(.+)$')
  if k == 'provider' then provider = v end
  if k == 'model' then model = v end
end

-- if provider/model specified, override task model for this run
if provider then cfg.provider = provider end
if model then
  cfg.task_models = cfg.task_models or {}
  cfg.task_models.analysis = model
end

local f = io.open(target,'r'); if not f then error('cannot open file: '..target) end
local code = f:read('*a'); f:close()

local res = analyzer.analyze_code{ filename = target, code = code }
if not res.ok then
  print('ERROR:', res.error)
  os.exit(1)
end
print(res.message)

