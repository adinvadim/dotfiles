# Phase 5. Polling

Back to [overview.md](overview.md).

## Goal

Scan every minute. Keep the empty tick tokenless.

## Changes

Policy `schedule` and the OpenClaw cron expression move to `* * * * *`. Scanner stays ID-only.

## Data structures

Unchanged trigger JSON. `llm_calls` stays 0 when `actionable_task_ids` is empty.

## Verification

Time a live empty scan on mini. Confirm the cron expr after the change. Ask OpenClaw before flipping cadence.
