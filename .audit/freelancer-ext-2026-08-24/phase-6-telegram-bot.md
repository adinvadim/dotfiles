# Phase 6. Telegram bot

Back to [overview.md](overview.md).

## Goal

Freelancer DMs the owner on its own bot. Adam is no longer the inbox.

## Changes

Store the token in 1Password and a mode-600 `tokenFile`. Add Telegram account `freelancer` and a specific binding. Point daily-report and YouDo alerts at that account.

## Data structures

Same OpenClaw `channels.telegram.accounts` + `bindings` shape as market/seo.

## Verification

`openclaw health` lists Telegram configured. Binding exists. Token is absent from git. A pairing or allowlist DM path is present for user 91645441.
