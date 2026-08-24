#!/bin/zsh
set -euo pipefail

workspace=${YOUDO_WORKSPACE:-/Users/mini/.openclaw/workspace-freelancer}
crm="$workspace/state/youdo-crm.json"
lock_dir="$workspace/state/.youdo-crm.lock"
task_id=${1:-}
next_funnel=${2:-}
lock_owned=false
tmp_crm=

cleanup() {
  [[ -z ${tmp_crm:-} ]] || /bin/rm -f "$tmp_crm" 2>/dev/null || true
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

[[ $task_id == <-> ]] || fail_json invalid_task_id
[[ $next_funnel == offered || $next_funnel == message_received || $next_funnel == in_progress || $next_funnel == done_paid ]] || fail_json invalid_funnel_state

if /bin/mkdir "$lock_dir" 2>/dev/null; then
  lock_owned=true
  printf '%s\n' $$ > "$lock_dir/pid"
else
  owner=$(/bin/cat "$lock_dir/pid" 2>/dev/null || true)
  modified=$(/usr/bin/stat -f %m "$lock_dir" 2>/dev/null || printf 0)
  now_epoch=$(/bin/date -u +%s)
  lock_age=$((now_epoch - modified))
  if [[ $owner == <-> ]] && /bin/kill -0 "$owner" 2>/dev/null && (( lock_age < 120 )); then
    fail_json crm_state_busy 3
  fi
  /bin/rm -f "$lock_dir/pid" 2>/dev/null || true
  /bin/rmdir "$lock_dir" 2>/dev/null || fail_json crm_state_busy 3
  /bin/mkdir "$lock_dir" 2>/dev/null || fail_json crm_state_busy 3
  lock_owned=true
  printf '%s\n' $$ > "$lock_dir/pid"
fi

[[ -f $crm ]] || fail_json crm_state_missing
/usr/bin/jq -e --arg id "$task_id" '.deals[$id] != null' "$crm" >/dev/null || fail_json deal_missing

current=$(/usr/bin/jq -r --arg id "$task_id" '.deals[$id].funnel' "$crm")
if [[ $current == "$next_funnel" ]]; then
  /usr/bin/jq -cn --arg task_id "$task_id" --arg funnel "$next_funnel" '{ok:true,task_id:$task_id,funnel:$funnel,idempotent:true}'
  exit 0
fi

now_utc=$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)
tmp_crm=$(/usr/bin/mktemp "$workspace/state/.youdo-crm.XXXXXX")
if ! /usr/bin/jq -e --arg id "$task_id" --arg next "$next_funnel" --arg now "$now_utc" '
  def rank:
    if . == "offered" then 0
    elif . == "message_received" then 1
    elif . == "in_progress" then 2
    elif . == "done_paid" then 3
    else -1 end;
  (.deals[$id].funnel | rank) as $from
  | ($next | rank) as $to
  | select($from >= 0 and $to == ($from + 1))
  | .deals[$id].funnel = $next
  | .deals[$id].updated_at = $now
  | .updated_at = $now
' "$crm" > "$tmp_crm"; then
  fail_json illegal_funnel_transition
fi

/bin/chmod 600 "$tmp_crm"
/bin/mv "$tmp_crm" "$crm"
tmp_crm=
/usr/bin/jq -cn --arg task_id "$task_id" --arg funnel "$next_funnel" '{ok:true,task_id:$task_id,funnel:$funnel,idempotent:false}'
