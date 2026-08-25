#!/bin/zsh
set -euo pipefail

workspace=${YOUDO_WORKSPACE:-/Users/mini/.openclaw/workspace-freelancer}
crm="$workspace/state/youdo-crm.json"
task_id=${1:-}
chat_id=${2:-}
skip_import=false
telecrawl=${TELECRAWL_BIN:-/Users/mini/.local/bin/telecrawl}

if [[ ${3:-} == --skip-import ]]; then
  skip_import=true
fi

fail_json() {
  /usr/bin/jq -cn --arg error "$1" '{ok:false,error:$error}'
  exit "${2:-2}"
}

[[ $task_id == <-> ]] || fail_json invalid_task_id
[[ -n $chat_id ]] || fail_json invalid_chat_id
[[ -f $crm ]] || fail_json crm_state_missing
/usr/bin/jq -e --arg id "$task_id" '.deals[$id] != null' "$crm" >/dev/null || fail_json deal_missing
[[ -x $telecrawl ]] || fail_json telecrawl_missing

funnel=$(/usr/bin/jq -r --arg id "$task_id" '.deals[$id].funnel' "$crm")
project_path=$(/usr/bin/jq -r --arg id "$task_id" '.deals[$id].project_path // ""' "$crm")
if [[ $funnel == in_progress || $funnel == done_paid || -n $project_path ]]; then
  dest_rel="projects/youdo/$task_id/correspondence"
else
  dest_rel="state/correspondence/$task_id"
fi
dest_dir="$workspace/$dest_rel"
/bin/mkdir -p "$dest_dir"
/bin/chmod 700 "$dest_dir"

if [[ $skip_import == false ]]; then
  "$telecrawl" --json import --chat "$chat_id" --messages-limit 500 >/dev/null
fi

archive_file="$dest_dir/messages.json"
"$telecrawl" --json messages --chat "$chat_id" --limit 500 > "$archive_file"
/bin/chmod 600 "$archive_file"

YOUDO_WORKSPACE="$workspace" "$workspace/scripts/attach-youdo-correspondence.zsh" "$task_id" "$chat_id" "$dest_rel"
