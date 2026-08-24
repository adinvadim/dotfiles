#!/bin/zsh
set -euo pipefail

workspace=${YOUDO_WORKSPACE:-/Users/mini/.openclaw/workspace-freelancer}
export PATH=/Users/mini/.openclaw/workspace/tools/youdo-cli:/Users/mini/.local/bin:/Users/mini/bin:/opt/homebrew/bin:/usr/bin:/bin
export YOUDO_BROWSER_HEADLESS=1
export AGENT_BROWSER_EXECUTABLE_PATH='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
export AGENT_BROWSER_PROXY=http://127.0.0.1:7897
export AGENT_BROWSER_USER_AGENT='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36'
export AGENT_BROWSER_ARGS=--disable-blink-features=AutomationControlled

if ! /usr/bin/nc -z 127.0.0.1 7897 >/dev/null 2>&1; then
  /usr/bin/jq -cn '{ok:false,error:"ru_proxy_unavailable"}'
  exit 0
fi

all_items='[]'
page=1
pages=0
total=0
while (( page <= 5 )); do
  result=$(
    youdo --account personal task discover \
      --status opened \
      --only-virtual \
      --category webdevelopment \
      --page "$page" \
      --json 2>/dev/null
  ) || {
    /usr/bin/jq -cn --argjson page "$page" '{ok:false,error:"youdo_feed_unavailable",page:$page}'
    exit 0
  }
  if [[ $(printf '%s' "$result" | /usr/bin/jq -r '.ok == true and (.data.items|type) == "array" and (.data.total|type) == "number"') != true ]]; then
    /usr/bin/jq -cn --argjson page "$page" '{ok:false,error:"invalid_feed_response",page:$page}'
    exit 0
  fi
  page_items=$(printf '%s' "$result" | /usr/bin/jq -c '.data.items')
  all_items=$(/usr/bin/jq -cn --argjson previous "$all_items" --argjson current "$page_items" '
    reduce ($previous + $current)[] as $item
      ({seen:{},items:[]};
        ($item.id | tostring) as $id
        | if .seen[$id] then . else .seen[$id]=true | .items += [$item] end)
    | .items
  ')
  total=$(printf '%s' "$result" | /usr/bin/jq -r '.data.total')
  (( pages += 1 ))
  fetched=$(printf '%s' "$all_items" | /usr/bin/jq 'length')
  page_count=$(printf '%s' "$page_items" | /usr/bin/jq 'length')
  (( page_count == 0 || fetched >= total )) && break
  (( page += 1 ))
done

fetched=$(printf '%s' "$all_items" | /usr/bin/jq 'length')
if (( fetched < total )); then
  /usr/bin/jq -cn --argjson pages "$pages" --argjson fetched "$fetched" --argjson total "$total" '{ok:false,error:"feed_truncated",pages:$pages,fetched:$fetched,total:$total}'
  exit 0
fi

draft_ids=$(for draft in "$workspace"/drafts/<->.md(N); do printf '%s\n' "${draft:t:r}"; done | /usr/bin/jq -Rsc 'split("\n") | map(select(test("^[0-9]+$"))) | unique')

/usr/bin/jq -c \
  --argjson items "$all_items" --argjson pages "$pages" --argjson fetched "$fetched" --argjson total "$total" --argjson drafts "$draft_ids" \
  --slurpfile ledger "$workspace/state/auto-offer-ledger.json" \
  --slurpfile operations "$workspace/state/youdo-operations.json" '
    (($ledger[0].sent_task_ids // []) + ($ledger[0].ambiguous_task_ids // []) + ($ledger[0].terminal_task_ids // [])) as $legacy_blocked
    | ($operations[0].tasks // {}) as $tasks
    | [$items[]?
          | . as $item
          | .id
          | tostring
          | select(test("^[0-9]+$"))
          | . as $id
          | select(($item.isOffered // false) != true or ($drafts | index($id)) != null)
          | select(($legacy_blocked | index($id)) == null)
          | select((($tasks[$id].state // "") | IN("confirmed","rejected","ambiguous","missed")) | not)]
        | reduce .[] as $id
            ({seen:{},ids:[]};
              if .seen[$id] then . else .seen[$id]=true | .ids += [$id] end)
        | {ok:true,task_ids:.ids,count:(.ids|length),pages:$pages,fetched:$fetched,total:$total,truncated:false}
  ' <<< '{}'
