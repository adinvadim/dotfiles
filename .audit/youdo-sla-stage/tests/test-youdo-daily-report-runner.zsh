#!/bin/zsh
set -euo pipefail

stage=${0:A:h:h}
fixture=$(/usr/bin/mktemp -d)
cleanup() { /bin/rm -rf "$fixture"; }
trap cleanup EXIT INT TERM

/bin/mkdir -p "$fixture/state" "$fixture/scripts" "$fixture/reports/daily"
/bin/cp "$stage/scripts/build-youdo-daily-report-input.zsh" "$fixture/scripts/"
/bin/cp "$stage/scripts/write-youdo-daily-report.zsh" "$fixture/scripts/"
/bin/cp "$stage/scripts/run-youdo-daily-report.zsh" "$fixture/scripts/"
/bin/chmod 700 "$fixture/scripts/"*.zsh

/usr/bin/jq -n '{
  schema_version:1,
  tasks:{},
  events:[],
  payment_blocked_events:[]
}' > "$fixture/state/youdo-operations.json"

/bin/cp "$stage/tests/fixtures/youdo-exec-package-list.zsh" "$fixture/scripts/youdo-exec.zsh"
/bin/chmod 700 "$fixture/scripts/youdo-exec.zsh"

/usr/bin/touch "$fixture/state/package-read-fails"
if failed=$(YOUDO_WORKSPACE="$fixture" YOUDO_DAILY_RETRY_DELAY_SECONDS=0 "$fixture/scripts/run-youdo-daily-report.zsh" 2026-08-22 2>&1); then
  print -u2 'package read failure unexpectedly produced a report'
  exit 1
fi
printf '%s' "$failed" | /usr/bin/grep -F 'live_package_list_failed' >/dev/null
[[ $(/bin/cat "$fixture/state/package-read-attempts") == 3 ]]
[[ ! -f "$fixture/state/youdo-daily-report.json" && ! -f "$fixture/reports/daily/2026-08-22.md" ]]

/bin/rm "$fixture/state/package-read-fails" "$fixture/state/package-read-attempts"
text=$(YOUDO_WORKSPACE="$fixture" YOUDO_DAILY_RETRY_DELAY_SECONDS=0 "$fixture/scripts/run-youdo-daily-report.zsh" 2026-08-22)
printf '%s' "$text" | /usr/bin/grep -F 'Отчёт YouDo за 22.08.2026' >/dev/null
[[ $(/bin/cat "$fixture/state/package-read-attempts") == 1 ]]
/usr/bin/jq -e '.report_date == "2026-08-22" and .sent_count == 0 and .not_sent_count == 0' "$fixture/state/youdo-daily-report.json" >/dev/null
[[ -f "$fixture/reports/daily/2026-08-22.md" ]]

/usr/bin/jq -cn '{ok:true}'
