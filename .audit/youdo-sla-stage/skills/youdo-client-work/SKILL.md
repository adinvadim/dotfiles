---
name: youdo-client-work
description: "Ship a taken YouDo job, archive a forwarded Telegram chat, or open its project folder."
---

# Client work

Use this when a Deal is taken or the human forwards client correspondence. Hunt and offer stay in `youdo-auto-offer`. YouDo client chat send still needs exact GO.

## 1. Locate the Deal

Read `state/youdo-crm.json`. Key is `task_id`. Funnel labels are Отклик, Получено сообщение, Взято в работу, Выполнено и оплачено.

Done when the Deal exists. If it does not, run `scripts/sync-youdo-crm.zsh` once and stop if still missing.

## 2. Archive forwarded correspondence

Human forwards the client chat into Telegram Desktop. Do not invent a chat id. Do not sweep all dialogs.

```bash
/Users/mini/.local/bin/telecrawl version
/Users/mini/.local/bin/telecrawl --json doctor
scripts/ingest-youdo-telecrawl.zsh <task_id> <chat_id>
```

`--skip-import` only when the chat is already in `~/.telecrawl` and the human said not to import.

Done when stdout has `ok=true` and the Deal has `correspondence.archive_path`. Same chat ingested twice keeps one pointer. Отклик may move to Получено сообщение. No second CRM card.

## 3. Open the project folder

Only when work is taken.

```bash
scripts/record-youdo-crm-transition.zsh <task_id> in_progress
```

Done when `projects/youdo/<task_id>/` exists and the Deal has that `project_path`. Replay reuses the folder. Correspondence staging under `state/correspondence/<task_id>/` moves into `projects/youdo/<task_id>/correspondence/`. Do not mkdir for mere Отклик.

## 4. Ship inside the folder

Write briefs, code, telecrawl exports, and drafts under `projects/youdo/<task_id>/`. Use `exec`, `apply_patch`, `browser`, `web_search`, and `web_fetch`. YouDo live calls stay on `scripts/youdo-exec.zsh`. OpenClaw `browser` is for the client site, not the YouDo profile.

Done when the deliverable lives in that folder and CRM still points at it.

## Guardrails

Safe Deal `--sbr` on every YouDo create. Legal-entity only when the task is `isB2B` / `isManagedB2B`. Telegram stay on account `freelancer`, allowlist Vadim only. Shared telecrawl DB is `~/.telecrawl/telecrawl.db`. Do not build a second archive.
