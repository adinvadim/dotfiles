#!/bin/zsh
set -euo pipefail

stage=${0:A:h:h}
fixture=$(/usr/bin/mktemp -d)
cleanup() { /bin/rm -rf "$fixture"; }
trap cleanup EXIT INT TERM

/bin/mkdir -p "$fixture/scripts" "$fixture/state"
/bin/cp "$stage/scripts/record-youdo-crm-transition.zsh" "$fixture/scripts/"
/bin/cp "$stage/scripts/sync-youdo-crm.zsh" "$fixture/scripts/"
/bin/cp "$stage/scripts/youdo-crm.zsh" "$fixture/scripts/"
/bin/cp "$stage/scripts/attach-youdo-correspondence.zsh" "$fixture/scripts/"
/bin/cp "$stage/scripts/ensure-youdo-project.zsh" "$fixture/scripts/"
/bin/chmod 700 "$fixture/scripts/"*.zsh

/usr/bin/jq -n '{
  schema_version:1,updated_at:"2026-08-24T00:00:00Z",tasks:{
    "101":{task_id:"101",state:"confirmed",offer_id:"9001",category_name:"Разработка",subcategory_name:"Сайты"},
    "102":{task_id:"102",state:"confirmed",offer_id:"9002",category_name:"Разработка",subcategory_name:"Боты"},
    "103":{task_id:"103",state:"deferred",reason:"payment_blocked"}
  },events:[]
}' > "$fixture/state/youdo-operations.json"

YOUDO_WORKSPACE="$fixture" "$fixture/scripts/sync-youdo-crm.zsh" >/dev/null
/usr/bin/jq -e '
  .deals["101"].funnel == "offered"
  and .deals["102"].funnel == "offered"
  and (.deals["103"] == null)
' "$fixture/state/youdo-crm.json" >/dev/null

replay=$(YOUDO_WORKSPACE="$fixture" "$fixture/scripts/sync-youdo-crm.zsh")
printf '%s' "$replay" | /usr/bin/jq -e '.ok == true and .deal_count == 2' >/dev/null
/usr/bin/jq -e '.deals["101"].funnel == "offered"' "$fixture/state/youdo-crm.json" >/dev/null

YOUDO_WORKSPACE="$fixture" "$fixture/scripts/record-youdo-crm-transition.zsh" 101 message_received >/dev/null
again=$(YOUDO_WORKSPACE="$fixture" "$fixture/scripts/record-youdo-crm-transition.zsh" 101 message_received)
printf '%s' "$again" | /usr/bin/jq -e '.ok == true and .idempotent == true' >/dev/null

if skip=$(YOUDO_WORKSPACE="$fixture" "$fixture/scripts/record-youdo-crm-transition.zsh" 101 done_paid); then
  print -u2 'illegal skip unexpectedly succeeded'
  exit 1
fi
printf '%s' "$skip" | /usr/bin/jq -e '.ok == false and .error == "illegal_funnel_transition"' >/dev/null

/usr/bin/jq -n '{schema_version:1,generated_at:"2026-08-24T01:00:00Z",new_count:1,items:[{task_id:"102",user_id:"7"}]}' > "$fixture/state/inbox-scan-pending.json"
YOUDO_WORKSPACE="$fixture" "$fixture/scripts/sync-youdo-crm.zsh" >/dev/null
/usr/bin/jq -e '
  .deals["101"].funnel == "message_received"
  and .deals["102"].funnel == "message_received"
' "$fixture/state/youdo-crm.json" >/dev/null

view=$(YOUDO_WORKSPACE="$fixture" "$fixture/scripts/youdo-crm.zsh")
printf '%s' "$view" | /usr/bin/jq -e '
  .ok == true
  and .deal_count == 2
  and .funnel.message_received == 2
  and .funnel.offered == 0
  and any(.categories[]; .name == "Сайты" and .count == 1)
  and any(.deals[]; .task_id == "101" and .funnel_label == "Получено сообщение")
' >/dev/null
[[ -f $fixture/state/youdo-crm.md ]] || { print -u2 'crm snapshot missing'; exit 1; }

/bin/mkdir -p "$fixture/state/correspondence/101"
print '{"ok":true,"chat_id":"777","messages":1}' > "$fixture/state/correspondence/101/messages.json"
attached=$(YOUDO_WORKSPACE="$fixture" "$fixture/scripts/attach-youdo-correspondence.zsh" 101 777 state/correspondence/101)
printf '%s' "$attached" | /usr/bin/jq -e '.ok == true and .idempotent == false' >/dev/null
again_attach=$(YOUDO_WORKSPACE="$fixture" "$fixture/scripts/attach-youdo-correspondence.zsh" 101 777 state/correspondence/101)
printf '%s' "$again_attach" | /usr/bin/jq -e '.ok == true and .idempotent == true' >/dev/null
/usr/bin/jq -e '
  .deals["101"].funnel == "message_received"
  and .deals["101"].correspondence.chat_id == "777"
  and .deals["101"].correspondence.archive_path == "state/correspondence/101"
  and .deals["101"].correspondence.source == "telecrawl"
  and .deals["102"].correspondence == null
  and (.deals | keys | length) == 2
' "$fixture/state/youdo-crm.json" >/dev/null
[[ ! -d $fixture/projects/youdo/101 ]] || { print -u2 'project folder created on offered/message_received'; exit 1; }

if offered_project=$(YOUDO_WORKSPACE="$fixture" "$fixture/scripts/ensure-youdo-project.zsh" 102); then
  print -u2 'project folder unexpectedly created for untaken deal'
  exit 1
fi
printf '%s' "$offered_project" | /usr/bin/jq -e '.ok == false and .error == "funnel_not_taken"' >/dev/null

YOUDO_WORKSPACE="$fixture" "$fixture/scripts/record-youdo-crm-transition.zsh" 101 in_progress >/dev/null
[[ -d $fixture/projects/youdo/101 ]] || { print -u2 'project folder missing after in_progress'; exit 1; }
[[ -d $fixture/projects/youdo/101/correspondence ]] || { print -u2 'correspondence not moved into project folder'; exit 1; }
[[ ! -d $fixture/state/correspondence/101 ]] || { print -u2 'stale correspondence staging left behind'; exit 1; }
/usr/bin/jq -e '
  .deals["101"].funnel == "in_progress"
  and .deals["101"].project_path == "projects/youdo/101"
  and .deals["101"].correspondence.archive_path == "projects/youdo/101/correspondence"
' "$fixture/state/youdo-crm.json" >/dev/null

replay_taken=$(YOUDO_WORKSPACE="$fixture" "$fixture/scripts/record-youdo-crm-transition.zsh" 101 in_progress)
printf '%s' "$replay_taken" | /usr/bin/jq -e '.ok == true and .idempotent == true' >/dev/null
[[ -d $fixture/projects/youdo/101 ]] || { print -u2 'project folder lost on replay'; exit 1; }
/usr/bin/jq -e '
  .deals["101"].project_path == "projects/youdo/101"
  and (.deals | keys | length) == 2
' "$fixture/state/youdo-crm.json" >/dev/null

/usr/bin/jq -cn '{ok:true}'
