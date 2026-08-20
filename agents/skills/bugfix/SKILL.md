---
name: bugfix
description: "Confirm a reported bug (description + screenshot), diagnose it, fix it end-to-end."
disable-model-invocation: true
---

# Bugfix

Pipeline for a user's bug report: **confirm → diagnose → fix → prove**. The report is a description plus (usually) a screenshot. Run the phases in order; each gate must pass before the next phase.

## 1 — Intake

The screenshot is the symptom's ground truth. Read it (pasted image or attachment path) and extract every observable: exact error text, the element and its wrong state, visible route/URL, data values, environment hints (viewport, theme, locale).

Restate the bug as one falsifiable claim: "On <route>, <action> shows <actual> instead of <expected>." If report + screenshot can't fill that sentence, ask the user for the one missing piece before touching code.

## 2 — Confirm

Observe the bug yourself before theorizing about it. Reproduce against the real app — invoking this skill authorizes an agent-only dev server. For UI bugs drive it with $agent-browser and capture your own screenshot of the reproduced state.

Confirmed when your repro shows the same observables as Phase 1 — same error text, same element, same wrong value. A nearby-but-different failure is a different bug: note it, keep hunting the reported one.

Cannot confirm after honest attempts → stop and report: what you tried, what you saw instead, most likely explanations (already fixed, env/config drift, data-dependent, misread UI). An unconfirmed bug gets a report, not a fix.

## 3 — Diagnose + fix

Invoke $diagnosing-bugs and follow it end to end; your Phase 2 repro seeds its feedback loop. It owns hypotheses, instrumentation, the fix, and the regression test.

The diagnosis is confident when the mechanism explains every observable from the screenshot and toggling the cause toggles the symptom in the loop. A fix whose mechanism leaves an observable unexplained is a guess — keep diagnosing.

## 4 — Prove + close

- Re-run the Phase 2 repro on the fixed build; capture the after-screenshot as the counterpart to the user's before.
- $autoreview the change; verify and address accepted findings.
- Changelog if user-visible; commit to the current branch.
- Final report: confirmed symptom → root cause (the causal chain, one paragraph) → fix → before/after screenshots + regression test.
