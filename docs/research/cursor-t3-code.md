# Can Cursor IDE use T3 Code as a local OpenAI-compatible backend?

**Short answer: no, not as designed.** T3 Code does not expose an OpenAI-compatible HTTP API (no `/v1/chat/completions`, no `/v1/models`). It exposes exactly one network surface — an internal, authenticated RPC **WebSocket** (`GET /ws`) used by its own web/desktop/mobile clients — and it runs in the *opposite* direction from what the question assumes: T3 Code drives the **Cursor CLI** (`cursor-agent`) as one of its supported coding-agent backends, not the other way around. There is no documented (and, per an empirical check against the user's own running instance, no actual) way to point Cursor IDE's "custom OpenAI" provider slot at a T3 Code server and get useful results.

Below is the evidence, organized by the five questions asked, plus the caveats.

---

## 1. What T3 Code actually is, and which direction the integration goes

T3 Code (`npx t3@latest`, desktop apps, `t3.codes`) is described in its own README as an "agent harness control surface" — a GUI that drives coding-agent CLIs already installed and authenticated on the machine:

> "T3 Code drives provider CLIs; it does not ship them."
> — `docs/user/install.md`

The five built-in provider drivers are `codex`, `claudeAgent`, `cursor`, `grok`, and `opencode` (`docs/internals/providers.md`). For Cursor specifically, the install doc says:

> "Cursor is special: install Cursor CLI so `cursor-agent` is available, then sign in with `agent login` — not `cursor-agent login`. Put the binary on PATH or set Settings → Binary path."
> — `docs/user/install.md`

So "Cursor" in the T3 Code universe means: T3 Code shells out to the locally-installed `cursor-agent` CLI and controls it as one of several interchangeable agent backends. This is the reverse of "Cursor the IDE calls T3 Code as a backend."

Sources:
- `docs/user/install.md` — https://raw.githubusercontent.com/pingdotgg/t3code/main/docs/user/install.md
- `docs/internals/providers.md` — https://raw.githubusercontent.com/pingdotgg/t3code/main/docs/internals/providers.md
- README — https://github.com/pingdotgg/t3code

## 2. T3 Code's network surface: RPC WebSocket, not a REST/OpenAI API

The architecture doc is explicit that clients talk to the server over one RPC channel, not a general HTTP API:

> "\[Clients] talk to it over one authenticated Effect RPC WebSocket." … "`websocketRpcRouteLayer` mounts `GET /ws`." … "Clients never call a provider directly." … "so callers name a thread, not an agent."
> — `docs/internals/overview.md`, `docs/internals/connection-runtime.md`

The connection-runtime internals doc (which specifically documents how connectivity, auth, retries, and transport work) contains **no mention of HTTP routes, listen ports beyond the RPC socket, or any REST/OpenAI-style surface** — confirmed by direct inspection of the doc text.

Orchestration works by RPC commands like `orchestration.dispatchCommand` (start/interrupt a turn, answer approvals, revert a checkpoint, etc.) and `orchestration.subscribeThread` for streaming results back — a bespoke RPC protocol, not Chat Completions/Responses-shaped JSON over REST.

Sources:
- `docs/internals/overview.md` — https://raw.githubusercontent.com/pingdotgg/t3code/main/docs/internals/overview.md
- `docs/internals/connection-runtime.md` — https://raw.githubusercontent.com/pingdotgg/t3code/main/docs/internals/connection-runtime.md

### Empirical confirmation against the user's own running instance

The user's T3 Code desktop backend was already running locally on `http://127.0.0.1:3773`. Direct probes:

```
$ curl -s -m 5 http://127.0.0.1:3773/            -> HTTP 200, returns the SPA's index.html
$ curl -s -m 5 http://127.0.0.1:3773/v1/models    -> same SPA index.html (client-side router catch-all)
```

Both paths return byte-identical SPA markup (the T3 Code web app shell), meaning there is no server-side route handling `/v1/models` or any OpenAI-style path — it just falls through to the client-side router like any unmatched path would. This matches the docs: the only real backend entry point is `GET /ws`.

## 3. Pairing / tokens (for completeness, since they exist but serve a different purpose)

T3 Code's pairing tokens are for **other T3 Code clients** (the hosted web app, another device, a phone) to authenticate to *your* T3 Code server over the RPC WebSocket — not API keys for a Chat Completions-style endpoint.

From `t3 pair --help` (verified locally via `npx t3@latest pair --help`):

```
DESCRIPTION
  Mint a pairing token for a running T3 Code server and print it as a QR code.
FLAGS
  --ttl string                 Token TTL, e.g. `5m`, `1h`, `15 minutes`. Defaults to 5 minutes.
  --label string                Optional label shown in the server's connections list.
  --tailscale                   Publish over Tailscale Serve HTTPS and pair through the tailnet URL.
  --tailscale-serve-port int    HTTPS port for Tailscale Serve when --tailscale is enabled.
```

And from `docs/user/remote-access.md`:

> "Remote access is pairing plus a saved environment. Clients do not start with a long-lived secret." … "one-time owner pairing token" is exchanged; the server then "creates an authenticated session." … "Token stays in the URL hash so the hosted app does not receive it." … "Bind `--host` to a private address (e.g. Tailnet IP), not a public bind, when possible."

This confirms the user's local setup (`npx t3@latest pair --tailscale --tailscale-serve-port 8443 --ttl 1h`, tailnet URL `https://macbook.tail707aa9.ts.net:8443/`, local backend `http://127.0.0.1:3773`) is working exactly as documented — for pairing *T3 Code clients* (phone, browser, another machine's T3 Code UI), not for handing a bearer token to an unrelated OpenAI-compatible HTTP client like Cursor.

