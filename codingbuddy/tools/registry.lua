--[[
Tool Registry - Provider-Agnostic Tool Definitions
==================================================

This module provides a centralized registry of tools with schema definitions that can be 
converted to provider-specific formats (Anthropic, OpenAI, etc.) by the ai_connector.

The registry uses Lua tables to describe tools with:
- description: Human-readable description of the tool's purpose
- input_schema: JSON Schema-compatible definition of required parameters
- handler: Function that executes the tool and returns results

All tools operate within sandbox constraints for security and isolation.

Author: CodingBuddy Development Team
License: MIT
--]]

local path = require('tools.path')
local fs = require('tools.fs')
local terminal = require('tools.terminal')
local editor = require('tools.editor')
local run_lint = require('tools.run_lint')
-- local patch = require('tools.patch') -- TODO: Implement patch module

local M = {}

-- Tool registry with schema definitions and handlers
-- Each tool follows a consistent pattern for provider conversion
M.registry = {
  
  -- File system operations
  read_file = {
    description = 'Read a text file from the sandbox',
    input_schema = {
      type = 'object',
      properties = {
        rel_path = {
          type = 'string',
          description = 'Relative path to the file within the sandbox'
        }
      },
      required = { 'rel_path' }
    },
    handler = function(args)
      -- Validate and resolve path
      local abs, err = path.to_abs(args.rel_path)
      if not abs then 
        return { error = 'Path resolution failed: ' .. (err or 'unknown error') }
      end
      
      -- Ensure path is within sandbox boundaries
      local ok, err2 = path.ensure_in_sandbox(abs)
      if not ok then 
        return { error = 'Sandbox violation: ' .. (err2 or 'path outside sandbox') }
      end
      
      -- Attempt to read file
      local data, rerr = fs.read_file(abs)
      if not data then 
        return { error = 'File read failed: ' .. (rerr or 'unknown error') }
      end
      
      return { content = data }
    end
  },

  write_file = {
    description = 'Write a text file atomically to the sandbox',
    input_schema = {
      type = 'object',
      properties = {
        rel_path = {
          type = 'string',
          description = 'Relative path where the file should be written'
        },
        content = {
          type = 'string',
          description = 'Text content to write to the file'
        },
        create_dirs = {
          type = 'boolean',
          description = 'Whether to create parent directories if they don\'t exist',
          default = false
        }
      },
      required = { 'rel_path', 'content' }
    },
    handler = function(args)
      -- Validate and resolve path
      local abs, err = path.to_abs(args.rel_path)
      if not abs then 
        return { error = 'Path resolution failed: ' .. (err or 'unknown error') }
      end
      
      -- Ensure path is within sandbox boundaries
      local ok, err2 = path.ensure_in_sandbox(abs)
      if not ok then 
        return { error = 'Sandbox violation: ' .. (err2 or 'path outside sandbox') }
      end
      
      -- Create parent directories if requested
      if args.create_dirs then
        local mkdir_ok, mkdir_err = fs.mkdir_p_for_file(abs)
        if not mkdir_ok then
          return { error = 'Directory creation failed: ' .. (mkdir_err or 'unknown error') }
        end
      end
      
      -- Perform atomic write operation
      local ok2, werr = fs.write_file_atomic(abs, args.content)
      if not ok2 then 
        return { error = 'File write failed: ' .. (werr or 'unknown error') }
      end
      
      return { ok = true, path = abs }
    end
  },

  list_dir = {
    description = 'List files and directories under a given sandbox path',
    input_schema = {
      type = 'object',
      properties = {
        rel_path = {
          type = 'string',
          description = 'Relative path to the directory to list'
        }
      },
      required = { 'rel_path' }
    },
    handler = function(args)
      -- Validate and resolve path
      local abs, err = path.to_abs(args.rel_path)
      if not abs then 
        return { error = 'Path resolution failed: ' .. (err or 'unknown error') }
      end
      
      -- Ensure path is within sandbox boundaries
      local ok, err2 = path.ensure_in_sandbox(abs)
      if not ok then 
        return { error = 'Sandbox violation: ' .. (err2 or 'path outside sandbox') }
      end
      
      -- List directory contents
      local items, lerr = fs.list_dir(abs)
      if not items then 
        return { error = 'Directory listing failed: ' .. (lerr or 'unknown error') }
      end
      
      return { entries = items }
    end
  },

  search_code = {
    description = 'Search for code patterns in the sandbox using ripgrep',
    input_schema = {
      type = 'object',
      properties = {
        query = {
          type = 'string',
          description = 'Search query pattern to find in files'
        }
      },
      required = { 'query' }
    },
    handler = function(args)
      -- Get the sandbox root path
      local root_abs, err = path.to_abs('.')
      if not root_abs then 
        return { error = 'Failed to get sandbox root: ' .. (err or 'unknown error') }
      end
      
      -- Ensure the root is within sandbox boundaries
      local ok, err2 = path.ensure_in_sandbox(root_abs)
      if not ok then 
        return { error = 'Sandbox violation: ' .. (err2 or 'path outside sandbox') }
      end
      
      -- Perform the search
      local results, serr = fs.search(root_abs, args.query)
      if not results then 
        return { error = 'Search failed: ' .. (serr or 'unknown error') }
      end
      
      return { results = results, query = args.query, searched_path = root_abs }
    end
  },

  -- Terminal operations
  run_command = {
    description = 'Run a terminal command in the sandbox working directory',
    input_schema = {
      type = 'object',
      properties = {
        cmd = {
          type = 'string',
          description = 'Command to execute in the terminal'
        },
        cwd_rel = {
          type = 'string',
          description = 'Optional relative working directory for command execution'
        }
      },
      required = { 'cmd' }
    },
    handler = function(args)
      -- Delegate to terminal module with proper error handling
      local result = terminal.run_command(args.cmd, args.cwd_rel)
      
      -- Ensure consistent return format
      if not result then
        return { error = 'Command execution failed: no result returned' }
      end
      
      return result
    end
  },

  -- Editor operations
  open_in_editor = {
    description = 'Open a file in the active Geany editor buffer',
    input_schema = {
      type = 'object',
      properties = {
        rel_path = {
          type = 'string',
          description = 'Relative path to the file to open in the editor'
        }
      },
      required = { 'rel_path' }
    },
    handler = function(args)
      -- Check if editor is available
      if not editor.is_available() then
        return { error = 'Geany editor interface is not available' }
      end
      
      -- Validate and resolve path
      local abs, err = path.to_abs(args.rel_path)
      if not abs then 
        return { error = 'Path resolution failed: ' .. (err or 'unknown error') }
      end
      
      -- Ensure path is within sandbox boundaries
      local ok, err2 = path.ensure_in_sandbox(abs)
      if not ok then 
        return { error = 'Sandbox violation: ' .. (err2 or 'path outside sandbox') }
      end
      
      -- Read the file content
      local content, rerr = fs.read_file(abs)
      if not content then 
        return { error = 'Failed to read file: ' .. (rerr or 'unknown error') }
      end
      
      -- Set the buffer text in the editor
      local success = editor.set_buffer_text(content)
      if not success then
        return { error = 'Failed to set buffer text in editor' }
      end
      
      return { 
        ok = true, 
        path = abs, 
        chars_loaded = string.len(content),
        editor_status = editor.get_status()
      }
    end
  },

  -- Patch operations for code modification (TODO: Implement patch module)
  --[[
  generate_diff = {
    description = 'Generate unified diff between existing file and proposed content',
    input_schema = {
      type = 'object',
      properties = {
        rel_path = {
          type = 'string',
          description = 'Relative path to the file to diff against'
        },
        new_content = {
          type = 'string',
          description = 'Proposed new content for comparison'
        }
      },
      required = { 'rel_path', 'new_content' }
    },
    handler = function(args)
      -- Delegate to patch module
      local result = patch.generate_diff(args.rel_path, args.new_content)
      
      -- Ensure consistent return format
      if not result then
        return { error = 'Diff generation failed: no result returned' }
      end
      
      return result
    end
  },

  apply_patch = {
    description = 'Apply a unified diff patch safely in the sandbox',
    input_schema = {
      type = 'object',
      properties = {
        rel_path = {
          type = 'string',
          description = 'Relative path to the file to patch'
        },
        patch_text = {
          type = 'string',
          description = 'Unified diff patch text to apply'
        },
        mode = {
          type = 'string',
          description = 'Patch application mode (e.g., "strict", "fuzzy")',
          enum = { 'strict', 'fuzzy', 'reverse' }
        }
      },
      required = { 'rel_path', 'patch_text' }
    },
    handler = function(args)
      -- Delegate to patch module
      local result = patch.apply_patch(args.rel_path, args.patch_text, args.mode)
      
      -- Ensure consistent return format
      if not result then
        return { error = 'Patch application failed: no result returned' }
      end
      
      return result
    end
  }
  --]]
}

