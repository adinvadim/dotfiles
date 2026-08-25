#!/bin/zsh
set -euo pipefail

workspace=${YOUDO_WORKSPACE:-/Users/mini/.openclaw/workspace-freelancer}
crm="$workspace/state/youdo-crm.json"
lock_dir="$workspace/state/.youdo-crm.lock"
task_id=${1:-}
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

funnel=$(/usr/bin/jq -r --arg id "$task_id" '.deals[$id].funnel' "$crm")
[[ $funnel == in_progress || $funnel == done_paid ]] || fail_json funnel_not_taken

project_rel="projects/youdo/$task_id"
project_dir="$workspace/$project_rel"
staging="$workspace/state/correspondence/$task_id"
archive_rel="$project_rel/correspondence"

/bin/mkdir -p "$project_dir"
if [[ -d $staging && ! -e $workspace/$archive_rel ]]; then
  /bin/mv "$staging" "$workspace/$archive_rel"
fi
/bin/rmdir "$staging" 2>/dev/null || true

existing_path=$(/usr/bin/jq -r --arg id "$task_id" '.deals[$id].project_path // ""' "$crm")
existing_archive=$(/usr/bin/jq -r --arg id "$task_id" '.deals[$id].correspondence.archive_path // ""' "$crm")
needs_write=false
[[ $existing_path == "$project_rel" ]] || needs_write=true
[[ $existing_archive != state/correspondence/* ]] || needs_write=true

if [[ $needs_write == false ]]; then
  /usr/bin/jq -cn --arg task_id "$task_id" --arg project_path "$project_rel" \
    '{ok:true,task_id:$task_id,project_path:$project_path,idempotent:true}'
  exit 0
fi

now_utc=$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)
tmp_crm=$(/usr/bin/mktemp "$workspace/state/.youdo-crm.XXXXXX")
/usr/bin/jq -e --arg id "$task_id" --arg project_path "$project_rel" --arg archive_rel "$archive_rel" --arg now "$now_utc" '
  .deals[$id].project_path = $project_path
  | if (.deals[$id].correspondence.archive_path // "") | startswith("state/correspondence/") then
      .deals[$id].correspondence.archive_path = $archive_rel
    else . end
  | .deals[$id].updated_at = $now
  | .updated_at = $now
' "$crm" > "$tmp_crm"

/bin/chmod 600 "$tmp_crm"
/bin/mv "$tmp_crm" "$crm"
tmp_crm=
/usr/bin/jq -cn --arg task_id "$task_id" --arg project_path "$project_rel" \
  '{ok:true,task_id:$task_id,project_path:$project_path,idempotent:false}'