Source: `docs/user/remote-access.md` — https://raw.githubusercontent.com/pingdotgg/t3code/main/docs/user/remote-access.md; local CLI help (`npx t3@latest pair --help`, `npx t3@latest --help`).

## 4/5. Answering the requested items directly

1. **Official steps to point Cursor at T3 Code** — none exist. No official T3 Code doc (`docs/user/*.md`, `docs/internals/*.md`) or README section describes exposing T3 Code to an external editor as an API backend. The only editor-facing relationship documented is the reverse one (T3 Code → `cursor-agent` CLI).
2. **URL/base path Cursor should use** — not applicable; there is no `/v1` (or any REST) path on the T3 Code server. The only mounted route besides the SPA/static assets is `GET /ws` (RPC WebSocket, not OpenAI-shaped JSON).
3. **API key / pairing token Cursor needs** — not applicable in the way Cursor expects. T3 Code pairing tokens (`t3 pair`, `t3 auth pairing`) authenticate other T3 Code clients to the RPC WebSocket; they are not bearer tokens for a Chat Completions API, and Cursor has no mechanism to speak T3 Code's RPC protocol.
4. **How to add models** — not applicable; T3 Code doesn't surface "models" to external HTTP clients. Inside T3 Code itself, "models" are whichever provider CLI you've authenticated (Codex, Claude, Cursor, Grok, OpenCode), configured under each provider's Settings entry (e.g., `docs/user/providers-codex.md`, `docs/user/providers-claude.md`).
5. **Known caveats (HTTPS, certs, localhost vs. tailnet)** — these apply to T3 Code's own remote-access feature (pairing other T3 Code UIs over Tailscale Serve HTTPS), not to a hypothetical Cursor integration. Per `docs/user/remote-access.md`: the hosted web app (`app.t3.codes`) requires HTTPS/WSS to talk to a backend (mixed content blocks HTTPS pages from calling plain HTTP/WS backends), so Tailscale Serve (or another TLS terminator) is needed for the hosted UI to reach a LAN/tailnet backend; a bare local `http://127.0.0.1:3773` works fine for same-machine clients (like the desktop app) without TLS.

## Cursor IDE's side: custom OpenAI-compatible endpoints

For completeness, since the second half of the question was about Cursor's own capability: Cursor's official, currently-fetchable docs (`cursor.com/docs`, `cursor.com/help/models-and-usage/api-keys`, `cursor.com/docs/models-and-pricing`) document **bring-your-own-key (BYOK)** for named first-party providers only:

