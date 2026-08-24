# Phase 2. CRM view

Back to [overview.md](overview.md).

## Goal

Show offers, categories, and funnel counts from local state.

## Changes

`scripts/youdo-crm.zsh` prints JSON. Sync also writes `state/youdo-crm.md` for the human.

## Data structures

View is a projection of `youdo-crm.json`. No second store.

## Verification

Fixture with two deals. JSON has both category names and funnel counts.
