#!/bin/zsh
set -euo pipefail

stage=${0:A:h:h}
fixture=$(/usr/bin/mktemp -d)
cleanup() { /bin/rm -rf "$fixture"; }
trap cleanup EXIT INT TERM

/bin/mkdir -p "$fixture/state" "$fixture/scripts"
/bin/cp "$stage/scripts/record-youdo-stage-timing.zsh" "$fixture/scripts/"
/bin/chmod 700 "$fixture/scripts/record-youdo-stage-timing.zsh"

first=$(YOUDO_WORKSPACE="$fixture" zsh "$fixture/scripts/record-youdo-stage-timing.zsh" 15120196 detect start)
printf '%s' "$first" | /usr/bin/jq -e '.ok == true and .task_id == "15120196" and .first_seen != null' >/dev/null
seen=$(printf '%s' "$first" | /usr/bin/jq -r '.first_seen')

/bin/sleep 1
YOUDO_WORKSPACE="$fixture" zsh "$fixture/scripts/record-youdo-stage-timing.zsh" 15120196 detect end >/dev/null
YOUDO_WORKSPACE="$fixture" zsh "$fixture/scripts/record-youdo-stage-timing.zsh" 15120196 tariff start >/dev/null
YOUDO_WORKSPACE="$fixture" zsh "$fixture/scripts/record-youdo-stage-timing.zsh" 15120196 tariff end >/dev/null
YOUDO_WORKSPACE="$fixture" zsh "$fixture/scripts/record-youdo-stage-timing.zsh" 15120196 create start >/dev/null
YOUDO_WORKSPACE="$fixture" zsh "$fixture/scripts/record-youdo-stage-timing.zsh" 15120196 create end >/dev/null
YOUDO_WORKSPACE="$fixture" zsh "$fixture/scripts/record-youdo-stage-timing.zsh" 15120196 verify start >/dev/null
YOUDO_WORKSPACE="$fixture" zsh "$fixture/scripts/record-youdo-stage-timing.zsh" 15120196 verify end >/dev/null
YOUDO_WORKSPACE="$fixture" zsh "$fixture/scripts/record-youdo-stage-timing.zsh" 15120196 publish_confirm start >/dev/null
published=$(YOUDO_WORKSPACE="$fixture" zsh "$fixture/scripts/record-youdo-stage-timing.zsh" 15120196 publish_confirm end)

again=$(YOUDO_WORKSPACE="$fixture" zsh "$fixture/scripts/record-youdo-stage-timing.zsh" 15120196 hydrate start)
again_seen=$(printf '%s' "$again" | /usr/bin/jq -r '.first_seen')
[[ $again_seen == "$seen" ]] || { print -u2 "first_seen mutated"; exit 1; }

printf '%s' "$published" | /usr/bin/jq -e '
  .ok == true
  and .detect_to_publish_s != null
  and .detect_to_publish_s >= 1
' >/dev/null

/usr/bin/jq -e --arg seen "$seen" '
  .tasks["15120196"].first_seen == $seen
  and .tasks["15120196"].stages.detect.duration_s != null
  and .tasks["15120196"].stages.tariff.ended_at != null
  and .tasks["15120196"].detect_to_publish_s >= 1
' "$fixture/state/youdo-task-timings.json" >/dev/null

/usr/bin/jq -cn '{ok:true}'
