# Research: Why developers say Codex is good at studying a codebase

> Scope: OpenAI Codex (2025–2026 agent incarnation — the cloud-based and CLI coding agent, not the 2021 model).
> Sources: Feb 2025 – Mar 2026.

---

## Summary

Developers credit Codex's codebase comprehension to four concrete, mutually reinforcing mechanisms: (1) a tool-calling agent loop that lets the model *run* code to learn, not just read it; (2) structured context injection via AGENTS.md that routes the model to the right files without overwhelming it; (3) RL training on binary code-correctness signals that made the underlying model (codex-1, an o3 variant) systematically reliable at multi-step reasoning; and (4) externalized durable state (repo + markdown plans) that lets it stay coherent on hours-long sessions. Vague praise ("it's smart" / "it understands context") is widespread but traceable — the mechanisms below explain where the reputation actually comes from.

---

## Findings

### Mechanism 1 — Tool-augmented read-run-repair loop (strongest evidence)

1. **Codex reads files, runs tests, observes failures, edits, repeats — rather than reasoning from training memory alone.** ByteByteGo's technical analysis of the agent architecture: "A single user request like 'fix the bug in the auth module' might trigger the agent to read several files, run the existing tests to see what fails, edit the code, run the tests again, fix a linting error, and run the tests one more time before producing a final commit." Available tools: file read/write, shell commands, test runners, linters, type checkers. [ByteByteGo — How OpenAI Codex Works](https://blog.bytebytego.com/p/how-openai-codex-works)

2. **The agent loop is the differentiator, not the model alone.** OpenAI's own long-horizon blog (Feb 2026): "This is also why Codex models feel better on Codex surfaces than a generic chat window: the harness supplies structured context (repo metadata, file tree, diffs, command outputs) and enforces a disciplined 'done when' routine." The model gets *real feedback* (errors, diffs, logs), not simulated context. The loop is: Plan → Edit → Run tools (tests/build/lint) → Observe results → Repair failures → Update docs/status → Repeat. [OpenAI Developers Blog — Run long horizon tasks with Codex](https://developers.openai.com/blog/run-long-horizon-tasks-with-codex/)

