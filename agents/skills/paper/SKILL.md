---
name: paper
description: "Paper workspace rules: files, pages, naming, concurrency."
disable-model-invocation: true
---

# Paper

Workspace rules for navigating and structuring Paper design files. This is not
an interview and does not stage decision forks. Invoke it when working in Paper
without grilling. Skills that mutate Paper read this file fully as reference
before the first Paper tool call.

The project working tree stays unchanged unless the user explicitly asks for a
repo-side export or write.

## Artifact model

```text
Paper file       = repository
Paper page       = bounded context
SPEC cluster     = issue/spec
CANON            = current accepted visual truth
WIP              = temporary alternatives
LOG              = compact visual-decision metadata
```

### Files and pages

- Use exactly one Paper file per repository. Prefer the explicit manifest name;
  fall back to the repository directory name.
- If `CONTEXT-MAP.md` exists, page names are the exact canonical context names
  it references. Create a context page lazily only when it has visual work.
- Otherwise use the `CONTEXT.md` title. If no domain model exists, use `Product`
  without inventing artificial subdomains.
- Never prefix context pages with numbers, `Context`, tickets, dates, sessions,
  stages, or `Grill`.
- Do not create a map page: `CONTEXT-MAP.md` remains canonical.
- Create `Foundations` only for real shared visual components or patterns;
  file-level tokens alone do not justify a page.
- Create `Cross-context journeys` only for a genuinely canonical journey that
  no single context owns. Keep only its unique overview there; do not duplicate
  context screens.
- If a context page needs renaming, ask the user to rename it manually. Do not
  create a duplicate page or reinterpret a differently named page.

Every durable visual cluster has exactly one owning context page. Choose the
context that owns the changed product concept or primary user-visible state, not
every context touched by its implementation. If ownership remains ambiguous after
inspecting the domain model and code, route to `/domain-modeling`; do not mirror
a SPEC cluster across pages.

### No migration

Existing session pages and their nodes are legacy and outside this workflow.
Never move, copy, rename, delete, consolidate, or otherwise migrate them. They
may be read before the first mutation as visual reference only. New work creates
or resumes the appropriate context page in the same repository file.

### Page geography

Keep every context canvas predictable from top to bottom:

```text
CTX     canonical context name + source path/link only when one exists
CANON   current journeys/screens; flows left-to-right, states/viewports downward
SPEC    one horizontal cluster per issue/spec, stacked below CANON
```

Paper must not duplicate repository documentation:

- `CTX` points to `CONTEXT.md`; it does not restate its scope or glossary.
- `SPEC` contains only issue identity, title, status, and URL; it does not copy
  the problem statement, requirements, rationale, or user stories.
- `LOG` contains only its decision ID, selected option label, and affected CANON
  artifact names. The rationale remains in the conversation or repo docs.
- Long-form product meaning, rationale, implementation, and testing decisions
  belong in repository docs or the issue tracker. Paper owns the visuals.

Use stable structural prefixes followed by the repository's canonical language:

```text
CTX · <context>
CANON · <screen or journey> · <state> · <viewport>
SPEC · #<issue> · <title>
SPEC · Draft · <subject>
WIP · <issue-or-Draft> · D<nn> · <decision> · <option> · <label>
LOG · <issue-or-Draft> · D<nn>
```

Omit state or viewport only when it adds no meaning. Never name durable work
after the last interview step, such as `Accepted — D03`.

An issue/spec is the durable identity of its cluster. Start without an issue as
`SPEC · Draft · <subject>`; when the user later publishes it through `/to-spec`,
the cluster may be renamed to `SPEC · #<issue> · <title>` in a separate Paper
operation. Do not invoke `/to-spec` automatically. Resume the existing cluster
and its spec-local monotonic decision numbering across sessions.

## Concurrency contract

Paper page selection is sticky session state while mutation tools address a
file, not a page. Treat the whole Paper file as one write lock:

- Allow only one active Paper writer per file, regardless of page.
- Never delegate Paper reads that switch pages or Paper mutations to parallel
  agents. Parallel agents may research the repository, docs, or web only.
- Resolve and open the owning context page before the first mutation. Do not
  switch pages again during that mutation session.
- If another known writer is using the file, serialize the Paper work.

## Session hygiene

- Load Paper's full guide with `get_guide({ topic: "paper-mcp-instructions" })`
  before other Paper tools. Reload it after context compaction.
- Call `get_font_family_info` before the first typographic styling in a session.
  Prefer families already listed by `get_basic_info` unless the user specifies
  otherwise.
- Before the first mutation in a new design surface, post the brief required by
  the Paper guide (palette, type scale, spacing, direction) unless the file
  already has an established system you are continuing.
- Build incrementally: each `write_html` adds roughly one visual group. Prefer
  `duplicate_nodes` with `update_styles` and `set_text_content` when faster than
  rewriting HTML.
- Screenshot after meaningful changes, fix issues against Paper's review
  checkpoints, then call `finish_working_on_nodes` when done creating or editing.
- After the Paper file is known, user-facing responses that reference the work
  include a clickable link to the exact Paper page. Never include raw node IDs.
- If Paper is unavailable, report the technical blocker and stop.

## Open or resume

1. Load the Paper guide.
2. Research discoverable facts in the codebase when the work depends on product
   meaning: `CONTEXT-MAP.md` or `CONTEXT.md`, relevant docs/ADRs, code, and any
   existing issue/spec.
3. Call `list_files`; open the repository's matching Paper file or create it when
   absent. Resolve one owning context and its exact page name using **Artifact
   model**. Resolve domain ambiguity through `/domain-modeling` before proceeding.
4. Call `get_basic_info`, then `get_selection`. A relevant legacy selection may
   inform the design but must never be copied or mutated. Find or lazily create
   the exact context page, then open it. This is the final page switch for the
   mutation session.
5. Locate the relevant `CANON`, `SPEC`, or other named band for the task. Create
   structure only when the task needs it; do not invent a full grilling layout for
   a simple edit.
6. Mutate only what the task requires, keep names and geography stable, screenshot
   to verify, and call `finish_working_on_nodes`.

Open/resume is complete when the file, owning context page, and target band or
nodes are known and the page will not switch again during mutation.
