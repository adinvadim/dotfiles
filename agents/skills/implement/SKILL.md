---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

Implement the work described by the user in the spec or tickets.

Use the workflow function to drive and track the implementation through completion. Parallelize independent work; sequence dependencies.

Use /tdd where possible, at pre-agreed seams.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

Once done, use /autoreview with `--max-priority P3` to review the full implementation. Verify every finding against the code and address accepted in-scope findings before committing.

Commit your work to the current branch.
