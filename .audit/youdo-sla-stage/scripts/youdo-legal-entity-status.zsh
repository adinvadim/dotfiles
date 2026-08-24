#!/bin/zsh
set -euo pipefail

# YouDo shows a company name on offers only when the account has HasLegalEntity.
# This reads the latest archived own offer. It does not print the display name.

db=${YOUDO_ARCHIVE_DB:-$HOME/Library/Application Support/youdo/accounts/personal/archive.db}
[[ -f $db ]] || {
  /usr/bin/jq -cn '{ok:false,error:"archive_missing",has_legal_entity:null}'
  exit 0
}

/usr/bin/sqlite3 -json "$db" 'select raw_json from records where collection="proposals_sent" order by last_seen_at desc limit 1' \
  | /usr/bin/jq -e '
      if type != "array" or length == 0 then
        {ok:true,has_legal_entity:null,source:"archive_empty"}
      else
        (.[0].raw_json | fromjson? // .) as $offer
        | {
            ok: true,
            has_legal_entity: $offer.CreatorInfo.UserInfo.HasLegalEntity,
            is_partner: $offer.IsPartner,
            source: "proposals_sent"
          }
      end
    '
