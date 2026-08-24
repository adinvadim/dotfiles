#!/bin/zsh
set -euo pipefail

stage=${0:A:h:h}
fixture=$(/usr/bin/mktemp -d)
cleanup() { /bin/rm -rf "$fixture"; }
trap cleanup EXIT INT TERM

/bin/mkdir -p "$fixture/scripts" "$fixture/state"
/bin/cp "$stage/scripts/record-youdo-outcome.zsh" "$fixture/scripts/record-youdo-outcome-real.zsh"
/bin/cp "$stage/scripts/requeue-youdo-covered-payment-blocked.zsh" "$fixture/scripts/requeue-youdo-covered-payment-blocked.zsh"

/bin/cat > "$fixture/state/youdo-operations.json" <<'JSON'
{"schema_version":1,"updated_at":"2026-08-21T00:00:00Z","tasks":{"101":{"task_id":"101","eligibility":"conditional","state":"deferred","reason":"payment_blocked","retry_after":"2026-08-22T00:00:00Z"},"102":{"task_id":"102","eligibility":"conditional","state":"deferred","reason":"verification_unavailable","origin_reason":"payment_blocked","retry_after":"2026-08-22T00:00:00Z"},"103":{"task_id":"103","eligibility":"eligible","state":"confirmed","offer_id":"900","resolved_at":"2026-08-21T00:00:00Z"},"104":{"task_id":"104","eligibility":"conditional","state":"deferred","reason":"payment_blocked","retry_after":"2026-08-22T00:00:00Z"}},"events":[]}
JSON
/bin/cat > "$fixture/state/auto-offer-ledger.json" <<'JSON'
{"schema_version":3,"updated_at":"2026-08-21T00:00:00Z","last_run":"2026-08-21T00:00:00Z","sent_task_ids":[],"offers":[],"ambiguous_task_ids":[],"terminal_task_ids":[],"terminal":[]}
JSON
/bin/cat > "$fixture/scripts/youdo-exec.zsh" <<'ZSH'
#!/bin/zsh
set -euo pipefail
[[ $1 == cli && $2 == --timeout && $3 == 90s && $4 == --account && $5 == personal && $6 == offer && $7 == package && $8 == check && $9 == <-> && ${10} == --json ]] || exit 9
lock=${0:A:h:h}/state/.youdo-auto-offer.lock
age=$(( $(/bin/date +%s) - $(/usr/bin/stat -f %m "$lock") ))
(( age <= 5 )) || exit 7
/usr/bin/touch -t 202001010000 "$lock"
[[ $9 != 102 || ! -f ${0:A:h:h}/state/fail-102 ]] || exit 8
if [[ $9 == 101 && -f ${0:A:h:h}/state/steal-101 ]]; then
  printf '%s\n' 424242 > "$lock/pid"
fi
covered=false
[[ $9 == 101 || $9 == 104 ]] && covered=true
/usr/bin/jq -cn --arg task "$9" --argjson covered "$covered" '{ok:true,data:{taskId:$task,categoryId:"4194304",subcategoryId:"63",covered:$covered}}'
ZSH
/bin/cat > "$fixture/scripts/record-youdo-outcome.zsh" <<'ZSH'
#!/bin/zsh
set -euo pipefail
lock=${0:A:h:h}/state/.youdo-auto-offer.lock
if [[ -d $lock ]]; then
  age=$(( $(/bin/date +%s) - $(/usr/bin/stat -f %m "$lock") ))
  (( age <= 5 )) || exit 7
  /usr/bin/touch -t 202001010000 "$lock"
fi
exec "${0:A:h}/record-youdo-outcome-real.zsh" "$@"
ZSH
/bin/chmod 700 "$fixture/scripts/"*.zsh

/usr/bin/touch "$fixture/state/steal-101"
if stolen=$(YOUDO_WORKSPACE="$fixture" "$fixture/scripts/requeue-youdo-covered-payment-blocked.zsh"); then
  print -u2 'lost lock unexpectedly succeeded'
  exit 1
fi
printf '%s' "$stolen" | /usr/bin/jq -e '.ok == false and .error == "auto_offer_lock_lost"' >/dev/null
[[ $(/bin/cat "$fixture/state/.youdo-auto-offer.lock/pid") == 424242 ]]
/bin/rm "$fixture/state/steal-101" "$fixture/state/.youdo-auto-offer.lock/pid"
/bin/rmdir "$fixture/state/.youdo-auto-offer.lock"

/usr/bin/touch "$fixture/state/fail-102"
if failed=$(YOUDO_WORKSPACE="$fixture" "$fixture/scripts/requeue-youdo-covered-payment-blocked.zsh"); then
  print -u2 'coverage read failure unexpectedly succeeded'
  exit 1
fi
printf '%s' "$failed" | /usr/bin/jq -e '.ok == false and .error == "package_coverage_check_failed"' >/dev/null
/usr/bin/jq -e '.tasks["101"].state == "deferred" and .tasks["102"].state == "deferred" and .tasks["104"].state == "deferred"' "$fixture/state/youdo-operations.json" >/dev/null
/bin/rm "$fixture/state/fail-102"

first=$(YOUDO_WORKSPACE="$fixture" "$fixture/scripts/requeue-youdo-covered-payment-blocked.zsh")
printf '%s' "$first" | /usr/bin/jq -e '
  .ok == true and .candidate_count == 3 and .covered_task_ids == ["101", "104"]
  and .uncovered_task_ids == ["102"] and .requeued_count == 2 and .llm_calls == 0
' >/dev/null
/usr/bin/jq -e '
  .tasks["101"].state == "retryable"
  and .tasks["101"].reason == "package_coverage_available"
  and .tasks["101"].origin_reason == "payment_blocked"
  and .tasks["102"].state == "deferred"
  and .tasks["103"].state == "confirmed"
  and .tasks["104"].state == "retryable"
' "$fixture/state/youdo-operations.json" >/dev/null

if conflict=$(YOUDO_WORKSPACE="$fixture" "$fixture/scripts/record-youdo-outcome-real.zsh" package_recovered 103); then
  print -u2 'confirmed task package recovery unexpectedly succeeded'
  exit 1
fi
printf '%s' "$conflict" | /usr/bin/jq -e '.ok == false and .error == "package_recovery_state_conflict"' >/dev/null
/usr/bin/jq -e '.tasks["103"].state == "confirmed"' "$fixture/state/youdo-operations.json" >/dev/null

second=$(YOUDO_WORKSPACE="$fixture" "$fixture/scripts/requeue-youdo-covered-payment-blocked.zsh")
printf '%s' "$second" | /usr/bin/jq -e '
  .ok == true and .candidate_count == 1 and .covered_task_ids == []
  and .uncovered_task_ids == ["102"] and .requeued_count == 0 and .llm_calls == 0
' >/dev/null

/usr/bin/jq -cn '{ok:true}'
