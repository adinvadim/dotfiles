#!/bin/zsh
set -euo pipefail

# Read-only inbox pass for the existing YouDo обход.
# Detects new inbound customer messages. Never calls chat.send.

workspace=${YOUDO_WORKSPACE:-/Users/mini/.openclaw/workspace-freelancer}
principal=${YOUDO_PRINCIPAL_ID:-1083331}
ledger="$workspace/state/inbox-scan-ledger.json"
pending="$workspace/state/inbox-scan-pending.json"
export PATH=/Users/mini/.local/bin:/Users/mini/bin:/opt/homebrew/bin:/usr/bin:/bin

now_utc=$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)
tmp_dir=$(/usr/bin/mktemp -d "$workspace/state/.inbox-scan.XXXXXX")
cleanup() { /bin/rm -rf "$tmp_dir" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

if [[ ! -f $ledger ]]; then
  /usr/bin/jq -cn --arg now "$now_utc" '{schema_version:1,seen:{},last_scan_at:null,last_error:null}' > "$ledger"
  /bin/chmod 600 "$ledger"
fi

archive_chat=$("$workspace/scripts/youdo-exec.zsh" cli --timeout 90s --account personal --json chat list --limit 50 2>/dev/null || true)
archive_notes=$("$workspace/scripts/youdo-exec.zsh" cli --timeout 90s --account personal --json notification list --limit 50 2>/dev/null || true)

if ! printf '%s' "$archive_chat" | /usr/bin/jq -e '.ok == true and (.data|type)=="array"' >/dev/null 2>&1; then
  archive_chat='{"ok":false,"data":[]}'
fi
if ! printf '%s' "$archive_notes" | /usr/bin/jq -e '.ok == true and (.data|type)=="array"' >/dev/null 2>&1; then
  archive_notes='{"ok":false,"data":[]}'
fi

live_contacts='{"ok":false,"data":[],"error":null}'
live_error=""
if live_raw=$("$workspace/scripts/youdo-exec.zsh" cli --timeout 90s --account personal --json chat contact list 2>"$tmp_dir/live.err"); then
  if printf '%s' "$live_raw" | /usr/bin/jq -e '.ok == true and (.data|type)=="array"' >/dev/null 2>&1; then
    live_contacts=$live_raw
  else
    live_error=$(printf '%s' "$live_raw" | /usr/bin/jq -r '.error.message // .error.code // "invalid_contact_list"')
  fi
else
  live_error=$(/usr/bin/tr '\n' ' ' < "$tmp_dir/live.err")
  [[ -n $live_error ]] || live_error="chat_contact_list_failed"
fi

candidates=$(/usr/bin/jq -cn \
  --arg principal "$principal" \
  --argjson live "$live_contacts" \
  --argjson chats "$archive_chat" \
  --argjson notes "$archive_notes" '
    def counterpart($item; $principal):
      ([$item.SenderId, $item.senderId, $item.RecipientId, $item.recipientId]
        | map(tostring | select(test("^[0-9]+$") and . != $principal and . != "0"))
        | .[0] // empty);
    def task_url($id):
      if ($id|tostring|test("^[0-9]+$")) then "https://youdo.com/t\($id)" else null end;
    [
      (($live.data // [])[]? | select(.IsNewMessage == true) | {
        source: "live_contact",
        user_id: (counterpart(.; $principal)),
        name: (([.Name, .LastName] | map(select(type=="string" and length>0)) | join(" ")) // ""),
        user_name: (.UserName // .SenderLogin // ""),
        message_id: null,
        message_text: (.LastMessageText // ""),
        message_at: (.LastMessageDate // ""),
        task_id: null,
        conversation_url: null,
        task_url: null
      }),
      (($chats.data // [])[]? | . as $row | {
        source: "archive_chat",
        user_id: (($row.userId // $row.user_id // $row.counterpartId // empty)|tostring),
        name: ($row.name // $row.title // ""),
        user_name: ($row.userName // ""),
        message_id: (($row.lastMessageId // $row.messageId // empty)|tostring),
        message_text: ($row.lastMessageText // $row.text // ""),
        message_at: ($row.lastMessageDate // $row.date // ""),
        task_id: (($row.taskId // empty)|tostring),
        conversation_url: (task_url($row.taskId // empty)),
        task_url: (task_url($row.taskId // empty))
      } | select(.user_id != "" and .user_id != $principal)),
      (($notes.data // [])[]? | select((.type // .kind // "") | tostring | test("chat|message|dialog"; "i")) | {
        source: "archive_notification",
        user_id: ((.userId // .fromUserId // empty)|tostring),
        name: (.title // .name // ""),
        user_name: "",
        message_id: ((.id // .notificationId // empty)|tostring),
        message_text: (.text // .body // ""),
        message_at: (.date // .createdAt // ""),
        task_id: ((.taskId // empty)|tostring),
        conversation_url: (task_url(.taskId // empty)),
        task_url: (task_url(.taskId // empty))
      })
    ]
    | map(select((.user_id|type)=="string" and (.user_id|test("^[0-9]+$"))))
    | map(.dedupe_key = (
        if .message_id != null and .message_id != "" then "msg:\(.user_id):\(.message_id)"
        else "preview:\(.user_id):\(.message_at):\(.message_text)"
        end
      ))
  ')

new_items=$(/usr/bin/jq -cn --argjson candidates "$candidates" --slurpfile ledger "$ledger" '
  ($ledger[0].seen // {}) as $seen
  | [$candidates[] | select($seen[.dedupe_key] == null)]
')

new_count=$(printf '%s' "$new_items" | /usr/bin/jq 'length')

/usr/bin/jq -n --arg now "$now_utc" --argjson items "$new_items" --argjson count "$new_count" \
  '{schema_version:1,generated_at:$now,new_count:$count,items:$items}' > "$tmp_dir/pending.json"
/bin/chmod 600 "$tmp_dir/pending.json"
/bin/mv "$tmp_dir/pending.json" "$pending"

/usr/bin/jq -n --arg now "$now_utc" --arg error "$live_error" --argjson items "$new_items" --slurpfile ledger "$ledger" '
  ($ledger[0].seen // {}) as $seen
  | reduce $items[] as $item ($seen; .[$item.dedupe_key] = {seen_at:$now, user_id:$item.user_id, source:$item.source})
  | {schema_version:1, last_scan_at:$now, last_error:(if $error == "" then null else $error end), seen:.}
' > "$tmp_dir/ledger.json"
/bin/chmod 600 "$tmp_dir/ledger.json"
/bin/mv "$tmp_dir/ledger.json" "$ledger"

live_ok=false
printf '%s' "$live_contacts" | /usr/bin/jq -e '.ok == true' >/dev/null 2>&1 && live_ok=true
archive_chat_ok=false
printf '%s' "$archive_chat" | /usr/bin/jq -e '.ok == true' >/dev/null 2>&1 && archive_chat_ok=true
archive_notes_ok=false
printf '%s' "$archive_notes" | /usr/bin/jq -e '.ok == true' >/dev/null 2>&1 && archive_notes_ok=true

/usr/bin/jq -cn \
  --argjson new_count "$new_count" \
  --argjson items "$new_items" \
  --argjson live_ok "$live_ok" \
  --argjson archive_chat_ok "$archive_chat_ok" \
  --argjson archive_notes_ok "$archive_notes_ok" \
  --arg live_error "$live_error" \
  '{
    ok:true,
    new_count:$new_count,
    items:$items,
    live_contact_ok:$live_ok,
    archive_chat_ok:$archive_chat_ok,
    archive_notification_ok:$archive_notes_ok,
    live_error:(if $live_error=="" then null else $live_error end),
    chat_send:false,
    llm_calls:0
  }'
