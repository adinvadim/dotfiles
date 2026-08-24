#!/bin/zsh
set -euo pipefail

stage=${0:A:h:h}
fixture=$(/usr/bin/mktemp -d)
cleanup() { /bin/rm -rf "$fixture"; }
trap cleanup EXIT INT TERM

/bin/mkdir -p "$fixture/state" "$fixture/scripts" "$fixture/reports/daily"
/bin/cp "$stage/scripts/build-youdo-daily-report-input.zsh" "$fixture/scripts/build-youdo-daily-report-input.zsh"
/bin/cp "$stage/scripts/write-youdo-daily-report.zsh" "$fixture/scripts/write-youdo-daily-report.zsh"
/bin/chmod 700 "$fixture/scripts/"*.zsh
/usr/bin/jq -n '{
  schema_version:1,
  tasks:{
    "101":{task_id:"101",state:"confirmed"},
    "102":{task_id:"102",state:"deferred",reason:"payment_blocked",updated_at:"2026-08-21T05:00:00Z"},
    "103":{task_id:"103",state:"deferred",reason:"payment_blocked",updated_at:"2026-08-21T06:00:00Z"},
    "104":{task_id:"104",state:"deferred",reason:"payment_blocked",updated_at:"2026-08-21T07:00:00Z"},
    "105":{task_id:"105",state:"missed",reason:"payment_blocked_until_expiry",resolved_at:"2026-08-22T07:00:00Z"}
  },
  events:[
    {task_id:"101",outcome:"confirmed",offer_id:"900",resolved_at:"2026-08-21T04:00:00Z"},
    {task_id:"102",outcome:"confirmed",offer_id:"901",resolved_at:"2026-08-21T08:00:00Z"}
  ],
  payment_blocked_events:[
    {task_id:"102",occurred_at:"2026-08-21T05:00:00Z",category_id:"4194304",category_name:"Разработка",subcategory_id:"63",subcategory_name:"Сайты"},
    {task_id:"103",occurred_at:"2026-08-21T06:00:00Z",category_id:"4194304",category_name:"Разработка",subcategory_id:"63",subcategory_name:"Сайты"}
  ]
}' > "$fixture/state/youdo-operations.json"

result=$(YOUDO_WORKSPACE="$fixture" "$stage/scripts/build-youdo-daily-report-input.zsh" 2026-08-21)
printf '%s' "$result" | /usr/bin/jq -e '
  .ok == true and .report_date == "2026-08-21"
  and .start_utc == "2026-08-20T16:00:00Z" and .end_utc == "2026-08-21T16:00:00Z"
  and .sent_count == 2 and [.sent[].task_id] == ["101","102"]
  and .not_sent_count == 1 and .not_sent[0].task_id == "103"
  and .not_sent_by_category == [{category_id:"4194304",category_name:"Разработка",subcategory_id:"63",subcategory_name:"Сайты",display_category:"Сайты",count:1,task_ids:["103"]}]
  and .missing_classification_task_ids == ["104","105"] and .llm_calls == 0
' >/dev/null

/usr/bin/jq '.payment_blocked_events += [
  {task_id:"104",occurred_at:"2026-08-21T07:00:00Z",category_id:"4194304",category_name:"Разработка",subcategory_id:"246",subcategory_name:"Интеграции"},
  {task_id:"105",occurred_at:"2026-08-21T07:30:00Z",category_id:"4194304",category_name:"Разработка",subcategory_id:"246",subcategory_name:"Интеграции"}
]' "$fixture/state/youdo-operations.json" > "$fixture/state/ops.next"
/bin/mv "$fixture/state/ops.next" "$fixture/state/youdo-operations.json"
/usr/bin/jq -n '{ok:true,data:[
  {Id:9,Status:1,PaidPrice:4270,TimeRemain:100,Category:4194304,SubcategoryId:146,OfferCountLimit:null,OfferCountRemain:null},
  {Id:10,Status:1,PaidPrice:100,TimeRemain:50,Category:4194304,SubcategoryId:63,OfferCountLimit:25,OfferCountRemain:0}
]}' > "$fixture/state/packages.json"
text=$(YOUDO_WORKSPACE="$fixture" "$fixture/scripts/write-youdo-daily-report.zsh" 2026-08-21 "$fixture/state/packages.json")
printf '%s' "$text" | /usr/bin/grep -F 'Отправлено откликов: 2.' >/dev/null
printf '%s' "$text" | /usr/bin/grep -F 'Не отправлено без подходящего купленного тарифа: 3.' >/dev/null
/usr/bin/jq -e '
  .schema_version == 1 and .report_date == "2026-08-21" and .sent_count == 2 and .not_sent_count == 3
  and .purchased_active_tariff_count == 1 and .report_path == "reports/daily/2026-08-21.md"
' "$fixture/state/youdo-daily-report.json" >/dev/null
[[ -f "$fixture/reports/daily/2026-08-21.md" && -f "$fixture/reports/daily/2026-08-21.input.json" && -f "$fixture/reports/daily/2026-08-21.packages.json" ]]
/usr/bin/grep -F 'category `4194304`, subcategory `146`' "$fixture/reports/daily/2026-08-21.md" >/dev/null
if /usr/bin/grep -F 'tariff `10`' "$fixture/reports/daily/2026-08-21.md" >/dev/null; then
  print -u2 'exhausted limited package was reported as active'
  exit 1
fi

/usr/bin/jq -cn '{ok:true}'
