#!/bin/zsh
set -euo pipefail

workspace=${YOUDO_WORKSPACE:-/Users/mini/.openclaw/workspace-freelancer}
operations="$workspace/state/youdo-operations.json"
ledger="$workspace/state/auto-offer-ledger.json"
lock_dir="$workspace/state/.youdo-outcome.lock"
action=${1:-}
task_id=${2:-}
tmp_operations=
tmp_ledger=
lock_owned=false

cleanup() {
  [[ -z ${tmp_operations:-} ]] || /bin/rm -f "$tmp_operations" 2>/dev/null || true
  [[ -z ${tmp_ledger:-} ]] || /bin/rm -f "$tmp_ledger" 2>/dev/null || true
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

succeed_idempotent() {
  /usr/bin/jq -cn --arg action "$action" --arg task_id "$task_id" '{ok:true,action:$action,task_id:$task_id,idempotent:true}'
  exit 0
}

validate_payment_classification() {
  local category_id=$1 subcategory_id=$2 category_name=$3 subcategory_name=$4
  [[ $category_id == null || ( $category_id == <-> && $category_id -gt 0 ) ]] || fail_json invalid_category_id
  [[ $subcategory_id == null || ( $subcategory_id == <-> && $subcategory_id -gt 0 ) ]] || fail_json invalid_subcategory_id
  [[ $category_id != null || $subcategory_id != null ]] || fail_json missing_payment_classification
  printf '%s' "$category_name" | /usr/bin/jq -eR 'length <= 120 and (test("[\\t\\r\\n]") | not)' >/dev/null || fail_json invalid_category_name
  printf '%s' "$subcategory_name" | /usr/bin/jq -eR 'length <= 120 and (test("[\\t\\r\\n]") | not)' >/dev/null || fail_json invalid_subcategory_name
}

payment_classification_matches() {
  local category_id=$1 subcategory_id=$2 category_name=$3 subcategory_name=$4
  /usr/bin/jq -e --arg task "$task_id" --arg category "$category_id" --arg subcategory "$subcategory_id" \
    --arg category_name "$category_name" --arg subcategory_name "$subcategory_name" '
      any((.payment_blocked_events // [])[]?;
        .task_id == $task
        and .category_id == (if $category == "null" then null else $category end)
        and .subcategory_id == (if $subcategory == "null" then null else $subcategory end)
        and .category_name == (if $category_name == "null" or $category_name == "" then null else $category_name end)
        and .subcategory_name == (if $subcategory_name == "null" or $subcategory_name == "" then null else $subcategory_name end))
    ' "$operations" >/dev/null
}

payment_classification_exists() {
  /usr/bin/jq -e --arg task "$task_id" 'any((.payment_blocked_events // [])[]?; .task_id == $task)' "$operations" >/dev/null
}

acquire_lock() {
  if /bin/mkdir "$lock_dir" 2>/dev/null; then
    lock_owned=true
    printf '%s\n' $$ > "$lock_dir/pid"
    return
  fi
  local owner modified now_epoch
  owner=$(/bin/cat "$lock_dir/pid" 2>/dev/null || true)
  modified=$(/usr/bin/stat -f %m "$lock_dir" 2>/dev/null || printf 0)
  now_epoch=$(/bin/date -u +%s)
  local lock_age=$((now_epoch - modified))
  if [[ $owner == <-> ]] && /bin/kill -0 "$owner" 2>/dev/null && (( lock_age < 300 )); then
    fail_json outcome_state_busy 3
  fi
  if [[ $owner != <-> ]] && (( lock_age < 2 )); then
    fail_json outcome_state_busy 3
  fi
  /bin/rm -f "$lock_dir/pid" 2>/dev/null || true
  /bin/rmdir "$lock_dir" 2>/dev/null || fail_json outcome_state_busy 3
  /bin/mkdir "$lock_dir" 2>/dev/null || fail_json outcome_state_busy 3
  lock_owned=true
  printf '%s\n' $$ > "$lock_dir/pid"
}

[[ $task_id == <-> ]] || fail_json invalid_task_id
[[ -f $operations ]] || fail_json operations_state_missing
[[ -f $ledger ]] || fail_json legacy_ledger_missing
acquire_lock

now=$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)
current_state=$(/usr/bin/jq -r --arg task "$task_id" '.tasks[$task].state // ""' "$operations")
current_offer=$(/usr/bin/jq -r --arg task "$task_id" '.tasks[$task].offer_id // ""' "$operations")

protect_transition() {
  local next_state=$1 next_offer=${2:-}
  if [[ $next_state == confirmed ]]; then
    [[ $current_state != confirmed_baseline ]] || fail_json baseline_cannot_enter_sla
    if [[ $current_state == confirmed && $current_offer != $next_offer ]]; then
      fail_json confirmed_offer_conflict
    fi
    return
  fi
  [[ $current_state != confirmed && $current_state != confirmed_baseline ]] || fail_json confirmed_state_is_terminal
  if [[ $current_state == ambiguous && $next_state != ambiguous ]]; then
    fail_json ambiguous_requires_reconciliation
  fi
  if [[ $current_state == missed || $current_state == rejected ]]; then
    [[ $current_state == $next_state ]] || fail_json terminal_state_conflict
  fi
}

tmp_operations=$(/usr/bin/mktemp "$workspace/state/.youdo-operations.XXXXXX")
tmp_ledger=$(/usr/bin/mktemp "$workspace/state/.auto-offer-ledger.XXXXXX")

finish_confirmed_idempotent() {
  if /usr/bin/jq -e --arg task "$task_id" --arg offer "$current_offer" --slurpfile operations "$operations" '
    ($operations[0].tasks[$task]) as $canonical
    | (.sent_task_ids | index($task)) != null
    and any(.offers[]?;
      .task_id == $task and .provider_id == $offer
      and .price == $canonical.price_minor
      and .draft_path == $canonical.draft_path
      and .text_sha256 == $canonical.text_sha256
      and .provider_position_index == $canonical.provider_position_index
      and .offer_position == $canonical.offer_position
      and .task_offers_count == $canonical.task_offers_count)
  ' "$ledger" >/dev/null; then
    succeed_idempotent
  fi
  canonical=$(/usr/bin/jq -c --arg task "$task_id" '.tasks[$task]' "$operations")
  /usr/bin/jq --arg task "$task_id" --arg now "$now" --argjson canonical "$canonical" '
    (if $canonical.provider_position_index != null then $now
     else ([.offers[]? | select(.task_id == $task)][0].position_captured_at // $canonical.resolved_at) end) as $captured_at
    | .schema_version=3 | .updated_at=$now | .last_run=$now
    | .sent_task_ids=([.sent_task_ids[]?, $task] | unique)
    | .ambiguous_task_ids=[.ambiguous_task_ids[]? | select(. != $task)]
    | .terminal_task_ids=[.terminal_task_ids[]? | select(. != $task)]
    | .terminal=[.terminal[]? | select(.task_id != $task)]
    | .offers=([.offers[]? | select(.task_id != $task)] + [{
        task_id:$task,provider_id:$canonical.offer_id,sent_at:$canonical.resolved_at,
        price:$canonical.price_minor,text_sha256:$canonical.text_sha256,draft_path:$canonical.draft_path,
        offer_position:$canonical.offer_position,provider_position_index:$canonical.provider_position_index,
        task_offers_count:$canonical.task_offers_count,position_captured_at:$captured_at,
        position_source:"task_scoped_offer_verify",position_kind:$canonical.position_kind
      }])
  ' "$ledger" > "$tmp_ledger"
  /bin/chmod 600 "$tmp_ledger"
  /bin/mv "$tmp_ledger" "$ledger"; tmp_ledger=
  /usr/bin/jq -cn --arg action "$action" --arg task_id "$task_id" '{ok:true,action:$action,task_id:$task_id,idempotent:true,repaired_projection:true}'
  exit 0
}

finish_terminal_idempotent() {
  local reason=$1
  if /usr/bin/jq -e --arg task "$task_id" --arg reason "$reason" '
    (.terminal_task_ids | index($task)) != null
    and any(.terminal[]?; .task_id == $task and .reason == $reason)
  ' "$ledger" >/dev/null; then
    succeed_idempotent
  fi
  resolved=$(/usr/bin/jq -r --arg task "$task_id" '.tasks[$task].resolved_at' "$operations")
  /usr/bin/jq --arg task "$task_id" --arg reason "$reason" --arg resolved "$resolved" --arg now "$now" '
    .schema_version=3 | .updated_at=$now | .last_run=$now
    | .ambiguous_task_ids=[.ambiguous_task_ids[]? | select(. != $task)]
    | .terminal_task_ids=([.terminal_task_ids[]?, $task] | unique)
    | .terminal=([.terminal[]? | select(.task_id != $task)] + [{task_id:$task,reason:$reason,resolved_at:$resolved}])
  ' "$ledger" > "$tmp_ledger"
  /bin/chmod 600 "$tmp_ledger"
  /bin/mv "$tmp_ledger" "$ledger"; tmp_ledger=
  /usr/bin/jq -cn --arg action "$action" --arg task_id "$task_id" '{ok:true,action:$action,task_id:$task_id,idempotent:true,repaired_projection:true}'
  exit 0
}

write_confirmed() {
  local source=$1 offer_id=$2 price_minor=$3 draft_path=$4 position_index=$5 task_offers_count=$6 text_sha256=$7
  [[ $offer_id == <-> ]] || fail_json invalid_offer_id
  [[ $price_minor == <-> ]] || fail_json invalid_price
  [[ $draft_path == drafts/${task_id}.md ]] || fail_json invalid_draft_path
  [[ $task_offers_count == <-> && $task_offers_count -gt 0 ]] || fail_json invalid_task_offers_count
  printf '%s' "$text_sha256" | /usr/bin/jq -eR 'test("^[0-9a-f]{64}$")' >/dev/null || fail_json invalid_text_sha256
  local index_json position_json
  if [[ $position_index == <-> ]]; then
    local offer_position=$((position_index + 1))
    [[ $offer_position -le $task_offers_count ]] || fail_json inconsistent_position
    index_json=$position_index
    position_json=$offer_position
  else
    [[ -z $position_index && $source == unavailable_after_send ]] || fail_json invalid_position_index
    index_json=null
    position_json=null
  fi
  protect_transition confirmed "$offer_id"
  if [[ $current_state == confirmed ]]; then
    current_price=$(/usr/bin/jq -r --arg task "$task_id" '.tasks[$task].price_minor | tostring' "$operations")
    current_draft=$(/usr/bin/jq -r --arg task "$task_id" '.tasks[$task].draft_path // ""' "$operations")
    current_sha=$(/usr/bin/jq -r --arg task "$task_id" '.tasks[$task].text_sha256 // ""' "$operations")
    current_position=$(/usr/bin/jq -r --arg task "$task_id" '.tasks[$task].provider_position_index | if type=="number" then tostring else "" end' "$operations")
    [[ $current_price == $price_minor && $current_draft == $draft_path && $current_sha == $text_sha256 ]] || fail_json confirmed_evidence_conflict
    if [[ -n $current_position ]]; then
      [[ -z $position_index || $current_position == $position_index ]] || fail_json confirmed_position_conflict
      finish_confirmed_idempotent
    fi
    [[ -n $position_index ]] || finish_confirmed_idempotent
  fi
  /usr/bin/jq \
    --arg task "$task_id" --arg offer "$offer_id" --arg now "$now" \
    --arg draft "$draft_path" --arg sha "$text_sha256" --arg source "$source" \
    --argjson price "$price_minor" --argjson index "$index_json" \
    --argjson position "$position_json" --argjson total "$task_offers_count" '
      (.tasks[$task].resolved_at // $now) as $resolved
      | ([.events[]? | select(.task_id == $task and .outcome == "confirmed")][0].resolved_at // $resolved) as $event_at
      | .tasks[$task] = {
        task_id:$task,eligibility:"eligible",state:"confirmed",offer_id:$offer,
        price_minor:$price,draft_path:$draft,text_sha256:$sha,
        provider_position_index:$index,offer_position:$position,
        task_offers_count:$total,position_kind:$source,resolved_at:$resolved
      }
      | .events = ([.events[]? | select(.task_id != $task)] +
          [{task_id:$task,outcome:"confirmed",offer_id:$offer,resolved_at:$event_at}])
      | .updated_at=$now
    ' "$operations" > "$tmp_operations"
  /usr/bin/jq \
    --arg task "$task_id" --arg offer "$offer_id" --arg now "$now" \
    --arg draft "$draft_path" --arg sha "$text_sha256" --arg source "$source" \
    --argjson price "$price_minor" --argjson index "$index_json" \
    --argjson position "$position_json" --argjson total "$task_offers_count" '
      ([.offers[]? | select(.task_id == $task)][0].sent_at // $now) as $sent_at
      | .schema_version=3 | .updated_at=$now | .last_run=$now
      | .sent_task_ids=([.sent_task_ids[]?, $task] | unique)
      | .ambiguous_task_ids=[.ambiguous_task_ids[]? | select(. != $task)]
      | .terminal_task_ids=[.terminal_task_ids[]? | select(. != $task)]
      | .terminal=[.terminal[]? | select(.task_id != $task)]
      | .offers=([.offers[]? | select(.task_id != $task)] + [{
          task_id:$task,provider_id:$offer,sent_at:$sent_at,price:$price,
          text_sha256:$sha,draft_path:$draft,offer_position:$position,
          provider_position_index:$index,task_offers_count:$total,
          position_captured_at:$now,position_source:"task_scoped_offer_verify",
          position_kind:$source
        }])
    ' "$ledger" > "$tmp_ledger"
}

case $action in
  confirmed)
    write_confirmed at_send "${3:-}" "${4:-}" "${5:-}" "${6:-}" "${7:-}" "${8:-}"
    ;;
  reconciled_confirmed)
    write_confirmed observed_after_send "${3:-}" "${4:-}" "${5:-}" "${6:-}" "${7:-}" "${8:-}"
    ;;
  reconciled_confirmed_unknown)
    write_confirmed unavailable_after_send "${3:-}" "${4:-}" "${5:-}" "" "${6:-}" "${7:-}"
    ;;
  reconciled_observed)
    offer_id=${3:-}; price_minor=${4:-}; draft_path=${5:-}; offer_position=${6:-}; text_sha256=${7:-}
    [[ $offer_id == <-> && $price_minor == <-> ]] || fail_json invalid_reconciliation
    [[ $draft_path == drafts/${task_id}.md && $offer_position == <-> && $offer_position -gt 0 ]] || fail_json invalid_reconciliation
    printf '%s' "$text_sha256" | /usr/bin/jq -eR 'test("^[0-9a-f]{64}$")' >/dev/null || fail_json invalid_text_sha256
    [[ -z $current_state || $current_state == confirmed_baseline ]] || fail_json baseline_state_conflict
    if [[ $current_state == confirmed_baseline ]]; then
      [[ $current_offer == $offer_id ]] || fail_json baseline_offer_conflict
      if /usr/bin/jq -e --arg task "$task_id" --arg offer "$offer_id" '(.sent_task_ids | index($task)) != null and any(.offers[]?; .task_id == $task and .provider_id == $offer)' "$ledger" >/dev/null; then
        succeed_idempotent
      fi
    fi
    /usr/bin/jq --arg task "$task_id" --arg offer "$offer_id" --arg now "$now" --arg draft "$draft_path" --arg sha "$text_sha256" --argjson price "$price_minor" --argjson position "$offer_position" '
      (.tasks[$task].reconciled_at // $now) as $reconciled_at
      | .tasks[$task]={task_id:$task,eligibility:"baseline",state:"confirmed_baseline",offer_id:$offer,price_minor:$price,draft_path:$draft,text_sha256:$sha,offer_position:$position,reconciled_at:$reconciled_at}
      | .updated_at=$now
    ' "$operations" > "$tmp_operations"
    /usr/bin/jq --arg task "$task_id" --arg offer "$offer_id" --arg now "$now" --arg draft "$draft_path" --arg sha "$text_sha256" --argjson price "$price_minor" --argjson position "$offer_position" '
      ([.offers[]? | select(.task_id == $task)][0].sent_at // $now) as $sent_at
      | .schema_version=3 | .updated_at=$now | .last_run=$now
      | .sent_task_ids=([.sent_task_ids[]?, $task] | unique)
      | .ambiguous_task_ids=[.ambiguous_task_ids[]? | select(. != $task)]
      | .offers=([.offers[]? | select(.task_id != $task)] + [{task_id:$task,provider_id:$offer,sent_at:$sent_at,price:$price,text_sha256:$sha,draft_path:$draft,offer_position:$position,position_captured_at:$now,position_source:"task_offer_total",position_kind:"observed_after_send"}])
    ' "$ledger" > "$tmp_ledger"
    ;;
  rejected|missed)
    reason=${3:-}
    printf '%s' "$reason" | /usr/bin/jq -eR 'test("^[a-z0-9_]+$")' >/dev/null || fail_json invalid_reason
    protect_transition "$action"
    if [[ $current_state == $action ]]; then
      current_reason=$(/usr/bin/jq -r --arg task "$task_id" '.tasks[$task].reason // ""' "$operations")
      [[ $current_reason == $reason ]] || fail_json terminal_evidence_conflict
      finish_terminal_idempotent "$reason"
    fi
    eligibility=ineligible; [[ $action == missed ]] && eligibility=eligible
    /usr/bin/jq --arg task "$task_id" --arg state "$action" --arg eligibility "$eligibility" --arg reason "$reason" --arg now "$now" '
      (.tasks[$task].origin_reason // null) as $origin
      | (.tasks[$task].first_payment_blocked_at // null) as $first_payment_blocked_at
      | .tasks[$task]=({task_id:$task,eligibility:$eligibility,state:$state,reason:$reason,resolved_at:$now}
          + (if $origin == null then {} else {origin_reason:$origin} end)
          + (if $first_payment_blocked_at == null then {} else {first_payment_blocked_at:$first_payment_blocked_at} end))
      | (if $state == "missed" then .events=([.events[]? | select(.task_id != $task)] + [{task_id:$task,outcome:"missed",reason:$reason,resolved_at:$now}]) else . end)
      | .updated_at=$now
    ' "$operations" > "$tmp_operations"
    /usr/bin/jq --arg task "$task_id" --arg reason "$reason" --arg now "$now" '
      .schema_version=3 | .updated_at=$now | .last_run=$now
      | .ambiguous_task_ids=[.ambiguous_task_ids[]? | select(. != $task)]
      | .terminal_task_ids=([.terminal_task_ids[]?, $task] | unique)
      | .terminal=([.terminal[]? | select(.task_id != $task)] + [{task_id:$task,reason:$reason,resolved_at:$now}])
    ' "$ledger" > "$tmp_ledger"
    ;;
  deferred)
    reason=${3:-}; retry_after=${4:-}
    printf '%s' "$reason" | /usr/bin/jq -eR 'test("^[a-z0-9_]+$")' >/dev/null || fail_json invalid_reason
    printf '%s' "$retry_after" | /usr/bin/jq -eR 'fromdateiso8601 > now' >/dev/null || fail_json invalid_retry_after
    protect_transition deferred
    category_id=${5:-null}; subcategory_id=${6:-null}; category_name=${7:-null}; subcategory_name=${8:-null}
    if [[ $reason == payment_blocked ]]; then
      validate_payment_classification "$category_id" "$subcategory_id" "$category_name" "$subcategory_name"
      if payment_classification_exists; then
        payment_classification_matches "$category_id" "$subcategory_id" "$category_name" "$subcategory_name" || fail_json payment_classification_conflict
      fi
    fi
    /usr/bin/jq --arg task "$task_id" --arg reason "$reason" --arg retry "$retry_after" --arg now "$now" \
      --arg category "$category_id" --arg subcategory "$subcategory_id" --arg category_name "$category_name" --arg subcategory_name "$subcategory_name" '
      (.tasks[$task].origin_reason // (if .tasks[$task].reason == "payment_blocked" or $reason == "payment_blocked" then "payment_blocked" else null end)) as $origin
      | (.tasks[$task].first_payment_blocked_at // (if $reason == "payment_blocked" then $now else null end)) as $first_payment_blocked_at
      | .tasks[$task]=({task_id:$task,eligibility:"conditional",state:"deferred",reason:$reason,retry_after:$retry,updated_at:$now}
          + (if $origin == null then {} else {origin_reason:$origin} end)
          + (if $first_payment_blocked_at == null then {} else {first_payment_blocked_at:$first_payment_blocked_at} end))
      | .payment_blocked_events = ((.payment_blocked_events // [])
          + (if $reason == "payment_blocked" and (any((.payment_blocked_events // [])[]?; .task_id == $task) | not) then [{
              task_id:$task,occurred_at:$now,
              category_id:(if $category == "null" then null else $category end),
              category_name:(if $category_name == "null" or $category_name == "" then null else $category_name end),
              subcategory_id:(if $subcategory == "null" then null else $subcategory end),
              subcategory_name:(if $subcategory_name == "null" or $subcategory_name == "" then null else $subcategory_name end)
            }] else [] end))
      | .updated_at=$now
    ' "$operations" > "$tmp_operations"
    /usr/bin/jq --arg now "$now" '.schema_version=3 | .updated_at=$now | .last_run=$now' "$ledger" > "$tmp_ledger"
    ;;
  classify_payment_blocked)
    category_id=${3:-null}; subcategory_id=${4:-null}; category_name=${5:-null}; subcategory_name=${6:-null}; occurred_at=${7:-}
    validate_payment_classification "$category_id" "$subcategory_id" "$category_name" "$subcategory_name"
    printf '%s' "$occurred_at" | /usr/bin/jq -eR 'fromdateiso8601 > 0 and fromdateiso8601 <= now' >/dev/null || fail_json invalid_payment_blocked_timestamp
    current_reason=$(/usr/bin/jq -r --arg task "$task_id" '.tasks[$task].reason // ""' "$operations")
    current_origin=$(/usr/bin/jq -r --arg task "$task_id" '.tasks[$task].origin_reason // ""' "$operations")
    [[ ( $current_state == deferred && ( $current_reason == payment_blocked || $current_origin == payment_blocked ) ) || ( $current_state == missed && $current_reason == payment_blocked_until_expiry ) ]] || fail_json payment_classification_state_conflict
    if payment_classification_exists; then
      payment_classification_matches "$category_id" "$subcategory_id" "$category_name" "$subcategory_name" || fail_json payment_classification_conflict
      succeed_idempotent
    fi
    /usr/bin/jq --arg task "$task_id" --arg occurred "$occurred_at" --arg now "$now" \
      --arg category "$category_id" --arg subcategory "$subcategory_id" --arg category_name "$category_name" --arg subcategory_name "$subcategory_name" '
      .payment_blocked_events = ((.payment_blocked_events // []) + [{
        task_id:$task,occurred_at:$occurred,
        category_id:(if $category == "null" then null else $category end),
        category_name:(if $category_name == "null" or $category_name == "" then null else $category_name end),
        subcategory_id:(if $subcategory == "null" then null else $subcategory end),
        subcategory_name:(if $subcategory_name == "null" or $subcategory_name == "" then null else $subcategory_name end)
      }])
      | .tasks[$task].first_payment_blocked_at = $occurred
      | .tasks[$task].origin_reason = "payment_blocked"
      | .updated_at=$now
    ' "$operations" > "$tmp_operations"
    /usr/bin/jq --arg now "$now" '.schema_version=3 | .updated_at=$now | .last_run=$now' "$ledger" > "$tmp_ledger"
    ;;
  package_recovered)
    current_reason=$(/usr/bin/jq -r --arg task "$task_id" '.tasks[$task].reason // ""' "$operations")
    current_origin=$(/usr/bin/jq -r --arg task "$task_id" '.tasks[$task].origin_reason // ""' "$operations")
    if [[ $current_state == retryable && $current_reason == package_coverage_available ]]; then
      succeed_idempotent
    fi
    [[ $current_state == deferred && ( $current_reason == payment_blocked || $current_origin == payment_blocked ) ]] || fail_json package_recovery_state_conflict
    protect_transition retryable
    /usr/bin/jq --arg task "$task_id" --arg now "$now" '
      .tasks[$task]={
        task_id:$task,eligibility:"conditional",state:"retryable",reason:"package_coverage_available",
        origin_reason:"payment_blocked",package_recovered_at:$now,updated_at:$now
      }
      | .updated_at=$now
    ' "$operations" > "$tmp_operations"
    /usr/bin/jq --arg now "$now" '.schema_version=3 | .updated_at=$now | .last_run=$now' "$ledger" > "$tmp_ledger"
    ;;
  review_rejection)
    review_decision=${3:-}; review_ref=${4:-}
    [[ $review_decision == uphold || $review_decision == retry ]] || fail_json invalid_review_decision
    printf '%s' "$review_ref" | /usr/bin/jq -eR 'length >= 8 and length <= 160 and test("^[A-Za-z0-9._:/-]+$")' >/dev/null || fail_json invalid_review_ref
    current_reason=$(/usr/bin/jq -r --arg task "$task_id" '.tasks[$task].reason // ""' "$operations")
    current_review=$(/usr/bin/jq -r --arg task "$task_id" '.tasks[$task].qualification_review.decision // ""' "$operations")
    current_review_ref=$(/usr/bin/jq -r --arg task "$task_id" '.tasks[$task].qualification_review.evidence_ref // ""' "$operations")
    if [[ $current_state == retryable && $current_reason == qualification_review_overturned && $current_review == retry ]]; then
      [[ $review_decision == retry && $current_review_ref == $review_ref ]] || fail_json qualification_review_conflict
      if /usr/bin/jq -e --arg task "$task_id" '
        (.terminal_task_ids | index($task)) == null
        and all(.terminal[]?; .task_id != $task)
      ' "$ledger" >/dev/null; then
        succeed_idempotent
      fi
      /usr/bin/jq --arg task "$task_id" --arg now "$now" '
        .schema_version=3 | .updated_at=$now | .last_run=$now
        | .terminal_task_ids=[.terminal_task_ids[]? | select(. != $task)]
        | .terminal=[.terminal[]? | select(.task_id != $task)]
      ' "$ledger" > "$tmp_ledger"
      /bin/chmod 600 "$tmp_ledger"
      /bin/mv "$tmp_ledger" "$ledger"; tmp_ledger=
      /usr/bin/jq -cn --arg action "$action" --arg task_id "$task_id" '{ok:true,action:$action,task_id:$task_id,idempotent:true,repaired_projection:true}'
      exit 0
    fi
    [[ $current_state == rejected && $current_reason == expertise_mismatch ]] || fail_json qualification_review_state_conflict
    if [[ $current_review == uphold ]]; then
      [[ $review_decision == uphold && $current_review_ref == $review_ref ]] || fail_json qualification_review_conflict
      succeed_idempotent
    fi
    [[ -z $current_review ]] || fail_json qualification_review_conflict
    if [[ $review_decision == uphold ]]; then
      /usr/bin/jq --arg task "$task_id" --arg now "$now" --arg ref "$review_ref" '
        .tasks[$task].qualification_review={decision:"uphold",reviewed_by:"operator",reviewed_at:$now,evidence_ref:$ref}
        | .updated_at=$now
      ' "$operations" > "$tmp_operations"
      /usr/bin/jq --arg now "$now" '.schema_version=3 | .updated_at=$now | .last_run=$now' "$ledger" > "$tmp_ledger"
    else
      /usr/bin/jq --arg task "$task_id" --arg now "$now" --arg ref "$review_ref" '
        .tasks[$task]={
          task_id:$task,eligibility:"conditional",state:"retryable",reason:"qualification_review_overturned",updated_at:$now,
          qualification_review:{decision:"retry",reviewed_by:"operator",reviewed_at:$now,evidence_ref:$ref}
        }
        | .updated_at=$now
      ' "$operations" > "$tmp_operations"
      /usr/bin/jq --arg task "$task_id" --arg now "$now" '
        .schema_version=3 | .updated_at=$now | .last_run=$now
        | .terminal_task_ids=[.terminal_task_ids[]? | select(. != $task)]
        | .terminal=[.terminal[]? | select(.task_id != $task)]
      ' "$ledger" > "$tmp_ledger"
    fi
    ;;
  ambiguous)
    offer_id=${3:-}; reason=${4:-}; price_minor=${5:-}; draft_path=${6:-}; text_sha256=${7:-}
    [[ -z $offer_id || $offer_id == <-> ]] || fail_json invalid_offer_id
    [[ $price_minor == <-> && $draft_path == drafts/${task_id}.md ]] || fail_json incomplete_ambiguous_evidence
    printf '%s' "$reason" | /usr/bin/jq -eR 'test("^[a-z0-9_]+$")' >/dev/null || fail_json invalid_reason
    printf '%s' "$text_sha256" | /usr/bin/jq -eR 'test("^[0-9a-f]{64}$")' >/dev/null || fail_json invalid_text_sha256
    protect_transition ambiguous "$offer_id"
    if [[ $current_state == ambiguous && -n $current_offer && -z $offer_id ]]; then
      offer_id=$current_offer
    fi
    [[ $current_state != ambiguous || -z $current_offer || -z $offer_id || $current_offer == $offer_id ]] || fail_json ambiguous_offer_conflict
    /usr/bin/jq --arg task "$task_id" --arg offer "$offer_id" --arg reason "$reason" --arg now "$now" --arg draft "$draft_path" --arg sha "$text_sha256" --argjson price "$price_minor" '
      (.tasks[$task].first_ambiguous_at // $now) as $first
      | .tasks[$task]={task_id:$task,eligibility:"eligible",state:"ambiguous",offer_id:(if $offer == "" then null else $offer end),reason:$reason,price_minor:$price,draft_path:$draft,text_sha256:$sha,first_ambiguous_at:$first,updated_at:$now}
      | .updated_at=$now
    ' "$operations" > "$tmp_operations"
    /usr/bin/jq --arg task "$task_id" --arg now "$now" '
      .schema_version=3 | .updated_at=$now | .last_run=$now
      | .ambiguous_task_ids=([.ambiguous_task_ids[]?, $task] | unique)
    ' "$ledger" > "$tmp_ledger"
    ;;
  *) fail_json invalid_action ;;
esac

/usr/bin/jq -e '.schema_version == 1 and (.tasks|type)=="object" and (.events|type)=="array" and ((.payment_blocked_events // [])|type)=="array"' "$tmp_operations" >/dev/null
/usr/bin/jq -e '(.sent_task_ids|type)=="array" and (.offers|type)=="array"' "$tmp_ledger" >/dev/null
/bin/chmod 600 "$tmp_operations" "$tmp_ledger"
/bin/mv "$tmp_operations" "$operations"; tmp_operations=
/bin/mv "$tmp_ledger" "$ledger"; tmp_ledger=
/usr/bin/jq -cn --arg action "$action" --arg task_id "$task_id" '{ok:true,action:$action,task_id:$task_id}'
