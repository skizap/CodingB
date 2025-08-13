#!/usr/bin/env lua
-- usage_cli.lua - Command-line interface for testing usage command
-- Simulates the /usage command functionality outside of the chat interface

-- Add the current directory to the path so we can require codingbuddy modules
package.path = package.path .. ';./codingbuddy/?.lua'

local usage_analyzer = require('usage_analyzer')

local function show_help()
  print("CodingBuddy Usage CLI")
  print("====================")
  print("")
  print("Usage: lua usage_cli.lua [command] [hours]")
  print("")
  print("Commands:")
  print("  all         Show all-time usage statistics (default)")
  print("  session <N> Show usage statistics for last N hours")
  print("  help        Show this help message")
  print("")
  print("Examples:")
  print("  lua usage_cli.lua             # Show all-time usage")
  print("  lua usage_cli.lua session 24  # Show last 24 hours")
  print("  lua usage_cli.lua session 1   # Show last 1 hour")
  print("  lua usage_cli.lua all          # Show all-time usage")
end

local function main(args)
  local command = args[1] or "all"
  
  if command == "help" or command == "-h" or command == "--help" then
    show_help()
    return
  end
  
  if command == "all" then
    print("Fetching all-time usage statistics...")
    print("")
    local summary = usage_analyzer.get_total_summary()
    print(summary)
  elseif command == "session" then
    local hours = tonumber(args[2])
    if not hours then
      print("Error: Please specify number of hours for session command")
      print("Example: lua usage_cli.lua session 24")
      return
    end
    
    print(string.format("Fetching usage statistics for last %d hours...", hours))
    print("")
    local summary = usage_analyzer.get_session_summary(hours)
    print(summary)
  else
    print("Error: Unknown command '" .. command .. "'")
    print("Use 'lua usage_cli.lua help' for usage information")
  end
end

-- Execute with command line arguments
main(arg or {})
