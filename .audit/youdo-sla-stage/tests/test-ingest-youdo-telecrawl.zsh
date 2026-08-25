#!/bin/zsh
set -euo pipefail

stage=${0:A:h:h}
fixture=$(/usr/bin/mktemp -d)
cleanup() { /bin/rm -rf "$fixture"; }
trap cleanup EXIT INT TERM

/bin/mkdir -p "$fixture/bin" "$fixture/scripts" "$fixture/state"
/bin/cp "$stage/scripts/ingest-youdo-telecrawl.zsh" "$fixture/scripts/"
/bin/cp "$stage/scripts/attach-youdo-correspondence.zsh" "$fixture/scripts/"
/bin/chmod 700 "$fixture/scripts/"*.zsh

/usr/bin/jq -n '{
  schema_version:1,
  updated_at:"2026-08-25T00:00:00Z",
  deals:{
    "101":{task_id:"101",offer_id:"9001",funnel:"offered",title:"Сайт для Ивана",client_name:"Иван Петров",category_name:"Разработка",subcategory_name:"Сайты",updated_at:"2026-08-25T00:00:00Z"},
    "102":{task_id:"102",offer_id:"9002",funnel:"offered",title:"Бот для Марии",client_name:"Мария",category_name:"Разработка",subcategory_name:"Боты",updated_at:"2026-08-25T00:00:00Z"}
  }
}' > "$fixture/state/youdo-crm.json"

cat > "$fixture/bin/telecrawl" <<'EOF'
#!/bin/zsh
set -euo pipefail
log=${TELECRAWL_ARGV_LOG:-/dev/null}
print -r -- ${(j: :)argv} >> "$log"
case ${1:-}:${2:-} in
  --json:chats)
    /usr/bin/jq -n '[
      {jid:"111",kind:"user",name:"Иван Петров",message_count:3},
      {jid:"222",kind:"user",name:"Иван Петров Jr",message_count:1},
      {jid:"333",kind:"user",name:"Unique Client",message_count:2}
    ]'
    ;;
  --json:import)
    /usr/bin/jq -n --arg chat "${4:-}" '{ok:true,imported:true,chat:$chat}'
    ;;
  --json:messages)
    /usr/bin/jq -n --arg chat "${4:-}" '{ok:true,chat_id:$chat,messages:[{text:"hi"}]}'
    ;;
  *)
    print -u2 "unexpected telecrawl argv: ${(j: :)argv}"
    exit 1
    ;;
esac
EOF
/bin/chmod 700 "$fixture/bin/telecrawl"

run_ingest() {
  YOUDO_WORKSPACE="$fixture" TELECRAWL_BIN="$fixture/bin/telecrawl" TELECRAWL_ARGV_LOG="$fixture/argv.log" \
    "$fixture/scripts/ingest-youdo-telecrawl.zsh" "$@"
}

if /usr/bin/grep -E '(^|[[:space:]])(send|post|write|sessions_send|conversations_send)($|[[:space:]])' "$stage/scripts/ingest-youdo-telecrawl.zsh" >/dev/null; then
  print -u2 'ingest script contains a write verb'
  exit 1
fi

exact=$(run_ingest --query 'Иван Петров' --task-id 101)
printf '%s' "$exact" | /usr/bin/jq -e '.ok == true and .task_id == "101" and .chat_id == "111" and .idempotent == false' >/dev/null
[[ -f $fixture/state/correspondence/101/messages.json ]] || { print -u2 'archive missing'; exit 1; }

again=$(run_ingest --query 'Иван Петров' --task-id 101)
printf '%s' "$again" | /usr/bin/jq -e '.ok == true and .chat_id == "111" and .idempotent == true' >/dev/null

unique=$(run_ingest --query 'Unique' --task-id 102)
printf '%s' "$unique" | /usr/bin/jq -e '.ok == true and .task_id == "102" and .chat_id == "333"' >/dev/null

if amb=$(run_ingest --query 'Иван' --task-id 101); then
  print -u2 'ambiguous chat match unexpectedly succeeded'
  exit 1
fi
printf '%s' "$amb" | /usr/bin/jq -e '
  .ok == false
  and .error == "ambiguous_chat_match"
  and (.candidates|length) == 2
  and any(.candidates[]; .chat_id == "111")
  and any(.candidates[]; .chat_id == "222")
' >/dev/null

if missing=$(run_ingest --query 'Нет такого чата' --task-id 101); then
  print -u2 'missing chat unexpectedly succeeded'
  exit 1
fi
printf '%s' "$missing" | /usr/bin/jq -e '.ok == false and .error == "no_chat_match"' >/dev/null

hatch=$(run_ingest --task-id 102 --chat-id 333 --skip-import)
printf '%s' "$hatch" | /usr/bin/jq -e '.ok == true and .chat_id == "333"' >/dev/null

by_deal=$(run_ingest --query 'Иван Петров')
printf '%s' "$by_deal" | /usr/bin/jq -e '.ok == true and .task_id == "101" and .chat_id == "111" and .idempotent == true' >/dev/null

if no_deal=$(run_ingest --query 'Unique Client'); then
  print -u2 'deal-less unique chat unexpectedly attached'
  exit 1
fi
printf '%s' "$no_deal" | /usr/bin/jq -e '.ok == false and .error == "deal_unmatched"' >/dev/null

/usr/bin/grep -E '(^|[[:space:]])(send|post|write)($|[[:space:]])' "$fixture/argv.log" >/dev/null && {
  print -u2 'fake telecrawl received a write verb'
  exit 1
}

/usr/bin/jq -cn '{ok:true}'
