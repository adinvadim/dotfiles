---
name: grill-with-paper
description: "Grill decisions through Paper only when they concern design."
disable-model-invocation: true
---

# Grill with Paper

## Route each question

Before opening Paper, classify the question being grilled:

- When visual form or interaction is part of the decision, use the Paper
  workflow below.
- Otherwise, use the interview format the user specified. If they did not
  specify one, invoke `/grilling` and follow it. This skill is complete for that
  question.
- When the owning domain, bounded-context boundary, or canonical term is
  unclear, invoke `/domain-modeling` before opening Paper. Domain ownership is
  not a visual decision.

Apply this routing again for every question in a mixed interview. The rest of
this skill applies only to questions routed into the Paper workflow.

Use Paper prototypes as the interview itself, not as an artifact produced after
an interview. Inherit `/grilling`'s one-decision-at-a-time discipline and
`/prototype`'s radically different variants, but do not run a preliminary
text-only design interview. Paper is the working surface; the project working
tree stays unchanged.

## Paper workspace

Read `~/.agents/skills/paper/SKILL.md` fully as reference before any Paper tool
call. Follow its artifact model, page geography, naming, concurrency contract,
session hygiene, and open/resume steps. This skill only adds the grilling
interview on top of that workspace.

## Non-negotiable interaction contract

- Never ask a discovery, clarification, preference, or design question without
  first staging concrete alternatives as a prototype.
- Every question must point to visible, labeled options in a Paper screenshot
  created or updated in the same turn. The prototype is the question.
- Every question gets one temporary compact question block beside its WIP fork.
  After the answer, reduce it to the permanent `LOG` metadata defined by
  `/paper`.
- After the Paper file is known, every user-facing response must include a
  clickable link to the exact Paper page containing the prototype.
- Research missing facts. If a visual assumption remains unknowable, stage it
  as a labeled prototype variant. Do not pause for a text-only clarification.
- After each answer, update CANON and stage the next visual fork before asking
  the next question. Never merely acknowledge an answer in prose.
- Delete rejected, superseded, and accepted WIP artboards only after CANON and
  LOG have been verified. Never delete CANON or completed LOG nodes as pruning.
- A prose option list, Markdown wireframe, or promise to prototype later does
  not satisfy this contract.
- If Paper is unavailable, report the technical blocker and stop. Do not fall
  back to ordinary `/grilling` for a visual decision.

## Start

1. Load the Paper workspace rules and open or resume the repository file and
   owning context page exactly as `/paper` requires. This is the final page
   switch for the mutation session.
2. Research discoverable facts in the codebase. Read `CONTEXT-MAP.md` or
   `CONTEXT.md`, relevant docs/ADRs, code, and any existing issue/spec. Reserve
   the interview for user decisions.
3. Find the existing `SPEC · #<issue>` or `SPEC · Draft` cluster. Create one only
   when absent, with identity/link metadata but no duplicated spec prose. Scan
   its `LOG` nodes and continue at the next spec-local `D<nn>`.
4. Identify the relevant CANON artifacts and the highest-dependency unresolved
   visual decision. If CANON does not exist, derive the initial baseline from
   code, docs, the current product, or read-only visual references; do not copy
   legacy Paper nodes.
5. Before the first Paper mutation, post the brief required by the Paper guide
   and call `get_font_family_info` for the chosen family.

Start is complete when the file, context page, SPEC cluster, relevant CANON, and
next decision are known. The first user-facing decision question comes only
after its fork is staged and reviewed in Paper.

## Visual decision loop

Repeat until the decision tree is exhausted.

### 1. Stage one fork

- Frame one decision whose answer changes the design.
- Default to three labeled options; use two to four when the decision naturally
  has fewer or more credible answers.
- Hold settled decisions, viewport, scenario, and data constant. Vary the
  current decision strongly enough to judge from the canvas.
- Prefer screens, state sequences, annotated flows, and diagrams in Paper. When
  the answer depends on executable behavior these cannot demonstrate, load
  [HTML-FALLBACK.md](HTML-FALLBACK.md).
- Duplicate the relevant CANON artifact into WIP options. If no CANON exists,
  create comparable first-fork artboards from the researched baseline.
- Use the next spec-local decision ID and stable names:
  `WIP · <issue-or-Draft> · D<nn> · <decision> · <option> · <label>`.
- Add one compact temporary question block containing only the short question
  and labeled option names.
- Build incrementally with Paper tools. Screenshot every option after meaningful
  changes, apply Paper's review checkpoints, fix issues, and give a one-line
  verdict.
- Call `finish_working_on_nodes`.

The fork is staged only when every credible option is visible, comparable,
readable, reviewed, and paired with its question block.

### 2. Ask one question

Show the question-block screenshot and option screenshots, then ask exactly one
question referencing their visible labels. Include:

- the consequence of each option;
- the recommended option and why;
- an invitation to choose one option or combine named parts.

Wait for the user's answer. Do not advance another decision in the same turn.
Do not ask a follow-up about the same fork unless revised prototypes are staged
first.

### 3. Apply and prune

- First convert the temporary question block into
  `LOG · <issue-or-Draft> · D<nn>`. Keep only the decision ID, selected option
  label, and affected CANON names; keep rationale in the conversation, not
  Paper.
- If the user rejects every option, record `none` in LOG, delete that fork's WIP
  nodes, and stage a new numbered fork for the same decision.
- For a hybrid, update the closest WIP option to the requested combination and
  verify it before changing CANON.
- When a relevant CANON node exists, apply the chosen visual changes to that
  node in place so its semantic name, node identity, and links remain stable.
- When no CANON exists, promote the chosen WIP artifact into the CANON band and
  give it a semantic `CANON · ...` name.
- Screenshot the resulting CANON and compare it with the chosen WIP result.
  Only after they match, delete every WIP artboard from the resolved fork,
  including the chosen reference copy.
- Verify that SPEC contains no duplicate accepted design or product prose, then
  call `finish_working_on_nodes`.
- If another unresolved decision remains, immediately stage its visual fork in
  the same turn. The next response must contain that fork and exactly one
  question.

Pruning is complete only when CANON contains one current visual truth for each
affected artifact, the resolved fork has no WIP nodes, and its compact LOG
remains in the owning SPEC cluster.

## Finish

When no unresolved design decisions remain, screenshot the complete affected
CANON and relevant LOG nodes, then ask the user to confirm shared understanding
against that visible artifact. This is the only question that does not require
multiple variants. After confirmation:

- leave the coherent CANON plus only the states/flows needed to explain it;
- preserve compact LOG nodes, but no product prose or duplicate accepted design;
- remove remaining WIP and comparison scaffolding;
- run one final screenshot review and call `finish_working_on_nodes`;
- report the decisions reached and link the exact Paper context page without raw
  node IDs;
- include this explicit handoff in the final response so a later `/to-spec` can
  preserve the design reference without changing that skill:

```md
Design reference for the spec:
- Paper: [<context page>](<exact page URL>)
- Context: <canonical context name>
- Canon: <affected CANON artifact names>
- Decisions: <issue-or-Draft>/D<first>-D<last>
- Preserve this Paper link in the published spec.
```

The skill is complete only after the user confirms the final Paper artifact.
