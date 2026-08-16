---
name: walk-map
description: "Walk an existing Wayfinder map through root-owned subagents."
argument-hint: "<map URL, path, or exact title> [-- run brief]"
disable-model-invocation: true
---

# Walk Map

Walk one existing Wayfinder map to a terminal state. The root conversation is
the **steward**: it owns the run, carries the user's brief, and mediates
decisions. Every ticket is worked by a fresh subagent following Wayfinder; the
root never becomes a ticket worker.

Use the harness's native subagent lifecycle. Keep the run inside this root
conversation: no CLI runner, background process, daemon, tmux session, or
runner state files.

## 1. Fix the map and run brief

Read `~/.agents/skills/wayfinder/SKILL.md` fully as reference before acting.

Resolve the selector as an existing map. The selector is the complete first
nonblank line after the invocation; when that line contains ` -- `, the text
before the delimiter is the selector and the text after it begins the Run
brief. This makes an exact multi-word title unambiguous. A tracker URL or local
map path is canonical and works independently of the current directory. A title
is resolved within the current repository's configured tracker. With no
selector, query that tracker for open `wayfinder:map` issues and let the user
choose by linked title; show each candidate's Destination and frontier state.
If the current repository does not identify the tracker unambiguously, ask for
a map URL or path.

Validate that the selection is a Wayfinder map, resolve its tracker repository
and local checkout when one is available, then load only its low-resolution
body and frontier. The map's repository, not the root session's current
directory, is the target. This skill walks a map; it does not chart a new one.

Everything after ` -- ` on the selector line plus every following line is the
**Run brief**. Without a delimiter, every line after the selector line is the
brief. Preserve it verbatim and include the complete block in every subagent
work order and every later continuation that needs it. With no brief, use the
map's Notes and Wayfinder defaults. The brief is scoped to this walk unless the
user explicitly asks to persist part of it in the map.

Apply instructions in this order:

1. safety, system instructions, and tool constraints;
2. repository instructions and this skill's stewardship and isolation
   invariants, all of which must hold together;
3. the map's Destination;
4. the Run brief;
5. the map's Notes and Wayfinder defaults.

If repository instructions, the Run brief, or map Notes require violating root
ownership, fresh isolated workers, mediated decisions, or the no-runner rule,
stop at **Instruction conflict** before dispatch instead of weakening either
contract.

The Run brief controls decision posture, preferences, evidence, delegated
authority, budgets, and the stopping point within the Destination. Treat a
conflict with Destination as a proposed redraw, not a preference: return that
conflict to the user before walking further.

Walking a map is a deliberately autonomous mode of Wayfinder. Wayfinder types
most tickets HITL, but a walk mediates that exchange rather than forwarding it:
the root stands in for the user on every decision the effective instructions
already determine, and spends the user's attention only on the ones they do
not. Read the Run brief as delegation, not as background context — every
preference, posture, or budget it states delegates the decisions that
preference determines. A brief that says which way to lean has already answered
every question that leans that way.

The run is fixed when exactly one map and one verbatim Run brief are in scope.

## 2. Steward the frontier

Reload the map and query its open children before every dispatch. Choose the
first open, unblocked, unclaimed frontier ticket in tracker order. The root may
read titles, labels, assignees, and blocking edges to select work, but leaves
the ticket body and all ticket mutations to its worker.

Every agent session claims through the same tracker identity, so an assignee
alone never proves a live session. Treat a claim as live only on evidence: a
worker of this run is running and holds it, the user has said another session
is walking this map, or the ticket carries fresh activity from a session other
than this one. A claim without that evidence is stale residue — from this run's
own earlier turn, a compacted context, or an abandoned walk that stopped
waiting on a user who never answered. The root releases a stale claim itself
and dispatches the ticket; that release is the one ticket mutation the root
performs, and only on a ticket no live worker holds. Track which tickets this
run's workers claim so the run can tell its own orphans from foreign work after
interruption or compaction. That record logs the run's own acts; it is not a
substitute for tracker state, which still decides what is open, blocked, or
assigned.

