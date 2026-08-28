---
name: notify-me
description: "Send a Telegram notification."
argument-hint: "<message or notification condition>"
disable-model-invocation: true
---

# Notify me

Send Telegram notifications only because the user explicitly invoked this skill in the current prompt. The invocation text defines what to send and, when attached to a longer task, which events should trigger a message.

For a direct message, send it once. For an event policy such as "on every problem", send one notification as soon as each distinct event is observed. Do not repeat an unchanged event. A resolved event that later recurs is distinct.

Write a concise, self-contained notification with the target or environment, the observed event, the strongest available evidence, and the action being taken. Keep it under Telegram's 4096-character limit. Redact credentials, tokens, cookies, personal data, and secret-bearing command output.

Pass the message on standard input so shell expansion cannot alter observed text:

```sh
python3 ~/.agents/skills/notify-me/scripts/notify.py <<'NOTIFY_ME_MESSAGE'
Production checkout: elevated 5xx rate reached 8.2% at 14:32 UTC. Investigating the API deployment now.
NOTIFY_ME_MESSAGE
```

The command is complete only when it prints `Telegram notification sent`. If delivery fails, report the sanitized error in the main conversation and continue the owning task unless successful notification delivery is its completion condition.

Configuration lives in `~/.env/.secrets`. When it is missing or invalid, ask the user to run this locally before retrying:

```sh
python3 ~/.agents/skills/notify-me/scripts/setup.py
```
