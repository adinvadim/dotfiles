#!/bin/zsh
set -euo pipefail

workspace=${YOUDO_WORKSPACE:-/Users/mini/.openclaw/workspace-freelancer}
operations="$workspace/state/youdo-operations.json"
position_state="$workspace/state/youdo-position-reconciliation.json"
lock_dir="$workspace/state/.youdo-position-reconciliation.lock"
wrapper="$workspace/scripts/youdo-exec.zsh"
recorder="$workspace/scripts/record-youdo-outcome.zsh"
lock_owned=false

cleanup() {
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
[[ -x $wrapper ]] || fail_json wrapper_missing
[[ -x $recorder ]] || fail_json recorder_missing

if ! /bin/mkdir "$lock_dir" 2>/dev/null; then
  owner=$(/bin/cat "$lock_dir/pid" 2>/dev/null || true)
  modified=$(/usr/bin/stat -f %m "$lock_dir" 2>/dev/null || printf 0)
  now_epoch=$(/bin/date -u +%s)
  lock_age=$((now_epoch - modified))
  if [[ $owner == <-> ]] && /bin/kill -0 "$owner" 2>/dev/null && (( lock_age < 720 )); then
    /usr/bin/jq -cn '{ok:true,busy:true,examined:0,captured:0,unresolved:0,llm_calls:0}'
    exit 0
  fi
  if [[ $owner != <-> ]] && (( lock_age < 2 )); then
    /usr/bin/jq -cn '{ok:true,busy:true,examined:0,captured:0,unresolved:0,llm_calls:0}'
    exit 0
  fi
  /bin/rm -f "$lock_dir/pid" 2>/dev/null || true
  /bin/rmdir "$lock_dir" 2>/dev/null || fail_json position_lock_busy 3
  /bin/mkdir "$lock_dir" 2>/dev/null || fail_json position_lock_busy 3
fi
lock_owned=true
printf '%s\n' $$ > "$lock_dir/pid"

if [[ ! -f $position_state ]]; then
  initial=$(/usr/bin/mktemp "$workspace/state/.youdo-position-reconciliation.XXXXXX")
  /usr/bin/jq -cn '{schema_version:1,updated_at:null,tasks:{}}' > "$initial"
  /bin/chmod 600 "$initial"
  /bin/mv "$initial" "$position_state"
fi
/usr/bin/jq -e '.schema_version == 1 and (.tasks|type) == "object"' "$position_state" >/dev/null || fail_json invalid_position_state

now_utc=$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)
candidate=$(/usr/bin/jq -c --arg now "$now_utc" --slurpfile position "$position_state" '
  [.tasks | to_entries[]? | .value
    | select(.state == "confirmed" and .provider_position_index == null)
    | . as $task
    | select((($position[0].tasks[$task.task_id].next_check_at // "1970-01-01T00:00:00Z") <= $now))]
  | sort_by(.resolved_at)
  | .[0] // empty
' "$operations")

if [[ -z $candidate ]]; then
  /usr/bin/jq -cn '{ok:true,examined:0,captured:0,unresolved:0,llm_calls:0}'
  exit 0
fi

task_id=$(printf '%s' "$candidate" | /usr/bin/jq -er '.task_id | select(type=="string" and test("^[0-9]+$"))') || fail_json invalid_position_candidate
offer_id=$(printf '%s' "$candidate" | /usr/bin/jq -er '.offer_id | select(type=="string" and test("^[0-9]+$"))') || fail_json invalid_position_candidate
price_minor=$(printf '%s' "$candidate" | /usr/bin/jq -er '.price_minor | select(type=="number" and floor==. and .>=0)') || fail_json invalid_position_candidate
draft_path=$(printf '%s' "$candidate" | /usr/bin/jq -er --arg task "$task_id" '.draft_path | select(. == ("drafts/" + $task + ".md"))') || fail_json invalid_position_candidate
text_sha256=$(printf '%s' "$candidate" | /usr/bin/jq -er '.text_sha256 | select(type=="string" and test("^[0-9a-f]{64}$"))') || fail_json invalid_position_candidate
next_check_at=$(/usr/bin/jq -nr 'now + 21600 | todateiso8601')

write_position_state() {
  local result=$1 last_error=${2:-} next_check=${3:-} position_index=${4:-} offers_total=${5:-}
  local tmp
  tmp=$(/usr/bin/mktemp "$workspace/state/.youdo-position-reconciliation.XXXXXX")
  /usr/bin/jq --arg task "$task_id" --arg offer "$offer_id" --arg now "$now_utc" \
    --arg result "$result" --arg error "$last_error" --arg next "$next_check" \
    --arg position "$position_index" --arg total "$offers_total" '
      .schema_version=1 | .updated_at=$now
      | .tasks[$task]={
          task_id:$task,offer_id:$offer,last_checked_at:$now,
          attempts:((.tasks[$task].attempts // 0) + 1),result:$result,
          next_check_at:(if $next == "" then null else $next end),
          last_error:(if $error == "" then null else $error end),
          provider_position_index:(if $position == "" then null else ($position|tonumber) end),
          task_offers_count:(if $total == "" then null else ($total|tonumber) end)
        }
    ' "$position_state" > "$tmp"
  /usr/bin/jq -e '.schema_version == 1 and (.tasks|type) == "object"' "$tmp" >/dev/null
  /bin/chmod 600 "$tmp"
  /bin/mv "$tmp" "$position_state"
}

proof=$($wrapper cli --timeout 30s --account personal --json offer verify "$task_id" --offer "$offer_id" 2>/dev/null) || {
  write_position_state deferred verification_failed "$next_check_at"
  /usr/bin/jq -cn --arg task_id "$task_id" --arg next "$next_check_at" '{ok:true,examined:1,captured:0,unresolved:1,task_id:$task_id,last_error:"verification_failed",next_check_at:$next,llm_calls:0}'
  exit 0
}
if ! printf '%s' "$proof" | /usr/bin/jq -e 'type == "object"' >/dev/null 2>&1; then
  write_position_state deferred invalid_verification_result "$next_check_at"
  /usr/bin/jq -cn --arg task_id "$task_id" --arg next "$next_check_at" '{ok:true,examined:1,captured:0,unresolved:1,task_id:$task_id,last_error:"invalid_verification_result",next_check_at:$next,llm_calls:0}'
  exit 0
fi

if [[ $(printf '%s' "$proof" | /usr/bin/jq -r --arg offer "$offer_id" '
  .ok == true and .data.published == true and .data.conclusive == true
  and .data.expectedOfferId == $offer
  and .data.offersComplete == true
  and (.data.positionAtTaskOffers|type) == "number" and (.data.positionAtTaskOffers|floor) == .data.positionAtTaskOffers and .data.positionAtTaskOffers >= 0
  and (.data.offersTotal|type) == "number" and (.data.offersTotal|floor) == .data.offersTotal and .data.offersTotal > .data.positionAtTaskOffers
') == true ]]; then
  position_index=$(printf '%s' "$proof" | /usr/bin/jq -r '.data.positionAtTaskOffers')
  offers_total=$(printf '%s' "$proof" | /usr/bin/jq -r '.data.offersTotal')
  $recorder reconciled_confirmed "$task_id" "$offer_id" "$price_minor" "$draft_path" "$position_index" "$offers_total" "$text_sha256" >/dev/null || fail_json position_record_failed
  write_position_state captured "" "" "$position_index" "$offers_total"
  /usr/bin/jq -cn --arg task_id "$task_id" --arg offer_id "$offer_id" --argjson position "$position_index" --argjson total "$offers_total" \
    '{ok:true,examined:1,captured:1,unresolved:0,task_id:$task_id,offer_id:$offer_id,provider_position_index:$position,offer_position:($position+1),task_offers_count:$total,llm_calls:0}'
  exit 0
fi

last_error=$(printf '%s' "$proof" | /usr/bin/jq -r '
  if .ok != true then "provider_read_failed"
  elif .data.published != true then "publication_not_observed"
  elif .data.conclusive != true then "verification_inconclusive"
  elif .data.offersComplete != true then "offer_list_incomplete"
  else "position_unavailable" end
')
write_position_state deferred "$last_error" "$next_check_at"
/usr/bin/jq -cn --arg task_id "$task_id" --arg error "$last_error" --arg next "$next_check_at" \
  '{ok:true,examined:1,captured:0,unresolved:1,task_id:$task_id,last_error:$error,next_check_at:$next,llm_calls:0}'
