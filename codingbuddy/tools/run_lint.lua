--[[
Linting Tool - Language-Aware Code Linters
==========================================

This module provides a run_lint tool that detects and runs appropriate
linters for different programming languages, presenting findings in a
structured format.

Supported Languages and Linters:
- Python: flake8, ruff
- Lua: luacheck
- JavaScript/TypeScript: eslint

All linting operations occur in sandbox context and respect terminal policy.

Author: CodingBuddy Development Team
License: MIT
--]]

local path = require('tools.path')
local fs = require('tools.fs')
local terminal = require('tools.terminal')
local json = require('json')

local M = {}

-- Get file extension from path
local function get_file_extension(file_path)
  return file_path:match('%.([^%.]+)$')
end

-- Detect language from file extension
local function detect_language(file_path)
  local ext = get_file_extension(file_path)
  if not ext then
    return nil, 'Unable to determine language: no file extension'
  end
  
  if ext == 'py' then
    return 'python'
  elseif ext == 'lua' then
    return 'lua'
  elseif ext == 'js' then
    return 'javascript'
  elseif ext == 'ts' or ext == 'tsx' then
    return 'typescript'
  else
    return nil, 'Unsupported file extension: ' .. ext
  end
end

-- Get available linters for a language
local function get_linters_for_language(language)
  local linters = {
    python = {
      { cmd = 'ruff', args = 'check --output-format=json' },
      { cmd = 'flake8', args = '--format=json' }
    },
    lua = {
      { cmd = 'luacheck', args = '--formatter=json' }
    },
    javascript = {
      { cmd = 'eslint', args = '--format=json' }
    },
    typescript = {
      { cmd = 'eslint', args = '--format=json' }
    }
  }
  
  return linters[language]
end

-- Check if a command is available in the system
local function is_command_available(cmd)
  local check_cmd = 'which ' .. cmd .. ' > /dev/null 2>&1'
  local result = terminal.run_command(check_cmd)
  return result and result.exit_code == 0
end

-- Find the first available linter for a language
local function find_available_linter(language, preferred)
  local linters = get_linters_for_language(language)
  if not linters then
    return nil, 'No linters configured for language: ' .. language
  end
  
  -- If preferred linter is specified, check if it's available
  if preferred then
    for _, linter in ipairs(linters) do
      if linter.cmd == preferred then
        if is_command_available(linter.cmd) then
          return linter
        else
          return nil, 'Requested linter not available: ' .. preferred
        end
      end
    end
    return nil, 'Requested linter not supported for ' .. language .. ': ' .. preferred
  end
  
  -- Find first available linter
  for _, linter in ipairs(linters) do
    if is_command_available(linter.cmd) then
      return linter
    end
  end
  
  -- No linters available
  local available_names = {}
  for _, linter in ipairs(linters) do
    table.insert(available_names, linter.cmd)
  end
  
  return nil, 'No linters available for ' .. language .. '. Install one of: ' .. 
    table.concat(available_names, ', ')
end

-- Parse JSON linter output into structured findings
local function parse_json_output(json_data, language, linter)
  local findings = {}
  
  if language == 'python' and linter == 'ruff' then
    for _, item in ipairs(json_data) do
      table.insert(findings, {
        file = item.filename,
        line = item.location and item.location.row,
        column = item.location and item.location.column,
        severity = item.code and (item.code:match('^E') and 'error' or 'warning') or 'warning',
        message = item.message,
        rule = item.code
      })
    end
  elseif language == 'python' and linter == 'flake8' then
    for filename, items in pairs(json_data) do
      for _, item in ipairs(items) do
        table.insert(findings, {
          file = filename,
          line = item.line_number,
          column = item.column_number,
          severity = item.code and (item.code:match('^E') and 'error' or 'warning') or 'warning',
          message = item.text,
          rule = item.code
        })
      end
    end
  elseif language == 'lua' and linter == 'luacheck' then
    for _, file_data in ipairs(json_data) do
      if file_data.events then
        for _, event in ipairs(file_data.events) do
          table.insert(findings, {
            file = file_data.filename,
            line = event.line,
            column = event.column,
            severity = event.code and (event.code:match('^0') and 'error' or 'warning') or 'warning',
            message = event.msg,
            rule = event.code
          })
        end
      end
    end
  elseif (language == 'javascript' or language == 'typescript') and linter == 'eslint' then
    for _, file_data in ipairs(json_data) do
      if file_data.messages then
        for _, msg in ipairs(file_data.messages) do
          table.insert(findings, {
            file = file_data.filePath,
            line = msg.line,
            column = msg.column,
            severity = msg.severity == 2 and 'error' or 'warning',
            message = msg.message,
            rule = msg.ruleId
          })
        end
      end
    end
  end
  
  return findings
