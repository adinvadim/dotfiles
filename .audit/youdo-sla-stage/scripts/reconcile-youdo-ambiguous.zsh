#!/bin/zsh
set -euo pipefail

workspace=${YOUDO_WORKSPACE:-/Users/mini/.openclaw/workspace-freelancer}
operations="$workspace/state/youdo-operations.json"
ledger="$workspace/state/auto-offer-ledger.json"
wrapper="$workspace/scripts/youdo-exec.zsh"
export PATH=/Users/mini/.openclaw/workspace/tools/youdo-cli:/Users/mini/.local/bin:/Users/mini/bin:/opt/homebrew/bin:/usr/bin:/bin
export YOUDO_BROWSER_HEADLESS=1
export AGENT_BROWSER_EXECUTABLE_PATH='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
export AGENT_BROWSER_PROXY=http://127.0.0.1:7897
export AGENT_BROWSER_USER_AGENT='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36'
export AGENT_BROWSER_ARGS=--disable-blink-features=AutomationControlled

[[ -f $operations ]] || {
  /usr/bin/jq -cn '{ok:false,error:"operations_state_missing"}'
  exit 2
}
[[ -f $ledger && -x $wrapper ]] || {
  /usr/bin/jq -cn '{ok:false,error:"reconciliation_dependency_missing"}'
  exit 2
}

typeset -a repair_ids
repair_ids=(${(f)$(/usr/bin/jq -r --slurpfile ledger "$ledger" '
  ($ledger[0]) as $ledger
  | .tasks | to_entries[]?
  | select(.value.state == "confirmed")
  | .value as $task
  | select(
      ($ledger.sent_task_ids | index($task.task_id)) == null
      or ([ $ledger.offers[]? | select(
          .task_id == $task.task_id and .provider_id == $task.offer_id
          and .sent_at == $task.resolved_at
          and .price == $task.price_minor
          and .draft_path == $task.draft_path
          and .text_sha256 == $task.text_sha256
          and .provider_position_index == $task.provider_position_index
          and .offer_position == $task.offer_position
          and .task_offers_count == $task.task_offers_count
        ) ] | length) == 0)
  | .key
' "$operations")})
repaired_projection=0
for repair_id in $repair_ids; do
  canonical=$(/usr/bin/jq -c --arg task "$repair_id" '.tasks[$task]' "$operations")
  offer_id=$(printf '%s' "$canonical" | /usr/bin/jq -r '.offer_id // ""')
  price_minor=$(printf '%s' "$canonical" | /usr/bin/jq -r '.price_minor // ""')
  draft_path=$(printf '%s' "$canonical" | /usr/bin/jq -r '.draft_path // ""')
  text_sha256=$(printf '%s' "$canonical" | /usr/bin/jq -r '.text_sha256 // ""')
  offers_total=$(printf '%s' "$canonical" | /usr/bin/jq -r '.task_offers_count // ""')
  position_index=$(printf '%s' "$canonical" | /usr/bin/jq -r '.provider_position_index | if type == "number" then tostring else "" end')
  if [[ -n $position_index ]]; then
    "$workspace/scripts/record-youdo-outcome.zsh" reconciled_confirmed "$repair_id" "$offer_id" "$price_minor" "$draft_path" "$position_index" "$offers_total" "$text_sha256" >/dev/null || {
      /usr/bin/jq -cn --arg task_id "$repair_id" '{ok:false,error:"projection_repair_failed",task_id:$task_id}'
      exit 3
    }
  else
    "$workspace/scripts/record-youdo-outcome.zsh" reconciled_confirmed_unknown "$repair_id" "$offer_id" "$price_minor" "$draft_path" "$offers_total" "$text_sha256" >/dev/null || {
      /usr/bin/jq -cn --arg task_id "$repair_id" '{ok:false,error:"projection_repair_failed",task_id:$task_id}'
      exit 3
    }
  fi
  (( repaired_projection += 1 ))
done

typeset -a task_ids
task_ids=(${(f)$(/usr/bin/jq -r '.tasks | to_entries[]? | select(.value.state == "ambiguous") | .key' "$operations")})
reconciled=0
unresolved=0

for task_id in $task_ids; do
  task=$(/usr/bin/jq -c --arg task "$task_id" '.tasks[$task]' "$operations")
  offer_id=$(printf '%s' "$task" | /usr/bin/jq -r '.offer_id // ""')
  if [[ -n $offer_id ]]; then
    proof=$($wrapper cli --timeout 90s --account personal --json offer verify "$task_id" --offer "$offer_id" 2>/dev/null) || {
      /usr/bin/jq -cn --arg task_id "$task_id" '{ok:false,error:"verify_failed",task_id:$task_id}'
      exit 3
    }
  else
    initial=$($wrapper cli --timeout 90s --account personal --json offer verify "$task_id" 2>/dev/null) || {
      /usr/bin/jq -cn --arg task_id "$task_id" '{ok:false,error:"verify_failed",task_id:$task_id}'
      exit 3
    }
    offer_id=$(printf '%s' "$initial" | /usr/bin/jq -r 'if .ok == true and .data.published == true and (.data.ownOfferIds|length) == 1 then .data.ownOfferIds[0] else "" end')
    if [[ -z $offer_id ]]; then
      (( unresolved += 1 ))
      continue
    fi
    proof=$($wrapper cli --timeout 90s --account personal --json offer verify "$task_id" --offer "$offer_id" 2>/dev/null) || {
      /usr/bin/jq -cn --arg task_id "$task_id" '{ok:false,error:"verify_failed",task_id:$task_id}'
      exit 3
    }
  fi

  if [[ $(printf '%s' "$proof" | /usr/bin/jq -r '.ok == true and .data.published == true and .data.conclusive == true and (.data.offersTotal|type) == "number" and .data.offersTotal > 0') != true ]]; then
    (( unresolved += 1 ))
    continue
  fi
  price_minor=$(printf '%s' "$task" | /usr/bin/jq -r '.price_minor // ""')
  draft_path=$(printf '%s' "$task" | /usr/bin/jq -r '.draft_path // ""')
  text_sha256=$(printf '%s' "$task" | /usr/bin/jq -r '.text_sha256 // ""')
  offers_total=$(printf '%s' "$proof" | /usr/bin/jq -r '.data.offersTotal')
  if [[ $(printf '%s' "$proof" | /usr/bin/jq -r '(.data.positionAtTaskOffers|type) == "number" and .data.offersComplete == true') == true ]]; then
    position_index=$(printf '%s' "$proof" | /usr/bin/jq -r '.data.positionAtTaskOffers')
    "$workspace/scripts/record-youdo-outcome.zsh" reconciled_confirmed "$task_id" "$offer_id" "$price_minor" "$draft_path" "$position_index" "$offers_total" "$text_sha256" >/dev/null
  else
    "$workspace/scripts/record-youdo-outcome.zsh" reconciled_confirmed_unknown "$task_id" "$offer_id" "$price_minor" "$draft_path" "$offers_total" "$text_sha256" >/dev/null
  fi
  (( reconciled += 1 ))
done

/usr/bin/jq -cn --argjson reconciled "$reconciled" --argjson unresolved "$unresolved" --argjson examined "${#task_ids}" --argjson repaired "$repaired_projection" \
  '{ok:true,examined:$examined,reconciled:$reconciled,unresolved:$unresolved,repaired_projection:$repaired,llm_calls:0}'
