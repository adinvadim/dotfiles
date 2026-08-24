# Freelancer extension 2026-08-24

## Context

The freelancer employee already scans YouDo every five minutes and sends package-covered offers. The owner needs a local deal list, Safe Deal on every offer, a restored legal-entity name path, faster cheap polling, and a private Telegram bot that is not Adam.

## Scope

Included: local CRM view and funnel, `--sbr` always, legal-entity restore if the existing path is found, one-minute tokenless scan, freelancer Telegram account.

Excluded: SaaS CRM, buying YouDo packages, sending customer chat without GO, a second offer-create mechanism.

## Constraints

Work lives in `.audit/youdo-sla-stage` and deploys to `/Users/mini/.openclaw/workspace-freelancer`. Secrets stay in 1Password and mode-600 token files. No push. No human-facing dev server.

## Alternatives

A hosted CRM. Rejected. The operations file already holds confirmed offers.

A new offer API for company name. Rejected until the existing YouDo path is found.

Polling by dumping cards into the model every tick. Rejected. The scanner already returns IDs only.

## Applicable skills

how, writing-for-agents, unslop, domain-modeling, ask-openclaw, one-password, show-me-your-work.

## Phases

- [phase-1-crm-model.md](phase-1-crm-model.md)
- [phase-2-crm-view.md](phase-2-crm-view.md)
- [phase-3-safe-deal.md](phase-3-safe-deal.md)
- [phase-4-legal-entity.md](phase-4-legal-entity.md)
- [phase-5-polling.md](phase-5-polling.md)
- [phase-6-telegram-bot.md](phase-6-telegram-bot.md)
- [testing.md](testing.md)

## Verification

`zsh .audit/youdo-sla-stage/tests/verify-youdo-stage.zsh` plus live mini checks: `openclaw health`, cron get, CRM JSON, offer create `--sbr` dry-run shape.

## Implementation guidance

Use the how skill before editing the live trigger. Unslop every skill and reply. Keep a decision trail at `.audit/freelancer-ext-2026-08-24/decisions.tsv`. Do not open a PR unless asked.