end

-- Parse plain text linter output
local function parse_text_output(output_text)
  local findings = {}
  
  for line in output_text:gmatch('[^\n]+') do
    -- Basic pattern matching for common formats (file:line:col: message)
    local file, line_no, col, msg = line:match('([^:]+):(%d+):(%d*):?%s*(.+)')
    if file and line_no and msg then
      table.insert(findings, {
        file = file,
        line = tonumber(line_no),
        column = col and tonumber(col) or nil,
        severity = 'warning',
        message = msg:gsub('^%s+', ''):gsub('%s+$', ''),
        rule = nil
      })
    end
  end
  
  return findings
end

-- Main linting function
function M.run_lint(rel_path, language, preferred_linter)
  -- Validate and resolve path
  local abs_path, err = path.to_abs(rel_path)
  if not abs_path then 
    return { error = 'Path resolution failed: ' .. (err or 'unknown error') }
  end
  
  -- Ensure path is within sandbox boundaries
  local ok, err2 = path.ensure_in_sandbox(abs_path)
  if not ok then 
    return { error = 'Sandbox violation: ' .. (err2 or 'path outside sandbox') }
  end
  
  -- Check if path exists
  if not fs.exists(abs_path) then
    return { error = 'Path does not exist: ' .. abs_path }
  end
  
  -- Determine language if not provided
  if not language then
    language, err = detect_language(abs_path)
    if not language then
      return { error = err }
    end
  end
  
  -- Find appropriate linter
  local linter, err3 = find_available_linter(language, preferred_linter)
  if not linter then
    return { error = err3 }
  end
  
  -- Execute linter
  local lint_cmd = linter.cmd .. ' ' .. linter.args .. ' "' .. abs_path .. '"'
  local result = terminal.run_command(lint_cmd)
  
  if not result then
    return { error = 'Linter execution failed' }
  end
  
  -- Parse output
  local findings = {}
  local raw_output = result.stdout or ''
  
  -- Try to parse JSON output first
  local success, parsed = pcall(function()
    return json.decode(raw_output)
  end)
  
  if success and parsed then
    findings = parse_json_output(parsed, language, linter.cmd)
  else
    -- Fall back to parsing plain text output
    findings = parse_text_output(raw_output)
  end
  
  -- Return structured results
  return {
    linter_used = linter.cmd,
    language = language,
    target_path = abs_path,
    findings_count = #findings,
    findings = findings,
    exit_code = result.exit_code,
    raw_output = raw_output
  }
end

-- Register the tool handler
function M.register(registry)
  registry.run_lint = {
    description = 'Run language-specific linters on files with structured output',
    input_schema = {
      type = 'object',
      properties = {
        rel_path = {
          type = 'string',
          description = 'Relative path to file or directory to lint'
        },
        language = {
          type = 'string',
          description = 'Override language detection (python, lua, javascript, typescript)',
          enum = { 'python', 'lua', 'javascript', 'typescript' }
        },
        linter = {
          type = 'string',
          description = 'Specific linter to use (overrides default for language)'
        }
      },
      required = { 'rel_path' }
    },
    handler = function(args)
      return M.run_lint(args.rel_path, args.language, args.linter)
    end
  }
end

return M
