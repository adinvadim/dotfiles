#!/bin/zsh
set -euo pipefail

workspace=${YOUDO_WORKSPACE:?}
attempts_path="$workspace/state/package-read-attempts"
attempts=$(( $(/bin/cat "$attempts_path" 2>/dev/null || printf 0) + 1 ))
printf '%s\n' "$attempts" > "$attempts_path"

[[ $1 == cli && $2 == --timeout && $3 == 60s && $4 == --account && $5 == personal && $6 == --json && $7 == offer && $8 == package && $9 == list ]] || exit 9
if [[ -f "$workspace/state/package-read-fails" ]]; then
  /usr/bin/jq -cn '{ok:false,error:"provider_unavailable"}'
  exit 6
fi
/usr/bin/jq -cn '{ok:true,data:[{Id:9,Status:1,PaidPrice:1200,TimeRemain:100,Category:4194304,SubcategoryId:146,OfferCountLimit:null,OfferCountRemain:null}]}'
