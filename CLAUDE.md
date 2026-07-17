Language: CLAUDE.md (global/project/local) is always written in English.

## Proxy models (`ccx`)

- In sessions launched with `ccx`, run proxy models directly as Agent/Workflow children using their full native IDs.
- Use `model: 'gpt-5.6-sol(high)'` for GPT-5.6 work and `model: 'grok-4.5'` for Grok work.
- Never use a Claude `sonnet` child as a wrapper and never shell out to Codex/Grok CLI when the direct proxy route is available.
- For mixed Workflows, set the full model ID explicitly on every stage; label children by the model that actually executes them.
- Treat every child model as an independent contributor, not final authority.

# Global Rules

- Never add "Co-Authored-By" lines to git commit messages
- Never add "Generated with Claude Code" or any similar attribution to PR descriptions
- Public repo safety: before every commit and push, check staged diff for secrets; never commit API keys, tokens, passwords, private credentials, or other sensitive data.
- MCP disabled by default. Enable only when explicitly needed.
- Never start a dev server unless the user explicitly asks.
