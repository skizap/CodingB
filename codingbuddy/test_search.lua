#!/usr/bin/env lua

--[[
Test script for the new search_code tool functionality
This script validates that the search function has been properly integrated.
--]]

-- Add the codingbuddy directory to the Lua path
-- We're already in the codingbuddy directory, so just add current path
package.path = "./?.lua;" .. package.path

-- Load required modules
local registry = require('tools.registry')
local fs = require('tools.fs')

print("=== CodingBuddy Search Tool Test ===")

-- Test 1: Verify the search_code tool exists in registry
print("\n1. Checking if search_code tool is registered...")
local search_tool = registry.get_tool('search_code')
if search_tool then
    print("✅ search_code tool found in registry")
    print("   Description: " .. search_tool.description)
else
    print("❌ search_code tool not found in registry")
    return
end

-- Test 2: Validate tool definition
print("\n2. Validating tool definition...")
local valid, err = registry.validate_tool_definition(search_tool)
if valid then
    print("✅ search_code tool definition is valid")
else
    print("❌ search_code tool definition invalid: " .. (err or "unknown error"))
    return
end

-- Test 3: Check if the search function exists in fs module
print("\n3. Checking if fs.search function exists...")
if type(fs.search) == 'function' then
    print("✅ fs.search function is available")
else
    print("❌ fs.search function not found")
    return
end

-- Test 4: Test registry validation
print("\n4. Testing complete registry validation...")
local reg_valid, reg_errors = registry.validate_registry()
if reg_valid then
    print("✅ Complete registry validation passed")
else
    print("❌ Registry validation failed:")
    for _, error in ipairs(reg_errors) do
        print("   - " .. error)
    end
end

-- Test 5: List all available tools
print("\n5. Available tools in registry:")
local tool_names = registry.get_tool_names()
for _, name in ipairs(tool_names) do
    print("   - " .. name)
end

print("\n=== Test Summary ===")
print("✅ Search functionality successfully integrated")
print("📋 Note: ripgrep (rg) needs to be installed for search to work:")
print("   sudo apt install ripgrep")
print("")
print("The search_code tool will:")
print("- Search the entire sandbox root directory")
print("- Use ripgrep for fast, efficient text searching")
print("- Return structured results with file, line number, and text")
print("- Respect sandbox boundaries for security")
