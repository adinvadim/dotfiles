#!/bin/zsh
set -euo pipefail

stage=${0:A:h:h}

out=$(zsh "$stage/scripts/youdo-legal-entity-status.zsh" '{"id":"15121387","isB2B":true}')
printf '%s' "$out" | /usr/bin/jq -e '.ok == true and .actor == "legal-entity" and .task_id == "15121387"' >/dev/null

personal=$(zsh "$stage/scripts/youdo-legal-entity-status.zsh" '{"id":"15109030","isB2B":false}')
printf '%s' "$personal" | /usr/bin/jq -e '.ok == true and .actor == "personal" and .task_id == "15109030"' >/dev/null

/usr/bin/jq -cn '{ok:true}'
