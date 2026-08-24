#!/bin/zsh
set -euo pipefail

workspace=${YOUDO_WORKSPACE:-/Users/mini/.openclaw/workspace-freelancer}
report_date=${1:-}
package_source=${2:-}
reports_dir="$workspace/reports/daily"
state_path="$workspace/state/youdo-daily-report.json"
input_path="$reports_dir/${report_date}.input.json"
packages_path="$reports_dir/${report_date}.packages.json"
report_path="$reports_dir/${report_date}.md"
tmp_dir=

cleanup() {
  [[ -z ${tmp_dir:-} ]] || /bin/rm -rf "$tmp_dir" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

fail_json() {
  /usr/bin/jq -cn --arg error "$1" '{ok:false,error:$error}'
  exit "${2:-2}"
}

[[ $report_date == <->-<->-<-> ]] || fail_json invalid_report_date
[[ -f $package_source ]] || fail_json package_snapshot_missing
/usr/bin/jq -e '.ok == true and (.data|type) == "array"' "$package_source" >/dev/null || fail_json invalid_package_snapshot

tmp_dir=$(/usr/bin/mktemp -d "$workspace/state/.youdo-daily-report.XXXXXX")
input_tmp="$tmp_dir/input.json"
packages_tmp="$tmp_dir/packages.json"
report_tmp="$tmp_dir/report.md"
text_tmp="$tmp_dir/telegram.txt"
state_tmp="$tmp_dir/state.json"

"$workspace/scripts/build-youdo-daily-report-input.zsh" "$report_date" > "$input_tmp"
/usr/bin/jq -e '.ok == true and (.missing_classification_task_ids|length) == 0' "$input_tmp" >/dev/null || fail_json payment_classification_incomplete
/usr/bin/jq -S '{ok:true,data:.data}' "$package_source" > "$packages_tmp"

sent_count=$(/usr/bin/jq -r '.sent_count' "$input_tmp")
not_sent_count=$(/usr/bin/jq -r '.not_sent_count' "$input_tmp")
purchased_count=$(/usr/bin/jq '[.data[]? | select(
  .Status == 1
  and (.PaidPrice|type) == "number" and .PaidPrice > 0
  and (.TimeRemain|type) == "number" and .TimeRemain > 0
  and (.OfferCountLimit == null or ((.OfferCountLimit|type) == "number" and .OfferCountLimit > 0 and (.OfferCountRemain|type) == "number" and .OfferCountRemain > 0))
)] | length' "$packages_tmp")
display_date=$(/bin/date -j -f '%Y-%m-%d' "$report_date" '+%d.%m.%Y')

{
  printf 'Отчёт YouDo за %s\n' "$display_date"
  printf 'Отправлено откликов: %s.\n' "$sent_count"
  printf 'Не отправлено без подходящего купленного тарифа: %s.\n' "$not_sent_count"
  if (( not_sent_count == 0 )); then
    printf 'Категории без отправки: нет.\n'
  else
    printf 'Категории без отправки:\n'
    /usr/bin/jq -r '.not_sent_by_category[] | "• \(.display_category) — \(.count)"' "$input_tmp"
  fi
  printf 'Купленные активные тарифы проверены Фрилансером: %s.\n' "$purchased_count"
} > "$text_tmp"

{
  printf '# Ежедневный отчёт YouDo за %s\n\n' "$report_date"
  printf 'Часовой пояс: Asia/Makassar. Интервал UTC: `%s` — `%s`.\n\n' \
    "$(/usr/bin/jq -r '.start_utc' "$input_tmp")" "$(/usr/bin/jq -r '.end_utc' "$input_tmp")"
  printf '## Telegram\n\n'
  /bin/cat "$text_tmp"
  printf '\n## Отправленные отклики\n\n'
  /usr/bin/jq -r 'if (.sent|length)==0 then "Нет." else .sent[] | "- `\(.task_id)` — offer `\(.offer_id)`, \(.resolved_at)" end' "$input_tmp"
  printf '\n## Не отправлено без купленного тарифа\n\n'
  /usr/bin/jq -r 'if (.not_sent|length)==0 then "Нет." else .not_sent[] | "- `\(.task_id)` — \(.display_category), \(.occurred_at)" end' "$input_tmp"
  printf '\n## Купленные активные тарифы — live snapshot Фрилансера\n\n'
  /usr/bin/jq -r '[.data[]? | select(
    .Status == 1
    and (.PaidPrice|type) == "number" and .PaidPrice > 0
    and (.TimeRemain|type) == "number" and .TimeRemain > 0
    and (.OfferCountLimit == null or ((.OfferCountLimit|type) == "number" and .OfferCountLimit > 0 and (.OfferCountRemain|type) == "number" and .OfferCountRemain > 0))
  )] | if length==0 then "Нет." else .[] | "- tariff `\(.Id // .TariffId // "unknown")`: category `\(.Category // "null")`, subcategory `\(.SubcategoryId // "null")`, paid `\(.PaidPrice)`, remain `\(.OfferCountRemain // "unlimited")`" end' "$packages_tmp"
} > "$report_tmp"

input_sha=$(/usr/bin/shasum -a 256 "$input_tmp" | /usr/bin/awk '{print $1}')
packages_sha=$(/usr/bin/shasum -a 256 "$packages_tmp" | /usr/bin/awk '{print $1}')
report_sha=$(/usr/bin/shasum -a 256 "$report_tmp" | /usr/bin/awk '{print $1}')
generated_at=$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)
/usr/bin/jq -n --arg report_date "$report_date" --arg generated_at "$generated_at" \
  --arg report_path "reports/daily/${report_date}.md" --arg input_path "reports/daily/${report_date}.input.json" \
  --arg packages_path "reports/daily/${report_date}.packages.json" --arg input_sha "$input_sha" \
  --arg packages_sha "$packages_sha" --arg report_sha "$report_sha" \
  --argjson sent "$sent_count" --argjson not_sent "$not_sent_count" --argjson purchased "$purchased_count" '
    {schema_version:1,report_date:$report_date,timezone:"Asia/Makassar",generated_at:$generated_at,
     sent_count:$sent,not_sent_count:$not_sent,purchased_active_tariff_count:$purchased,
     report_path:$report_path,input_path:$input_path,packages_path:$packages_path,
     input_sha256:$input_sha,packages_sha256:$packages_sha,report_sha256:$report_sha}
  ' > "$state_tmp"

/bin/mkdir -p "$reports_dir"
/bin/chmod 600 "$input_tmp" "$packages_tmp" "$report_tmp" "$state_tmp"
/bin/mv "$input_tmp" "$input_path"
/bin/mv "$packages_tmp" "$packages_path"
/bin/mv "$report_tmp" "$report_path"
/bin/mv "$state_tmp" "$state_path"
/bin/cat "$text_tmp"
