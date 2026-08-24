#!/bin/zsh
set -euo pipefail

workspace=${YOUDO_WORKSPACE:-/Users/mini/.openclaw/workspace-freelancer}
operations="$workspace/state/youdo-operations.json"
state_file="$workspace/state/auto-offer-trigger-state.json"
lock_dir="$workspace/state/.youdo-auto-offer.lock"
path_prefix=${YOUDO_PATH_PREFIX:-}
export PATH=${path_prefix:+$path_prefix:}/Users/mini/.openclaw/workspace/tools/youdo-cli:/Users/mini/.local/bin:/Users/mini/bin:/opt/homebrew/bin:/usr/bin:/bin

lock_owned=false
cleanup() {
  if [[ $lock_owned == true ]]; then
    /bin/rm -f "$lock_dir/pid" 2>/dev/null || true
    /bin/rmdir "$lock_dir" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

if ! /bin/mkdir "$lock_dir" 2>/dev/null; then
  owner=$(/bin/cat "$lock_dir/pid" 2>/dev/null || true)
  modified=$(/usr/bin/stat -f %m "$lock_dir" 2>/dev/null || printf 0)
  now_epoch=$(/bin/date -u +%s)
  lock_age=$((now_epoch - modified))
  if [[ $owner == <-> ]] && /bin/kill -0 "$owner" 2>/dev/null && (( lock_age < 2400 )); then
    /usr/bin/jq -cn '{ok:true,busy:true,llm_calls:0}'
    exit 0
  fi
  if [[ $owner != <-> ]] && (( lock_age < 5 )); then
    /usr/bin/jq -cn '{ok:true,busy:true,llm_calls:0}'
    exit 0
  fi
  /bin/rm -f "$lock_dir/pid" 2>/dev/null || true
  /bin/rmdir "$lock_dir" 2>/dev/null || {
    /usr/bin/jq -cn '{ok:false,error:"stale_lock_recovery_failed",llm_calls:0}'
    exit 2
  }
  /bin/mkdir "$lock_dir" 2>/dev/null || {
    /usr/bin/jq -cn '{ok:false,error:"lock_reacquire_failed",llm_calls:0}'
    exit 2
  }
fi
lock_owned=true
printf '%s\n' $$ > "$lock_dir/pid"

[[ -f $operations ]] || {
  /usr/bin/jq -cn '{ok:false,error:"operations_state_missing",llm_calls:0}'
  exit 2
}

reconcile_result=$("$workspace/scripts/reconcile-youdo-ambiguous.zsh") || {
  /usr/bin/jq -cn --argjson reconciliation "${reconcile_result:-null}" '{ok:false,error:"reconciliation_failed",reconciliation:$reconciliation,llm_calls:0}'
  exit 2
}

scan_result=$("$workspace/scripts/scan-youdo-new-tasks.zsh")
if [[ $(printf '%s' "$scan_result" | /usr/bin/jq -r '.ok // false') != true ]]; then
  scan_error=$(printf '%s' "$scan_result" | /usr/bin/jq -r '.error // "scanner_failed"')
  /usr/bin/jq -cn --arg error "$scan_error" '{ok:false,error:$error,llm_calls:0}'
  exit 2
fi

current_ids=$(printf '%s' "$scan_result" | /usr/bin/jq -c '.task_ids')
if [[ -x $workspace/scripts/record-youdo-stage-timing.zsh ]]; then
  printf '%s' "$current_ids" | /usr/bin/jq -r '.[]?' | while read -r seen_id; do
    [[ $seen_id == <-> ]] || continue
    if [[ -f $workspace/state/youdo-task-timings.json ]] && /usr/bin/jq -e --arg id "$seen_id" '.tasks[$id].first_seen != null' "$workspace/state/youdo-task-timings.json" >/dev/null; then
      continue
    fi
    "$workspace/scripts/record-youdo-stage-timing.zsh" "$seen_id" detect start >/dev/null || true
    "$workspace/scripts/record-youdo-stage-timing.zsh" "$seen_id" detect end >/dev/null || true
  done
fi

inbox_result='{"ok":true,"new_count":0,"items":[],"chat_send":false}'
inbox_new_count=0
crm_sync='{"ok":true,"deal_count":0,"message_received_count":0}'

run_chat_crm_sync() {
  local timing_ids=${1:-[]}
  if [[ -x $workspace/scripts/record-youdo-stage-timing.zsh ]]; then
    printf '%s' "$timing_ids" | /usr/bin/jq -r '.[]?' | while read -r timed_id; do
      [[ $timed_id == <-> ]] || continue
      "$workspace/scripts/record-youdo-stage-timing.zsh" "$timed_id" chat_crm_sync start >/dev/null || true
    done
  fi
  inbox_result=$("$workspace/scripts/scan-youdo-inbox.zsh") || inbox_result='{"ok":false,"error":"inbox_scan_failed","new_count":0,"items":[],"chat_send":false}'
  if ! printf '%s' "$inbox_result" | /usr/bin/jq -e 'type == "object"' >/dev/null 2>&1; then
    inbox_result='{"ok":false,"error":"invalid_inbox_scan_result","new_count":0,"items":[],"chat_send":false}'
  fi
  inbox_new_count=$(printf '%s' "$inbox_result" | /usr/bin/jq -r '.new_count // 0')
  crm_sync=$("$workspace/scripts/sync-youdo-crm.zsh") || crm_sync='{"ok":false,"error":"crm_sync_failed"}'
  if ! printf '%s' "$crm_sync" | /usr/bin/jq -e 'type == "object"' >/dev/null 2>&1; then
    crm_sync='{"ok":false,"error":"invalid_crm_sync_result"}'
  fi
  if [[ -x $workspace/scripts/record-youdo-stage-timing.zsh ]]; then
    printf '%s' "$timing_ids" | /usr/bin/jq -r '.[]?' | while read -r timed_id; do
      [[ $timed_id == <-> ]] || continue
      "$workspace/scripts/record-youdo-stage-timing.zsh" "$timed_id" chat_crm_sync end >/dev/null || true
    done
  fi
}

now_utc=$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)
actionable_ids=$(/usr/bin/jq -cn --argjson current "$current_ids" --slurpfile state "$operations" --arg now "$now_utc" '
  ($state[0].tasks // {}) as $tasks
  | ([$current[] | tostring | . as $id
      | ($tasks[$id] // null) as $task
      | select(
          $task == null
          or $task.state == "retryable"
          or ($task.state == "deferred" and (($task.retry_after // "1970-01-01T00:00:00Z") <= $now))
        )]) as $feed_actionable
  | ([$tasks | to_entries[]?
        | select(.value.state == "retryable")
        | .key] | sort_by(tonumber) | reverse) as $pending_retryable
  | ([$tasks | to_entries[]?
        | select(.value.state == "deferred" and ((.value.retry_after // "1970-01-01T00:00:00Z") <= $now))
        | .key]) as $due_deferred
  | reduce ($feed_actionable + $pending_retryable + $due_deferred)[] as $id
      ({seen:{},ids:[]};
        if .seen[$id] then . else .seen[$id]=true | .ids += [$id] end)
  | .ids
')
actionable_count=$(printf '%s' "$actionable_ids" | /usr/bin/jq 'length')
batch_size=$(/usr/bin/jq -er '.transport_batch_size | select(type=="number" and floor==. and .>=1 and .<=20)' "$workspace/state/auto-offer-policy.json") || {
  /usr/bin/jq -cn '{ok:false,error:"invalid_transport_batch_size",llm_calls:0}'
  exit 2
}
batch_ids=$(printf '%s' "$actionable_ids" | /usr/bin/jq -c --argjson size "$batch_size" '.[0:$size]')
batch_count=$(printf '%s' "$batch_ids" | /usr/bin/jq 'length')

write_trigger_state() {
  local llm_calls=$1
  local run_error=${2:-}
  local tmp state_now
  state_now=$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)
  tmp=$(/usr/bin/mktemp "$workspace/state/.auto-offer-trigger-state.XXXXXX")
  /usr/bin/jq -cn --arg now "$state_now" --arg error "$run_error" \
    --argjson current "$current_ids" --argjson actionable "$actionable_ids" --argjson llm "$llm_calls" '
      {schema_version:2,last_scan_at:$now,current_task_ids:$current,actionable_task_ids:$actionable,llm_calls_last_run:$llm}
      + (if $llm > 0 then {last_agent_run_at:$now} else {} end)
      + (if $error != "" then {last_error:$error} else {} end)
    ' > "$tmp"
  /bin/chmod 600 "$tmp"
  /bin/mv "$tmp" "$state_file"
}

if (( actionable_count == 0 )); then
  run_chat_crm_sync '[]'
  if ! position_enrichment=$("$workspace/scripts/capture-youdo-offer-position.zsh" 2>/dev/null); then
    position_enrichment=${position_enrichment:-'{"ok":false,"error":"position_enrichment_failed","llm_calls":0}'}
  fi
  if ! printf '%s' "$position_enrichment" | /usr/bin/jq -e 'type == "object"' >/dev/null 2>&1; then
    position_enrichment='{"ok":false,"error":"invalid_position_enrichment_result","llm_calls":0}'
  fi
  inbox_llm=0
  if (( inbox_new_count > 0 )); then
    session_run=$(/bin/date -u +%Y%m%dT%H%M%SZ)-$$
    inbox_message="Inbox YouDo: new_count=$inbox_new_count. Прочитай skills/youdo-inbox-scan/SKILL.md и запиши отчёт владельцу. Не вызывай Адама и не вызывай chat send. Очередь откликов пуста — отклики не создавай."
    cd "$workspace"
    write_trigger_state 1
    if openclaw --log-level silent agent \
      --agent freelancer \
      --session-key "agent:freelancer:youdo-inbox-cron-$session_run" \
      --message "$inbox_message" \
      --thinking low \
      --timeout 900 >/dev/null; then
      inbox_llm=1
    else
      write_trigger_state 1 inbox_agent_run_failed
      current_count=$(printf '%s' "$current_ids" | /usr/bin/jq 'length')
      /usr/bin/jq -cn --argjson current "$current_count" --argjson inbox "$inbox_result" --argjson position "$position_enrichment" \
        '{ok:false,error:"inbox_agent_run_failed",current_count:$current,new_count:0,inbox:$inbox,position_enrichment:$position,llm_calls:1}'
      exit 3
    fi
  else
    write_trigger_state 0
  fi
  current_count=$(printf '%s' "$current_ids" | /usr/bin/jq 'length')
  /usr/bin/jq -cn --argjson current "$current_count" --argjson inbox "$inbox_result" --argjson crm "$crm_sync" --argjson position "$position_enrichment" --argjson llm "$inbox_llm" \
    '{ok:true,current_count:$current,new_count:0,inbox:$inbox,crm:$crm,position_enrichment:$position,llm_calls:$llm}'
  exit 0
fi

id_csv=$(printf '%s' "$batch_ids" | /usr/bin/jq -r 'join(", ")')
session_run=$(/bin/date -u +%Y%m%dT%H%M%SZ)-$$
message="Новые или готовые к retry YouDo task ID: $id_csv. Прочитай skills/youdo-auto-offer/SKILL.md полностью и выполни его в режиме live только для этих ID. Для каждого ID обязательно зафиксируй конечный outcome через scripts/record-youdo-outcome.zsh. Пользователь заранее разрешил автономную отправку; отдельный GO не нужен. Inbox scan и CRM sync выполнятся после этого turn. Не вызывай Адама и не вызывай chat send."


cd "$workspace"
write_trigger_state 1
if ! openclaw --log-level silent agent \
  --agent freelancer \
  --session-key "agent:freelancer:youdo-auto-offer-cron-$session_run" \
  --message "$message" \
  --thinking low \
  --timeout 1800 >/dev/null; then
  write_trigger_state 1 agent_run_failed
  /usr/bin/jq -cn --argjson batch "$batch_count" --argjson queued "$actionable_count" '{ok:false,error:"agent_run_failed",batch_count:$batch,queue_count:$queued,llm_calls:1}'
  exit 3
fi

unresolved=$(/usr/bin/jq -cn --argjson ids "$batch_ids" --slurpfile state "$operations" '
  ($state[0].tasks // {}) as $tasks
  | [$ids[] | tostring | . as $id
      | select(($tasks[$id].state // "") as $outcome
          | (["confirmed","rejected","deferred","ambiguous","missed"] | index($outcome)) == null)]
')
unresolved_count=$(printf '%s' "$unresolved" | /usr/bin/jq 'length')
if (( unresolved_count > 0 )); then
  write_trigger_state 1 agent_left_unresolved_tasks
  /usr/bin/jq -cn --argjson unresolved "$unresolved" \
    '{ok:false,error:"agent_left_unresolved_tasks",unresolved_task_ids:$unresolved,llm_calls:1}'
  exit 4
fi

actionable_ids=$(/usr/bin/jq -cn --argjson ids "$actionable_ids" --slurpfile state "$operations" '
  ($state[0].tasks // {}) as $tasks
  | [$ids[] | tostring | . as $id
      | select(($tasks[$id].state // "") as $outcome
          | (["confirmed","rejected","deferred","ambiguous","missed"] | index($outcome)) == null)]
')
remaining_count=$(printf '%s' "$actionable_ids" | /usr/bin/jq 'length')
run_chat_crm_sync "$batch_ids"
inbox_llm=0
if (( inbox_new_count > 0 )); then
  session_run=$(/bin/date -u +%Y%m%dT%H%M%SZ)-$$
  inbox_message="Inbox YouDo: new_count=$inbox_new_count. Прочитай skills/youdo-inbox-scan/SKILL.md и запиши отчёт владельцу. Не вызывай Адама и не вызывай chat send. Отклики уже обработаны в этом запуске."
  if openclaw --log-level silent agent \
    --agent freelancer \
    --session-key "agent:freelancer:youdo-inbox-cron-$session_run" \
    --message "$inbox_message" \
    --thinking low \
    --timeout 900 >/dev/null; then
    inbox_llm=1
  else
    write_trigger_state 2 inbox_agent_run_failed
    /usr/bin/jq -cn --argjson processed "$batch_count" --argjson inbox "$inbox_result" --argjson crm "$crm_sync" \
      '{ok:false,error:"inbox_agent_run_failed",processed_count:$processed,inbox:$inbox,crm:$crm,llm_calls:2}'
    exit 3
  fi
fi
llm_calls=$((1 + inbox_llm))
write_trigger_state "$llm_calls"
/usr/bin/jq -cn --argjson processed "$batch_count" --argjson remaining "$remaining_count" --argjson queued "$actionable_count" --argjson inbox "$inbox_result" --argjson crm "$crm_sync" --argjson llm "$llm_calls" \
  '{ok:true,processed_count:$processed,remaining_count:$remaining,queue_count:$queued,inbox:$inbox,crm:$crm,llm_calls:$llm}'
