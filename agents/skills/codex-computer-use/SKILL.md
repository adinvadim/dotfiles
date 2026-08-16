---
name: codex-computer-use
description: "Delegate local browser and desktop UI work to the Codex desktop runtime with native Browser, Chrome, and Computer Use capabilities."
---

# Codex Computer Use

Use Codex as a separate local UI agent for browser interaction, logged-in web sessions, desktop apps, simulators, screenshots, and runtime verification.

## Required invocation

Run Codex through the desktop-runtime wrapper, never bare `codex exec`:

```sh
printf '%s\n' "$PROMPT" | codex-computer-use -
```

The wrapper selects the Codex binary bundled with the ChatGPT/Codex desktop app. That runtime exposes the same bundled Browser, Chrome, Computer Use, and Node REPL capabilities used by the GUI. It intentionally uses full local access because UI control cannot work in the normal CLI sandbox.

Default: no source edits. Put all task context and permissions in one self-contained prompt. Set `CODEX_COMPUTER_USE_CWD` when the working directory differs from Claude's current directory.

## Browser selection

For browser work, tell Codex which native surface to use:

1. Existing Chrome login, tabs, profile, or extensions needed: bundled **Chrome** browser-extension surface.
2. Chrome extension unavailable or unsuitable: bundled **Computer Use** against the already-running `Google Chrome` app.
3. Authentication state irrelevant: bundled in-app **Browser** is acceptable.

Never use `agent-browser`, standalone Playwright, a manually launched Chrome, a copied Chrome profile, `--user-data-dir`, remote-debugging/CDP startup, or direct profile files. Never ask the user to quit Chrome merely because a profile is locked. A profile-lock error means the wrong automation backend was chosen: retry with bundled Chrome or Computer Use while Chrome remains open.

For Computer Use fallback, explicitly say:

- use the bundled `computer-use` skill and its Node REPL runtime;
- target the existing app by `com.google.Chrome` or `Google Chrome`;
- do not close, restart, or relaunch Chrome;
- preserve existing windows, tabs, and logged-in sessions;
- re-read app state after actions and prefer accessibility element indices over coordinates.

## Prompt requirements

Include:

- exact goal and target app/site;
- whether existing Chrome authentication is required;
- allowed side effects and whether source edits are allowed;
- known URLs, launch commands, credentials flow, fixtures, or deep links;
- confirmation boundaries for destructive, financial, account, credential, API-key, 2FA, or representational actions;
- artifact/report paths when screenshots or logs are needed;
- required final result: `pass`, `fail`, or `blocked`, steps performed, observations, artifact paths, and actionable feedback.

Do not ask the user to prepare the browser before trying native Chrome and Computer Use. Ask only for an action Codex truly cannot perform, such as entering a required 2FA code or confirming a risky final action.

## Example: authenticated website

```text
Use the bundled Chrome browser-extension surface first because this task requires the user's existing logged-in Chrome session. If extension connection fails after its documented retry, use bundled Computer Use on the already-running Google Chrome app. Keep Chrome open and preserve all existing windows, tabs, profiles, and sessions. Do not use agent-browser, standalone Playwright/CDP, Chrome profile directories, or launch another Chrome instance. Do not ask the user to quit Chrome because of a profile lock.

[Task and confirmation boundaries here.]
```

## Scope

Do not use this skill for ordinary code reading, linting, typechecking, or tests Claude can run directly. Launching or reading an app is allowed when requested. Follow Codex's native confirmation policy; do not weaken confirmation requirements in the prompt.
