#!/bin/zsh
set -euo pipefail

stage=${0:A:h:h}
fixture=$(/usr/bin/mktemp -d)
cleanup() { /bin/rm -rf "$fixture"; }
trap cleanup EXIT INT TERM

/bin/mkdir -p "$fixture/state" "$fixture/scripts"
/bin/cp "$stage/scripts/finish-youdo-monitor-run.zsh" "$fixture/scripts/"
/bin/chmod 700 "$fixture/scripts/finish-youdo-monitor-run.zsh"

/usr/bin/jq -n '{
  schema_version:1,
  checked_at:"2026-08-23T07:00:00Z",
  technical:{healthy:false,proxy_ok:true,auth_ok:true,package_ok:true,deployment_ok:true,state_contract_ok:true,reconciliation_ok:true,projection_consistent:true,events_consistent:true,scan_cron_contract_ok:true,monitor_cron_contract_ok:true,daily_report_cron_contract_ok:true,daily_report_fresh:false,scan_fresh:true,monitor_fresh:true}
}' > "$fixture/state/youdo-monitor.json"

if YOUDO_WORKSPACE="$fixture" "$fixture/scripts/finish-youdo-monitor-run.zsh"; then
  print -u2 'first unhealthy state unexpectedly succeeded'
  exit 1
else
  [[ $? == 3 ]]
fi
YOUDO_WORKSPACE="$fixture" "$fixture/scripts/finish-youdo-monitor-run.zsh"

/usr/bin/jq '.technical.auth_ok = false' "$fixture/state/youdo-monitor.json" > "$fixture/state/monitor.next"
/bin/mv "$fixture/state/monitor.next" "$fixture/state/youdo-monitor.json"
if YOUDO_WORKSPACE="$fixture" "$fixture/scripts/finish-youdo-monitor-run.zsh"; then
  print -u2 'changed unhealthy state unexpectedly succeeded'
  exit 1
else
  [[ $? == 3 ]]
fi

/usr/bin/jq '.technical.package_ok = false | .checked_at = "2026-08-23T07:01:00Z"' "$fixture/state/youdo-monitor.json" > "$fixture/state/monitor.next"
/bin/mv "$fixture/state/monitor.next" "$fixture/state/youdo-monitor.json"
YOUDO_WORKSPACE="$fixture" "$fixture/scripts/finish-youdo-monitor-run.zsh"
if YOUDO_WORKSPACE="$fixture" "$fixture/scripts/finish-youdo-monitor-run.zsh"; then
  print -u2 'pending changed failure did not alert after the breaker tick'
  exit 1
else
  [[ $? == 3 ]]
fi

/usr/bin/jq '.technical.healthy = true | .technical.auth_ok = true | .technical.package_ok = true | .checked_at = "2026-08-23T07:05:00Z"' "$fixture/state/youdo-monitor.json" > "$fixture/state/monitor.next"
/bin/mv "$fixture/state/monitor.next" "$fixture/state/youdo-monitor.json"
YOUDO_WORKSPACE="$fixture" "$fixture/scripts/finish-youdo-monitor-run.zsh"
/usr/bin/jq -e '.active == false and .last_recovered_at == "2026-08-23T07:05:00Z"' "$fixture/state/youdo-monitor-alert.json" >/dev/null

/usr/bin/jq '.technical.healthy = false | .technical.daily_report_fresh = false | .checked_at = "2026-08-23T07:10:00Z"' "$fixture/state/youdo-monitor.json" > "$fixture/state/monitor.next"
/bin/mv "$fixture/state/monitor.next" "$fixture/state/youdo-monitor.json"
if YOUDO_WORKSPACE="$fixture" "$fixture/scripts/finish-youdo-monitor-run.zsh"; then
  print -u2 'new outage after recovery unexpectedly succeeded'
  exit 1
else
  [[ $? == 3 ]]
fi
/usr/bin/jq -e '.active == true and (.fingerprint|type) == "string" and (.fingerprint|length) == 64' "$fixture/state/youdo-monitor-alert.json" >/dev/null

/usr/bin/jq -cn '{ok:true}'
