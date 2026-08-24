# Phase 3. Safe Deal

Back to [overview.md](overview.md).

## Goal

Every `offer create` goes out with `--sbr`.

## Changes

`scripts/youdo-exec.zsh` injects `--sbr` for create. The auto-offer skill shows the same flag. No second create path.

## Data structures

Same `OfferPayload.IsSbr`. Wrapper policy, not a new type.

## Verification

Fixture `YOUDO_BIN` echoes argv and must contain `--sbr` even when the caller omitted it or passed `--sbr=false`.
