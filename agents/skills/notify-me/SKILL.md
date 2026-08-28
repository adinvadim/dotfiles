---
name: notify-me
description: "Send a Telegram notification."
argument-hint: "<message or notification condition>"
disable-model-invocation: true
---

# Notify me

Treat the invocation text as the notification policy for the current task. A direct message sends once. A condition such as "on every problem" sends once for each newly observed problem, when it happens.

Send concise, self-contained text and redact secrets:

```sh
python3 ~/.agents/skills/notify-me/scripts/notify.py <<'NOTIFY'
<message>
NOTIFY
```

Delivery is complete when the command prints `Telegram notification sent`. On a configuration error, ask the user to run `python3 ~/.agents/skills/notify-me/scripts/notify.py --setup` locally.
