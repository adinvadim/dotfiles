#!/bin/zsh
set -euo pipefail

workspace=${YOUDO_WORKSPACE:-/Users/mini/.openclaw/workspace-freelancer}
operations="$workspace/state/youdo-operations.json"
ledger="$workspace/state/auto-offer-ledger.json"
policy="$workspace/state/auto-offer-policy.json"
trigger_state="$workspace/state/auto-offer-trigger-state.json"
monitor_state="$workspace/state/youdo-monitor.json"
monitor_history="$workspace/state/youdo-monitor-history.jsonl"
position_state="$workspace/state/youdo-position-reconciliation.json"
scan_job_id=e9fc43fa-4c72-4437-abd8-85e335ed8d8e
monitor_job_id=e00cf9a2-4aa8-44c9-a46e-087efe897684
daily_report_job_id=1008cf2d-34db-48d8-a03c-a1b950b7ee0c
session_record="$HOME/Library/Application Support/youdo/accounts/personal/browser-profile/current.json"
main_lock="$workspace/state/.youdo-auto-offer.lock"
export PATH=/Users/mini/.openclaw/workspace/tools/youdo-cli:/Users/mini/.local/bin:/Users/mini/bin:/opt/homebrew/bin:/usr/bin:/bin
export YOUDO_BROWSER_HEADLESS=1
export AGENT_BROWSER_EXECUTABLE_PATH='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
export AGENT_BROWSER_PROXY=http://127.0.0.1:7897
export AGENT_BROWSER_USER_AGENT='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36'
export AGENT_BROWSER_ARGS=--disable-blink-features=AutomationControlled

[[ -f $operations ]] || exit 2
[[ -f $ledger ]] || exit 2
[[ -f $policy ]] || exit 2
[[ -f $trigger_state ]] || exit 2

now=$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)
now_epoch=$(/bin/date -u +%s)
proxy_ok=false
/usr/bin/nc -z 127.0.0.1 7897 >/dev/null 2>&1 && proxy_ok=true
scan_active=false
scan_lock_age=-1
if [[ -d $main_lock ]]; then
  scan_lock_mtime=$(/usr/bin/stat -f %m "$main_lock" 2>/dev/null || printf 0)
  scan_lock_age=$((now_epoch - scan_lock_mtime))
  scan_lock_owner=$(/bin/cat "$main_lock/pid" 2>/dev/null || true)
  if [[ $scan_lock_owner == <-> ]] && /bin/kill -0 "$scan_lock_owner" 2>/dev/null && (( scan_lock_age >= 0 && scan_lock_age <= 2100 )); then
    scan_active=true
  fi
fi

if [[ $scan_active == true ]]; then
  reconciliation_json=$(/usr/bin/jq -cn '{ok:true,examined:0,reconciled:0,unresolved:0,llm_calls:0,deferred_for_active_scan:true}')
  auth_ok=$(/usr/bin/jq -r '(.technical.auth_ok == true)' "$monitor_state" 2>/dev/null || printf false)
  package_ok=$(/usr/bin/jq -r '(.technical.package_ok == true)' "$monitor_state" 2>/dev/null || printf false)
