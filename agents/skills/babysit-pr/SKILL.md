---
name: babysit-pr
description: "Clear every reviewer finding on a PR until the reviewers confirm it's OK."
disable-model-invocation: true
---

# Babysit PR

Loop until every **finding** is **clear**. A finding is a reviewer's request for a change — inline thread, review body, or conversation comment — from a human, Codex, Copilot, or any other review service. CI is `fix ci`. Landing is a separate request.

**Clear** means the author of the finding confirmed it: they resolved the thread, replied accepting the fix, or submitted a later review that no longer requests that change. A push or our reply is a **round**, not clear.

Work on the PR head with a clean tree. Identify the PR from the argument or `gh pr view`. Merged or closed → stop.

## 1 — Census

Collect every finding:

- unresolved `reviewThreads` (GraphQL) — `gh pr view` and conversation comments miss these
- review submissions that request changes
- conversation comments that request a change

Skip our own comments, unpublished (`PENDING`) reviews, and non-finding noise (status bots, merge notes, bare LGTM). Outdated unresolved threads still count.

Census is complete when every finding from every reviewer is labeled **open** or **clear**.

## 2 — Fix the open set

Default is to implement the finding. Ask the user only when it is a product call, contradicts the spec, or looks wrong.

Commit and push to the PR head. Reply on the thread citing the fix (commit + file/line). Leave the thread for the reviewer to clear.

The open set is worked when every open finding has a pushed fix or is blocked on the user.

## 3 — Wait for clear

Poll the census until it moves — a finding clears, or a new finding appears. Sleep on a review cadence (minutes).

Unchanged after a wait: nudge once on still-open threads (fix is on HEAD), then keep polling. Say who's outstanding; stay in the wait until the census is all clear or the user stops.

New findings after a round return to step 2. When the census has no open findings and no reviewer still requests changes, the PR is **clear**. Stop.
