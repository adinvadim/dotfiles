#!/bin/zsh
set -euo pipefail

workspace=${YOUDO_WORKSPACE:-/Users/mini/.openclaw/workspace-freelancer}
timings="$workspace/state/youdo-task-timings.json"
lock_dir="$workspace/state/.youdo-task-timings.lock"
lock_owned=false
tmp_timings=

cleanup() {
  [[ -z ${tmp_timings:-} ]] || /bin/rm -f "$tmp_timings" 2>/dev/null || true
  if [[ $lock_owned == true ]]; then
    /bin/rm -f "$lock_dir/pid" 2>/dev/null || true
    /bin/rmdir "$lock_dir" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

fail_json() {
  /usr/bin/jq -cn --arg error "$1" '{ok:false,error:$error}'
  exit "${2:-2}"
}

task_id=${1:-}
stage=${2:-}
action=${3:-}
[[ $task_id == <-> ]] || fail_json invalid_task_id
case $stage in
  detect|hydrate|tariff|create|verify|publish_confirm|chat_crm_sync) ;;
  *) fail_json invalid_stage ;;
esac
[[ $action == start || $action == end ]] || fail_json invalid_action

if /bin/mkdir "$lock_dir" 2>/dev/null; then
  lock_owned=true
  printf '%s\n' $$ > "$lock_dir/pid"
else
  owner=$(/bin/cat "$lock_dir/pid" 2>/dev/null || true)
  modified=$(/usr/bin/stat -f %m "$lock_dir" 2>/dev/null || printf 0)
  now_epoch=$(/bin/date -u +%s)
  lock_age=$((now_epoch - modified))
  if [[ $owner == <-> ]] && /bin/kill -0 "$owner" 2>/dev/null && (( lock_age < 120 )); then
    fail_json timings_state_busy 3
  fi
  /bin/rm -f "$lock_dir/pid" 2>/dev/null || true
  /bin/rmdir "$lock_dir" 2>/dev/null || fail_json timings_state_busy 3
  /bin/mkdir "$lock_dir" 2>/dev/null || fail_json timings_state_busy 3
  lock_owned=true
  printf '%s\n' $$ > "$lock_dir/pid"
fi

if [[ ! -f $timings ]]; then
  /usr/bin/jq -n '{schema_version:1,updated_at:null,tasks:{}}' > "$timings"
  /bin/chmod 600 "$timings"
fi

now=$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)
tmp_timings=$(/usr/bin/mktemp "$workspace/state/.youdo-task-timings.XXXXXX")

if [[ $action == start ]]; then
  /usr/bin/jq --arg task "$task_id" --arg stage "$stage" --arg now "$now" '
    .schema_version = 1
    | .updated_at = $now
    | .tasks[$task] = (
        (.tasks[$task] // {task_id:$task,first_seen:$now,stages:{}})
        | .task_id = $task
        | .first_seen = (.first_seen // $now)
        | .stages[$stage] = {started_at:$now}
      )
  ' "$timings" > "$tmp_timings"
else
  /usr/bin/jq --arg task "$task_id" --arg stage "$stage" --arg now "$now" '
    def secs($start; $end):
      (($end | fromdateiso8601) - ($start | fromdateiso8601));
    .schema_version = 1
    | .updated_at = $now
    | .tasks[$task] = (
        (.tasks[$task] // {task_id:$task,first_seen:$now,stages:{}})
        | .task_id = $task
        | .first_seen = (.first_seen // $now)
        | .stages[$stage] = (
            (.stages[$stage] // {started_at:$now})
            | .ended_at = $now
            | .duration_s = secs(.started_at; $now)
          )
        | if $stage == "publish_confirm" and (.first_seen|type)=="string" then
            .detect_to_publish_s = secs(.first_seen; $now)
          else .
          end
      )
  ' "$timings" > "$tmp_timings"
fi

/usr/bin/jq -e '.schema_version == 1 and (.tasks|type)=="object"' "$tmp_timings" >/dev/null
/bin/chmod 600 "$tmp_timings"
/bin/mv "$tmp_timings" "$timings"
tmp_timings=

/usr/bin/jq -cn --arg task "$task_id" --arg stage "$stage" --arg action "$action" --slurpfile state "$timings" '
  ($state[0].tasks[$task]) as $row
  | {
      ok:true,
      task_id:$task,
      stage:$stage,
      action:$action,
      first_seen:$row.first_seen,
      duration_s:($row.stages[$stage].duration_s // null),
      detect_to_publish_s:($row.detect_to_publish_s // null)
    }
'
