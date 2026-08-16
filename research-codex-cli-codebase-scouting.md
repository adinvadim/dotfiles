# Research: OpenAI Codex CLI — Codebase Scouting & Onboarding

> Current as of March 2026. Sources: official OpenAI developer docs, the open-source Codex repo system prompt, community forum, and third-party practitioner guides.

---

## Summary

Codex CLI has **no dedicated scout/planning phase by default** — reconnaissance is emergent, driven by the model issuing shell commands (`rg`, `cat`, `git log`, `git blame`) as needed within the tool-use loop. Codebase understanding is bootstrapped upfront through `AGENTS.md` files (injected into context before the first user message), then expanded during execution via the `shell` tool. Approval modes govern how much autonomy the agent has during this exploration and any subsequent writes.

---

## Findings

### 1. AGENTS.md is the primary static onboarding mechanism

Codex reads `AGENTS.md` files **before doing any work**, injecting them as user-role messages at the top of the conversation history. This is the single most important lever for codebase onboarding.

**Discovery chain (once per session, at startup):**
1. **Global scope** — `~/.codex/AGENTS.override.md` → `~/.codex/AGENTS.md` (first non-empty wins)
2. **Project scope** — git root → … → CWD, checking `AGENTS.override.md` → `AGENTS.md` → fallback filenames per directory; one file per directory
3. **Merge order** — root to leaf, concatenated with blank lines; deeper files override shallower ones (later in the prompt)
4. **Size cap** — 32 KiB by default (`project_doc_max_bytes` in config)

Each discovered file becomes its own user-role message formatted as:
```
# AGENTS.md instructions for <directory>
<INSTRUCTIONS>
...file contents...
</INSTRUCTIONS>
```

The system prompt instructs the model: *"for every file you touch in the final patch, you must obey instructions in any AGENTS.md file whose scope includes that file."* Nested files win conflicts; direct prompt/developer instructions win over AGENTS.md.

**What a good `AGENTS.md` covers** (per official best-practices doc):
- Repo layout and important directories
- How to run the project
- Build, test, and lint commands
- Engineering conventions and PR expectations
- Constraints and do-not rules
- Definition of "done" and how to verify work

The `/init` slash command scaffolds a starter `AGENTS.md` from the current directory, but OpenAI recommends editing the output to match real team conventions.

