#!/bin/zsh
set -euo pipefail

workspace=${YOUDO_WORKSPACE:-/Users/mini/.openclaw/workspace-freelancer}
operations="$workspace/state/youdo-operations.json"
report_date=${1:-$(TZ=Asia/Makassar /bin/date -v-1d +%Y-%m-%d)}

fail_json() {
  /usr/bin/jq -cn --arg error "$1" '{ok:false,error:$error,llm_calls:0}'
  exit "${2:-2}"
}

[[ -f $operations ]] || fail_json operations_state_missing
normalized=$(/bin/date -j -f '%Y-%m-%d' "$report_date" '+%Y-%m-%d' 2>/dev/null) || fail_json invalid_report_date
[[ $normalized == $report_date ]] || fail_json invalid_report_date
end_date=$(/bin/date -j -v+1d -f '%Y-%m-%d' "$report_date" '+%Y-%m-%d')
start_utc=$(/bin/date -j -u -f '%Y-%m-%dT%H:%M:%S%z' "${report_date}T00:00:00+0800" '+%Y-%m-%dT%H:%M:%SZ')
end_utc=$(/bin/date -j -u -f '%Y-%m-%dT%H:%M:%S%z' "${end_date}T00:00:00+0800" '+%Y-%m-%dT%H:%M:%SZ')

/usr/bin/jq -cn --arg report_date "$report_date" --arg start "$start_utc" --arg end "$end_utc" --slurpfile state "$operations" '
  ($state[0]) as $ops
  | ([$ops.events[]?
      | select(.outcome == "confirmed" and .resolved_at >= $start and .resolved_at < $end)
      | {task_id,offer_id,resolved_at}]
      | sort_by(.resolved_at,.task_id)) as $sent
  | ([$ops.payment_blocked_events[]?
      | select(.occurred_at >= $start and .occurred_at < $end)
      | . as $blocked
      | select(([ $ops.events[]?
          | select(.task_id == $blocked.task_id and .outcome == "confirmed" and .resolved_at < $end) ] | length) == 0)
      | {
          task_id,occurred_at,category_id,category_name,subcategory_id,subcategory_name,
          display_category:(.subcategory_name // .category_name //
            ("category " + (.category_id // "null") + "/subcategory " + (.subcategory_id // "null")))
        }]
      | unique_by(.task_id)
      | sort_by(.display_category,.task_id)) as $not_sent
  | ([$not_sent
      | group_by([.category_id,.category_name,.subcategory_id,.subcategory_name,.display_category])[]
      | {
          category_id:.[0].category_id,
          category_name:.[0].category_name,
          subcategory_id:.[0].subcategory_id,
          subcategory_name:.[0].subcategory_name,
          display_category:.[0].display_category,
          count:length,
          task_ids:[.[].task_id]
        }]) as $not_sent_by_category
  | ([$ops.tasks | to_entries[]?
      | . as $entry
      | select(.value.reason == "payment_blocked" or .value.origin_reason == "payment_blocked" or .value.reason == "payment_blocked_until_expiry")
      | select(any($ops.payment_blocked_events[]?; .task_id == $entry.key) | not)
      | .key] | sort_by(tonumber)) as $missing
  | {
      ok:true,schema_version:1,report_date:$report_date,timezone:"Asia/Makassar",
      start_utc:$start,end_utc:$end,
      sent_count:($sent|length),sent:$sent,
      not_sent_count:($not_sent|length),not_sent:$not_sent,
      not_sent_by_category:$not_sent_by_category,
      missing_classification_task_ids:$missing,
      llm_calls:0
    }
'
