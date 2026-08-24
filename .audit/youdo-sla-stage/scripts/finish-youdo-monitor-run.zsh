#!/bin/zsh
set -euo pipefail

workspace=${YOUDO_WORKSPACE:-/Users/mini/.openclaw/workspace-freelancer}
monitor_state="$workspace/state/youdo-monitor.json"
alert_state="$workspace/state/youdo-monitor-alert.json"
repeat_seconds=${YOUDO_MONITOR_REALERT_SECONDS:-21600}

[[ $repeat_seconds == <-> && $repeat_seconds -gt 0 ]] || exit 2
/usr/bin/jq -e '.schema_version == 1 and (.checked_at|type) == "string" and (.technical.healthy|type) == "boolean"' "$monitor_state" >/dev/null || exit 2

checked_at=$(/usr/bin/jq -r '.checked_at' "$monitor_state")
healthy=$(/usr/bin/jq -r '.technical.healthy' "$monitor_state")
previous=$(/usr/bin/jq -c . "$alert_state" 2>/dev/null || /usr/bin/jq -cn '{schema_version:1,active:false}')
tmp=$(/usr/bin/mktemp "$workspace/state/.youdo-monitor-alert.XXXXXX")
cleanup() { [[ ! -f ${tmp:-} ]] || /bin/rm "$tmp"; }
trap cleanup EXIT INT TERM

if [[ $healthy == true ]]; then
  printf '%s' "$previous" | /usr/bin/jq --arg now "$checked_at" '
    .schema_version = 1
    | .last_seen_at = $now
    | if .active == true then .last_recovered_at = $now else . end
    | .active = false
    | .last_exit_was_error = false
    | .pending_fingerprint = null
  ' > "$tmp"
  /bin/chmod 600 "$tmp"
  /bin/mv "$tmp" "$alert_state"
  exit 0
fi

fingerprint_source=$(/usr/bin/jq -Sc '
  .technical
  | {
      proxy_ok,auth_ok,package_ok,deployment_ok,deployment_mismatches,state_contract_ok,
      reconciliation_ok,projection_consistent,events_consistent,stale_ambiguous_count,
      scan_cron_enabled,scan_cron_contract_ok,monitor_cron_contract_ok,daily_report_cron_contract_ok,
      daily_report_fresh,daily_report_expected_date,daily_report_artifacts_ok,daily_report_receipt_date,
      payment_classification_backlog_count,
      auth_state_valid:((.auth_state_age_seconds // -1) >= 0),
      scan_fresh,monitor_fresh
    }
' "$monitor_state")
fingerprint=$(printf '%s' "$fingerprint_source" | /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}')
checked_epoch=$(/bin/date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$checked_at" +%s 2>/dev/null || printf 0)
previous_epoch=$(printf '%s' "$previous" | /usr/bin/jq -r '.last_alerted_at // empty' | xargs -I{} /bin/date -j -u -f '%Y-%m-%dT%H:%M:%SZ' '{}' +%s 2>/dev/null || printf 0)
previous_fingerprint=$(printf '%s' "$previous" | /usr/bin/jq -r '.fingerprint // ""')
previous_active=$(printf '%s' "$previous" | /usr/bin/jq -r '(.active == true)')
previous_exit_was_error=$(printf '%s' "$previous" | /usr/bin/jq -r '(.last_exit_was_error == true)')
alert_candidate=false
if [[ $previous_active != true || $previous_fingerprint != $fingerprint || $checked_epoch -eq 0 || $previous_epoch -eq 0 || $((checked_epoch - previous_epoch)) -ge $repeat_seconds ]]; then
  alert_candidate=true
fi
should_error=false
[[ $alert_candidate != true || $previous_exit_was_error == true ]] || should_error=true

printf '%s' "$previous" | /usr/bin/jq --arg now "$checked_at" --arg fingerprint "$fingerprint" \
  --argjson candidate "$alert_candidate" --argjson should_error "$should_error" '
  .schema_version = 1
  | .active = true
  | .last_seen_at = $now
  | .last_exit_was_error = $should_error
  | if $should_error then
      .fingerprint = $fingerprint
      | .pending_fingerprint = null
      | .last_alerted_at = $now
      | .suppressed_count = 0
    elif $candidate then
      .pending_fingerprint = $fingerprint
      | .suppressed_count = ((.suppressed_count // 0) + 1)
    else
      .pending_fingerprint = null
      | .suppressed_count = ((.suppressed_count // 0) + 1)
    end
' > "$tmp"
/bin/chmod 600 "$tmp"
/bin/mv "$tmp" "$alert_state"
[[ $should_error == false ]] || exit 3
