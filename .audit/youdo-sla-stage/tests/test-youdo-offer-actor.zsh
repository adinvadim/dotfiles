#!/bin/zsh
set -euo pipefail

stage=${0:A:h:h}
classify="$stage/scripts/classify-youdo-offer-actor.zsh"

b2b=$(zsh "$classify" "$(/bin/cat "$stage/tests/fixtures/youdo-offer-actor-b2b.json")")
printf '%s' "$b2b" | /usr/bin/jq -e '
  .ok == true
  and .actor == "legal-entity"
  and .legal_entity == true
  and .task_id == "15121387"
' >/dev/null

personal=$(zsh "$classify" "$(/bin/cat "$stage/tests/fixtures/youdo-offer-actor-personal.json")")
printf '%s' "$personal" | /usr/bin/jq -e '
  .ok == true
  and .actor == "personal"
  and .legal_entity == false
  and .task_id == "15109030"
' >/dev/null

historical=$(zsh "$classify" "$(/bin/cat "$stage/tests/fixtures/youdo-offer-actor-historical-15073504.json")")
printf '%s' "$historical" | /usr/bin/jq -e '
  .ok == true
  and .actor == "personal"
  and .legal_entity == false
  and .task_id == "15073504"
' >/dev/null

managed=$(zsh "$classify" '{"id":"1","isB2B":false,"isManagedB2B":true}')
printf '%s' "$managed" | /usr/bin/jq -e '.ok == true and .actor == "legal-entity"' >/dev/null

again=$(zsh "$classify" "$(/bin/cat "$stage/tests/fixtures/youdo-offer-actor-b2b.json")")
[[ $again == "$b2b" ]] || { print -u2 'classifier is not idempotent'; exit 1; }

/usr/bin/jq -cn '{ok:true}'
