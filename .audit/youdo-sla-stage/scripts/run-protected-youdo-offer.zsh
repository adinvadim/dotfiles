#!/bin/zsh
set -euo pipefail

# Ordered machine after a draft exists: verify, tariff, create, publish_confirm.
# Detect, hydrate, and chat_crm_sync stay with the trigger or the agent.

workspace=${YOUDO_WORKSPACE:-/Users/mini/.openclaw/workspace-freelancer}
exec_wrapper="$workspace/scripts/youdo-exec.zsh"
timing="$workspace/scripts/record-youdo-stage-timing.zsh"
export PATH=/Users/mini/.openclaw/workspace/tools/youdo-cli:/Users/mini/.local/bin:/Users/mini/bin:/opt/homebrew/bin:/usr/bin:/bin

task_id=${1:-}
price_minor=${2:-}
draft_path=${3:-}
dry_run=0
if [[ ${4:-} == --dry-run ]]; then
  dry_run=1
fi

fail_json() {
  /usr/bin/jq -cn --arg error "$1" '{ok:false,error:$error}'
  exit "${2:-2}"
}

[[ $task_id == <-> ]] || fail_json invalid_task_id
[[ $price_minor == <-> ]] || fail_json invalid_price
[[ $draft_path == drafts/${task_id}.md ]] || fail_json invalid_draft_path
[[ -f $workspace/$draft_path ]] || fail_json draft_missing
[[ -x $exec_wrapper ]] || fail_json wrapper_missing

record_stage() {
  local stage=$1 action=$2
  [[ -x $timing ]] || return 0
  "$timing" "$task_id" "$stage" "$action" >/dev/null || true
}

cli_json() {
  "$exec_wrapper" cli --timeout 90s --account personal --no-input --json "$@"
}

field() {
  local json=$1 query=$2
  printf '%s' "$json" | /usr/bin/jq -r "$query"
}

record_stage verify start
verify_json=$(cli_json offer verify "$task_id") || fail_json verify_failed
record_stage verify end

if ! printf '%s' "$verify_json" | /usr/bin/jq -e 'type == "object"' >/dev/null 2>&1; then
  fail_json invalid_verify
fi

published=$(field "$verify_json" '.data.published // .published // false')
own_offer=$(field "$verify_json" '
  .data.ownOfferIds[0] // .data.providerId // .ownOfferIds[0] // .providerId // empty
')

if [[ $published == true ]]; then
  [[ $own_offer == <-> ]] || fail_json published_without_offer
  /usr/bin/jq -cn --arg task "$task_id" --arg offer "$own_offer" \
    '{ok:true,task_id:$task,already_published:true,provider_id:$offer,published:true,create_attempted:false}'
  exit 0
fi

conclusive=$(field "$verify_json" '.data.conclusive // .conclusive // false')
safe=$(field "$verify_json" '.data.safeToCreate // .safeToCreate // false')
can_add=$(field "$verify_json" '.data.canAddOffer // .canAddOffer // false')
post_offer=$(field "$verify_json" '.data.isPostOffer // .isPostOffer // false')
[[ $conclusive == true && $safe == true && $can_add == true && $post_offer != true ]] || fail_json not_safe_to_create

record_stage tariff start
package_json=$(cli_json offer package check "$task_id") || fail_json tariff_failed
record_stage tariff end

covered=$(field "$package_json" '.data.covered // .covered // false')
zero_cost=$(field "$package_json" '.data.zeroAdditionalCost // .zeroAdditionalCost // false')
paid_price=$(field "$package_json" '.data.package.paidPrice // .package.paidPrice // 0')
if [[ $covered != true || $zero_cost != true || $paid_price == 0 || $paid_price == null ]]; then
  category_id=$(field "$package_json" '.data.categoryId // .data.category.id // .categoryId // "null"')
  subcategory_id=$(field "$package_json" '.data.subcategoryId // .data.subcategory.id // .subcategoryId // "null"')
  category_name=$(field "$package_json" '.data.categoryName // .data.category.name // .categoryName // "null"')
  subcategory_name=$(field "$package_json" '.data.subcategoryName // .data.subcategory.name // .subcategoryName // "null"')
  /usr/bin/jq -cn --arg error payment_blocked \
    --arg category "$category_id" --arg subcategory "$subcategory_id" \
    --arg category_name "$category_name" --arg subcategory_name "$subcategory_name" \
    '{ok:false,error:$error,category_id:$category,subcategory_id:$subcategory,category_name:$category_name,subcategory_name:$subcategory_name}'
  exit 2
fi

typeset -a create_args
create_args=(--timeout 90s --account personal --no-input --json offer create "$task_id" --sbr --payment package --price "$price_minor" --text-file "$draft_path")
if (( dry_run )); then
  create_args=(--dry-run "${create_args[@]}")
else
  create_args=(--force "${create_args[@]}")
fi

record_stage create start
create_json=$("$exec_wrapper" cli "${create_args[@]}") || {
  record_stage create end
  fail_json create_failed
}
record_stage create end

if (( dry_run )); then
  /usr/bin/jq -cn --arg task "$task_id" --argjson create "${create_json:-null}" \
    '{ok:true,task_id:$task,dry_run:true,already_published:false,create_attempted:true,create:$create}'
  exit 0
fi

provider_id=$(field "$create_json" '.data.providerId // .providerId // empty')
[[ $provider_id == <-> ]] || fail_json create_missing_provider

record_stage publish_confirm start
confirm_json=$(cli_json offer verify "$task_id" --offer "$provider_id") || fail_json publish_confirm_failed
record_stage publish_confirm end

confirm_published=$(field "$confirm_json" '.data.published // .published // false')
[[ $confirm_published == true ]] || fail_json publication_unconfirmed

position_index=$(field "$create_json" '.data.positionAtTaskOffers // .positionAtTaskOffers // empty')
task_offers_count=$(field "$create_json" '.data.taskOffersCount // .taskOffersCount // empty')
text_sha256=$(/usr/bin/shasum -a 256 "$workspace/$draft_path" | /usr/bin/awk '{print $1}')

/usr/bin/jq -cn \
  --arg task "$task_id" --arg offer "$provider_id" --arg sha "$text_sha256" \
  --arg index "$position_index" --arg total "$task_offers_count" \
  '{
    ok:true,
    task_id:$task,
    already_published:false,
    create_attempted:true,
    published:true,
    provider_id:$offer,
    text_sha256:$sha,
    provider_position_index:(if $index == "" then null else ($index|tonumber) end),
    task_offers_count:(if $total == "" then null else ($total|tonumber) end)
  }'