Create a fresh, isolated subagent for the chosen ticket with no inherited root
turns. If the native lifecycle cannot start an isolated child and later resume
that same child, stop as unsupported before anything claims the ticket. Give
the worker a self-contained work order containing:

- the linked map title and canonical map reference;
- the linked ticket title and identity;
- the target repository and exact working directory when local work is needed;
- the verbatim Run brief;
- an instruction to read the installed Wayfinder skill fully as reference and
  execute only its **Work through the map** branch;
- an instruction to read the target repository instructions and every skill
  named by the map or brief;
- an instruction to claim and verify the ticket before reading its full body;
- the complete discriminated response contract in the next section;
- the boundary: work exactly this ticket and do not choose another.

The worker owns the ticket for its whole lifetime. It performs the complete
Wayfinder **Work through the map** branch: claim, investigation or grilling,
resolution comment, close, map pointer, and any newly surfaced ticket and fog
changes. If its claim loses a race, it returns `race_lost` without working the
ticket; the root reloads the frontier.

For a research ticket, the fresh child invokes `/research` and is itself the
research subagent required by Wayfinder. Research is AFK: a research worker may
return `ticket_resolved`, `race_lost`, or `blocked`, but never
`decision_request`; any decision its findings expose becomes a separate
Wayfinder ticket. Run independent research tickets in parallel when native
slots allow. Keep at most one non-research worker active so only one worker can
hold a pending decision request and its decisions and map edits see the latest
frontier.

The dispatch is complete when the worker has verified its claim or reported a
lost race.

## 3. Drive the worker protocol

Every worker turn returns exactly one of the following discriminated outcomes.
Include this whole contract in its work order.

A decision request costs the run a round trip and may cost the user their
attention, so a worker earns one. Before returning a request, the worker
answers the question itself from the Destination, the Run brief, the map's
Notes, and the evidence it gathered; when those determine an answer, it
decides, records that reasoning and its authority in the resolution comment,
and carries on. Only an undetermined question is raised: one that redraws the
Destination or scope, that is expensive to reverse once later work builds on
it, that turns on a user preference or an external fact no reachable evidence
supplies, or that spends money, credentials, production state, or a public
surface. A question is not undetermined merely because it is important,
architectural, or interesting.

A worker that reaches that bar returns `decision_request` with one question:

```yaml
kind: decision_request
ticket: <linked title>
authority: root-may-decide | human-required
question: <one concrete question>
recommendation: <the worker's recommended answer>
reason: <why this decision is needed now>
alternatives:
  - <a real alternative, when one exists>
consequence: <what the answer makes decidable>
```

`authority` is `human-required` only for an unrecoverable preference or a
real-world commitment — the last two classes above — or when the Run brief
reserves this class of decision to the user. Every other request is
`root-may-decide`.

Every terminal worker outcome uses its matching shape:

```yaml
kind: ticket_resolved
ticket: <linked title>
gist: <one-line resolution>
```

```yaml
kind: race_lost
ticket: <linked title>
reason: <who claimed it or what verification failed>
```

```yaml
kind: blocked
ticket: <linked title>
reason: <the concrete unmet dependency or action>
claim: retained | released
user_action: <the exact requested action when retained; null when released>
```

Before returning `blocked`, the worker retains its claim only when one concrete
pending user response or action will resume this same worker. Otherwise it
releases the claim and verifies the release. The `claim` field reports that
observed postcondition; it is not a request for the root to mutate the ticket.

The worker supplies the question and recommendation but never answers its own
request. A different model context is useful separation, not human authority.
The root resolves authority itself, through the instruction precedence from
Section 1, and answers by default. It re-tests every request against the same
bar the worker was held to rather than deferring to the `authority` field: a
`human-required` on a question the effective instructions determine is
downgraded and answered as `delegated-root`. If the root's own read is that the
recommendation follows from the brief, the Destination, and the evidence, then
that read is the answer — relaying it for agreement buys nothing and spends the
attention the walk exists to save.

