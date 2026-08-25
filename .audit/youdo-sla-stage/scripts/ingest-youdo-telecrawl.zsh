#!/bin/zsh
set -euo pipefail

workspace=${YOUDO_WORKSPACE:-/Users/mini/.openclaw/workspace-freelancer}
crm="$workspace/state/youdo-crm.json"
telecrawl=${TELECRAWL_BIN:-/Users/mini/.local/bin/telecrawl}
skip_import=false
task_id=
chat_query=
chat_id=
typeset -a positionals
positionals=()

fail_json() {
  /usr/bin/jq -cn --arg error "$1" '{ok:false,error:$error}'
  exit "${2:-2}"
}

while (( $# > 0 )); do
  case $1 in
    --skip-import)
      skip_import=true
      shift
      ;;
    --task-id)
      [[ -n ${2:-} ]] || fail_json invalid_task_id
      task_id=$2
      shift 2
      ;;
    --chat-id)
      [[ -n ${2:-} ]] || fail_json invalid_chat_id
      chat_id=$2
      shift 2
      ;;
    --query)
      [[ -n ${2:-} ]] || fail_json invalid_chat_query
      chat_query=$2
      shift 2
      ;;
    --*)
      fail_json invalid_flag
      ;;
    *)
      positionals+=("$1")
      shift
      ;;
  esac
done

if (( ${#positionals} > 2 )); then
  fail_json invalid_args
fi

if (( ${#positionals} == 2 )); then
  [[ -z $task_id && ${positionals[1]} == <-> ]] || fail_json invalid_task_id
  [[ -z $chat_query ]] || fail_json invalid_args
  task_id=${positionals[1]}
  chat_query=${positionals[2]}
elif (( ${#positionals} == 1 )); then
  if [[ -z $chat_query ]]; then
    chat_query=${positionals[1]}
  elif [[ -z $task_id && ${positionals[1]} == <-> ]]; then
    task_id=${positionals[1]}
  else
    fail_json invalid_args
  fi
fi

[[ -f $crm ]] || fail_json crm_state_missing
[[ -x $telecrawl ]] || fail_json telecrawl_missing

if [[ -z $chat_id ]]; then
  [[ -n $chat_query ]] || fail_json invalid_chat_query
  chats=$("$telecrawl" --json chats --limit 5000) || fail_json telecrawl_chats_failed
  printf '%s' "$chats" | /usr/bin/jq -e 'type=="array"' >/dev/null || fail_json invalid_chats_json
  resolved=$(printf '%s' "$chats" | /usr/bin/jq -c --arg q "$chat_query" '
    def norm: ascii_downcase;
    ($q | gsub("^\\s+|\\s+$";"")) as $raw
    | ($raw | norm) as $ql
    | map({
        chat_id:(.jid // .id // "" | tostring),
        name:(.name // .title // "")
      })
    | map(select(.chat_id != "" and .name != "")) as $all
    | [$all[] | select(.name == $raw)] as $exact
    | [$all[] | select((.name | norm) == $ql)] as $exact_ci
    | [$all[] | select((.name | norm | index($ql)) != null)] as $sub
    | if ($raw | length) == 0 then
        {ok:false,error:"invalid_chat_query"}
      elif ($exact | length) == 1 then
        {ok:true,chat_id:$exact[0].chat_id,name:$exact[0].name,match:"exact"}
      elif ($exact | length) > 1 then
        {ok:false,error:"ambiguous_chat_match",candidates:$exact}
      elif ($exact_ci | length) == 1 then
        {ok:true,chat_id:$exact_ci[0].chat_id,name:$exact_ci[0].name,match:"exact"}
      elif ($exact_ci | length) > 1 then
        {ok:false,error:"ambiguous_chat_match",candidates:$exact_ci}
      elif ($sub | length) == 1 then
        {ok:true,chat_id:$sub[0].chat_id,name:$sub[0].name,match:"substring"}
      elif ($sub | length) == 0 then
        {ok:false,error:"no_chat_match"}
      else
        {ok:false,error:"ambiguous_chat_match",candidates:$sub}
      end
  ')
  if ! printf '%s' "$resolved" | /usr/bin/jq -e '.ok == true' >/dev/null; then
    printf '%s\n' "$resolved"
    exit 2
  fi
  chat_id=$(printf '%s' "$resolved" | /usr/bin/jq -r '.chat_id')
fi

[[ -n $chat_id ]] || fail_json invalid_chat_id

if [[ -z $task_id ]]; then
  [[ -n $chat_query ]] || fail_json invalid_chat_query
  deal=$(/usr/bin/jq -c --arg q "$chat_query" '
    def norm: ascii_downcase;
    def labels($d):
      [$d.title, $d.client_name, $d.task_name, $d.name]
      | map(select(type=="string" and length>0));
    ($q | gsub("^\\s+|\\s+$";"")) as $raw
    | ($raw | norm) as $ql
    | [.deals[]?] as $deals
    |     [$deals[] | select(.task_id == $raw)] as $by_id
    | [$deals[] | select((labels(.) | map(select(. == $raw)) | length) > 0)] as $exact
    | [$deals[] | select((labels(.) | map(norm | select(index($ql) != null)) | length) > 0)] as $sub
    | if ($by_id | length) == 1 then
        {ok:true,task_id:$by_id[0].task_id,match:"task_id"}
      elif ($exact | length) == 1 then
        {ok:true,task_id:$exact[0].task_id,match:"exact"}
      elif ($exact | length) > 1 then
        {ok:false,error:"ambiguous_deal_match",candidates:[$exact[] | {task_id,title:(.title // .task_name // .name // .client_name)}]}
      elif ($sub | length) == 1 then
        {ok:true,task_id:$sub[0].task_id,match:"substring"}
      elif ($sub | length) == 0 then
        {ok:false,error:"deal_unmatched"}
      else
        {ok:false,error:"ambiguous_deal_match",candidates:[$sub[] | {task_id,title:(.title // .task_name // .name // .client_name)}]}
      end
  ' "$crm")
  if ! printf '%s' "$deal" | /usr/bin/jq -e '.ok == true' >/dev/null; then
    printf '%s\n' "$deal"
    exit 2
  fi
  task_id=$(printf '%s' "$deal" | /usr/bin/jq -r '.task_id')
fi

[[ $task_id == <-> ]] || fail_json invalid_task_id
/usr/bin/jq -e --arg id "$task_id" '.deals[$id] != null' "$crm" >/dev/null || fail_json deal_missing

funnel=$(/usr/bin/jq -r --arg id "$task_id" '.deals[$id].funnel' "$crm")
project_path=$(/usr/bin/jq -r --arg id "$task_id" '.deals[$id].project_path // ""' "$crm")
if [[ $funnel == in_progress || $funnel == done_paid || -n $project_path ]]; then
  dest_rel="projects/youdo/$task_id/correspondence"
else
  dest_rel="state/correspondence/$task_id"
fi
dest_dir="$workspace/$dest_rel"
/bin/mkdir -p "$dest_dir"
/bin/chmod 700 "$dest_dir"

if [[ $skip_import == false ]]; then
  "$telecrawl" --json import --chat "$chat_id" --messages-limit 500 >/dev/null
fi

archive_file="$dest_dir/messages.json"
"$telecrawl" --json messages --chat "$chat_id" --limit 500 > "$archive_file"
/bin/chmod 600 "$archive_file"

YOUDO_WORKSPACE="$workspace" "$workspace/scripts/attach-youdo-correspondence.zsh" "$task_id" "$chat_id" "$dest_rel"
