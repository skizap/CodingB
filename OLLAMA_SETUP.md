# Ollama Local AI Model Support

CodingBuddy now supports local AI inference through [Ollama](https://ollama.com/), enabling offline development and enhanced privacy.

## Features

- **Offline AI Inference**: Run models locally without internet connectivity
- **Privacy**: Keep your code and conversations entirely local
- **Cost-Free**: No API charges for local models
- **Fallback Support**: Automatically falls back to other providers if Ollama is unavailable
- **Model Flexibility**: Support for various open-source models

## Installation

### 1. Install Ollama

#### Linux/macOS:
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

#### Windows:
Download and install from [ollama.com](https://ollama.com/download/windows)

### 2. Start Ollama Service

```bash
ollama serve
```

This starts the Ollama API server on `http://localhost:11434`

### 3. Download Models

#### Recommended Models for Coding:

**Llama 3.1 (Default):**
```bash
ollama pull llama3.1
```

**CodeLlama for specialized coding tasks:**
```bash
ollama pull codellama
```

**Mistral for general programming:**
```bash
ollama pull mistral
```

**Deepseek Coder for advanced coding tasks:**
```bash
ollama pull deepseek-coder
```

### 4. Verify Installation

Test that Ollama is working:
```bash
ollama list  # Show installed models
curl http://localhost:11434/api/version  # Test API endpoint
```

## Configuration

### Enable Ollama in CodingBuddy

Edit your `~/.config/geany/plugins/geanylua/codingbuddy/config.json`:

#### Option 1: Add to fallback chain
```json
{
  "fallback_chain": ["openrouter", "openai", "anthropic", "deepseek", "ollama"]
}
```

#### Option 2: Use as primary provider
```json
{
  "provider": "ollama",
  "fallback_chain": ["ollama", "openrouter", "openai"]
}
```

#### Option 3: Offline-first configuration
```json
{
  "provider": "ollama",
  "fallback_chain": ["ollama"]
}
```

### Model Configuration

Specify which models to use:

```json
{
  "provider_models": {
    "ollama": "llama3.1"
  }
}
```

Available model options:
- `llama3.1` (default, good general purpose)
- `codellama` (specialized for code)
- `mistral` (fast and efficient)
- `deepseek-coder` (advanced coding capabilities)
- Any model available via `ollama list`

## Usage Examples

### Direct Ollama Usage
```lua
local ai = require('codingbuddy.ai_connector')

-- Use Ollama specifically
local response = ai.chat({
  prompt = "Explain this function",
  provider = "ollama",
  model = "llama3.1"
})
```

### Automatic Fallback
```lua
-- Will try Ollama first if it's in fallback_chain
local response = ai.chat({
  prompt = "Review this code for bugs"
})
```

### Model Selection
```lua
-- Use CodeLlama for specialized coding tasks
local response = ai.chat({
  prompt = "Generate unit tests for this function",
  provider = "ollama",
  model = "codellama"
})
```

## Model Recommendations

### For Code Analysis
- **llama3.1**: General-purpose, good balance
- **deepseek-coder**: Advanced code understanding
- **codellama**: Specialized for code tasks

### For Documentation
- **llama3.1**: Excellent for explanations
- **mistral**: Fast and coherent

### For Code Generation
- **codellama**: Best for generating code
- **deepseek-coder**: Advanced code generation

### Performance Considerations
- **llama3.1**: ~4GB RAM, moderate speed
- **codellama**: ~2-7GB RAM (varies by size)
- **mistral**: ~4GB RAM, faster inference
- **deepseek-coder**: ~4-8GB RAM, high quality

## Advanced Configuration

### Custom Ollama Server
If running Ollama on a different host/port:

```json
{
  "ollama_base_url": "http://192.168.1.100:11434"
}
```

**Note**: Currently hardcoded to `localhost:11434`. This would require code modification.

### Memory Management
For better performance with limited RAM:

```bash
# Set memory limits
OLLAMA_HOST=127.0.0.1:11434 ollama serve

# Use smaller models
ollama pull llama3.1:8b  # 8B parameter version
```

## Troubleshooting

### Ollama Service Not Running
```bash
# Check if Ollama is running
curl http://localhost:11434/api/version

# If not, start it
ollama serve
```

### Model Not Found
```bash
# List available models
ollama list

# Pull missing model
ollama pull llama3.1
```

### Connection Refused
1. Ensure Ollama service is running (`ollama serve`)
2. Check firewall settings (port 11434)
3. Verify in CodingBuddy logs: `~/.config/geany/plugins/geanylua/codingbuddy/logs/usage.jsonl`

### Poor Performance
1. Use smaller models (e.g., `mistral` instead of `llama3.1`)
2. Increase system RAM
3. Close other applications
4. Consider using CPU-optimized models

### Fallback Issues
If Ollama fails and doesn't fallback:
1. Check `fallback_chain` in config.json
2. Verify other providers have valid API keys
3. Check CodingBuddy logs for error messages

## Benefits of Local Models

### Privacy
- Code never leaves your machine
- No data sent to external APIs
- Complete control over processing

### Cost
- No API charges
- No usage limits
- No subscription fees

### Availability
- Works offline
- No network dependency
- No service outages

### Customization
- Choose models for specific tasks
- Fine-tune models for your needs
- Full control over inference parameters

## Integration with CodingBuddy Features

Ollama integrates seamlessly with all CodingBuddy features:

- **Code Analysis**: Local analysis with privacy
- **Documentation**: Generate docs offline
- **Refactoring**: Suggest improvements locally
- **Code Generation**: Create code without external APIs
- **Chat Interface**: Interactive coding assistance
- **Tool Integration**: Works with all CodingBuddy tools

## System Requirements

### Minimum
- 8GB RAM
- 10GB disk space
- Modern CPU (2015+ recommended)

### Recommended
- 16GB+ RAM
- SSD storage
- Multi-core CPU
- GPU support (optional, for faster inference)

## Model Performance Comparison

| Model | Size | RAM Usage | Speed | Code Quality | General Purpose |
|-------|------|-----------|-------|--------------|-----------------|
| llama3.1 | 4.7GB | ~8GB | Medium | High | Excellent |
| codellama | 3.8GB | ~6GB | Fast | Very High | Good |
| mistral | 4.1GB | ~6GB | Fast | Good | Very Good |
| deepseek-coder | 6.2GB | ~10GB | Slower | Excellent | Good |

Choose based on your system capabilities and use case priorities.
