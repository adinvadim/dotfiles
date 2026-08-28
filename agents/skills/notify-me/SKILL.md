---
name: notify-me
description: "Send a Telegram notification."
argument-hint: "<message or notification condition>"
disable-model-invocation: true
---

# Notify me

Treat the invocation text as the notification policy for the current task. A direct message sends once. A condition such as "on every problem" sends once for each newly observed problem, when it happens.

Keep each notification under 800 characters. Start with one useful status emoji such as 🚨, ⚠️, ✅, or ℹ️, then a short heading and only the facts needed to act. Telegram Rich Markdown supports headings, emphasis, code, links, lists, quotes, details, and tables. Use a table only when comparing several values is faster to scan than prose. Redact secrets.

```sh
python3 ~/.agents/skills/notify-me/scripts/notify.py <<'NOTIFY'
## 🚨 Production problem

| Metric | Value |
|---|---:|
| API 5xx | 8.2% |

**Action:** checking the latest deployment.
NOTIFY
```

Delivery is complete when the command prints `Telegram notification sent`. On a configuration error, ask the user to run `python3 ~/.agents/skills/notify-me/scripts/notify.py --setup` locally.