The root stops for the user only when the request genuinely clears that bar,
when the Run brief reserves this class of decision to the user, or when the
root cannot determine the answer either. An explicit Run brief restriction
overrides a delegation in map Notes, while Notes may supply delegation when the
brief is silent. When one of those holds, present that single question, the
worker's recommendation, and the root's own read, then wait for the answer.

Return the answer to the same worker:

```yaml
kind: decision_response
authority: delegated-root | confirmed-by-user
answer: <the decision>
constraints: <material qualifications, if any>
```

When the pending item was a retained `user_action`, resume the worker with:

```yaml
kind: action_response
authority: confirmed-by-user
result: <what the user did or why they declined>
```

If an outcome is malformed or its tracker postcondition is false, reject it and
resume the same worker with a correction message:

```yaml
kind: protocol_correction
failed_postcondition: <what was missing or false>
required: <the exact state the worker must establish and re-report>
```

An autonomous root answer is `delegated-root`, never HITL. Only an answer the
user actually supplied is `confirmed-by-user`. The worker records this authority
in its resolution comment. If the worker needs another answer, it returns the
next single request and the root repeats the exchange. Resume the same subagent
for every turn of one ticket so its grilling context stays intact.

The request is mediated when the same worker has received a response with
truthful authority, or the run is visibly waiting on the user.

## 4. Accept outcomes and continue

On `ticket_resolved`, verify the tracker state at low resolution: the ticket is
closed, its resolution exists, and the map contains its Decisions-so-far
pointer. Report the linked title and one-line gist, then reload the map and
continue without waiting for approval.

On `decision_request`, follow the mediation step. On `race_lost`, discard that
worker and reload the frontier. On `blocked`, verify its advertised claim
postcondition. A retained claim requires a concrete `user_action`: present it
and enter **Waiting on the user** without another dispatch. A released claim
is valid only when tracker state also removes that ticket from the frontier,
for example through a newly wired blocker. Reload the frontier and continue
when another ticket exists; if the released ticket is immediately selectable
again, enter **Broken frontier** instead of redispatching it.

The root keeps no private substitute for tracker state. After compaction,
interruption, or another session's concurrent edit, reorient from the canonical
map, active claims, and the verbatim Run brief before continuing.

## 5. Stop at a real terminal state

Continue until one of these conditions is observable:

- **Map clear** — no open child tickets remain and Not yet specified is empty.
  Report the Destination reached and the linked decisions; stop at planning
  unless the Run brief explicitly authorizes the map's next flow.
- **Waiting on the user** — Section 3 requires an actual user answer: a request
  that clears the escalation bar and survives the root's own re-test, a class of
  decision the Run brief reserves to the user, or a `blocked` outcome that
  retained its claim for a concrete `user_action`. One worker holds one claimed
  ticket and one pending decision or action. Ask it and stop the turn; resume
  that same worker when the user replies.
- **Blocked map** — open work remains, but every ticket is blocked or held by a
  claim the Section 2 test finds live, and no worker is running. Report the
  named blocker or claim rather than manufacturing work.
- **Broken frontier** — fog remains but no ticket can advance it, or tracker
  state contradicts the map. Report the inconsistency; do not silently redraw
  the map.
- **Run limit reached** — a budget or stopping rule from the Run brief fires.
  Report the exact stopping condition and leave tracker state resumable.
- **Unsupported harness** — the native subagent lifecycle cannot start a child
  without inherited root turns or resume the same child for a later decision
  response. Stop before dispatch; an external runner is not a fallback.
- **Instruction conflict** — repository instructions, the Run brief, or map
  Notes cannot coexist with the stewardship and isolation invariants. Name the
  conflicting instructions and stop before dispatch.

A terminal state is a fact about the map, not a request for permission. When
the root can establish the state itself — releasing stale residue, rereading
the tracker, requerying the frontier — it does that and keeps walking instead
of stopping to ask the user to do it for it.

The walk is complete only at one of these terminal states; completing one
ticket is progress, not completion.
