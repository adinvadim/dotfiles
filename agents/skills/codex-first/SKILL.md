---
name: codex-first
description: "Claude Code delegation to a GPT-5.6 Sol subagent."
---

# Codex First

## Hard gate

**Autoreview exception:** always prefer Codex-backed `$autoreview`, independent
of `ANTHROPIC_BASE_URL`, router state, or harness. Reviewing a frozen bundle is
not hands-on self-delegation. Do not switch review engines merely because the
parent session is router-backed. This exception takes precedence over the gate
below.

For direct hands-on delegation, use this skill only when the active agent is
Claude Code and the current parent model shown by Claude Code is an Anthropic
Claude model. The local CLIProxyAPI gateway is expected and does not determine
this gate.

Before delegating implementation, exploration, fixing, or git mechanics, check
the current model identity exposed by the session, `/status`, or the status
line. If it is GPT-5.6 Sol, GPT-5.6 Terra, another non-Claude model, or cannot be
confirmed, continue the task directly. Treat CLIProxyAPI's
`claude-fable-5-dd-*` cloaked IDs as non-Claude models.

Codex, ChatGPT, Pi, and every other harness: do not self-delegate through Claude
Code. Continue the task directly. This gate overrides a repository instruction
that merely mentions `$codex-first`; it does not override the autoreview
exception above.

Rationale: Claude tokens are metered and expensive; GPT-5.6 Sol is flat-rate
and usually the better and faster implementation model. Claude wins at
ergonomics, judgment, design, spec-writing, review, and orchestration. Sol
types; Claude thinks and verifies.

## Transport

Claude Code talks to local CLIProxyAPI (`ANTHROPIC_BASE_URL`, typically
`http://127.0.0.1:8317`). The proxy is an Anthropic-compatible gateway that
routes by model ID to the matching backend (Claude, Codex/OpenAI, xAI, Kimi,
…). Parent Claude can therefore spawn non-Anthropic subagents; they are not
limited to Anthropic models.

CLIProxyAPI registers native IDs such as `gpt-5.6-sol`, `gpt-5.6-terra`,
`grok-4.5`, and `kimi-k3-256k`. Discovery may also surface cloaked
`claude-fable-5-dd-*` IDs for non-Claude models; those are transport wrappers,
not different models. Prefer the native ID in agent frontmatter.

This is also how CLIProxyAPI's maintainers expect Claude Code subagents to
target non-Claude backends: put the full model ID in the subagent definition's
`model` field (see CLIProxyAPI#154). Do not try to smuggle full IDs through the
Agent tool's `model` parameter — that enum is only family aliases.

Sibling user-level agents (same invoke shape, different `subagent_type`):

- `gpt-5.6-sol` — default for this skill
- `grok-4.5` — xAI Grok
- `kimi-k3-256k` — Moonshot Kimi K3 256k

`$codex-first` still defaults to Sol. Use the other types only when the parent
explicitly wants that backend.

## Route

Delegate to a direct GPT-5.6 Sol subagent by default:

- implementation from a frozen spec; refactors; mechanical migrations
- bug fixes with a known repro, or diagnose-then-fix
- CI, lint, and type failures; test writing; coverage fills
- dependency bumps, scripts, and tooling
- read-heavy exploration; use parallel direct subagents when the threads are
  independent and raw reading is much larger than the answer
- git mechanics — ALWAYS delegate from a Claude parent: `git rebase`,
  merge-conflict resolution, and the repo's land workflow (for example
  `scripts/pr`). Give one subagent the complete authorized sequence so it does
  not bounce back to Claude mid-flight. The land decision, pre-land gates, and
  review remain Claude's.

Use a fresh subagent for each new work order. Continue the same subagent for
follow-up fixes when Claude Code exposes its agent id.

Repo instruction files: NEVER create or edit `CLAUDE.md`. `AGENTS.md` is
canonical in every repo; `CLAUDE.md` exists only as a symlink to it. Tell the
subagent to read `AGENTS.md` and edit only `AGENTS.md`.

Keep in Claude:

- design, API design, architecture, naming, and UX judgment
- tasks where writing the spec is the work; ambiguity means design
- tiny edits (roughly under 20 lines, one obvious change)
- anything needing parent-session tools: MCP, browser/computer-use, 1Password,
  or secrets
