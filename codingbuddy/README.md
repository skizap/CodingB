CodingBuddy (GeanyLua plugin)

Overview
- Lua-based coding assistant plugin for Geany.
- Phase 1 delivers: OpenRouter connection, basic analysis, simple configuration.

Install (dev workflow)
1) Copy/symlink this folder to: ~/.config/geany/plugins/geanylua/codingbuddy
2) Ensure Geany and GeanyLua are installed.
3) Ensure Lua 5.1 and lua-socket are installed. For HTTPS, luasec is recommended.
4) Put your OpenRouter API key in config.json or environment var OPENROUTER_API_KEY.

Config file location
~/.config/geany/plugins/geanylua/codingbuddy/config.json

Files
- main.lua            Entry point; registers menu command
- ai_connector.lua    OpenRouter API client
- analyzer.lua        Builds prompt and calls AI for suggestions
- config.lua          Loads keys and preferences
- dialogs.lua         Minimal UI helpers
- utils.lua           Helpers (hashing, fs)
- prompts/analysis.txt Prompt for analysis
- cache/              Local cache dir
- logs/               Logs

Notes
- luasec was not detected in this environment. HTTP fallback is possible but not recommended; install luasec for HTTPS.
- This is a development scaffold; iterate here then sync to Geany config path.
