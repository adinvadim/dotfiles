#!/bin/zsh
set -euo pipefail

# Offer actor is personal or legal-entity. YouDo isB2B / isManagedB2B selects legal-entity.

if [[ $# -gt 0 && $1 != - ]]; then
  printf '%s' "$1"
else
  /bin/cat
fi | /usr/bin/jq -c '
  if type != "object" then
    {ok:false,error:"invalid_task"}
  else
    (.isB2B == true or .isManagedB2B == true) as $business
    | {
        ok: true,
        actor: (if $business then "legal-entity" else "personal" end),
        legal_entity: $business,
        task_id: ((.id // .taskId // .TaskId // null) | if . == null then null else tostring end)
      }
  end
'
