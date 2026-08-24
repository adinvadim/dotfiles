#!/bin/zsh
set -euo pipefail

stage=${0:A:h:h}
fixture=$(/usr/bin/mktemp -d)
cleanup() { /bin/rm -rf "$fixture"; }
trap cleanup EXIT INT TERM

/bin/mkdir -p "$fixture/scripts" "$fixture/state"
/bin/cp "$stage/scripts/record-youdo-outcome.zsh" "$fixture/scripts/record-youdo-outcome.zsh"
/bin/chmod 700 "$fixture/scripts/record-youdo-outcome.zsh"
/usr/bin/jq -n '{
  schema_version:1,updated_at:"2026-08-21T00:00:00Z",tasks:{
    "203":{task_id:"203",eligibility:"conditional",state:"deferred",reason:"verification_unavailable",origin_reason:"payment_blocked",retry_after:"2026-08-22T00:00:00Z",updated_at:"2026-08-22T05:00:00Z"},
    "204":{task_id:"204",eligibility:"eligible",state:"missed",reason:"payment_blocked_until_expiry",resolved_at:"2026-08-22T06:00:00Z"}
  },events:[],payment_blocked_events:[]
}' > "$fixture/state/youdo-operations.json"
/usr/bin/jq -n '{schema_version:3,updated_at:"2026-08-21T00:00:00Z",last_run:"2026-08-21T00:00:00Z",sent_task_ids:[],offers:[],ambiguous_task_ids:[],terminal_task_ids:[],terminal:[]}' > "$fixture/state/auto-offer-ledger.json"

retry_after=$(/bin/date -u -v+1d +%Y-%m-%dT%H:%M:%SZ)
YOUDO_WORKSPACE="$fixture" "$fixture/scripts/record-youdo-outcome.zsh" deferred 201 payment_blocked "$retry_after" 4194304 63 Разработка Сайты >/dev/null
YOUDO_WORKSPACE="$fixture" "$fixture/scripts/record-youdo-outcome.zsh" deferred 201 payment_blocked "$retry_after" 4194304 63 Разработка Сайты >/dev/null
/usr/bin/jq -e '
  .tasks["201"].state == "deferred" and .tasks["201"].reason == "payment_blocked"
  and ([.payment_blocked_events[] | select(.task_id == "201")]|length) == 1
  and .payment_blocked_events[0].category_id == "4194304"
  and .payment_blocked_events[0].subcategory_id == "63"
  and .payment_blocked_events[0].subcategory_name == "Сайты"
' "$fixture/state/youdo-operations.json" >/dev/null

if conflict=$(YOUDO_WORKSPACE="$fixture" "$fixture/scripts/record-youdo-outcome.zsh" classify_payment_blocked 201 4194304 64 Разработка Другое 2026-08-21T04:00:00Z); then
  print -u2 'classification conflict unexpectedly succeeded'
  exit 1
fi
printf '%s' "$conflict" | /usr/bin/jq -e '.ok == false and .error == "payment_classification_conflict"' >/dev/null

YOUDO_WORKSPACE="$fixture" "$fixture/scripts/record-youdo-outcome.zsh" classify_payment_blocked 203 4194304 146 Разработка Автоматизация 2026-08-21T05:00:00Z >/dev/null
replay=$(YOUDO_WORKSPACE="$fixture" "$fixture/scripts/record-youdo-outcome.zsh" classify_payment_blocked 203 4194304 146 Разработка Автоматизация 2026-08-21T05:00:00Z)
printf '%s' "$replay" | /usr/bin/jq -e '.ok == true and .idempotent == true' >/dev/null
/usr/bin/jq -e '
  ([.payment_blocked_events[] | select(.task_id == "203")]|length) == 1
  and ([.payment_blocked_events[] | select(.task_id == "203")][0].occurred_at == "2026-08-21T05:00:00Z")
' "$fixture/state/youdo-operations.json" >/dev/null

YOUDO_WORKSPACE="$fixture" "$fixture/scripts/record-youdo-outcome.zsh" classify_payment_blocked 204 4194304 63 Разработка Сайты 2026-08-21T06:00:00Z >/dev/null
/usr/bin/jq -e '
  .tasks["204"].state == "missed" and .tasks["204"].reason == "payment_blocked_until_expiry"
  and .tasks["204"].first_payment_blocked_at == "2026-08-21T06:00:00Z"
  and any(.payment_blocked_events[]; .task_id == "204" and .occurred_at == "2026-08-21T06:00:00Z")
' "$fixture/state/youdo-operations.json" >/dev/null

YOUDO_WORKSPACE="$fixture" "$fixture/scripts/record-youdo-outcome.zsh" deferred 202 verification_unavailable "$retry_after" >/dev/null
/usr/bin/jq -e 'all(.payment_blocked_events[]; .task_id != "202")' "$fixture/state/youdo-operations.json" >/dev/null

/usr/bin/jq -cn '{ok:true}'
