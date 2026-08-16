---
name: next-human
description: "Work the next actionable human checkpoint in the current repository."
disable-model-invocation: true
---

# Next Human

Process exactly one item from the current repository's **human inbox**.

## 1. Load the queue

Read the repository's issue-tracker and triage-label configuration under
`docs/agents/`. It should have been provided — recommend
`/setup-matt-pocock-skills` if not. When the tracker and role labels can be
inferred unambiguously from repository conventions, continue with them and note
the inference. Stop only when the missing configuration makes the human inbox
ambiguous or unsafe to mutate.

Query every open issue carrying any of:

- the configured `ready-for-human` role, including `needs-human` when that is
  the repository's label;
- an explicit `HITL` label;
- the configured `needs-info` role;
- `wayfinder:prototype`;
- `wayfinder:grilling`, which is HITL without an additional `HITL` label.

Treat `wayfinder:task` as HITL only when it also carries an explicit human/HITL
label. An issue's assignee is its claim, using the tracker's native assignment
mechanism just as Wayfinder does. Include issues assigned to the current user or
nobody; skip any issue with another assignee.

Classify every candidate before choosing:

- a `needs-info` issue is actionable only when its original reporter has
  commented after the latest `## Triage Notes` comment;
- a Wayfinder issue is actionable only when all blockers are closed;
- conflicting triage state roles require the conflict to be shown before work
  continues.

The queue is loaded when every matching open issue is either actionable or has
an explicit skip reason.

## 2. Take the next checkpoint

Resume actionable work already assigned to the current user first. Otherwise
take the oldest actionable unassigned issue, breaking ties by tracker id. When
several candidates belong to one Wayfinder map, preserve that map's frontier
order.

Selection is provisional until the claim succeeds. Claim the selected issue by
assigning it to the current user before reading its full brief or doing any
work, then re-read its assignees and verify the claim. If another session claimed
it first, do not work it; reload the queue and choose again. Never hold claims on
more than one issue for this invocation.

After the claim is confirmed, show the issue's linked title and one sentence
explaining why it is actionable.

The checkpoint is taken when exactly one issue is selected and claimed.

## 3. Resume its owning flow

Read the relevant installed skill fully from
`~/.agents/skills/<skill-name>/SKILL.md` as reference, then execute only its
owning branch:

- `needs-info` — `/triage`, **Resuming a previous session**;
- work that requires a prototype, including every `wayfinder:prototype` ticket
  — `/grill-with-paper`;
- `wayfinder:grilling` — `/wayfinder`, **Work through the map**, using its
  grilling and domain-modeling discipline;
- another Wayfinder HITL ticket — `/wayfinder`, **Work through the map**;
- another human issue — read its full brief, complete all preparation possible,
  then present one specific decision or action.

For prototype work, the Paper prototype is the HITL conversation. After the
human confirms the final artifact, return to the owning flow: record the
resolution, link the Paper artifact, update the map or triage state, and close
the issue only when that flow's completion criterion is met.

A HITL issue is worked with the human who speaks for themselves.

## Completion

End after exactly one selected issue has either:

- been resolved and moved to its next tracker state; or
- reached one specific human decision or action, with all preparatory work
  complete and the issue still claimed.