3. **The Harness Engineering team built 1M lines across a real product with 3 engineers and zero manually-written code** in 5 months — averaging 3.5 PRs/engineer/day — by making the entire app (logs, metrics, DevTools, UI state) directly legible to Codex through tool access. Without tool access, progress stalled. "The agent lacked the tools, abstractions, and internal structure required to make progress toward high-level goals." [OpenAI — Harness engineering: leveraging Codex in an agent-first world](https://openai.com/index/harness-engineering/) (Feb 2026, first-person from OpenAI eng)

4. **Cursor's team (a competitor) independently confirmed**: "OpenAI models are much better at extended autonomous work: following instructions, keeping focus, avoiding drift, and implementing things precisely and completely." Cited in OpenAI's own blog but the observation comes from a competing team. [OpenAI cites Cursor — Scaling agents](https://cursor.com/blog/scaling-agents)

---

### Mechanism 2 — AGENTS.md as structured codebase map (strong evidence)

5. **"Give Codex a map, not a 1,000-page instruction manual."** Harness Engineering tried a monolithic AGENTS.md and found it failed in predictable ways: context crowded out the task; too much guidance became non-guidance; it rotted immediately and couldn't be mechanically verified. The winning pattern was a lean AGENTS.md (~100 lines, table of contents) pointing to a structured `docs/` directory with design docs, exec plans, and architecture maps. Progressive disclosure: agents start with a small stable entry point and are taught where to look next. [OpenAI — Harness engineering](https://openai.com/index/harness-engineering/)

6. **AGENTS.md is the mechanism behind "it just knows the project."** Pragmatic Engineer (Feb 2026 interview with Codex head Thibault Sottiaux): "On the Codex team, these files tell the agent how to navigate the codebase, which commands to run for testing, and how to follow the project's standards. These are a bit like README files, but written for AI agents instead of humans." ByteByteGo confirms: "These files tell Codex how to navigate the codebase … The model performs better with them." [The Pragmatic Engineer — How Codex is built](https://newsletter.pragmaticengineer.com/p/how-codex-is-built) / [ByteByteGo](https://blog.bytebytego.com/p/how-openai-codex-works)

7. **AGENTS.md is injected as a named layer in the prompt assembly stack.** ByteByteGo details the prompt construction: "Above [user input], the system stacks environment context like your current working directory and shell, the contents of any AGENTS.md files in your repository … sandbox permission rules, developer instructions from configuration files, model-specific instructions, tool definitions, and a system message." Each layer carries a priority role (system / developer / user). This is structural — not conversational — context injection. [ByteByteGo](https://blog.bytebytego.com/p/how-openai-codex-works)

8. **"Anything it can't access in-context effectively doesn't exist."** The Harness team articulated what becomes the principal constraint and the optimization target: "Knowledge that lives in Google Docs, chat threads, or people's heads are not accessible to the system. Repository-local, versioned artifacts (code, markdown, schemas, executable plans) are all it can see." Developers who encode their architecture into the repo — not just their code — get dramatically better codebase comprehension results. [OpenAI — Harness engineering](https://openai.com/index/harness-engineering/)

---

### Mechanism 3 — RL training on binary code-correctness signals (medium evidence, primary sources)

9. **"Code either works or it doesn't" creates an unusually tight training loop.** FastCompany interview with Codex head Sottiaux (Feb 2026): "There's lots and lots of examples out there with a problem statement and a solution, and being able to tell whether the solution is correct or not. So you can at the very least use that for evaluations to understand the performance of models over time, and drive that performance up." This is why SWE coding tasks reward-model differently from open-ended text. [Fast Company — Inside OpenAI's fast-growing Codex](https://fastcompanyme.com/technology/inside-openais-fast-growing-codex-the-people-building-the-ai-that-codes-alongside-you/)

10. **codex-1 (the model underneath) is an o3 variant fine-tuned with RL on real-world coding tasks**, specifically optimized to follow pull-request norms, write clean diffs, and run a test suite until it passes. The model "learned to produce code that matches human-like style and adheres to instructions strictly." It achieves ~70% accuracy on OpenAI's internal coding task benchmark. [Medium — OpenAI Codex: From 2021 Code Model to a 2025 Autonomous Coding Agent](https://medium.com/@aliazimidarmian/openai-codex-from-2021-code-model-to-a-2025-autonomous-coding-agent-85ef0c48730a) (secondary, citing official OpenAI announcements)

11. **METR's independent research confirms the time-horizon trend is real and fast.** The length of software tasks frontier agents can complete with ~50% and 80% reliability has been climbing with a rough ~7-month doubling time. This is the external, non-vendor source backing the "Codex gets longer tasks right" claim. [METR — Measuring AI Ability to Complete Long Tasks](https://metr.org/blog/2025-03-19-measuring-ai-ability-to-complete-long-tasks/)

---

### Mechanism 4 — Durable externalized state + context compaction (medium evidence)

12. **Long-horizon codebase work is only coherent because state lives in the repo, not in the context window.** OpenAI long-horizon blog (first-person experiment, Feb 2026): "The most important technique was durable project memory. I wrote the spec, plan, constraints, and status in markdown files that Codex could revisit repeatedly. That prevented drift and kept a stable definition of 'done.'" A 25-hour uninterrupted session generating 30k lines used this pattern. [OpenAI — Run long horizon tasks with Codex](https://developers.openai.com/blog/run-long-horizon-tasks-with-codex/)

13. **Context compaction prevents context window degradation.** ByteByteGo: "When conversations hit the context window limit, Codex compacts the conversation. It replaces the full history with a smaller, representative version that preserves the model's understanding of what happened through an encrypted payload that carries the model's latent state." This is why "starting fresh threads for new tasks often gives better results." ByteByteGo also documents a real bug where adding MCP tool support broke prefix caching because tool definitions were inconsistently ordered — breaking cache hits and inflating costs. This is concrete, observable engineering behavior, not marketing. [ByteByteGo](https://blog.bytebytego.com/p/how-openai-codex-works)

14. **Harness used recurring "doc-gardening" agents to keep the knowledge base non-stale.** An automated Codex agent runs on a schedule, scans for stale documentation that doesn't match real code behavior, and opens fix-up PRs. This is the maintenance side of the context-quality problem. "Technical debt is like a high-interest loan: almost always better to pay it down continuously." [OpenAI — Harness engineering](https://openai.com/index/harness-engineering/)

---

### Mechanism 5 — "Pragmatic" personality = direct codebase entry (weaker, semi-verified)

15. **Codex dives directly into the codebase rather than planning first.** FastCompany interview, citing Peter Steinberger (elite developer who built OpenClaw entirely on Codex and later joined OpenAI): "Claude Code is more conversational and iterative … Codex, by contrast, does not formally separate planning and coding and instead tends to dive directly into the codebase to gather context and begin working." Sottiaux confirmed: "The pragmatic personality has always been the personality that we have on Codex." This makes it fast for codebase study but sometimes frustrating for iterative design. [Fast Company](https://fastcompanyme.com/technology/inside-openais-fast-growing-codex-the-people-building-the-ai-that-codes-alongside-you/)

16. **Typical Codex team engineer runs 4–8 parallel agents simultaneously**, including dedicated agents for "codebase understanding" and "summarizing what team members have done." From Pragmatic Engineer (Sottiaux): tasks explicitly listed include *Codebase understanding*, *Going through plans and summarizing*, and *Going through what team members have done and summarizing changes*. This is the first-party confirmation that codebase study is a recognized, regular use case — not a side effect. [The Pragmatic Engineer — How Codex is built](https://newsletter.pragmaticengineer.com/p/how-codex-is-built)

---

### Mechanism 6 — Test-enforced architecture makes the codebase agent-legible (OpenAI-internal evidence)

17. **Structuring the codebase "to make it inevitable for the model to succeed" is a real engineering discipline.** Pragmatic Engineer interview: "The team has deliberately structured their codebase 'to make it inevitable for the model to succeed'. Structuring means having tests in-place, clear module boundaries, and instructions on how the model should run validation." When the model implements something incorrectly, a test fails, the agent notices, and retries. "Since the model is trained to be persistent, it keeps trying until it gets it right." [The Pragmatic Engineer](https://newsletter.pragmaticengineer.com/p/how-codex-is-built)

18. **Harness enforced layered domain architecture via custom lints.** The architecture rule (Types → Config → Repo → Service → Runtime → UI) was enforced by Codex-generated linters with error messages written specifically to inject remediation instructions into agent context. "In a human-first workflow, these rules might feel pedantic or constraining. With agents, they become multipliers: once encoded, they apply everywhere at once." [OpenAI — Harness engineering](https://openai.com/index/harness-engineering/)

---

## Sources

### Kept

| Source | URL | Why kept |
|--------|-----|----------|
| The Pragmatic Engineer — How Codex is built | https://newsletter.pragmaticengineer.com/p/how-codex-is-built | Named interviews: Tibo (Codex head), SQ Mah (researcher), Emma Tang (data infra). Feb 2026. Concrete internal practices. |
| OpenAI — Harness engineering | https://openai.com/index/harness-engineering/ | First-person account of building a real product (1M LOC, 3 engineers, 5 months) with zero manually written code. Feb 2026. |
| ByteByteGo — How OpenAI Codex Works | https://blog.bytebytego.com/p/how-openai-codex-works | Independent technical architecture analysis with real engineering details (cache bug, prompt layering, compaction mechanics). |
| OpenAI — Run long horizon tasks with Codex | https://developers.openai.com/blog/run-long-horizon-tasks-with-codex/ | First-person 25-hour experiment with token usage, session stats. Feb 2026. |
| Fast Company — Inside OpenAI's fast-growing Codex | https://fastcompanyme.com/technology/inside-openais-fast-growing-codex-the-people-building-the-ai-that-codes-alongside-you/ | Named sources: Sottiaux, Glaese, Embiricos. Third-party journalist. Feb 2026. |
| OpenAI — Codex CLI Features | https://developers.openai.com/codex/cli/features/ | Canonical feature docs: "Ask" mode, approval modes, AGENTS.md injection. |
| METR — Measuring AI Ability to Complete Long Tasks | https://metr.org/blog/2025-03-19-measuring-ai-ability-to-complete-long-tasks/ | Independent research org, externally validates time-horizon improvement trend. |
| Cursor — Scaling agents | https://cursor.com/blog/scaling-agents | Competitor (Cursor) independently praising OpenAI model reliability for extended work. |
| OpenAI Cookbook — Modernizing your Codebase | https://developers.openai.com/cookbook/examples/codex/code_modernization | Concrete walkthrough of codebase inventory, discovery, and modernization workflow. |

### Dropped

| Source | Reason |
|--------|--------|
| Medium — OpenAI Codex: From 2021 Code Model... | Secondary summary of official announcements; no new information |
| Nate's Newsletter — Claude vs Codex | Paywalled; preview too shallow to extract mechanisms |
| r/theprimeagen — "Most Developers Aren't Ready for 2026" | General AI hype, not codebase study mechanisms |
| r/ExperiencedDevs — 2026 advice thread | Too general, no Codex-specific codebase comprehension content |
| Sid Saladi Substack — Codex 101 | Tutorial restatement of official docs; no independent signal |
| Various SEO/LinkedIn posts | No named sources, no concrete mechanisms, pure description |

---

## Gaps

### What couldn't be answered

1. **No independent third-party benchmarks specifically on codebase comprehension quality.** METR measures task-completion length, not "how well did it understand an unfamiliar codebase." There is no publicly available head-to-head comparison of Codex vs Claude Code vs Copilot on specifically the "understand/study a codebase" use case.

2. **Weak non-elite developer voices.** Most concrete evidence comes from either OpenAI insiders, OpenAI-published case studies, or elite developers like Peter Steinberger. Independent Reddit/community discourse didn't surface strong specific codebase-study testimonials beyond general praise.

3. **"Ask mode" is under-documented externally.** The Codex CLI's dedicated Ask mode (`codex "Explain this codebase to me"`) is mentioned in official docs but doesn't appear in independent developer writeups with enough concrete specificity to evaluate quality independently.

4. **Harness Engineering is OpenAI-internal.** The most detailed case study is from OpenAI's own team using Codex on an OpenAI product. This is the strongest evidence of *how* it works, but it's not independent evidence of how it works for external teams.

### Suggested next steps

- Search for independent conference talks (PyCon, GOTO, QCon 2025–2026) where developers share Codex-specific codebase onboarding stories
- Look for open GitHub repos that ship AGENTS.md + document their Codex workflows (the [agents.md](https://agents.md) site tracks this)
- Check METR for any codebase-comprehension-specific eval suites
- Look for Codex usage data in OpenAI developer community forums for specific `codex "explain this codebase"` or codebase-study thread patterns
