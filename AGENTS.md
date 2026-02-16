Vadim owns this. Start: say hi + 1 motivating line. Work style: telegraph; noun-phrases ok; drop grammar; min tokens.

- Workspace: ~/sandbox. Missing steipete repo: clone https://github.com/adinvadim/<repo>.git or https://github.com/adinvadim-dev/<repo>.git.
- 3rd-party/OSS (non-steipete): clone under ~/Projects/oss.
- “Make a note” => edit AGENTS.md (shortcut; not a blocker). Ignore CLAUDE.md.
- Bugs: add regression test when it fits.
- Keep files <~500 LOC; split/refactor as needed.
- Commits: Conventional Commits (feat|fix|refactor|build|ci|chore|docs|style|perf|test).
- CI: gh run list/view (rerun/fix til green).

## Docs

- Start: run docs-list (ignore if not installed); open docs before coding.
- Follow links until domain makes sense; honor Read when hints.
- Keep notes short; update docs when behavior/API changes (no ship w/o docs).
- Add read_when hints on cross-cutting docs.

## Build / Test

- Before handoff: run full gate (lint/typecheck/tests/docs).
- CI red: gh run list/view, rerun, fix, push, repeat til green.
- Keep it observable (logs, panes, tails, MCP/browser tools).
- Release: read docs/RELEASING.md (or find best checklist if missing).

## Critical Thinking

- Fix root cause (not band-aid).
- Unsure: read more code; if still stuck, ask w/ short options.
- Conflicts: call out; pick safer path.
- Unrecognized changes: assume other agent; keep going; focus your changes. If it causes issues, stop + ask user.
- Leave breadcrumb notes in thread.

## Tools

### gh

- GitHub CLI for PRs/CI/releases. Given issue/PR URL (or /pull/5): use gh, not web search.
- Use gh for adding github secrets if user ask

### ohmydb

- Use when you need local Postgres/Redis/ClickHouse/MinIO in dev. Prefer this over Docker for these services.
- `ohmydb` (no args) shows PG databases + Redis info + ClickHouse databases + MinIO buckets.
- ClickHouse is managed locally by `ohmydb setup` (no manual credential config expected).
- Back-compat: `db` still works but just forwards to `ohmydb`.
- `ohmydb --help` for details.

### firecrawl mcp

- Use for live crawl/scrape/extract/search tasks when web data is needed in-agent.
- Preconfigured globally as MCP server `firecrawl` for Codex, Claude Code, and OpenCode.

### docs-list

- Optional. Lists docs/ + enforces front-matter.

### trash

- Move files to Trash: trash … (system command).

### coolify, wrangler, vercel

- Use only if user ask. If you need it to use it - ask user.
