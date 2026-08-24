#!/bin/zsh
set -euo pipefail

stage=${0:A:h:h}

bypass=$(/usr/bin/grep -R -n -E --include='*.zsh' -e 'youdo[[:space:]].*offer[[:space:]]+create' "$stage/scripts" || true)
printf '%s' "$bypass" | /usr/bin/grep -v 'youdo-exec.zsh' && {
  print -u2 "bare youdo offer create outside wrapper"
  exit 1
}

/usr/bin/grep -n -E --include='*.zsh' -e 'offer[[:space:]]+create' "$stage/scripts/run-youdo-auto-offer-if-new.zsh" \
  "$stage/scripts/youdo-sla-monitor.zsh" \
  "$stage/scripts/scan-youdo-new-tasks.zsh" && {
  print -u2 "cron or monitor path creates offers"
  exit 1
}

/usr/bin/jq -cn '{ok:true}'
