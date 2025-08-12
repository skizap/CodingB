# CodingBuddy Documentation

This directory contains technical documentation for CodingBuddy developers and advanced users.

## Documentation Structure

### Main Documentation (Root Level)
- **[README.md](../README.md)** - Project overview and quick start
- **[INSTALL.md](../INSTALL.md)** - Installation and setup guide
- **[USER_GUIDE.md](../USER_GUIDE.md)** - Complete user manual
- **[DEVELOPER.md](../DEVELOPER.md)** - API reference and development guide

### Technical Documentation (This Directory)
- **[architecture.md](architecture.md)** - Detailed system architecture design
- **[chat_interface.md](chat_interface.md)** - Chat interface technical reference
- **[anthropic_enhancements.md](anthropic_enhancements.md)** - Advanced AI features and tool support

## Documentation Guide

### For Users
1. Start with [README.md](../README.md) for project overview
2. Follow [INSTALL.md](../INSTALL.md) for setup
3. Read [USER_GUIDE.md](../USER_GUIDE.md) for complete usage instructions

### For Developers
1. Read [DEVELOPER.md](../DEVELOPER.md) for API reference
2. Study [architecture.md](architecture.md) for system design
3. Check [chat_interface.md](chat_interface.md) for implementation details
4. Review [anthropic_enhancements.md](anthropic_enhancements.md) for advanced features

### For Contributors
1. Follow [DEVELOPER.md](../DEVELOPER.md) contribution guidelines
2. Understand the architecture from [architecture.md](architecture.md)
3. Run tests as described in [DEVELOPER.md](../DEVELOPER.md)
4. Update documentation when adding features

## Quick Reference

### Key Concepts
- **Chat Interface** - Interactive AI conversation system
- **Conversation Manager** - Persistent conversation state management
- **AI Connector** - Multi-provider AI communication layer
- **Provider Fallback** - Automatic switching between AI providers

### Important Files
- `main.lua` - Plugin entry point and Geany integration
- `chat_interface.lua` - User interface and interaction logic
- `conversation_manager.lua` - Conversation state and persistence
- `ai_connector.lua` - Multi-provider AI communication
- `config.lua` - Configuration management

### Configuration
- Config file: `~/.config/geany/plugins/geanylua/codingbuddy/config.json`
- Sample config: `codingbuddy/config.sample.json`
- Environment variables: `OPENROUTER_API_KEY`, `ANTHROPIC_API_KEY`, etc.

### Testing
- Test files: `tests/test_*.lua`
- Run tests: `lua tests/test_ai_connector.lua`
- Debug mode: `export CODINGBUDDY_DEBUG=1`

## Documentation Standards

### Writing Guidelines
- Use clear, concise language
- Include code examples for technical concepts
- Provide both basic and advanced usage examples
- Cross-reference related documentation

### Code Documentation
- Document all public functions with parameters and return values
- Include usage examples in function documentation
- Use consistent naming conventions
- Add inline comments for complex logic

### Updating Documentation
When making changes to CodingBuddy:

1. **Update relevant documentation** in the same PR
2. **Add examples** for new features
3. **Update API reference** for function changes
4. **Test documentation** for accuracy
5. **Check cross-references** are still valid

## Getting Help

### Documentation Issues
- **Missing information** - Open an issue requesting specific documentation
- **Outdated content** - Submit a PR with corrections
- **Unclear explanations** - Suggest improvements in issues

### Technical Support
- **Installation problems** - Check [INSTALL.md](../INSTALL.md) troubleshooting
- **Usage questions** - Review [USER_GUIDE.md](../USER_GUIDE.md)
- **Development help** - See [DEVELOPER.md](../DEVELOPER.md)
- **Bug reports** - Use GitHub issues with detailed information

---

**Contributing to documentation?** See [DEVELOPER.md](../DEVELOPER.md) for guidelines.
