#!/usr/bin/env lua

-- test_fix.lua - Test that the module loading fix works
-- This script tests if all CodingBuddy modules can be loaded correctly

print("Testing CodingBuddy module loading fix...")
print("==========================================")

-- Change to codingbuddy directory
local original_path = package.path
package.path = './codingbuddy/?.lua;./codingbuddy/?/init.lua;' .. package.path

local modules_to_test = {
  'utils',
  'config', 
  'json',
  'ai_connector',
  'analyzer',
  'dialogs',
  'conversation_manager',
  'chat_interface',
  'main'
}

local success_count = 0
local total_count = #modules_to_test

for _, module_name in ipairs(modules_to_test) do
  local ok, result = pcall(require, module_name)
  if ok then
    print("✓ " .. module_name .. " - loaded successfully")
    success_count = success_count + 1
  else
    print("✗ " .. module_name .. " - failed to load: " .. tostring(result))
  end
end

print("\nResults:")
print("========")
print("Successful: " .. success_count .. "/" .. total_count)

if success_count == total_count then
  print("🎉 All modules loaded successfully!")
  print("\nThe fix worked! You can now try CodingBuddy in Geany:")
  print("1. Restart Geany")
  print("2. Look for CodingBuddy options in Tools menu")
  print("3. Try 'CodingBuddy: Open Chat'")
else
  print("❌ Some modules failed to load.")
  print("Please check the error messages above.")
end

-- Restore original path
package.path = original_path
