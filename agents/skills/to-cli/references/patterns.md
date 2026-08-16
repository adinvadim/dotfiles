# Reference project patterns

These are boundary patterns, not code templates. Recheck current project files
when one of these repositories is in scope.

## `beget-cli`: documented API control plane

- Build commands around documented provider namespaces and preserve their
  conceptual grouping.
- Keep profiles non-secret. A strict, versioned external `credential_process`
  resolves only the fields a network adapter requests and is never invoked by
  help, local validation, or dry-run.
- Retry reads only. Send mutations once, require confirmation, and distinguish
  a provider rejection from an unknown post-dispatch outcome.
- Stable JSON output and exit classes make the same CLI useful to humans and
  agents.

Primary local references: `README.md`, `docs/CLI_SPEC.md`,
`docs/AUTHENTICATION.md`, and `lib/credential-process.js` in `beget-cli`.

## `regru`: mixed public and private control plane

- Expose a capability matrix rather than pretending every configured account
  has every provider capability.
- Keep private portal operations behind typed browser programs and drift
  probes. Reduce private responses before they cross into command output.
- Authenticate in a dedicated headed browser profile. Stage a new session,
  verify the provider principal, and promote it only on success; preserve the
  old session on cancellation, mismatch, timeout, or drift.
- Require dry-run and confirmation for actions. Reconcile interrupted
  mutations through a bounded read, returning `outcome_unknown` when proof is
  impossible.

Primary local references: `README.md`, `docs/cli-contract.md`,
`docs/profile-secret-contract.md`, `docs/research/auth-tty-safety-contract.md`,
and `docs/research/go-cdp-session-broker-contract.md` in `reg-ru-cli`.

## `diacrawl`: private-web archive

- Separate the auth/session client, provider adapter, transactional crawl
  runner, archive, asset store, and CLI renderer.
- Commit a response page and its next opaque cursor together. An explicit
  completion marker distinguishes a finished collection from a missing
  checkpoint; a crashed run resumes safely.
- Treat completeness as collection-specific and preserve unknown private
  surfaces as unknown. Normalized fields support use; raw responses preserve
  future remapping.
- Store large originals and derived files by content hash outside SQLite, with
  durable database links written only after the bytes are published.

Primary local references: `README.md`, `docs/architecture.md`,
`docs/coverage.md`, and `docs/private-web-api.md` in `diacrawl`.

## `exchangecrawl`: official read-only archive

- Keep independent app identities, configuration, credentials, databases, and
  scheduler jobs even when binaries share one deep archive module.
- Query commands are strictly local. Sync uses bounded windows and pagination,
  overlaps the last checkpoint for late delivery, upserts idempotently, and
  advances final freshness only after all pages succeed.
- Signing, rate limits, pagination, and response normalization belong to the
  provider adapter; crawlkit owns provider-neutral storage, state, config, and
  control metadata.
- `doctor` reports credential presence, not values; `metadata --json` exposes
  `crawlkit.control.v1` for `crawlctl`.

Primary local references: `README.md`, `SPEC.md`, and `CONTEXT.md` in
`exchangecrawl`.

## Combined decision rule

Use direct commands for current state and actions. When research finds any
useful durable collection, history, or user-owned artifact, a crawlkit archive
is the default; the grill may explicitly defer a named collection but does not
silently replace it with ephemeral fetches. A service may need both: one typed
provider adapter can support a live control plane while a separate archive
boundary owns collection sync and local reads.
