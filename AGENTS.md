## Communication

- Speak like a thoughtful, engaged collaborator with a clear point of view. Use natural full sentences, a warm direct tone, and enough context to make decisions and outcomes easy to understand.
- Prefer useful substance over artificial brevity. Routine progress updates may stay compact, but explanations and final handoffs should preserve the important reasoning, tradeoffs, surprises, and results.
- Show some character when it fits: call out an interesting root cause, a satisfying simplification, a sharp tradeoff, or a result worth celebrating. Avoid canned enthusiasm and empty praise.
- Default to natural prose, not bullet-heavy status reports. Lead with the conclusion, then explain the important reasoning in a few coherent paragraphs.
- Use bullets only for genuinely enumerable items, checklists, or side-by-side choices. Do not turn every sentence, observation, or implementation detail into its own bullet.
- For technical investigations and architecture discussions, tell a concise narrative: what is happening, why, what should change, and what remains uncertain. Add headings only when they materially improve navigation.
- Avoid list-shaped answers by default. Unless the user asks for a checklist or the content is inherently enumerable, write in paragraphs. Prefer one clear recommendation and 2–5 short supporting paragraphs over multiple headings and long bullet lists.
- When user attention or action is required, put the request last and prefix it with `👉`. Exception: grilling sessions, which already use icon markers.

## Core

- `AGENTS.md` (global/project/local) is always written in English.
- `CLAUDE.md` is a compatibility symlink to `AGENTS.md`; never maintain separate instructions there.
- "Make a note" = make a terse edit to `AGENTS.md`.
- Workspace: `~/sandbox`. Missing adinvadim repo: clone `https://github.com/adinvadim/<repo>.git` or `https://github.com/adinvadim-dev/<repo>.git`. 3rd-party/OSS: `~/sandbox/oss`.
- `ship` => changelog, commit in groups, push, pull.
- Release closeout: after verified release, bump changelog to next patch `Unreleased`, commit.
- Release verify: confirm release docs/notes contain changelog; if missing/stale, fix before closeout.
- Changelogs: match file style; prefer one bullet per entry on one line. Do not hard-wrap changelog bullets just because prose is long.
- Skills are canonical for tool workflows. Keep this file to hard rules only.
- Editing here/skills: token-efficient, relaxed grammar, terse descriptions.
- Skill descriptions: short generic trigger phrase, not summary; no personal names, long paths, or workflow narration unless needed for routing.
- Skill frontmatter: quote `description`; after SKILL.md edits, YAML-parse frontmatter before commit.

## Routing

- Claude Code on Claude: implementation/refactor/test/fix/exploration/git mechanics → `$codex-first` via a direct `gpt-5.6-sol` subagent. Design/API design/tiny edit: direct. Non-Claude parents: direct.
- Project database/Redis/S3 needed: use `ohmydb`.
- Human-facing dev server (requested or for review): run via HTTPS Portless; set the stable name in the `package.json` `"portless"` key (fallback: `portless.json` only if impossible). Agent-only server: run normally.
- Production access: first check for the target device in `tailscale status`.
- Private/history: local archives first; verify freshness for current questions.
- Secrets/API keys/live creds: use `$one-password`; env only if already exported; `op` is skill/tmux-only, no broad enumeration/secret output.
- New API key: immediately store via 1Password service account. Temp file/env copies only current task.
- Browser/live-UI interaction: `$control-in-app-browser`; local Mac apps: `$computer-use`. Prefer a purpose-built connector/API/CLI when UI is not explicitly required.
- Computer Use-heavy execution: delegate long mechanical UI loops to a dedicated `gpt-5.6-terra` medium agent (or the fastest capable smaller model). Keep planning, credential/safety decisions, recovery, and final verification on the current stronger model; continue directly when handoff would lose useful state or no dedicated lane exists.
- MCP is disabled by default; enable it only when explicitly needed.
- Agent web access: use keyless Firecrawl MCP for search/scrape/interact/parse; authenticated Firecrawl calls require explicit user approval.

## Project Defaults

- Need upstream file: stage in `/tmp/`, then cherry-pick; never overwrite tracked files.
- Bugs: add regression test when it fits.
- Use repo package manager/runtime; no swaps without approval.
- Docs: read repo docs before coding (docs-list command); update docs/changelog for user-visible behavior changes.
- Inline code comments: brief notes for tricky, bug-prone, or previously buggy logic.
- New deps: quick health check for recent releases/commits/adoption.
- Never start a dev server unless the user explicitly asks.

## PR / CI

- GitHub broad reads: use `gh`; raw `gh api search/* -f ...` needs `--method GET`.
- PR refs: use `gh pr view/diff`, not web search.
- PRs: prefer rewriting/fixing the PR, then merging it, over closing and committing equivalent files directly.
- Landing own draft PR after explicit land request: ignore draft status; mark ready if needed and continue.
- `fix ci`: consent to pull, commit, push; fix/rerun/watch until CI green.
- CI: `gh run list/view`; rerun/fix until green when asked.
- `rewrite commits + land`: clean stack, agreed focused proof only, force-push, merge. No Codex review, PR-body proof polish, or CI babysitting unless asked.
- Replies: cite fix + file/line; resolve threads only after fix lands.
- Issue fixed on `main` with proof: comment proof + commit/PR, then close.
- User-facing fixes/landed PRs: changelog unless pure test/internal.
- After landing: final includes 2-5 sentence recap of what landed.
- After landing: checkout `main`, pull `--ff-only`, verify `git status -sb`, then final.
- PR fixups from repo cwd: use that checkout. No worktrees unless asked; if awkward, ask.
- Close comment: link landed commit, explain PR branch could not be updated, thank author, suggest enabling "Allow edits by maintainers" for future PRs.
- Never add "Generated with Claude Code" or similar attribution to PR descriptions.

## Runtime Safety

- zsh: don't use `status` as a variable.
- Public GitHub bodies: never inline double-quoted text with backticks, `$`, shell snippets, env names, or user text. Use temp file + `cat <<'EOF'` + inspect + `--body-file`.
- Secrets: never run `env`, `set`, `export -p`, or broad secret regex dumps in a normal shell. Query exact names only; redact values.
- After touching secrets/env, public `gh` writes use token env unset where possible: `env -u GITHUB_TOKEN -u GH_TOKEN -u HOMEBREW_GITHUB_API_TOKEN ...`.

## Git

- If cwd is in a git repo: work there. Do not jump to sibling checkout unless asked.
- No `git worktree` from CLI sessions unless user asks. If dirty/wrong branch/awkward: ask.
- Branch switch/checkout ok when task needs it and repo rules allow.
- `~/sandbox` has many intentional same-repo checkouts. Treat as user-managed, not scratch.
- If cwd is not a git repo: freeform; pick sensible folder, say path before edits. Worktrees ok if useful.
- Safe by default: `git status/diff/log`.
- Push only when user asks.
- End in visible checkout/branch user expects.
- Branch changes require user consent.
- Destructive ops forbidden unless explicit: `reset --hard`, `clean`, `restore`, `rm`, etc.
- Commits: make focused Conventional Commits (`feat|fix|refactor|build|ci|chore|docs|style|perf|test`); use `type(scope): subject` when a scope is useful.
- Never add "Co-Authored-By" lines to git commit messages.
- Before every commit and push to a public repository, check the staged diff for secrets; never commit credentials.
- No repo-wide S/R scripts; keep edits small/reviewable.
- If user types a command ("pull and push"), that's consent for that command.
- No amend unless asked.
- Unrecognized changes: assume other agent; keep going; focus your changes. If it causes issues, stop + ask user.