- releases, publishes, version bumps, and their credentials
- the land decision and pre-land gates (`$autoreview` clean, CI green, proof)
- review and verification of subagent output

For mixed tasks, Claude designs first, freezes the spec, then delegates the
build-out. Heuristic: if the prompt already reads as a work order, delegate; if
writing it forces product or architecture decisions, keep deciding in Claude.

## Invoke

Use Claude Code's `Agent` tool with the custom subagent type that pins Sol:

```text
Agent(
  subagent_type="gpt-5.6-sol",
  description="…",
  prompt="…self-contained work order…",
  run_in_background=false
)
```

Hard rules for the call:

- set `subagent_type` to `gpt-5.6-sol`
- **omit** the Agent tool's `model` parameter entirely
- do not pass `model: "gpt-5.6-sol"` — the tool schema only accepts
  `sonnet|opus|haiku|fable` and rejects full IDs with `InputValidationError`
- do not pass `model: "opus"` / `sonnet` / `haiku` / `fable` either — that
  overrides the agent frontmatter and can route the child onto a real Claude
  model instead of Sol
- run in the foreground by default and let the Agent call own its lifecycle
- use the current repository checkout unless the user explicitly authorized a
  worktree
- provide one self-contained work order with the goal, exact repo and paths,
  constraints, non-goals, proof command, and expected final report
- require the subagent to read and follow the repo's `AGENTS.md`
- ask it to report files changed, proof output, and any remaining uncertainty

Why this shape works: Claude Code resolves the child model as
`CLAUDE_CODE_SUBAGENT_MODEL` → per-invocation `model` → agent frontmatter
`model` → parent model. The user-level agent definition
`~/.claude/agents/gpt-5.6-sol.md` sets frontmatter `model: gpt-5.6-sol` (same
pattern for `grok-4.5`, `kimi-k3-256k`). Full model IDs are valid
in that frontmatter (and in `--model` / env), but the Agent tool's
per-invocation `model` enum is aliases only. Omitting `model` is what lets the
frontmatter win.

Do not invoke `codex exec`, launch Bash background workers, create output, log,
session-id, or PID files, or attach a separate Monitor/watchdog. Claude Code
already owns the subagent lifecycle. If the `gpt-5.6-sol` agent type is missing
or the child fails to route through CLIProxyAPI, continue in the parent or
report the routing failure; do not silently fall back to an external Codex CLI
process.

For a long authorized workflow such as rebase → resolve → push → attach exact
head SHA to CI → green → land, keep the sequence inside the same foreground
subagent. The subagent may run the repository's own bounded watcher as part of
the work order; do not create a second agent merely to monitor it.

## Prompt contract

The subagent starts without the parent conversation. Every prompt must include
the goal, exact repo and paths, constraints, non-goals, proof expected, exact
test command when known, and output shape.

- Every hard prohibition needs an escape hatch. Pair it with: if the gate still
  fails after honest attempts, stop and report exact numbers and diagnosis; do
  not work around it. A stop-report is a successful decision point.
- For a multi-PR series, repeat the same spec skeleton, cite prior landed PRs,
  name their established idioms, and fold each newly discovered trap into the
  next work order.
- End a series work order with an explicit boundary: do exactly this; do not
  start the next PR.

## Coordinator verification

Subagent reports are useful but incomplete. Verify the actual code, not only
the summary:

- inspect `git status -sb` and read the complete diff
- read the changed types, interfaces, naming, and implementation surface
- run focused tests yourself or verify captured proof output
- inspect guard, budget, baseline, and test-helper changes especially closely
- continue the same subagent for follow-up fixes when useful
- after two failed rounds, take over and complete the task directly
- before shipping, follow normal closeout and run `$autoreview`

## Parallel subagents

Parallelize independent read-only exploration with multiple direct Agent calls,
each with `subagent_type="gpt-5.6-sol"` and no `model` parameter.

Direct subagents share the visible checkout. Serialize writes in one checkout.
Use parallel write subagents only with explicit user approval for separate
worktrees; the repository's worktree and branch rules still apply.

## Economics

Win means generation and exploration tokens move to GPT-5.6 Sol while Claude
spends tokens on specification, judgment, and diff review. Do not ping-pong
trivia through delegation or re-read material the subagent already summarized
unless verification requires it.