> "Open Cursor Settings > Models," pick a listed vendor (OpenAI, Anthropic, Google, Azure OpenAI, or AWS Bedrock), paste the key, save. "Custom API keys only work with chat models" (Tab completion still uses Cursor's own models). "Cursor's Zero Data Retention policy does not apply when you use your own API keys." Keys are sent per-request for prompt assembly and are not persisted on Cursor's servers.
> — https://cursor.com/help/models-and-usage/api-keys

**I could not find an "Override OpenAI Base URL" control documented in Cursor's current official docs** (checked `cursor.com/docs`, `cursor.com/help/models-and-usage/api-keys`, `cursor.com/docs/models-and-pricing` — none mention overriding the base URL, custom OpenAI-compatible endpoints, or registering arbitrary model IDs). The only place this toggle is attested is Cursor's **community forum** (`forum.cursor.com`), which is not an official docs source and doesn't specify a canonical URL format, TLS requirement, or whether BYOK traffic to a custom base URL is proxied through Cursor's backend or sent directly from the client. Given the instruction to cite primary sources only, I'm flagging this as **unverified against official docs** rather than asserting it as a supported, documented feature. If you want to actually pursue Cursor → arbitrary-local-backend wiring, the accurate official statement is: BYOK is scoped to five named vendors, and there is no documented general-purpose "point Cursor at any OpenAI-compatible URL" flow in the current official docs.

Sources:
- https://cursor.com/help/models-and-usage/api-keys (also mirrored at https://cursor.com/docs/settings/api-keys)
- https://cursor.com/docs/models-and-pricing
- https://cursor.com/docs (sidebar/navigation check)
- Unverified/community-only: https://forum.cursor.com/t/openai-api-and-override-base-url-values/148140 (confirms only that base-URL configuration, if present, is GUI-only — "Cursor Settings > Models" — with no scriptable config; does not confirm URL format or transport details)

## Bottom line / recommendation

Given what T3 Code actually is (a local control surface that *drives* CLI coding agents, including Cursor's own CLI, via an internal RPC WebSocket) there's no wiring to do here — Cursor IDE cannot be pointed at a T3 Code backend because T3 Code doesn't speak the OpenAI Chat Completions/Responses protocol at all, on any path or port. If the goal is "use Cursor's agent smarts from inside T3 Code," that already exists and is a one-time `cursor-agent` install + `agent login`, documented in `docs/user/install.md`. If the goal is "use a local OpenAI-compatible model server from Cursor," that's an unrelated tool (Ollama, LM Studio, litellm, etc. exposing `/v1/chat/completions`) and a separate Cursor BYOK/base-URL question that isn't fully documented in Cursor's current official docs.

## All sources

- T3 Code README — https://github.com/pingdotgg/t3code
- `docs/user/install.md` — https://raw.githubusercontent.com/pingdotgg/t3code/main/docs/user/install.md
- `docs/user/remote-access.md` — https://raw.githubusercontent.com/pingdotgg/t3code/main/docs/user/remote-access.md
- `docs/user/providers-codex.md` — https://raw.githubusercontent.com/pingdotgg/t3code/main/docs/user/providers-codex.md
- `docs/internals/overview.md` — https://raw.githubusercontent.com/pingdotgg/t3code/main/docs/internals/overview.md
- `docs/internals/connection-runtime.md` — https://raw.githubusercontent.com/pingdotgg/t3code/main/docs/internals/connection-runtime.md
- `docs/internals/providers.md` — https://raw.githubusercontent.com/pingdotgg/t3code/main/docs/internals/providers.md
- T3 Code repo docs directory listing (GitHub Contents API) — `docs/user/`, `docs/internals/`, `docs/architecture/`, `docs/operations/` under https://github.com/pingdotgg/t3code/tree/main/docs
- Local CLI help: `npx t3@latest --help`, `npx t3@latest pair --help`, `npx t3@latest serve --help`, `npx t3@latest start --help`, `npx t3@latest connect --help`, `npx t3@latest auth --help` (run on this machine)
- Local empirical probe: `curl http://127.0.0.1:3773/` and `curl http://127.0.0.1:3773/v1/models` against the user's own running T3 Code desktop backend (Alpha app)
- Cursor BYOK docs — https://cursor.com/help/models-and-usage/api-keys
- Cursor models & pricing docs — https://cursor.com/docs/models-and-pricing
- Cursor docs navigation — https://cursor.com/docs
- Cursor community forum (unofficial, cited only to show the base-URL override is GUI-only where it exists) — https://forum.cursor.com/t/openai-api-and-override-base-url-values/148140
