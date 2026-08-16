---
name: to-cli
description: "Turn an authorized website or online service into a complete, tested CLI, with a crawlkit archive when durable collections belong in the product."
---

# To CLI

Turn a website or online service into a working CLI. Own the full path from
primary-source research through an approved interface, implementation, tests,
documentation, and a local commit. Publishing and release remain separate.

Use this only for accounts and services the user is authorized to automate.
Read [`references/patterns.md`](references/patterns.md) before research; it
distills the reusable boundaries from `regru`, `beget`, `diacrawl`, and
`exchangecrawl`.

## 1. Establish the workspace

Read repository instructions and run `docs-list` before changing code. Inspect
the package manager, runtime, tests, changelog, current branch, and worktree.
Preserve unrelated changes. For greenfield work, choose a sensible target
directory and create `docs/research/` for the evidence; implementation waits
until the research and grilling gates are complete.

This step is complete when every research worker has one exact repository,
working directory, report path, and non-overlapping question.

## 2. Research in parallel

Invoke `$research` once per track so it launches independent background
subagents; include the target repo and output path in every work order. Run as
many tracks concurrently as available slots allow and queue the rest. Use
primary sources and sanitized observations. At minimum cover these tracks:

1. **Official surface** — first-party docs, OpenAPI/specs, SDK/source, API
   versions, auth, rate limits, pricing, read capabilities, actions, async
   operations, and provider guarantees. A suitable free first-party API is the
   default and may be selected without another permission round trip.
2. **Authenticated web surface** — sign into the in-scope account and use
   `$agent-browser` to inspect the site's network traffic, loaded application
   code, request shapes, CSRF/session behavior, pagination, principal identity,
   contract-drift signals, and CAPTCHA type. Research the current first-party
   2Captcha API needed for a native solver adapter. Record private endpoints as
   observed contracts, not provider promises. Prefer a typed private API to DOM
   scraping.
3. **Data and crawl boundary** — enumerate durable collections, history,
   stable identities, cursors, late-arriving records, binary assets, search
   needs, retention sensitivity, completeness evidence, and unknown surfaces.
   Inspect the current tagged `crawlkit` API and decide what it owns versus the
   provider adapter.
4. **Actions and failure semantics** — map every useful mutation, destructive
   or financial effect, idempotency support, confirmation boundary, retry
   safety, read-after-write reconciliation, and ambiguous outcomes.

The authenticated worker follows the authentication ladder below. It may use
live read-only requests. It does not perform a live mutation merely to discover
its contract; derive it from first-party code/specs or capture an already
authorized human action. Keep credentials, cookies, auth headers, CSRF values,
private response bodies, and account data out of reports.

Wait for all reports, then write `docs/research/to-cli-synthesis.md` with a
capability matrix. Each row identifies the source, official/private status,
free/paid status, auth method, read/action behavior, direct/crawl candidate,
risk, evidence, and confidence. Conflicts and unknowns stay explicit.

This step is complete when every proposed capability and auth path is supported
by primary evidence or labeled unknown, and the crawl decision can be made
without asking the user for facts.

## 3. Grill the product boundary

Run `$grill-me` only after the synthesis exists. Give it the reports and a
prefilled design tree. Keep the interview short: ask only decisions that remain
undetermined by evidence, and give a concrete recommendation for each.

Settle the command name and audience, capability scope, direct-versus-archive
boundary, collection completeness, account model, authentication fallback,
mutation confirmations, output contracts, runtime/distribution, and explicit
deferrals. Do not ask the user to rediscover facts the research agents could
find. Wait until the user confirms shared understanding.

This step is complete when the design tree has no open frontier and every
deferred capability is named.

## 4. Freeze the contracts

Read and apply `$create-cli`; it is the canonical source for the interface.
Write the agreed command tree, arguments and flags, human/`--json`/`--plain`
output, stdout/stderr split, errors and exit codes, prompts, `--no-input`,
`--dry-run`, `--force`, configuration precedence, completion, signals, and
examples to `docs/CLI_SPEC.md` or the repository's established equivalent.

Also record the adapter, auth, and archive contracts needed to make the CLI
spec implementable:

- Direct commands fetch single current values and perform actions.
- Every agreed provider action has an explicit CLI command and documented
  safety semantics; it is not hidden inside sync or a generic request escape
  hatch.
- Durable collections and history use a local-first crawlkit archive. `sync`
  is the explicit network boundary; list, search, show, and export commands are
  local unless their help and contract clearly say otherwise.
- A crawlkit build uses its current tagged Go packages for reusable config,
  SQLite/store, state/checkpoints, output, and control metadata. Provider auth,
  endpoints, schemas, pagination, normalization, retry policy, and completeness
  remain in the application. Prefer one Go binary unless existing constraints
  justify a separate Go component.
