#!/usr/bin/env lua

-- lua_linter.lua - Simple Lua code quality analyzer
-- Performs basic static analysis and style checks on Lua files

local function analyze_file(file_path)
    print("=== Lua Code Analysis: " .. file_path .. " ===")
    print()
    
    local file = io.open(file_path, "r")
    if not file then
        print("✗ Error: Cannot open file " .. file_path)
        return false
    end
    
    local content = file:read("*a")
    file:close()
    
    local issues = {}
    local warnings = {}
    local stats = {
        lines = 0,
        comments = 0,
        blank_lines = 0,
        functions = 0,
        local_vars = 0,
        global_vars = 0
    }
    
    -- Analyze line by line
    local lines = {}
    for line in content:gmatch("[^\n]*") do
        table.insert(lines, line)
    end
    
    stats.lines = #lines
    
    for i, line in ipairs(lines) do
        local trimmed = line:match("^%s*(.-)%s*$") or ""
        
        -- Count blank lines
        if trimmed == "" then
            stats.blank_lines = stats.blank_lines + 1
        end
        
        -- Count comments
        if trimmed:match("^%-%-") then
            stats.comments = stats.comments + 1
        end
        
        -- Count functions
        if trimmed:match("^%s*function%s") or trimmed:match("^%s*local%s+function%s") then
            stats.functions = stats.functions + 1
        end
        
        -- Count local variables
        if trimmed:match("^%s*local%s+%w") and not trimmed:match("^%s*local%s+function%s") then
            stats.local_vars = stats.local_vars + 1
        end
        
        -- Check for common issues
        if line:match("%s+$") then
            table.insert(warnings, string.format("Line %d: Trailing whitespace", i))
        end
        
        if #line > 120 then
            table.insert(warnings, string.format("Line %d: Line too long (%d chars)", i, #line))
        end
        
        if line:match("print%s*%(") and not line:match("^%s*%-%-") then
            table.insert(warnings, string.format("Line %d: Debug print statement found", i))
        end
        
        -- Check for potential globals (basic heuristic)
        for word in line:gmatch("%w+%s*=") do
            local var = word:match("(%w+)%s*=")
            if var and not line:match("local%s") and not line:match("%.%s*" .. var) 
               and not line:match("%[%s*['\"]" .. var .. "['\"]%s*%]") then
                -- This is a very basic check - would need more sophisticated parsing
                -- for accurate global detection
            end
        end
    end
    
    -- Syntax check
    local syntax_ok = true
    local func, err = loadfile(file_path)
    if not func then
        syntax_ok = false
        table.insert(issues, "Syntax error: " .. (err or "Unknown error"))
    end
    
    -- Print results
    print("Code Statistics:")
    print(string.format("  Total lines: %d", stats.lines))
    print(string.format("  Blank lines: %d (%.1f%%)", stats.blank_lines, stats.blank_lines/stats.lines*100))
    print(string.format("  Comment lines: %d (%.1f%%)", stats.comments, stats.comments/stats.lines*100))
    print(string.format("  Functions: %d", stats.functions))
    print(string.format("  Local variables: %d", stats.local_vars))
    print()
    
    if syntax_ok then
        print("✓ Syntax: Valid Lua syntax")
    else
        print("✗ Syntax: Issues found")
    end
    
    print()
    
    if #issues > 0 then
        print("Issues Found:")
        for _, issue in ipairs(issues) do
            print("  ✗ " .. issue)
        end
        print()
    end
    
    if #warnings > 0 then
        print("Warnings:")
        for _, warning in ipairs(warnings) do
            print("  ⚠ " .. warning)
        end
        print()
    end
    
    if #issues == 0 and #warnings == 0 then
        print("✓ No issues found - code looks good!")
    end
    
    print()
    print("Quality Score: " .. math.floor((1 - (#issues * 0.2 + #warnings * 0.1)) * 100) .. "%")
    
    return #issues == 0
end

-- Main execution
if arg and arg[1] then
    local success = analyze_file(arg[1])
    os.exit(success and 0 or 1)
else
    print("Usage: lua lua_linter.lua <file.lua>")
    os.exit(1)
end
