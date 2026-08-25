#!/bin/zsh
set -euo pipefail

workspace=${YOUDO_WORKSPACE:-/Users/mini/.openclaw/workspace-freelancer}
crm="$workspace/state/youdo-crm.json"
lock_dir="$workspace/state/.youdo-crm.lock"
task_id=${1:-}
chat_id=${2:-}
archive_path=${3:-}
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
[[ -n $chat_id ]] || fail_json invalid_chat_id
[[ -n $archive_path ]] || fail_json invalid_archive_path

if [[ ${YOUDO_CRM_LOCK_HELD:-0} != 1 ]]; then
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
fi

[[ -f $crm ]] || fail_json crm_state_missing
/usr/bin/jq -e --arg id "$task_id" '.deals[$id] != null' "$crm" >/dev/null || fail_json deal_missing

now_utc=$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)
current=$(/usr/bin/jq -c --arg id "$task_id" '.deals[$id]' "$crm")
same=$(printf '%s' "$current" | /usr/bin/jq -e --arg chat_id "$chat_id" --arg archive_path "$archive_path" '
  (.correspondence.chat_id // "") == $chat_id
  and (.correspondence.archive_path // "") == $archive_path
' >/dev/null && print true || print false)

if [[ $same == true ]]; then
  /usr/bin/jq -cn --arg task_id "$task_id" --arg chat_id "$chat_id" --arg archive_path "$archive_path" \
    '{ok:true,task_id:$task_id,chat_id:$chat_id,archive_path:$archive_path,idempotent:true}'
  exit 0
fi

tmp_crm=$(/usr/bin/mktemp "$workspace/state/.youdo-crm.XXXXXX")
/usr/bin/jq -e --arg id "$task_id" --arg chat_id "$chat_id" --arg archive_path "$archive_path" --arg now "$now_utc" '
  .deals[$id].correspondence = {
    chat_id: $chat_id,
    archive_path: $archive_path,
    fetched_at: $now,
    source: "telecrawl"
  }
  | if .deals[$id].funnel == "offered" then
      .deals[$id].funnel = "message_received"
    else . end
  | .deals[$id].updated_at = $now
  | .updated_at = $now
' "$crm" > "$tmp_crm"

/bin/chmod 600 "$tmp_crm"
/bin/mv "$tmp_crm" "$crm"
tmp_crm=
/usr/bin/jq -cn --arg task_id "$task_id" --arg chat_id "$chat_id" --arg archive_path "$archive_path" \
  '{ok:true,task_id:$task_id,chat_id:$chat_id,archive_path:$archive_path,idempotent:false}'