else
  reconciliation_json=$("$workspace/scripts/reconcile-youdo-ambiguous.zsh") || {
    /usr/bin/jq -cn --argjson reconciliation "${reconciliation_json:-null}" '{ok:false,error:"reconciliation_failed",reconciliation:$reconciliation}'
    exit 4
  }
  auth_json=$(youdo --account personal contractor status --json 2>/dev/null || true)
  auth_ok=$(printf '%s' "$auth_json" | /usr/bin/jq -r '(.ok == true and .data.principalId == "1083331" and .data.verified == true)' 2>/dev/null || printf false)
  package_json=$(youdo --account personal offer package list --json 2>/dev/null || true)
  package_subcategory=$(/usr/bin/jq -er '.active_package_subcategory_id | select(type=="number" and floor==. and .>0)' "$workspace/state/auto-offer-policy.json" 2>/dev/null || printf 0)
  package_ok=$(printf '%s' "$package_json" | /usr/bin/jq -r --argjson subcategory "$package_subcategory" '
      .ok == true and $subcategory > 0
    and any(.data[]?;
      .Status == 1
      and (.PaidPrice|type) == "number" and .PaidPrice > 0
      and .SubcategoryId == $subcategory
      and (.TimeRemain|type) == "number" and .TimeRemain > 0
      and (.OfferCountLimit == null or ((.OfferCountLimit|type) == "number" and .OfferCountLimit > 0 and (.OfferCountRemain|type) == "number" and .OfferCountRemain > 0)))
  ' 2>/dev/null || printf false)
fi
auth_refreshed=false
auth_refresh_deferred=false
auth_state_age=-1
if [[ $auth_ok == true && -f $session_record ]]; then
  profile_dir=$(/usr/bin/jq -er '.profileDir' "$session_record" 2>/dev/null || true)
  if [[ $profile_dir == "$HOME/Library/Application Support/youdo/accounts/personal/browser-profile/"* ]]; then
    verified_state="$profile_dir/agent-browser-state.json"
    if [[ -f $verified_state ]]; then
      state_mtime=$(/usr/bin/stat -f %m "$verified_state")
      auth_state_age=$((now_epoch - state_mtime))
      (( auth_state_age < 0 )) && auth_state_age=0
      if (( auth_state_age > 21600 )); then
        if [[ -d $main_lock ]]; then
          auth_refresh_deferred=true
        else
          refresh_json=$(youdo --account personal auth refresh --json 2>/dev/null || true)
          refresh_ok=$(printf '%s' "$refresh_json" | /usr/bin/jq -r '(.ok == true and .data.principalId == "1083331")' 2>/dev/null || printf false)
          if [[ $refresh_ok == true ]]; then
            auth_refreshed=true
            auth_state_age=0
          else
            auth_ok=false
          fi
        fi
      fi
    fi
  fi
fi
cron_json=$(openclaw cron get "$scan_job_id" --json 2>/dev/null || printf '{}')
monitor_cron_json=$(openclaw cron get "$monitor_job_id" --json 2>/dev/null || printf '{}')
daily_report_cron_json=$(openclaw cron get "$daily_report_job_id" --json 2>/dev/null || printf '{}')
local_hour=$(TZ=Asia/Makassar /bin/date +%H)
if (( 10#$local_hour >= 9 )); then
  expected_report_date=$(TZ=Asia/Makassar /bin/date -v-1d +%Y-%m-%d)
else
  expected_report_date=$(TZ=Asia/Makassar /bin/date -v-2d +%Y-%m-%d)
fi
daily_receipt_path="$workspace/state/youdo-daily-report.json"
daily_receipt=$(/usr/bin/jq -c . "$daily_receipt_path" 2>/dev/null || printf '{}')
daily_artifacts_ok=false
expected_input_path="$workspace/reports/daily/${expected_report_date}.input.json"
expected_packages_path="$workspace/reports/daily/${expected_report_date}.packages.json"
expected_report_path="$workspace/reports/daily/${expected_report_date}.md"
if [[ -f $expected_input_path && -f $expected_packages_path && -f $expected_report_path ]]; then
  input_sha=$(/usr/bin/shasum -a 256 "$expected_input_path" | /usr/bin/awk '{print $1}')
  packages_sha=$(/usr/bin/shasum -a 256 "$expected_packages_path" | /usr/bin/awk '{print $1}')
  report_sha=$(/usr/bin/shasum -a 256 "$expected_report_path" | /usr/bin/awk '{print $1}')
  daily_artifacts_ok=$(printf '%s' "$daily_receipt" | /usr/bin/jq -r \
    --arg date "$expected_report_date" --arg input_sha "$input_sha" --arg packages_sha "$packages_sha" --arg report_sha "$report_sha" \
    --slurpfile input "$expected_input_path" --slurpfile packages "$expected_packages_path" '
      .schema_version == 1 and .report_date == $date and .timezone == "Asia/Makassar"
      and .report_path == ("reports/daily/" + $date + ".md")
      and .input_path == ("reports/daily/" + $date + ".input.json")
      and .packages_path == ("reports/daily/" + $date + ".packages.json")
      and .input_sha256 == $input_sha and .packages_sha256 == $packages_sha and .report_sha256 == $report_sha
      and (.generated_at | fromdateiso8601) > 0
      and .sent_count == $input[0].sent_count and .not_sent_count == $input[0].not_sent_count
      and $input[0].report_date == $date and ($input[0].missing_classification_task_ids|length) == 0
      and $packages[0].ok == true and ($packages[0].data|type) == "array"
      and .purchased_active_tariff_count == ([$packages[0].data[]? | select(
        .Status == 1
        and (.PaidPrice|type) == "number" and .PaidPrice > 0
        and (.TimeRemain|type) == "number" and .TimeRemain > 0
        and (.OfferCountLimit == null or ((.OfferCountLimit|type) == "number" and .OfferCountLimit > 0 and (.OfferCountRemain|type) == "number" and .OfferCountRemain > 0))
      )] | length)
    ' 2>/dev/null || printf false)
fi
deployment_json=$("$workspace/scripts/verify-youdo-deployment.zsh" 2>/dev/null || true)
if ! printf '%s' "$deployment_json" | /usr/bin/jq -se 'length == 1 and (.[0] | type == "object")' >/dev/null 2>&1; then
  deployment_json='{"ok":false,"revision":"unknown","mismatches":["verifier_failed"]}'
fi
position_json=$(/usr/bin/jq -c . "$position_state" 2>/dev/null || /usr/bin/jq -cn '{schema_version:1,updated_at:null,tasks:{}}')

tmp=$(/usr/bin/mktemp "$workspace/state/.youdo-monitor.XXXXXX")
/usr/bin/jq -n \
  --arg now "$now" --argjson now_epoch "$now_epoch" \
  --argjson proxy_ok "$proxy_ok" --argjson auth_ok "$auth_ok" \
  --argjson auth_refreshed "$auth_refreshed" --argjson auth_refresh_deferred "$auth_refresh_deferred" --argjson auth_state_age "$auth_state_age" \
  --argjson package_ok "$package_ok" --argjson scan_active "$scan_active" --argjson scan_lock_age "$scan_lock_age" \
  --arg expected_report_date "$expected_report_date" --argjson daily_receipt "$daily_receipt" --argjson daily_artifacts_ok "$daily_artifacts_ok" \
  --slurpfile operations "$operations" --slurpfile ledger "$ledger" --slurpfile policy "$policy" --slurpfile trigger "$trigger_state" \
  --argjson reconciliation "$reconciliation_json" \
  --argjson cron "$cron_json" --argjson monitor_cron "$monitor_cron_json" --argjson daily_cron "$daily_report_cron_json" --argjson deployment "$deployment_json" --argjson position "$position_json" '
    def epoch($value): try ($value | fromdateiso8601) catch 0;
    def streak($events):
      reduce ($events | reverse[]) as $event
        ({count:0,stopped:false};
          if .stopped then .
          elif $event.outcome == "confirmed" then .count += 1
          else .stopped = true end) | .count;
    ($operations[0]) as $ops
    | ($policy[0].sla_window) as $target
    | ($trigger[0]) as $trigger
    | ($ledger[0]) as $ledger
    | ([$ops.events[]? | select(.resolved_at >= $ops.measurement_started_at)] | sort_by(.resolved_at)) as $events
    | ($events | .[-$target:]) as $window
    | ([$ops.tasks | to_entries[]? | .value | select(.state == "ambiguous")]) as $ambiguous
    | ([$ops.tasks | to_entries[]? | .value | select(.state == "deferred")]) as $deferred
    | ([$ops.tasks | to_entries[]? | .value | select(.state == "retryable")]) as $retryable
    | ([$ops.tasks | to_entries[]? | . as $entry
        | select(.value.reason == "payment_blocked" or .value.origin_reason == "payment_blocked" or .value.reason == "payment_blocked_until_expiry")
        | select(any($ops.payment_blocked_events[]?; .task_id == $entry.key) | not)
        | .key]) as $payment_classification_missing
    | ([$ops.tasks | to_entries[]? | .value | select(.state == "rejected" and .reason == "expertise_mismatch")]) as $expertise_rejected
    | ([$expertise_rejected[] | select(.qualification_review.decision != "uphold")]) as $expertise_review_pending
    | ((($trigger.actionable_task_ids // []) + [$retryable[].task_id]) | unique) as $actionable
    | ([$ops.tasks | to_entries[]? | .value | select(.state == "confirmed")]) as $confirmed_tasks
    | ([$confirmed_tasks[] | select(.provider_position_index == null)]) as $position_unknown
    | ([$position.tasks | to_entries[]? | .value] | sort_by(.last_checked_at) | .[-1] // null) as $latest_position
    | ([ $confirmed_tasks[] as $task | select(
          ($ledger.sent_task_ids | index($task.task_id)) == null
          or ([ $ledger.offers[]? | select(
              .task_id == $task.task_id and .provider_id == $task.offer_id
              and .sent_at == $task.resolved_at
              and .price == $task.price_minor
              and .draft_path == $task.draft_path
              and .text_sha256 == $task.text_sha256
              and .provider_position_index == $task.provider_position_index
              and .offer_position == $task.offer_position
              and .task_offers_count == $task.task_offers_count
            ) ] | length) == 0
        ) ] | length == 0) as $projection_consistent
    | ([ $ops.events[]? | select(.outcome == "confirmed")
          | select(($ops.tasks[.task_id].state // "") != "confirmed" or ($ops.tasks[.task_id].offer_id // "") != (.offer_id // ""))
        ] | length == 0) as $events_consistent
    | ([ $ambiguous[] | select(($now_epoch - epoch(.first_ambiguous_at // .updated_at // "")) > 600) ] | length) as $stale_ambiguous
    | (($now_epoch - epoch($trigger.last_scan_at // "")) | if . < 0 then 0 else . end) as $scan_age
    | (($now_epoch * 1000 - (($cron.lastRunAtMs // 0) + ($cron.lastDurationMs // $cron.state.lastDurationMs // 0))) / 1000 | floor | if . < 0 then 0 else . end) as $cron_age
    | (($now_epoch * 1000 - (($monitor_cron.lastRunAtMs // 0) + ($monitor_cron.lastDurationMs // $monitor_cron.state.lastDurationMs // 0))) / 1000 | floor | if . < 0 then 0 else . end) as $monitor_cron_age
    | ($daily_cron.lastRunAtMs // $daily_cron.state.lastRunAtMs // 0) as $daily_last_run
    | (($now_epoch * 1000 - $daily_last_run) / 1000 | floor | if . < 0 then 0 else . end) as $daily_report_age
    | (((($cron.lastDurationMs // $cron.state.lastDurationMs // 0)) / 1000) | floor) as $cron_duration
    | ($cron.enabled == true
        and $cron.schedule.kind == "cron" and $cron.schedule.expr == "* * * * *" and $cron.schedule.tz == "Asia/Makassar" and ($cron.schedule.staggerMs // 0) == 0
        and $cron.payload.kind == "command"
        and $cron.payload.argv == ["/Users/mini/.openclaw/workspace-freelancer/scripts/run-youdo-auto-offer-if-new.zsh"]
        and $cron.payload.cwd == "/Users/mini/.openclaw/workspace-freelancer"
        and $cron.payload.noOutputTimeoutSeconds == 1900 and $cron.payload.timeoutSeconds == 1950 and $cron.payload.outputMaxBytes == 20000
        and $cron.delivery.mode == "none"
        and $cron.failureAlert.after == 1 and $cron.failureAlert.channel == "telegram" and $cron.failureAlert.to == "91645441"
        and $cron.failureAlert.accountId == "freelancer" and $cron.failureAlert.mode == "announce" and $cron.failureAlert.cooldownMs == 1800000 and ($cron.failureAlert.includeSkipped // false) == false) as $scan_contract_ok
    | ($monitor_cron.enabled == true
        and $monitor_cron.schedule.kind == "cron" and $monitor_cron.schedule.expr == "2-59/5 * * * *" and $monitor_cron.schedule.tz == "Asia/Makassar" and ($monitor_cron.schedule.staggerMs // 0) == 0
        and $monitor_cron.payload.kind == "command"
        and $monitor_cron.payload.argv == ["/Users/mini/.openclaw/workspace-freelancer/scripts/youdo-sla-monitor.zsh"]
        and $monitor_cron.payload.cwd == "/Users/mini/.openclaw/workspace-freelancer"
        and $monitor_cron.payload.noOutputTimeoutSeconds == 90 and $monitor_cron.payload.timeoutSeconds == 120 and $monitor_cron.payload.outputMaxBytes == 20000
        and $monitor_cron.delivery.mode == "none"
        and $monitor_cron.failureAlert.after == 1 and $monitor_cron.failureAlert.channel == "telegram" and $monitor_cron.failureAlert.to == "91645441"
        and $monitor_cron.failureAlert.accountId == "freelancer" and $monitor_cron.failureAlert.mode == "announce" and $monitor_cron.failureAlert.cooldownMs == 1800000 and ($monitor_cron.failureAlert.includeSkipped // false) == false) as $monitor_contract_ok
    | ($daily_cron.enabled == true
        and $daily_cron.declarationKey == "freelancer-youdo-daily-report"
        and $daily_cron.agentId == "freelancer"
        and $daily_cron.schedule.kind == "cron" and $daily_cron.schedule.expr == "0 9 * * *" and $daily_cron.schedule.tz == "Asia/Makassar" and ($daily_cron.schedule.staggerMs // 0) == 0
        and $daily_cron.sessionTarget == "isolated" and $daily_cron.sessionKey == "agent:freelancer:youdo-daily-report"
        and $daily_cron.payload.kind == "command"
        and $daily_cron.payload.argv == ["/Users/mini/.openclaw/workspace-freelancer/scripts/run-youdo-daily-report.zsh"]
        and $daily_cron.payload.cwd == "/Users/mini/.openclaw/workspace-freelancer"
        and $daily_cron.payload.env == {YOUDO_DAILY_REPORT:"1"}
        and $daily_cron.payload.noOutputTimeoutSeconds == 900 and $daily_cron.payload.timeoutSeconds == 900 and $daily_cron.payload.outputMaxBytes == 20000
        and $daily_cron.delivery.mode == "announce" and $daily_cron.delivery.channel == "telegram" and $daily_cron.delivery.to == "91645441" and $daily_cron.delivery.accountId == "freelancer"
        and $daily_cron.failureAlert.after == 1 and $daily_cron.failureAlert.channel == "telegram" and $daily_cron.failureAlert.to == "91645441"
        and $daily_cron.failureAlert.accountId == "freelancer" and $daily_cron.failureAlert.mode == "announce" and $daily_cron.failureAlert.cooldownMs == 21600000 and ($daily_cron.failureAlert.includeSkipped // false) == false) as $daily_report_contract_ok
    | ($daily_last_run > 0
        and ($daily_cron.lastRunStatus // $daily_cron.state.lastRunStatus // "unknown") == "ok"
        and ($daily_cron.lastDeliveryStatus // $daily_cron.state.lastDeliveryStatus // "unknown") == "delivered"
        and $daily_receipt.report_date == $expected_report_date
        and $daily_artifacts_ok) as $daily_report_fresh
    | ($target == 30
        and $ops.schema_version == 1 and $ops.window_size == $target
        and ($ops.tasks|type) == "object" and ($ops.events|type) == "array" and ($ops.payment_blocked_events|type) == "array"
        and epoch($ops.measurement_started_at // "") > 0
        and all($ops.events[]?; (.task_id|type) == "string" and (.outcome|IN("confirmed","missed")) and epoch(.resolved_at // "") > 0)
        and all($ops.payment_blocked_events[]?;
          (.task_id|type) == "string" and (.task_id|test("^[0-9]+$")) and epoch(.occurred_at // "") > 0
          and ((.category_id == null) or ((.category_id|type) == "string" and (.category_id|test("^[1-9][0-9]*$"))))
          and ((.subcategory_id == null) or ((.subcategory_id|type) == "string" and (.subcategory_id|test("^[1-9][0-9]*$"))))
          and (.category_id != null or .subcategory_id != null))) as $state_contract_ok
    | ([ $window[] | select(.outcome == "confirmed") ] | length) as $confirmed
    | ([ $window[] | select(.outcome != "confirmed") ] | length) as $failed
    | (streak($events)) as $streak
    | ($monitor_cron_age <= 450 or ((($cron.lastRunStatus // "unknown") == "ok") and $cron_duration >= 300 and $cron_age <= 150)) as $monitor_fresh
    | (((($cron.lastRunStatus // "ok") == "ok" and $scan_age <= 450 and $cron_age <= 450) or $scan_active)) as $scan_fresh
    | ($proxy_ok and $auth_ok and $auth_state_age >= 0 and $package_ok and ($deployment.ok == true) and $state_contract_ok and ($reconciliation.ok == true) and $projection_consistent and $events_consistent and $stale_ambiguous == 0 and ($payment_classification_missing|length) == 0 and $scan_contract_ok and $monitor_contract_ok and $daily_report_contract_ok and $daily_report_fresh and $scan_fresh and $monitor_fresh) as $technical_healthy
    | {
        schema_version:1,
        checked_at:$now,
        technical:{
          healthy:$technical_healthy,
          proxy_ok:$proxy_ok,
          auth_ok:$auth_ok,
          auth_refreshed:$auth_refreshed,
          auth_refresh_deferred:$auth_refresh_deferred,
          auth_state_age_seconds:$auth_state_age,
          package_ok:$package_ok,
          deployment_ok:($deployment.ok == true),
          deployment_revision:($deployment.revision // "unknown"),
          deployment_mismatches:($deployment.mismatches // []),
          state_contract_ok:$state_contract_ok,
          reconciliation_ok:($reconciliation.ok == true),
          projection_consistent:$projection_consistent,
          events_consistent:$events_consistent,
          stale_ambiguous_count:$stale_ambiguous,
          scan_cron_enabled:($cron.enabled == true),
          scan_cron_contract_ok:$scan_contract_ok,
          monitor_cron_contract_ok:$monitor_contract_ok,
          daily_report_cron_contract_ok:$daily_report_contract_ok,
          daily_report_fresh:$daily_report_fresh,
          daily_report_expected_date:$expected_report_date,
          daily_report_artifacts_ok:$daily_artifacts_ok,
          daily_report_receipt_date:($daily_receipt.report_date // null),
          daily_report_age_seconds:$daily_report_age,
          daily_report_last_status:($daily_cron.lastRunStatus // $daily_cron.state.lastRunStatus // "never"),
          daily_report_last_delivery_status:($daily_cron.lastDeliveryStatus // $daily_cron.state.lastDeliveryStatus // "never"),
          payment_classification_backlog_count:($payment_classification_missing|length),
          scan_active:$scan_active,
          scan_fresh:$scan_fresh,
          scan_lock_age_seconds:$scan_lock_age,
          scan_cron_last_status:($cron.lastRunStatus // "unknown"),
          scan_age_seconds:$scan_age,
          cron_age_seconds:$cron_age,
          monitor_cron_age_seconds:$monitor_cron_age,
          monitor_fresh:$monitor_fresh,
          cron_consecutive_errors:($cron.state.consecutiveErrors // 0)
        },
        sla:{
          window_size:$target,
          sample_size:($window|length),
          confirmed:$confirmed,
          failed:$failed,
          percent:(if ($window|length)==0 then 0 else (($confirmed * 10000 / ($window|length)) | floor / 100) end),
          current_confirmed_streak:$streak,
          target_remaining:([($target - $streak),0] | max),
          gate_30_of_30:(($window|length) == $target and $failed == 0),
          qualification_review_pending_count:($expertise_review_pending|length),
          goal_ready:($technical_healthy and ($window|length) == $target and $failed == 0 and ($ambiguous|length) == 0 and ($deferred|length) == 0 and ($actionable|length) == 0 and ($expertise_review_pending|length) == 0)
        },
        queue:{
          actionable_count:($actionable|length),
          retryable_count:($retryable|length),
          retryable:[ $retryable[] | {task_id,state,reason,updated_at} ],
          expertise_rejected_count:($expertise_rejected|length),
          qualification_review_pending_count:($expertise_review_pending|length),
          qualification_review_pending:[ $expertise_review_pending[] | {task_id,state,reason,resolved_at} ],
          position_unknown_count:($position_unknown|length),
          position_unknown:[ $position_unknown[] | {task_id,offer_id,task_offers_count,resolved_at} ],
          position_enrichment:{
            tracked_count:(($position.tasks // {})|length),
            task_id:($latest_position.task_id // null),
            offer_id:($latest_position.offer_id // null),
            last_checked_at:($latest_position.last_checked_at // null),
            last_result:($latest_position.result // null),
            last_error:($latest_position.last_error // null),
            next_check_at:($latest_position.next_check_at // null)
          },
          ambiguous_count:($ambiguous|length),
          ambiguous:[ $ambiguous[] | {task_id,state,reason,first_ambiguous_at,updated_at} ],
          deferred_count:($deferred|length),
          deferred:[ $deferred[] | {task_id,state,reason,origin_reason,retry_after} ]
        },
        reconciliation:$reconciliation
      }
  ' > "$tmp"
/bin/chmod 600 "$tmp"
/bin/mv "$tmp" "$monitor_state"
history_tmp=$(/usr/bin/mktemp "$workspace/state/.youdo-monitor-history.XXXXXX")
if [[ -f $monitor_history ]]; then
  /usr/bin/tail -n 2015 "$monitor_history" > "$history_tmp"
fi
/usr/bin/jq -c . "$monitor_state" >> "$history_tmp"
/bin/chmod 600 "$history_tmp"
/bin/mv "$history_tmp" "$monitor_history"
/usr/bin/jq -c . "$monitor_state"
"$workspace/scripts/finish-youdo-monitor-run.zsh"
