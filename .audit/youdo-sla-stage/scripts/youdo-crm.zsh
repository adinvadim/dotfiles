#!/bin/zsh
set -euo pipefail

workspace=${YOUDO_WORKSPACE:-/Users/mini/.openclaw/workspace-freelancer}
crm="$workspace/state/youdo-crm.json"
snapshot="$workspace/state/youdo-crm.md"

[[ -f $crm ]] || {
  /usr/bin/jq -cn '{ok:false,error:"crm_state_missing"}'
  exit 2
}

view=$(/usr/bin/jq -c '
  def funnel_label:
    if . == "offered" then "Отклик"
    elif . == "message_received" then "Получено сообщение"
    elif . == "in_progress" then "Взято в работу"
    elif . == "done_paid" then "Выполнено и оплачено"
    else . end;
  def category($deal):
    ($deal.subcategory_name // $deal.category_name // "без категории");
  [.deals[]?] as $deals
  | {
      ok: true,
      deal_count: ($deals|length),
      funnel: {
        offered: ([ $deals[] | select(.funnel == "offered") ] | length),
        message_received: ([ $deals[] | select(.funnel == "message_received") ] | length),
        in_progress: ([ $deals[] | select(.funnel == "in_progress") ] | length),
        done_paid: ([ $deals[] | select(.funnel == "done_paid") ] | length)
      },
      categories: (
        [$deals[] | {key: category(.), deal:.}]
        | group_by(.key)
        | map({name: .[0].key, count: length})
      ),
      deals: (
        $deals
        | sort_by(.updated_at)
        | reverse
        | map({
            task_id,
            offer_id,
            category: category(.),
            funnel,
            funnel_label: (.funnel | funnel_label),
            project_path,
            correspondence,
            updated_at
          })
      )
    }
' "$crm")

{
  print '# YouDo CRM'
  print
  printf '%s' "$view" | /usr/bin/jq -r '
    "**Воронка.** Отклик \(.funnel.offered). Получено сообщение \(.funnel.message_received). Взято в работу \(.funnel.in_progress). Выполнено и оплачено \(.funnel.done_paid).",
    "",
    "**Категории.**",
    (if (.categories|length) == 0 then "- нет" else (.categories[] | "- \(.name): \(.count)") end),
    "",
    "| Задача | Отклик | Категория | Воронка |",
    "|---|---|---|---|",
    (.deals[] | "| \(.task_id) | \(.offer_id) | \(.category) | \(.funnel_label) |")
  '
} > "$snapshot"
/bin/chmod 600 "$snapshot"

printf '%s\n' "$view"
