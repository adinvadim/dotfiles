#!/bin/zsh
set -euo pipefail

workspace=${YOUDO_WORKSPACE:-/Users/mini/.openclaw/workspace-freelancer}
manifest="$workspace/state/youdo-deployment-manifest.json"

fail_json() {
  /usr/bin/jq -cn --arg error "$1" '{ok:false,revision:"unknown",mismatches:[$error]}'
  exit 2
}

[[ -f $manifest ]] || fail_json manifest_missing
revision=$(/usr/bin/jq -er '.revision | select(type=="string" and test("^[a-z0-9._-]+$"))' "$manifest") || fail_json invalid_manifest_revision
source_commit=$(/usr/bin/jq -er '.source_commit | select(type=="string" and test("^[0-9a-f]{40}$"))' "$manifest") || fail_json invalid_source_commit
required_artifacts='["cli","scripts/build-youdo-daily-report-input.zsh","scripts/capture-youdo-offer-position.zsh","scripts/finalize-youdo-sbr-offer.zsh","scripts/finish-youdo-monitor-run.zsh","scripts/reconcile-youdo-ambiguous.zsh","scripts/record-youdo-crm-transition.zsh","scripts/record-youdo-outcome.zsh","scripts/requeue-youdo-covered-payment-blocked.zsh","scripts/run-youdo-auto-offer-if-new.zsh","scripts/run-youdo-daily-report.zsh","scripts/scan-youdo-inbox.zsh","scripts/scan-youdo-new-tasks.zsh","scripts/sync-youdo-crm.zsh","scripts/verify-youdo-deployment.zsh","scripts/write-youdo-daily-report.zsh","scripts/youdo-crm.zsh","scripts/youdo-exec.zsh","scripts/youdo-sla-monitor.zsh","skills/youdo-auto-offer/SKILL.md","skills/youdo-daily-report/SKILL.md","skills/youdo-opportunity-scout/SKILL.md","state/auto-offer-policy.json"]'
/usr/bin/jq -e --argjson required "$required_artifacts" '
  (.artifacts|type) == "object"
  and ((.artifacts|keys|sort) == ($required|sort))
  and all(.artifacts[]; type == "string" and test("^[0-9a-f]{64}$"))
' "$manifest" >/dev/null || fail_json invalid_artifact_manifest

typeset -a mismatches
mismatches=()
while IFS=$'\t' read -r artifact expected_sha; do
  if [[ $artifact == cli ]]; then
    artifact_path=/Users/mini/.local/bin/youdo
  elif [[ $artifact == scripts/* || $artifact == skills/* || $artifact == state/* ]]; then
    artifact_path="$workspace/$artifact"
  else
    mismatches+=("invalid:$artifact")
    continue
  fi
  if [[ ! -f $artifact_path ]]; then
    mismatches+=("missing:$artifact")
    continue
  fi
  actual_sha=$(/usr/bin/shasum -a 256 "$artifact_path" | /usr/bin/awk '{print $1}')
  [[ $actual_sha == $expected_sha ]] || mismatches+=("hash:$artifact")
done < <(/usr/bin/jq -r '.artifacts | to_entries[] | [.key,.value] | @tsv' "$manifest")

/usr/bin/jq -cn --arg revision "$revision" --arg source_commit "$source_commit" --args '
  {ok:($ARGS.positional|length == 0),revision:$revision,source_commit:$source_commit,mismatches:$ARGS.positional}
' -- "${mismatches[@]}"
(( ${#mismatches} == 0 )) || exit 3
