# Task Mode and Approvals System

## Overview

The task mode and approvals system provides a safety mechanism for AI-requested operations that could modify files or execute commands. When enabled, certain operations are queued for user approval rather than executed immediately.

## Features

### Task Mode Commands

- `/task start` - Enable task mode (operations require approval)
- `/task stop` - Disable task mode (operations execute normally)
- `/ops` - Show pending operations queue
- `/approve <id>` - Approve operation by ID for execution
- `/reject <id>` - Reject operation by ID (removes from queue)
- `/clear` - Clear all completed (approved/rejected) operations

### Operations That Require Approval

When task mode is enabled, these operations are intercepted and queued:

1. **write_file** - Writing content to files
2. **apply_patch** - Applying code patches
3. **run_command** - Executing terminal commands

Other operations (like `read_file`, `list_dir`, `search_code`) continue to execute normally.

### User Interface Indicators

- Chat window shows `[TASK MODE]` when enabled
- Pending operations are automatically displayed after AI responses
- Operation summaries shown after execution

## Workflow

1. **Enable Task Mode**: User runs `/task start`
2. **AI Interaction**: User asks AI to perform file operations
3. **Operation Queuing**: Instead of immediate execution, operations are queued
4. **User Review**: User sees operation details and decides to approve/reject
5. **Execution**: On next user message, approved operations are executed
6. **Results**: Execution results are shown and added to conversation context

## Example Session

```
User: /task start
System: Task mode enabled. AI requests for file operations will require approval.

User: Create a hello world script in Python
AI: I'll create a Python hello world script for you.

Operation 1 (write_file) has been queued for approval. Use /approve 1 to execute or /reject 1 to cancel.

User: /ops
Operations Queue:
[10:30] ID:1 write_file - Write to: hello.py (PENDING)

User: /approve 1
System: Approved operation 1

User: Thanks!
System: Executed approved operations:
- Operation 1 (write_file): Success

AI: You're welcome! The hello.py script has been created successfully.
```

## Technical Implementation

### Tool Wrapping

The system uses a tool wrapper that intercepts specific operations when task mode is enabled:

```lua
local function wrap_tools_for_task_mode(tools)
  -- Wraps write_file, apply_patch, run_command
  -- Other tools pass through unchanged
end
```

### Operations Queue

Operations are stored with:
- Unique ID
- Operation type (write_file, apply_patch, etc.)
- Payload with original arguments
- Status (pending, approved, rejected)
- Timestamp

### Execution Model

1. **Queue Phase**: Operations are stored instead of executed
2. **Approval Phase**: User reviews and approves/rejects operations
3. **Execution Phase**: On next AI interaction, approved operations run
4. **Results Phase**: Execution results feed back into conversation

## Safety Benefits

- **Review Before Action**: Users see exactly what will be modified
- **Selective Approval**: Users can approve some operations and reject others
- **Rollback Prevention**: Dangerous operations can be caught before execution
- **Audit Trail**: All operations are logged with timestamps and status

## Integration with Chat Interface

The task mode system is fully integrated with the chat interface:

- Mode indication in UI
- Automatic operation display
- Status tracking in chat status
- Seamless workflow integration

## Configuration

Task mode state is managed per chat session and doesn't persist across restarts. Users need to re-enable it each session if desired.

Future enhancements could include:
- Persistent task mode settings
- Per-operation type approval settings
- Batch approval/rejection
- Operation templates for common tasks