[Source: AGENTS.md guide](https://developers.openai.com/codex/guides/agents-md) | [Source: system prompt (repo)](https://github.com/openai/codex/blob/main/codex-rs/core/prompt_with_apply_patch_instructions.md)

---

### 2. Reconnaissance is emergent via the `shell` tool — not a separate phase

Codex has **no hardcoded scout/explore phase**. After AGENTS.md is injected, the model decides what to read based on the task. The system prompt explicitly favors speed:

> "Prefer using `rg` or `rg --files` respectively because `rg` is much faster than alternatives like `grep`. (If `rg` is not found, use alternatives.)"

Typical reconnaissance commands the model issues autonomously:
- `rg --files` / `find` — file discovery
- `cat`, `rg <pattern>` — reading and searching file contents
- `git log`, `git blame` — history and authorship context
- `ls` — directory structure

The system prompt encourages brief **preamble messages** before tool calls, producing visible commentary like:
> *"I've explored the repo; now checking the API route definitions."*
> *"Ok cool, so I've wrapped my head around the repo. Now digging into the API routes."*
> *"Spotted a clever caching util; now hunting where it gets used."*

This makes recon *legible* to the user even though it is entirely emergent behavior. The model does NOT announce "scout phase start/end" — it just reads files until it has enough context, then transitions to edits.

[Source: system prompt (repo)](https://github.com/openai/codex/blob/main/codex-rs/core/prompt_with_apply_patch_instructions.md) | [Source: CLI features](https://developers.openai.com/codex/cli/features)

---

### 3. Plan mode and `update_plan` provide optional explicit planning

When invoked explicitly (via `/plan` toggle or `Shift+Tab`), Codex enters **Plan mode**: it gathers context, may ask clarifying questions, and produces a step-by-step plan *before* writing code.

Outside plan mode, the model can still use the `update_plan` tool (which renders a live checklist in the TUI), but only for multi-step non-trivial tasks. From the system prompt:

> "Use a plan when: the task is non-trivial and will require multiple actions over a long time horizon; there are logical phases or dependencies where sequencing matters; the work has ambiguity that benefits from outlining high-level goals."

> "Do NOT use plans for simple or single-step queries that you can just do or answer immediately."

The system prompt calls for high-quality plans with 5–6 verifiable steps, and explicitly bans low-quality filler plans. Best-practices guidance also mentions `PLANS.md` templates for orchestrating long-running agentic tasks.

Community practitioners confirm that plan mode is one of the most-praised features: it surfaces the agent's intent before any file is touched, letting users course-correct early.

[Source: system prompt (repo)](https://github.com/openai/codex/blob/main/codex-rs/core/prompt_with_apply_patch_instructions.md) | [Source: best practices](https://developers.openai.com/codex/learn/best-practices) | [Source: community tips forum](https://community.openai.com/t/tips-and-tricks-for-using-codex/1373143)

---

### 4. Three core tools power all execution — including recon

The model is trained to use exactly three first-party tools:

| Tool | Role |
|------|------|
| `shell` | Run any terminal command. Used for both recon (`rg`, `git log`, `cat`) and execution (`npm test`, `cargo build`) |
| `apply_patch` | File edits (add/update/delete) using a custom diff format. Never used for reads. |
| `update_plan` | Maintains and renders the step checklist visible to the user |

From the official Codex Prompting Guide cookbook:
> *"We strongly recommend using our exact `apply_patch` implementation as the model has been trained to excel at this diff format. For terminal commands we recommend our `shell` tool, and for plan/TODO items our `update_plan` tool should be most performant."*

Web search is a fourth tool, enabled by default using a cached index (not live pages) to reduce prompt-injection risk. In `--yolo` (full-access) mode, web search defaults to live results.

MCP (Model Context Protocol) servers can add additional tools for external context (databases, issue trackers, Figma, etc.), configured in `config.toml`. Skills (SKILL.md files) are loaded lazily — only their metadata appears in context until explicitly invoked.

[Source: Codex prompting guide](https://developers.openai.com/cookbook/examples/gpt-5/codex_prompting_guide/) | [Source: system prompt (repo)](https://github.com/openai/codex/blob/main/codex-rs/core/prompt_with_apply_patch_instructions.md) | [Source: CLI features](https://developers.openai.com/codex/cli/features)

---

### 5. Approval modes govern how much the agent can explore and act without interruption

Four operational presets, set via `--sandbox` + `--ask-for-approval` flags (or `/permissions` in-session):

| Mode | Flags | Behavior |
|------|-------|----------|
| **Auto** (default) | `--full-auto` | Reads + edits + runs commands in workspace; asks before touching outside scope or network |
| **Read-only** | `--sandbox read-only --ask-for-approval on-request` | Browse freely, no writes/commands without approval — "consultative mode" |
| **Untrusted** | `--sandbox workspace-write --ask-for-approval untrusted` | Reads + writes, but asks before running "untrusted" commands (destructive git ops, etc.) |
| **Dangerous** | `--yolo` / `--dangerously-bypass-approvals-and-sandbox` | No sandbox; no approvals. Not recommended. |

Protected paths even in Auto mode: `.git`, `.agents/`, `.codex/` directories are read-only. Network access is OFF by default. The workspace = current directory + `/tmp`.

**Sandbox architecture:** On macOS, the OS-level sandbox (Seatbelt) enforces limits. On cloud (Codex Web), isolated containers with a two-phase runtime: setup phase (network enabled, installs deps) → agent phase (offline by default).

For codebase onboarding specifically: **read-only mode with on-request** is the safest for unfamiliar repos. The docs note that Codex "may start in `read-only` until you explicitly trust the working directory."

[Source: agent approvals & security](https://developers.openai.com/codex/agent-approvals-security) | [Source: system prompt (repo)](https://github.com/openai/codex/blob/main/codex-rs/core/prompt_with_apply_patch_instructions.md)

---

### 6. Session continuity: context persists across resumes

Sessions are stored locally as JSONL transcripts under `~/.codex/sessions/`. The `resume` subcommand reopens a prior session including its transcript, plan history, and approvals:
```bash
codex resume --last          # most recent session
codex resume <SESSION_ID>    # specific session
codex exec resume --last "Implement the plan"   # non-interactive resume
```

This means a codebase-exploration session can be run separately from implementation, with the model carrying forward everything it learned. Context compaction handles long sessions — Codex auto-compacts or the user invokes `/compact`, summarizing earlier turns to keep the context window usable.

[Source: CLI features](https://developers.openai.com/codex/cli/features)

---

### 7. The `Explain a codebase` workflow is the canonical onboarding pattern

The official Workflows page treats "Explain a codebase" as the first workflow pattern:

**IDE extension approach:**
1. Open relevant files
2. Prompt: *"Explain how the request flows through the selected code. Include: a short summary of each module's responsibilities, what data is validated and where, one or two gotchas to watch for when changing this."*

**CLI approach:**
```bash
codex
# then:
"I need to understand the protocol used by this service. Read @foo.ts @schema.ts
and explain the schema and request/response flow. Focus on required vs optional
fields and backward compatibility rules."
```

Or as a one-shot:
```bash
codex "Explain this codebase to me"
```

The docs note: **"In the CLI, you usually need to mention paths explicitly"** (vs the IDE extension which automatically includes open files). `@` path autocomplete and `/mention` help attach files.

[Source: workflows](https://developers.openai.com/codex/workflows)

---

### 8. Community-praised workflow patterns

From the official community tips forum (Feb 2026, curated by OpenAI staff member `vb`):

**High-signal patterns practitioners praise:**
- **Test-first loop**: Define tests upfront as the "done" signal; Codex iterates until they pass. `vb` (OpenAI): *"Codex can iterate over the results until the desired outcome is achieved. Designing the tests to be meaningful then becomes a necessary part of the planning phase."*
- **Local docs over web scraping**: *"Equip your agents with high-quality local documentation instead of relying on web scraping."*
- **Plan mode for complex tasks**: Getting a plan before code starts, with an option to negotiate the plan before implementation.
- **Greptile or external review tools for PR validation**: Closing the loop with automated review on push.
- **AGENTS.md as living document**: *"When Codex makes the same mistake twice, ask it for a retrospective and update `AGENTS.md`."* (official best-practices)
- **Substack/community takeaway** (Peter Steinberger on Lex Fridman): *"Consider how Codex sees your codebase. They start a new session and know nothing about your project. So you gotta help those agents a little bit."* — endorsing AGENTS.md as teammate onboarding.

**Friction points users report:**
- `apply_patch` is strict: exact text matching, no fuzzy or AST-based matching — stale context causes patch failures
- Without `AGENTS.md`, each new session is context-blind — repeated mistakes without persistent guidance
- Long threads degrade quality; best practice is one thread per task, not one per project
- Approval prompts interrupting workflow (r/OpenAI: "I have to approve every single operation since today") — resolved by understanding the default `auto` mode

[Source: community tips forum](https://community.openai.com/t/tips-and-tricks-for-using-codex/1373143) | [Source: Codex 101 substack](https://sidsaladi.substack.com/p/openai-codex-101-the-complete-guide) | [Source: r/OpenAI approvals thread](https://www.reddit.com/r/OpenAI/comments/1nm3s04/codex_cli_i_have_to_approve_every_single/)

---

### 9. Subagents are explicit, not automatic

Codex only spawns subagents **when explicitly asked**. Each subagent does its own model + tool work (consuming credits/quota proportionally). Use cases: parallelizing bounded sub-tasks (exploration, tests, triage) while the main agent focuses on the core problem. Subagents are managed with `/agent` slash command in the CLI and appear in git worktrees (Codex app).

[Source: CLI features](https://developers.openai.com/codex/cli/features) | [Source: subagents docs](https://developers.openai.com/codex/subagents)

---

## Sources

**Kept:**
- [System prompt (open source repo)](https://github.com/openai/codex/blob/main/codex-rs/core/prompt_with_apply_patch_instructions.md) — authoritative; the actual instructions given to the model, including tool usage rules, AGENTS.md spec, planning criteria, and preamble guidance
- [AGENTS.md guide](https://developers.openai.com/codex/guides/agents-md) — official; full discovery algorithm, layering, fallback filenames, troubleshooting
- [CLI features](https://developers.openai.com/codex/cli/features) — official; approval modes, interactive mode, session resume, web search, subagents
- [Agent approvals & security](https://developers.openai.com/codex/agent-approvals-security) — official; sandbox modes, protected paths, approval combos table
- [Best practices](https://developers.openai.com/codex/learn/best-practices) — official; prompting structure, AGENTS.md content guide, MCP, skills, common mistakes
- [Workflows](https://developers.openai.com/codex/workflows) — official; canonical "explain a codebase" pattern, bug fix, refactor, review workflows
- [Codex Prompting Guide (cookbook)](https://developers.openai.com/cookbook/examples/gpt-5/codex_prompting_guide/) — official; tool recommendations, AGENTS.md injection mechanics, compaction
- [Community tips forum](https://community.openai.com/t/tips-and-tricks-for-using-codex/1373143) — curated by OpenAI staff; real practitioner patterns and friction points
- [Codex 101 Substack (Saladi, Feb 2026)](https://sidsaladi.substack.com/p/openai-codex-101-the-complete-guide) — good practitioner synthesis; includes Peter Steinberger / OpenClaw case study

**Dropped:**
- YouTube OpenAI Codex CLI video — no additional unique content vs docs
- Reddit r/ChatGPTCoding hype thread — paywalled / low signal for this research question
- DeployHQ blog post — surface-level tutorial, no unique insight beyond official docs
- feiskyer/codex-settings repo — config examples (useful reference, not authoritative on behavior)

---

## Gaps

1. **Source code tool implementation**: The tools directory (`codex-rs/core/src/tools/`) contains files like `sandboxing.rs`, `parallel.rs`, `orchestrator.rs`, `router.rs` — reviewing these would clarify exactly how tool calls are routed and whether there is any hard-coded recon ordering. Not fully scraped due to credit constraints.

2. **`/init` scaffold behavior**: Exactly what commands Codex runs to generate the initial `AGENTS.md` (does it `ls`, `git log`, read package.json?) is not documented; only the outcome (a scaffold) is described.

3. **Context window behavior during large repos**: The 32 KiB AGENTS.md cap is documented, but the behavior when a large monorepo's instruction chain exceeds it (truncation strategy, which files are dropped) is only partially explained.

4. **Quantitative recon cost**: No data on how many shell calls a typical "explain codebase" session issues, or what the token overhead of a full AGENTS.md chain is vs. no guidance.

5. **Automatic vs. skill-triggered recon**: Whether certain skills or prompts trigger more systematic recon patterns (like a built-in tree walk) is not confirmed from public docs.

**Suggested next steps:**
- Read `codex-rs/core/src/tools/orchestrator.rs` and `router.rs` for the actual tool dispatch logic
- Read `codex-rs/core/prompt.md` and `gpt_5_codex_prompt.md` for alternate model system prompts
- Test `/init` on a real repo and observe what shell commands are issued in the transcript (`~/.codex/sessions/`)
- Review [execution plans guide](https://developers.openai.com/cookbook/articles/codex_exec_plans) for PLANS.md templating patterns
