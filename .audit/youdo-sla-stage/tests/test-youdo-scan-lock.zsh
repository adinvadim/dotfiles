#!/bin/zsh
set -euo pipefail

stage=${0:A:h:h}
fixture=$(/usr/bin/mktemp -d)
cleanup() {
  /bin/kill "$holder_pid" 2>/dev/null || true
  /bin/rm -rf "$fixture"
}
trap cleanup EXIT INT TERM

/bin/mkdir -p "$fixture/state" "$fixture/scripts"
/bin/cp "$stage/scripts/run-youdo-auto-offer-if-new.zsh" "$fixture/scripts/"
/bin/chmod 700 "$fixture/scripts/run-youdo-auto-offer-if-new.zsh"

/bin/sleep 120 &
holder_pid=$!
lock_dir="$fixture/state/.youdo-auto-offer.lock"
/bin/mkdir "$lock_dir"
printf '%s\n' "$holder_pid" > "$lock_dir/pid"

out=$(YOUDO_WORKSPACE="$fixture" zsh "$fixture/scripts/run-youdo-auto-offer-if-new.zsh")
printf '%s' "$out" | /usr/bin/jq -e '.ok == true and .busy == true and .llm_calls == 0' >/dev/null

/usr/bin/jq -cn '{ok:true}'
