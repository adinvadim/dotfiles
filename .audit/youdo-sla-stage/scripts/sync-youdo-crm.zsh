#!/bin/zsh
set -euo pipefail

workspace=${YOUDO_WORKSPACE:-/Users/mini/.openclaw/workspace-freelancer}
operations="$workspace/state/youdo-operations.json"
crm="$workspace/state/youdo-crm.json"
inbox_pending="$workspace/state/inbox-scan-pending.json"
lock_dir="$workspace/state/.youdo-crm.lock"
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

[[ -f $operations ]] || fail_json operations_state_missing

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

if [[ ! -f $crm ]]; then
  /usr/bin/jq -n '{schema_version:1,updated_at:null,deals:{}}' > "$crm"
  /bin/chmod 600 "$crm"
fi

inbox_items='[]'
if [[ -f $inbox_pending ]]; then
  inbox_items=$(/usr/bin/jq -c '.items // []' "$inbox_pending")
fi

now_utc=$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)
tmp_crm=$(/usr/bin/mktemp "$workspace/state/.youdo-crm.XXXXXX")
/usr/bin/jq -e --arg now "$now_utc" --argjson inbox "$inbox_items" --slurpfile ops "$operations" '
  def seed:
    ($ops[0].tasks // {})
    | to_entries[]
    | select((.value.state == "confirmed" or .value.state == "confirmed_baseline") and ((.value.offer_id // "") | test("^[0-9]+$")))
    | {
        task_id: .key,
        offer_id: (.value.offer_id | tostring),
        category_id: (.value.category_id // null),
        subcategory_id: (.value.subcategory_id // null),
        category_name: (.value.category_name // null),
        subcategory_name: (.value.subcategory_name // null),
        funnel: "offered",
        updated_at: ($now)
      };

  def advance($deal; $items):
    if $deal.funnel != "offered" then $deal
    elif any($items[]?; ((.task_id // "") | tostring) == $deal.task_id) then
      $deal | .funnel = "message_received" | .updated_at = $now
    else $deal end;

  (.deals // {}) as $existing
  | reduce [seed][] as $deal ($existing;
      if .[$deal.task_id] == null then .[$deal.task_id] = $deal
      else
        .[$deal.task_id] = (.[$deal.task_id] + {
          offer_id: $deal.offer_id,
          category_id: (.[$deal.task_id].category_id // $deal.category_id),
          subcategory_id: (.[$deal.task_id].subcategory_id // $deal.subcategory_id),
          category_name: (.[$deal.task_id].category_name // $deal.category_name),
          subcategory_name: (.[$deal.task_id].subcategory_name // $deal.subcategory_name)
        })
      end)
  | reduce to_entries[] as $row ({};
      .[$row.key] = advance($row.value; $inbox))
  | {schema_version:1, updated_at:$now, deals:.}
' "$crm" > "$tmp_crm"

/bin/chmod 600 "$tmp_crm"
/bin/mv "$tmp_crm" "$crm"
tmp_crm=

deal_count=$(/usr/bin/jq '.deals | length' "$crm")
advanced=$(/usr/bin/jq '[.deals[] | select(.funnel == "message_received")] | length' "$crm")
/usr/bin/jq -cn --argjson deals "$deal_count" --argjson advanced "$advanced" '{ok:true,deal_count:$deals,message_received_count:$advanced}'