- Crawl commands normally include `init`, `doctor`, `sync`, `status`, local
  queries, and `metadata --json` with `crawlkit.control.v1`. Every collection
  has its own checkpoint and completion meaning. Store normalized rows for use
  and lossless raw provider records for remapping; keep binary assets
  content-addressed when present.
- Bounded pagination, transactional page-plus-checkpoint commits, idempotent
  upserts, overlap windows where records can arrive late, explicit degraded
  runs, and resumability are part of the archive contract.
- Mutations are sent once. Dry-run performs no auth or network activity.
  Timeout or interruption after dispatch triggers bounded read-after-write
  reconciliation; unresolved state is `outcome_unknown`, never a blind retry.
- Private APIs live behind typed adapters and bounded drift probes. Contract
  drift fails closed with a stable error instead of guessing through a changed
  endpoint.

This step is complete when a fresh implementation agent can build the product
from the specs and reports without inventing behavior.

## Authentication ladder

Prefer, in order: a suitable free official API, an authenticated first-party
private web API, then DOM extraction only for data unavailable through either
API. Selecting a free first-party interface needs no extra confirmation. Paid
access, plan changes, purchases, or broader account permissions remain explicit
user decisions.

Use `$one-password` for durable credentials. When the agreed capability needs
a free provider credential, provision it with the least sufficient scope
without another chat confirmation round trip. Store newly provisioned API
keys, passwords, and recovery material immediately in `Service Vault`, one
targeted item per service/account. Follow the skill's single persistent
tmux-session workflow and verify fields without printing values. Normal config
stores only non-secret account aliases and credential routing. Prefer a strict,
versioned, bounded `credential_process` that is invoked lazily by network
adapters; never put secret values in flags, command arrays, logs, archives, or
committed files.

Browser cookies and CSRF state remain in an isolated per-account browser/session
store rather than a normal config or archive. Keep local session files private
to the OS user and keep auth objects outside crawler and renderer interfaces.

The product owns a native 2Captcha integration built against its current
first-party API, with no external solver CLI dependency. During setup, use
`$one-password` to resolve the existing 2Captcha credential from `Service
Vault` and configure its targeted credential route without asking the user.
Keep the key behind the same lazy secret boundary as provider credentials.

When an authorized login encounters a supported challenge, the browser/auth
adapter detects its type, sends 2Captcha only the minimum challenge metadata,
polls with a bounded deadline, injects the returned response, and consumes it
before expiry. Never send account credentials, cookies, private page content,
or unrelated user data. Treat unsupported challenges, unsolvable responses,
zero balance, timeout, 2FA, and provider rejection as typed outcomes and use
the `regru`-style human fallback: open a dedicated headed browser, let the user
complete login there, verify the resulting provider principal, then atomically
promote the staged profile. Cancellation, timeout, mismatch, or drift preserves
the previously committed session. Interactive login requires a TTY, honors
`--no-input`, and is never launched implicitly by an ordinary command.

This ladder is complete when every network capability names its credential or
session source, principal check, expiry behavior, and noninteractive failure.

## 5. Implement

Invoke `$implement` with the approved specs, all research reports, and the
reference-project patterns as its work order. Let it drive the implementation,
TDD at agreed seams, continuous typechecking and focused tests, the final full
suite, `/autoreview --max-priority P3`, accepted fixes, documentation,
changelog, and a focused local commit.

Keep provider I/O behind testable adapters. Tests use scripted adapters,
temporary stores, and local HTTP servers; they never depend on live credentials
or mutate a live account. Add contract tests for request signing/auth,
pagination, drift, redaction, native 2Captcha task/poll/injection outcomes, and
ambiguous mutation reconciliation. When crawling, add idempotency, checkpoint,
partial-failure, migration, local-query, and control-manifest tests.

This step is complete only when `$implement` reports its review findings
resolved and the requested product is committed locally.

## 6. Verify the product boundary

Before declaring completion, verify the repository's full prescribed checks
and smoke `--help`, `--version`, human output, JSON success and error envelopes,
plain output, dry-run, noninteractive failures, and secret redaction. Prove
local archive queries make no network or credential calls. Prove mutations are
never automatically retried after dispatch. If crawlkit is used, verify
`doctor`, repeat sync/idempotence, recovery from a failed page, and
`metadata --json` against its schema.

Live verification is read-only unless the user separately authorizes a precise
mutation. Do not publish, push, or release unless asked.

The workflow is complete when the approved CLI exists, checks pass with fresh
evidence, docs match behavior, secrets remain outside the repository, and the
final handoff names the commit plus any provider-contract unknowns.
