---
name: youdo-client-work
description: "Ship a taken YouDo job, archive a named Telegram chat, or open its project folder."
---

# Client work

Use this when a Deal is taken or the human names a client Telegram chat. Hunt and offer stay in `youdo-auto-offer`. `message` talks to Vadim only. Client Telegram and YouDo client chat stay read-only.

## 1. Locate the Deal

Read `state/youdo-crm.json`. Key is `task_id`. Funnel labels are Отклик, Получено сообщение, Взято в работу, Выполнено и оплачено.

Done when the Deal exists. If it does not, run `scripts/sync-youdo-crm.zsh` once and stop if still missing.

## 2. Find the named chat and archive it

Human sends the chat name (`название`). Find it. Prefer an explicit YouDo `task_id` when the human also sent one.

```bash
/Users/mini/.local/bin/telecrawl --json chats --limit 5000
scripts/ingest-youdo-telecrawl.zsh --query '<название>' --task-id <task_id>
```

Exact title wins. One substring match is enough. Zero matches stop. Two or more matches stop and list `{jid,name}` candidates to Vadim via `message`. `--chat-id` is an escape hatch only.

`--skip-import` only when the chat is already in `~/.telecrawl` and the human said not to import.

Done when stdout has `ok=true` and the Deal has `correspondence.archive_path`. Same resolved chat attaches once. Отклик may move to Получено сообщение. No second CRM card. Folder still only after `Взято в работу`.

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
