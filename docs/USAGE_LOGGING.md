# CodingBuddy Usage Logging and Diagnostics

## Overview

CodingBuddy now includes comprehensive usage logging and diagnostics to make costs and token usage transparent and auditable. Every AI API call is logged with detailed metrics including token counts, costs, and timing information.

## Features

### Automatic Logging

Every call to `ai_connector.chat()` automatically logs the following information to `usage.jsonl`:

- **Timestamp**: ISO 8601 formatted timestamp
- **Provider**: AI provider used (anthropic, openai, openrouter, etc.)
- **Model**: Specific model used (claude-3-5-sonnet-latest, gpt-4o-mini, etc.)
- **Prompt Tokens**: Number of tokens in the input
- **Completion Tokens**: Number of tokens in the response
- **Total Tokens**: Sum of prompt and completion tokens
- **Estimated Cost**: Calculated cost based on provider pricing
- **Currency**: Cost currency (usually USD)

### Usage Commands

#### In Chat Interface

Use the `/usage` command in the chat interface:

- `/usage` - Show all-time usage statistics
- `/usage 24` - Show usage for the last 24 hours
- `/usage 1` - Show usage for the last 1 hour

#### Command Line Interface

For testing or external access, use the CLI utility:

```bash
# Show all-time usage
lua usage_cli.lua all

# Show usage for last 24 hours
lua usage_cli.lua session 24

# Show usage for last 2 hours
lua usage_cli.lua session 2

# Show help
lua usage_cli.lua help
```

## Usage Report Format

### Example Output

```
=== CodingBuddy Usage Summary ===
Time Range: all time

Overall Usage:
  Total Requests: 15
  Prompt Tokens: 3,450
  Completion Tokens: 8,750
  Total Tokens: 12,200
  Estimated Cost: $0.0485 USD
  Average Cost per Request: $0.0032
  Average Tokens per Request: 813.3

Usage by Provider:
  anthropic:
    Requests: 8 (53.3%)
    Tokens: 6,200 (50.8%)
    Cost: $0.0285 (58.8%)
  openrouter:
    Requests: 4 (26.7%)
    Tokens: 3,500 (28.7%)
    Cost: $0.0125 (25.8%)
  openai:
    Requests: 3 (20.0%)
    Tokens: 2,500 (20.5%)
    Cost: $0.0075 (15.5%)

Usage by Model (Top 5):
  claude-3-5-sonnet-latest:
    Requests: 8
    Tokens: 6,200
    Cost: $0.0285
  anthropic/claude-3.5-sonnet:
    Requests: 4
    Tokens: 3,500
    Cost: $0.0125
  gpt-4o-mini:
    Requests: 3
    Tokens: 2,500
    Cost: $0.0075
```

## Configuration

### Enabling/Disabling Logging

Usage logging is controlled by the `log_enabled` setting in your `config.json`:

```json
{
  "log_enabled": true,
  "cost": {
    "enabled": true,
    "currency": "USD",
    "prices_per_1k": {
      "openai": { "default_input": 0.003, "default_output": 0.006 },
      "anthropic": { "default_input": 0.003, "default_output": 0.015 },
      "openrouter": { "default_input": 0.0, "default_output": 0.0 }
    }
  }
}
```

### Cost Estimation

Costs are estimated based on the pricing configuration in `config.json`. Different providers have different pricing structures:

- **Input/Prompt tokens**: Cost per 1,000 input tokens
- **Output/Completion tokens**: Cost per 1,000 output tokens

Update the `prices_per_1k` section to reflect current pricing for accurate cost estimation.

## File Locations

### Usage Log File

The usage log is stored at:
```
~/.config/geany/plugins/geanylua/codingbuddy/logs/usage.jsonl
```

This is a JSON Lines format file where each line contains a complete usage record.

### Configuration File

Configuration is stored at:
```
~/.config/geany/plugins/geanylua/codingbuddy/config.json
```

## Implementation Details

### AI Connector Integration

The logging happens automatically in `ai_connector.lua` in the `log_usage()` function. Every successful API call triggers logging with the following data flow:

1. AI API request is made
2. Response is received and parsed
3. Usage information is extracted (tokens, cost)
4. Entry is written to `usage.jsonl`

### Usage Analyzer Module

The `usage_analyzer.lua` module provides:

- Reading and parsing usage log entries
- Time-based filtering (last N hours)
- Statistical analysis and aggregation
- Formatted report generation
- Provider and model breakdown

### Error Handling

The logging system includes robust error handling:

- Falls back to manual JSON formatting if libraries unavailable
- Creates log directory automatically if missing
- Gracefully handles missing or corrupted log entries
- Safe file operations with proper error checking

## Troubleshooting

### No Usage Data

If you're not seeing usage data:

1. Check that `log_enabled: true` in your config
2. Verify the logs directory exists and is writable
3. Make sure you've made at least one AI request
4. Check for errors in `codingbuddy.log`

### Incorrect Cost Estimates

Cost estimates depend on the pricing configuration:

1. Update `prices_per_1k` in your config file
2. Check that you're using the correct model names
3. Verify currency settings match your expectations

### Time Filtering Issues

Time filtering uses simple date comparison:

- For periods ≤24 hours: compares dates only
- For longer periods: calculates approximate day ranges
- Timezone is handled in UTC (ISO 8601 format)

## Testing

To test the usage logging system:

```bash
# Run the test suite
lua test_usage_logging.lua

# Test CLI functionality
lua usage_cli.lua help
lua usage_cli.lua all
lua usage_cli.lua session 1
```

The test suite creates sample data and verifies all functionality is working correctly.

## Data Privacy

Usage logs are stored locally only:

- No data is sent to external services
- Only aggregate usage metrics are recorded
- Actual message content is not logged
- You can delete or archive log files as needed

## Future Enhancements

Potential future improvements include:

- Export to CSV/Excel formats
- Graphical usage charts
- Budget alerts and warnings
- Integration with external analytics tools
- Real-time usage monitoring
- Historical trend analysis
