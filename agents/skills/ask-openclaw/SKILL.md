---
name: ask-openclaw
description: "Delegate a task to an OpenClaw coworker agent (seo, editor, dev, finance…) and come back with its reply."
---

# Ask OpenClaw

The crew lives on the `mini` Gateway; this CLI is a paired remote client. One
call is one full agent turn, blocking until the reply lands.

Roster: the `Agents:` line of `openclaw health`. `openclaw agents list` and
`openclaw sessions list` read local config instead of the Gateway and show an
empty `main` — ignore them.

```bash
openclaw --log-level silent agent --agent seo \
  --session-key agent:seo:cc-<topic>-<date> \
  --message "…" --timeout 300
```

- stdout is the reply text verbatim, so `$(…)` captures it. With `--json` read
  `.result.meta.finalAssistantVisibleText`.
- The session key opens its own thread and keeps the work out of the coworker's
  `main` session (the human's Telegram chat). Same key continues the history;
  new topic gets a new key.
- The agent runs on `mini` and cannot see local paths. Send content:
  `--message-file ./brief.md` for a long brief.
- Keep the reply here — `--deliver` posts it into the coworker's Telegram.
- Return the answer with its caveats intact, and name the thread key so the
  human can open it: `openclaw tui agent:seo:<thread>`.
