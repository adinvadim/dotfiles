---
name: ask-openclaw
description: "Delegate a task to an OpenClaw coworker agent and bring the answer back."
---

# Ask OpenClaw

Use this to hand a scoped question or task to one of the OpenClaw agents living
on the `mini` Gateway (SEO, editor, dev, finance, …) and return with its reply.
Every call runs one full agent turn on `mini` and blocks until the answer is
ready.

## Prerequisites

The local CLI is a paired remote client: `gateway.mode=remote`,
`gateway.remote.url=wss://mini.tail707aa9.ts.net/`, device approved on `mini`.
Verify with `openclaw health`; `device pairing required` means the device was
revoked and needs `openclaw devices approve <requestId>` on `mini`.

## Roster

`openclaw health` prints the live `Agents:` line. Current crew:

```text
adam            main assistant        seo      SEO
editor          Редакторка            dev      Девелопер
finance         Финбот                market   Маркет
reconciliation  Сварщик               archie   Арчи
outreach        outreach
```

`openclaw agents list` and `openclaw sessions list` read the **local** config
and store, not the Gateway — they will show one empty `main` agent. Ignore them.

## Ask in a dedicated thread

```bash
openclaw agent --agent seo \
  --session-key agent:seo:cc-title-audit-20260820 \
  --message "Прогони SEO-pass по этому заголовку: …" \
  --timeout 300
```

Plain stdout is exactly the agent's reply text, so it captures cleanly:

```bash
answer=$(openclaw --log-level silent agent --agent seo --session-key agent:seo:cc-title-audit-20260820 --message "…")
```

With `--json` the reply is at `.result.meta.finalAssistantVisibleText`; the same
object carries `status`, `runId`, `result.meta.durationMs`, and the model that
answered under `result.meta.executionTrace`.

Session keys are `agent:<id>:<thread>`. Pick a fresh `cc-<topic>-<date>` thread
per task so the coworker's own `main` session (the human's Telegram chat) stays
clean. Reuse the same key for follow-ups — the thread keeps its history.

## Long briefs and files

The agent runs on `mini` and cannot read paths on this machine. Send content,
not paths:

```bash
openclaw agent --agent editor --session-key agent:editor:cc-brief-20260820 --message-file ./brief.md
```

`--message-file` is read locally and capped at 4 MiB.

## Rules

- Never pass `--deliver`: it posts the reply into the coworker's chat channel
  (Telegram) instead of just returning it.
- Default timeout is 600s. Raise `--timeout` for research-sized asks; a blocked
  turn is better than a truncated one.
- `--thinking low|medium|high` and `--model` override the run when the default
  is too cheap or too slow.
- Report the coworker's answer verbatim when it is the deliverable; do not
  paraphrase away its caveats.
- The human can open any thread you created: `openclaw tui agent:seo:<thread>`.
