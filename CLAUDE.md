Language: CLAUDE.md (global/project/local) is always written in English.

# Global Rules

- Never add "Co-Authored-By" lines to git commit messages
- Never add "Generated with Claude Code" or any similar attribution to PR descriptions
- Public repo safety: before every commit and push, check staged diff for secrets; never commit API keys, tokens, passwords, private credentials, or other sensitive data.
- MCP disabled by default. Enable only when explicitly needed.
- Never start a dev server unless the user explicitly asks.
