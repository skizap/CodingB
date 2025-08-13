# run_lint Tool Documentation

## Overview

The `run_lint` tool provides language-aware static code analysis using existing CLI linting tools. It automatically detects the programming language from file extensions and runs the appropriate linter, presenting findings in a structured format.

## Supported Languages and Linters

### Python
- **Primary**: `ruff` (fast modern linter)
- **Fallback**: `flake8` (traditional Python linter)
- **Output**: JSON format with detailed error/warning information

### Lua
- **Primary**: `luacheck` (Lua static analyzer)
- **Output**: JSON format with code analysis results

### JavaScript/TypeScript
- **Primary**: `eslint` (JavaScript/TypeScript linter)
- **Output**: JSON format with ESLint findings
- **Supported Extensions**: `.js`, `.ts`, `.tsx`

## Tool Schema

```json
{
  "name": "run_lint",
  "description": "Run language-specific linters on files with structured output",
  "input_schema": {
    "type": "object",
    "properties": {
      "rel_path": {
        "type": "string",
        "description": "Relative path to file or directory to lint",
        "required": true
      },
      "language": {
        "type": "string",
        "description": "Override language detection",
        "enum": ["python", "lua", "javascript", "typescript"],
        "required": false
      },
      "linter": {
        "type": "string", 
        "description": "Specific linter to use (overrides default)",
        "required": false
      }
    }
  }
}
```

## Output Format

### Success Response
```json
{
  "linter_used": "ruff",
  "language": "python",
  "target_path": "/absolute/path/to/file.py",
  "findings_count": 3,
  "findings": [
    {
      "file": "/absolute/path/to/file.py",
      "line": 15,
      "column": 8,
      "severity": "error",
      "message": "Undefined name 'undefined_variable'",
      "rule": "F821"
    }
  ],
  "exit_code": 1,
  "raw_output": "..."
}
```

### Error Response
```json
{
  "error": "No linters available for python. Install one of: ruff, flake8"
}
```

## Usage Examples

### Basic Usage
```lua
local result = tool_handler({
  rel_path = "src/main.py"
})
```

### Override Language Detection
```lua
local result = tool_handler({
  rel_path = "script.txt",
  language = "python"
})
```

### Force Specific Linter
```lua
local result = tool_handler({
  rel_path = "src/main.py",
  linter = "flake8"
})
```

## Finding Structure

Each finding in the `findings` array contains:

- **file**: Absolute path to the file with the issue
- **line**: Line number (1-based)
- **column**: Column number (1-based, may be null)
- **severity**: `"error"`, `"warning"`, or `"info"`
- **message**: Human-readable description of the issue
- **rule**: Linter-specific rule identifier (e.g., "F821", "E302")

## Security and Sandboxing

### Terminal Policy Integration
The tool respects the terminal security policy and only executes allowed linter commands:
- `ruff`
- `flake8` 
- `luacheck`
- `eslint`
- `which` (for availability checking)

### Sandbox Boundaries
All file paths are validated to ensure they remain within the configured sandbox directory.

### Command Execution
Linter commands are constructed safely with proper shell escaping to prevent injection attacks.

## Error Handling

### Common Errors
1. **Path Resolution**: `"Path resolution failed: <reason>"`
2. **Sandbox Violation**: `"Sandbox violation: path outside sandbox"`
3. **File Not Found**: `"Path does not exist: <path>"`
4. **Language Detection**: `"Unsupported file extension: <ext>"`
5. **Linter Unavailable**: `"No linters available for <language>. Install one of: <list>"`
6. **Execution Failure**: `"Linter execution failed"`

### Graceful Degradation
- If JSON parsing fails, falls back to plain text parsing
- If primary linter unavailable, tries fallback linters
- Provides meaningful error messages for debugging

## Installation Requirements

### For Python Support
```bash
# Install ruff (recommended)
pip install ruff

# Or install flake8
pip install flake8
```

### For Lua Support  
```bash
# Install luacheck
luarocks install luacheck
```

### For JavaScript/TypeScript Support
```bash
# Install eslint
npm install -g eslint
```

## Integration with Analysis Engine

The `run_lint` tool integrates seamlessly with the broader analysis engine:

1. **Automatic Detection**: Files are automatically analyzed based on extension
2. **Structured Output**: Results integrate with other analysis tools
3. **Performance**: Leverages efficient CLI tools for fast analysis
4. **Extensibility**: Easy to add support for additional languages

## Performance Considerations

- **Fast Execution**: Uses native CLI tools optimized for performance
- **Minimal Overhead**: Direct command execution without heavy frameworks
- **Concurrent Safe**: Multiple linting operations can run simultaneously
- **Resource Efficient**: Minimal memory footprint

## Future Enhancements

Planned improvements include:
- Support for more languages (Go, Rust, Java)
- Configuration file detection (.eslintrc, .flake8, etc.)
- Custom rule configuration
- Batch processing of multiple files
- Integration with language servers for real-time analysis
