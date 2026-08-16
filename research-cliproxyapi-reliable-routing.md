# CLIProxyAPI + Claude Code: reliable GPT routing

Checked: 2026-07-19. Local versions: CLIProxyAPI `7.2.80`; Claude Code `2.1.207`. Upstream CLIProxyAPI latest: [`v7.2.88`](https://github.com/router-for-me/CLIProxyAPI/releases/tag/v7.2.88). No configuration changed.

## Finding

GPT really runs through Claude Code and CLIProxyAPI. The odd discovered ID is expected proxy behavior, not model substitution:

- CLIProxyAPI serves `/v1/models` in Anthropic format when `Anthropic-Version` or a `claude-cli` User-Agent is present ([server routing](https://github.com/router-for-me/CLIProxyAPI/blob/93d74a890a44802f656d7f39a573916b2611896e/internal/api/server.go#L1178-L1213)).
- Non-Claude IDs are deliberately encoded as `claude-fable-5-dd-<reversed-id>`; requests are decoded before execution ([encoder/decoder](https://github.com/router-for-me/CLIProxyAPI/blob/93d74a890a44802f656d7f39a573916b2611896e/internal/util/claude_model.go#L12-L47), [Claude `/v1/messages` handler](https://github.com/router-for-me/CLIProxyAPI/blob/93d74a890a44802f656d7f39a573916b2611896e/sdk/api/handlers/claude/code_handlers.go#L64-L93)). Thus `gpt-5.6-sol` appears to Claude Code as `claude-fable-5-dd-los-6.5-tpg`, while the proxy routes the decoded native ID to Codex.
- Claude Code officially supports gateway discovery from `/v1/models` when `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1`; discovered entries use `display_name` and authenticate like inference requests ([gateway docs](https://code.claude.com/docs/en/llm-gateway)).

The failure in the screenshot came before inference: the Agent tool rejected native `gpt-5.6-sol(high)` as its invocation parameter, then GPT retried with `opus`, which selected real Opus. CLIProxyAPI never silently switched that GPT request to Opus.

## Strong recommendation: strict GPT overlay

Make `settings-gpt.json` the deterministic profile; keep CLIProxyAPI as transport/model translator. Do not depend on the model recognizing `ccx`, obeying `CLAUDE.md`, or remembering to omit `model`.

Recommended profile values:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:8317",
    "ANTHROPIC_AUTH_TOKEN": "dummy",
    "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY": "1",
    "ANTHROPIC_MODEL": "gpt-5.6-sol(high)",
    "CLAUDE_CODE_SUBAGENT_MODEL": "gpt-5.6-sol(high)",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "gpt-5.6-sol(high)"
  }
}
```

Why this is reliable:

- `ANTHROPIC_MODEL` pins the main session for this settings profile. `ANTHROPIC_BASE_URL` only changes the endpoint, not the answering model ([model configuration](https://code.claude.com/docs/en/model-config)).
- `CLAUDE_CODE_SUBAGENT_MODEL` is the highest-priority subagent selector: it overrides Agent's per-invocation `model`, agent frontmatter, agent-team models, and Workflow agents ([model configuration](https://code.claude.com/docs/en/model-config#environment-variables), [subagent resolution](https://code.claude.com/docs/en/sub-agents#choose-a-model)).
- `ANTHROPIC_DEFAULT_HAIKU_MODEL` prevents background/fast tasks from escaping to Haiku ([environment reference](https://code.claude.com/docs/en/env-vars)).
- These variables exist only in the file passed by `claude-gpt --settings ...`; ordinary `claude` remains unaffected. No special `CLAUDE.md` is needed.

Empirical local proof on Claude Code `2.1.207`: launched GPT with `CLAUDE_CODE_SUBAGENT_MODEL=gpt-5.6-sol(high)`, explicitly instructed the parent to invoke Agent with `model: opus`, and received success. Parent transcript recorded `model: opus`; child transcript recorded `model: gpt-5.6-sol`. Result `modelUsage` contained only `gpt-5.6-sol(high)`. Evidence: [parent transcript](/Users/comp/.claude/projects/-Users-comp-sandbox-dotfiles/1a88b789-781d-4628-a8a0-7f80c6a2d858.jsonl), [child transcript](/Users/comp/.claude/projects/-Users-comp-sandbox-dotfiles/1a88b789-781d-4628-a8a0-7f80c6a2d858/subagents/agent-a331abef3ea7f8c15.jsonl).

Tradeoff: this profile intentionally makes every Agent/Workflow child GPT, even if the parent requests `opus`. For an actual Claude child, use ordinary `claude` or a second profile without `CLAUDE_CODE_SUBAGENT_MODEL`. That separation is mechanical and auditable.

## Why proxy-side per-key routing is not the default answer

- Top-level `api-keys` are a flat ingress allowlist. The built-in provider validates Bearer, `X-Goog-Api-Key`, `X-Api-Key`, or query credentials and returns only principal/source metadata; it does not attach a model/provider policy ([implementation](https://github.com/router-for-me/CLIProxyAPI/blob/93d74a890a44802f656d7f39a573916b2611896e/internal/access/config_access/provider.go#L55-L103)). Different dummy keys therefore do not create different routing profiles.
- OAuth aliases rename models for listing and request routing, but are global per provider channel or per upstream auth, not per inbound client key. Official config warns that overlapping client-visible names are ambiguous and recommends unique aliases/prefixes for strict backend pinning ([config example](https://github.com/router-for-me/CLIProxyAPI/blob/93d74a890a44802f656d7f39a573916b2611896e/config.example.yaml#L405-L452)). `fork` preserves the original alongside the alias; it is not a client-profile switch.
- A plugin ModelRouter can inspect inbound headers/body before provider/auth selection and force a provider/model ([plugin API](https://github.com/router-for-me/CLIProxyAPI/blob/93d74a890a44802f656d7f39a573916b2611896e/sdk/pluginapi/types.go#L524-L578), [host order](https://github.com/router-for-me/CLIProxyAPI/blob/93d74a890a44802f656d7f39a573916b2611896e/internal/pluginhost/model_router.go#L33-L74)). This could implement `X-Profile: ccx`, but it adds custom trusted code and a new failure surface. Current policy plugins are young, and model catalog filtering is not per key. Not recommended for one local GPT profile.
- Running a second proxy instance/config/port is deterministic, but heavier and risks concurrent OAuth-file refresh if both instances share one `auth-dir`. Prefer the client overlay unless independent credentials/auth directories are also used.

## Reloads and versions

- CLIProxyAPI watches `config.yaml` and auth files and hot-reloads them ([SDK docs](https://github.com/router-for-me/CLIProxyAPI/blob/93d74a890a44802f656d7f39a573916b2611896e/docs/sdk-usage.md#L159-L162)). Claude Code settings/env are startup state: restart `ccx` after changing `settings-gpt.json`.
- Upgrade CLIProxyAPI `7.2.80` to `7.2.88` when convenient. Releases after `7.2.80` include OAuth alias display names (`7.2.84`), agent-scoped Codex cache isolation (`7.2.85`), and parallel-tool normalization (`7.2.86`), but none is the routing fix above ([releases](https://github.com/router-for-me/CLIProxyAPI/releases)).
- Upgrade Claude Code `2.1.207` to current `2.1.214` before relying on newer follow-up/resume semantics. Current docs note that before `2.1.211`, resumed subagents could lose the per-invocation model selection; the environment override avoids that class already ([subagent docs](https://code.claude.com/docs/en/sub-agents#choose-a-model), [changelog](https://code.claude.com/docs/en/changelog)).

## Conclusion

Use a strict, ccx-only environment overlay: `ANTHROPIC_MODEL` for the parent, `CLAUDE_CODE_SUBAGENT_MODEL` for every child/Workflow, and `ANTHROPIC_DEFAULT_HAIKU_MODEL` for background calls. This is enforced by Claude Code before the request reaches CLIProxyAPI and has been verified locally against an explicit `model: opus` child request. Keep mixed Claude/GPT work as separate launch profiles; stock CLIProxyAPI API keys and aliases do not provide a reliable per-client policy boundary.