--[[
Get the complete tool registry
@return table The registry containing all tool definitions
--]]
function M.get_registry()
  return M.registry
end

--[[
Get a specific tool definition by name
@param tool_name string The name of the tool to retrieve
@return table|nil The tool definition or nil if not found
--]]
function M.get_tool(tool_name)
  if not tool_name or type(tool_name) ~= 'string' then
    return nil
  end
  return M.registry[tool_name]
end

--[[
Get list of all available tool names
@return table Array of tool names
--]]
function M.get_tool_names()
  local names = {}
  for name, _ in pairs(M.registry) do
    table.insert(names, name)
  end
  table.sort(names) -- Consistent ordering
  return names
end

--[[
Validate that a tool definition has required fields
@param tool_def table The tool definition to validate
@return boolean, string Whether the definition is valid and error message if not
--]]
function M.validate_tool_definition(tool_def)
  if type(tool_def) ~= 'table' then
    return false, 'Tool definition must be a table'
  end
  
  if not tool_def.description or type(tool_def.description) ~= 'string' then
    return false, 'Tool definition must have a string description'
  end
  
  if not tool_def.input_schema or type(tool_def.input_schema) ~= 'table' then
    return false, 'Tool definition must have an input_schema table'
  end
  
  if not tool_def.handler or type(tool_def.handler) ~= 'function' then
    return false, 'Tool definition must have a handler function'
  end
  
  -- Validate input_schema structure
  local schema = tool_def.input_schema
  if schema.type ~= 'object' then
    return false, 'Input schema type must be "object"'
  end
  
  if not schema.properties or type(schema.properties) ~= 'table' then
    return false, 'Input schema must have properties table'
  end
  
  return true, nil
end

--[[
Validate the entire registry for consistency
@return boolean, table Whether the registry is valid and any error details
--]]
function M.validate_registry()
  local errors = {}
  
  for name, tool_def in pairs(M.registry) do
    local valid, err = M.validate_tool_definition(tool_def)
    if not valid then
      table.insert(errors, string.format('Tool "%s": %s', name, err))
    end
  end
  
  return #errors == 0, errors
end

-- Initialize additional tools
run_lint.register(M.registry)

return M
