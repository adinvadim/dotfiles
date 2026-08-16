---
name: npm
description: "npm registry operations with 1Password-backed authentication."
metadata: {"clawdbot":{"emoji":"📦","requires":{"bins":["npm","node","tmux","op","jq"]}}}
---

# npm

Use for npm registry and account tasks: `npm whoami`, package availability, package reservation, publish, organization checks, and auth debugging.

## Authentication

- Read and follow `one-password` first. Never run `op` outside its persistent `op-work` tmux session.
- Default item: `npmjs` in `Service Vault`. Prefer the existing `OP_SERVICE_ACCOUNT_TOKEN`; if it is unavailable, use the `my.1password.com` desktop fallback in the same tmux session.
- The local item uses canonical `username` and `password` fields plus a concealed `registry_token`. Reuse the token while it passes `npm whoami`; if it expires, replace that field or add TOTP to the same item instead of creating another credential item.
- After a TOTP-backed password login, the helpers add or refresh `registry_token` in the same item.
- Keep npm auth in a temporary npmrc. The helpers isolate registry commands from caller-local npm configuration and delete temporary auth files on exit.
- Stop if the item is missing, duplicate credential fields make selection ambiguous, authentication fails, npm denies package access, or a publish target differs from the repository package/version.
- Do not hand-roll 1Password field extraction, npm login, token caching, or OTP handling. Use the scripts in this skill directory.

## Authenticated commands

From a dedicated window in the shared `op-work` tmux session, run:

```bash
scripts/npm-service.sh -- whoami
scripts/npm-service.sh -- access ls-packages
```

Use `--vault`, `--item`, or `--account` only for an explicit override. `--account my.1password.com` forces the desktop path.

## Publishing

From the package root and inside the same tmux window:

```bash
scripts/publish-package.sh
```

The helper verifies identity, refuses an existing version, publishes with a fresh TOTP when required, retries one expired OTP, verifies registry visibility, and cleans authentication files.

## Package reservation

Inside the same tmux window:

```bash
scripts/reserve-packages.sh package-one package-two
```

Use `--dry-run` to validate names without publishing placeholders. For scoped packages, `npm view` can lag after publication; `npm access get status <package>` is the authoritative follow-up check.
