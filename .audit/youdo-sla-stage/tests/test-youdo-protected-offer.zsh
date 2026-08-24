#!/bin/zsh
set -euo pipefail

stage=${0:A:h:h}
fixture=$(/usr/bin/mktemp -d)
cleanup() { /bin/rm -rf "$fixture"; }
trap cleanup EXIT INT TERM

/bin/mkdir -p "$fixture/state" "$fixture/scripts" "$fixture/drafts"
/bin/cp "$stage/scripts/run-protected-youdo-offer.zsh" "$fixture/scripts/"
/bin/cp "$stage/scripts/record-youdo-stage-timing.zsh" "$fixture/scripts/"
/bin/chmod 700 "$fixture/scripts/"*.zsh
print -r -- 'draft' > "$fixture/drafts/15120196.md"

cat > "$fixture/scripts/youdo-exec.zsh" <<'EOF'
#!/bin/zsh
set -euo pipefail
log=${YOUDO_WORKSPACE}/state/exec-log
print -r -- ${(j: :)argv} >> "$log"
if [[ ${(j: :)argv} == *'offer verify'* && ${(j: :)argv} != *'--offer'* ]]; then
  if [[ -f ${YOUDO_WORKSPACE}/state/published ]]; then
    /usr/bin/jq -cn '{ok:true,data:{conclusive:true,published:true,safeToCreate:false,canAddOffer:false,isPostOffer:true,ownOfferIds:["67027252"],providerId:"67027252"}}'
  else
    /usr/bin/jq -cn '{ok:true,data:{conclusive:true,published:false,safeToCreate:true,canAddOffer:true,isPostOffer:false}}'
  fi
  exit 0
fi
if [[ ${(j: :)argv} == *'offer package check'* ]]; then
  /usr/bin/jq -cn '{ok:true,data:{covered:true,zeroAdditionalCost:true,package:{paidPrice:6160}}}'
  exit 0
fi
if [[ ${(j: :)argv} == *'offer create'* ]]; then
  [[ ${(j: :)argv} == *'--sbr'* ]] || { print -u2 'create missing --sbr'; exit 1; }
  print -r -- create >> "${YOUDO_WORKSPACE}/state/create-log"
  /usr/bin/jq -cn '{ok:true,data:{providerId:"67027252",positionAtTaskOffers:0,taskOffersCount:7}}'
  exit 0
fi
if [[ ${(j: :)argv} == *'offer verify'* && ${(j: :)argv} == *'--offer'* ]]; then
  /usr/bin/jq -cn '{ok:true,data:{published:true,conclusive:true,ownOfferIds:["67027252"]}}'
  exit 0
fi
/usr/bin/jq -cn '{ok:false,error:"unexpected"}'
exit 2
EOF
/bin/chmod 700 "$fixture/scripts/youdo-exec.zsh"

first=$(YOUDO_WORKSPACE="$fixture" zsh "$fixture/scripts/run-protected-youdo-offer.zsh" 15120196 1400000 drafts/15120196.md)
printf '%s' "$first" | /usr/bin/jq -e '
  .ok == true
  and .already_published == false
  and .create_attempted == true
  and .published == true
  and .provider_id == "67027252"
' >/dev/null
[[ $(($(/usr/bin/wc -l < "$fixture/state/create-log"))) == 1 ]] || { print -u2 'first run did not create once'; exit 1; }

print -n '' > "$fixture/state/published"
second=$(YOUDO_WORKSPACE="$fixture" zsh "$fixture/scripts/run-protected-youdo-offer.zsh" 15120196 1400000 drafts/15120196.md)
printf '%s' "$second" | /usr/bin/jq -e '
  .ok == true
  and .already_published == true
  and .create_attempted == false
  and .provider_id == "67027252"
' >/dev/null
[[ $(($(/usr/bin/wc -l < "$fixture/state/create-log"))) == 1 ]] || { print -u2 'retry created a second offer'; exit 1; }

/usr/bin/jq -e '
  .tasks["15120196"].first_seen != null
  and .tasks["15120196"].stages.verify.ended_at != null
  and .tasks["15120196"].stages.tariff.ended_at != null
  and .tasks["15120196"].stages.create.ended_at != null
  and .tasks["15120196"].stages.publish_confirm.ended_at != null
' "$fixture/state/youdo-task-timings.json" >/dev/null

/usr/bin/jq -cn '{ok:true}'
