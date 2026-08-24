#!/bin/zsh
set -euo pipefail

stage=${0:A:h:h}
fixture=$(/usr/bin/mktemp -d)
cleanup() { /bin/rm -rf "$fixture"; }
trap cleanup EXIT INT TERM

/usr/bin/sqlite3 "$fixture/archive.db" 'create table records (collection text, last_seen_at text, raw_json text);'
offer_json='{"CreatorInfo":{"UserInfo":{"HasLegalEntity":false}},"IsPartner":false}'
/usr/bin/sqlite3 "$fixture/archive.db" "insert into records values ('proposals_sent','2026-08-24T00:00:00Z','$offer_json');"

out=$(YOUDO_ARCHIVE_DB="$fixture/archive.db" zsh "$stage/scripts/youdo-legal-entity-status.zsh")
printf '%s' "$out" | /usr/bin/jq -e '
  .ok == true
  and .has_legal_entity == false
  and .is_partner == false
  and .source == "proposals_sent"
' >/dev/null

/usr/bin/jq -cn '{ok:true}'
