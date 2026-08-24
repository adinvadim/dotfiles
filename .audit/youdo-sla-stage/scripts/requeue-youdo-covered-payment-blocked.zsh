#!/bin/zsh
set -euo pipefail

workspace=${YOUDO_WORKSPACE:-/Users/mini/.openclaw/workspace-freelancer}
operations="$workspace/state/youdo-operations.json"
lock_dir="$workspace/state/.youdo-auto-offer.lock"
lock_owned=false

cleanup() {
  if [[ $lock_owned == true ]]; then
    local owner
    owner=$(/bin/cat "$lock_dir/pid" 2>/dev/null || true)
    if [[ $owner == $$ ]]; then
      /bin/rm -f "$lock_dir/pid" 2>/dev/null || true
      /bin/rmdir "$lock_dir" 2>/dev/null || true
    fi
  fi
}
trap cleanup EXIT INT TERM

fail_json() {
  /usr/bin/jq -cn --arg error "$1" '{ok:false,error:$error,llm_calls:0}'
  exit "${2:-2}"
}

heartbeat() {
  local owner
  owner=$(/bin/cat "$lock_dir/pid" 2>/dev/null || true)
  [[ $owner == $$ ]] || fail_json auto_offer_lock_lost 3
  /usr/bin/touch "$lock_dir"
}

[[ -f $operations ]] || fail_json operations_state_missing
if ! /bin/mkdir "$lock_dir" 2>/dev/null; then
  fail_json auto_offer_busy 3
fi
lock_owned=true
printf '%s\n' $$ > "$lock_dir/pid"
heartbeat

candidates=$(/usr/bin/jq -c '[.tasks | to_entries[]?
  | select(.value.state == "deferred")
  | select(.value.reason == "payment_blocked" or .value.origin_reason == "payment_blocked")
  | .key] | sort_by(tonumber)' "$operations")
candidate_count=$(printf '%s' "$candidates" | /usr/bin/jq 'length')
if (( candidate_count == 0 )); then
  /usr/bin/jq -cn '{ok:true,candidate_count:0,covered_task_ids:[],uncovered_task_ids:[],requeued_count:0,llm_calls:0}'
  exit 0
fi

typeset -a task_ids covered uncovered
task_ids=("${(@f)$(printf '%s' "$candidates" | /usr/bin/jq -r '.[]')}")
covered=()
uncovered=()
for task_id in "${task_ids[@]}"; do
  heartbeat
  if check=$("$workspace/scripts/youdo-exec.zsh" cli --timeout 90s --account personal offer package check "$task_id" --json); then
    check_rc=0
  else
    check_rc=$?
  fi
  heartbeat
  (( check_rc == 0 )) || fail_json package_coverage_check_failed 4
  printf '%s' "$check" | /usr/bin/jq -e --arg task "$task_id" '
    .ok == true and .data.taskId == $task and (.data.covered|type) == "boolean"
  ' >/dev/null || fail_json invalid_package_coverage_result 4
  if [[ $(printf '%s' "$check" | /usr/bin/jq -r '.data.covered') == true ]]; then
    covered+=("$task_id")
  else
    uncovered+=("$task_id")
  fi
done

for task_id in "${covered[@]}"; do
  heartbeat
  if "$workspace/scripts/record-youdo-outcome.zsh" package_recovered "$task_id" >/dev/null; then
    record_rc=0
  else
    record_rc=$?
  fi
  heartbeat
  (( record_rc == 0 )) || fail_json package_requeue_failed 5
done

covered_json=$(printf '%s\n' "${covered[@]}" | /usr/bin/jq -Rsc 'split("\n") | map(select(length > 0))')
uncovered_json=$(printf '%s\n' "${uncovered[@]}" | /usr/bin/jq -Rsc 'split("\n") | map(select(length > 0))')
/usr/bin/jq -cn --argjson candidates "$candidate_count" --argjson covered "$covered_json" --argjson uncovered "$uncovered_json" '
  {ok:true,candidate_count:$candidates,covered_task_ids:$covered,uncovered_task_ids:$uncovered,
   requeued_count:($covered|length),llm_calls:0}
'
