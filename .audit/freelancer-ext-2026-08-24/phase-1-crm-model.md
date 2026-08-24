# Phase 1. CRM model

Back to [overview.md](overview.md).

## Goal

Encode the four-state funnel as one transition table. Seed deals from confirmed operations.

## Changes

`.audit/youdo-sla-stage/CONTEXT.md` holds terms. `scripts/sync-youdo-crm.zsh` and `scripts/record-youdo-crm-transition.zsh` own the machine. `state/youdo-crm.json` is the write target.

## Data structures

`Deal {task_id, offer_id, category_*, funnel, updated_at}`. Funnel is a linear state machine.

## Verification

`zsh tests/test-youdo-crm.zsh`. Illegal skips fail. Replay is idempotent.
