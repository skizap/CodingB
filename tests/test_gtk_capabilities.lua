-- test_gtk_capabilities.lua - Explore GeanyLua GTK bindings
-- This script tests what GTK functionality is available in GeanyLua

local geany = rawget(_G, 'geany')

local function test_basic_geany_functions()
  print("=== Testing Basic Geany Functions ===")
  
  if geany then
    print("✓ geany global is available")
    
    -- Test basic functions
    local functions_to_test = {
      'message', 'add_menu_item', 'filename', 'text', 'buffer',
      'fileinfo', 'selection', 'word_at_pos', 'line_count'
    }
    
    for _, func_name in ipairs(functions_to_test) do
      if geany[func_name] then
        print("✓ geany." .. func_name .. " is available")
      else
        print("✗ geany." .. func_name .. " is NOT available")
      end
    end
  else
    print("✗ geany global is NOT available (running outside Geany)")
  end
end

local function test_gtk_access()
  print("\n=== Testing GTK Access ===")
  
  -- Try to access GTK directly
  local gtk_attempts = {
    function() return rawget(_G, 'gtk') end,
    function() return rawget(_G, 'Gtk') end,
    function() return rawget(_G, 'GTK') end,
    function() return require('gtk') end,
    function() return require('Gtk') end,
  }
  
  local gtk_found = false
  for i, attempt in ipairs(gtk_attempts) do
    local ok, result = pcall(attempt)
    if ok and result then
      print("✓ GTK access method " .. i .. " works: " .. tostring(result))
      gtk_found = true
      
      -- Try to explore what's available
      if type(result) == 'table' then
        local count = 0
        for k, v in pairs(result) do
          if count < 10 then  -- Limit output
            print("  - " .. tostring(k) .. ": " .. type(v))
          end
          count = count + 1
        end
        if count > 10 then
          print("  ... and " .. (count - 10) .. " more items")
        end
      end
      break
    else
      print("✗ GTK access method " .. i .. " failed: " .. tostring(result))
    end
  end
  
  if not gtk_found then
    print("✗ No GTK access found through standard methods")
  end
end

local function test_dialog_creation()
  print("\n=== Testing Dialog Creation ===")
  
  -- Try different approaches to create dialogs
  if geany then
    -- Test if we can create custom dialogs through geany
    local dialog_tests = {
      function() return geany.dialog end,
      function() return geany.create_dialog end,
      function() return geany.gtk_dialog end,
    }
    
    for i, test in ipairs(dialog_tests) do
      local ok, result = pcall(test)
      if ok and result then
        print("✓ Dialog creation method " .. i .. " available: " .. type(result))
      else
        print("✗ Dialog creation method " .. i .. " not available")
      end
    end
  end
end

local function test_lua_capabilities()
  print("\n=== Testing Lua Environment ===")
  
  -- Check Lua version and capabilities
  print("Lua version: " .. _VERSION)
  
  -- Test if we can load common libraries
  local libs_to_test = {
    'io', 'os', 'string', 'table', 'math', 'debug',
    'socket', 'socket.http', 'ssl.https', 'json', 'dkjson'
  }
  
  for _, lib_name in ipairs(libs_to_test) do
    local ok, result = pcall(require, lib_name)
    if ok then
      print("✓ " .. lib_name .. " library available")
    else
      print("✗ " .. lib_name .. " library not available: " .. tostring(result))
    end
  end
end

local function explore_geany_object()
  print("\n=== Exploring Geany Object ===")
  
  if geany then
    print("Geany object type: " .. type(geany))
    
    -- Try to enumerate all available functions/properties
    local items = {}
    for k, v in pairs(geany) do
      table.insert(items, {name = k, type = type(v)})
    end
    
    -- Sort for consistent output
    table.sort(items, function(a, b) return a.name < b.name end)
    
    print("Available geany functions/properties:")
    for _, item in ipairs(items) do
      print("  " .. item.name .. " (" .. item.type .. ")")
    end
  end
end

-- Main test execution
local function run_all_tests()
  print("GeanyLua GTK Capabilities Test")
  print("==============================")
  
  test_basic_geany_functions()
  test_gtk_access()
  test_dialog_creation()
  test_lua_capabilities()
  explore_geany_object()
  
  print("\n=== Test Complete ===")
  print("This information will help determine what's possible for the chat interface.")
end

-- Export for use as a module or run directly
local M = {}
M.run_all_tests = run_all_tests

-- If running directly (not as a module), execute tests
if not package.loaded[...] then
  run_all_tests()
end

return M
