#!/bin/zsh
set -euo pipefail

stage=${0:A:h:h}
fixture=$(/usr/bin/mktemp -d)
cleanup() { /bin/rm -rf "$fixture"; }
trap cleanup EXIT INT TERM

/bin/mkdir -p "$fixture/state" "$fixture/scripts" "$fixture/bin"
/bin/cp "$stage/scripts/run-youdo-auto-offer-if-new.zsh" "$fixture/scripts/"
/bin/cp "$stage/scripts/record-youdo-stage-timing.zsh" "$fixture/scripts/"
/bin/chmod 700 "$fixture/scripts/"*.zsh

/usr/bin/jq -n '{schema_version:1,updated_at:null,tasks:{},events:[],payment_blocked_events:[]}' > "$fixture/state/youdo-operations.json"
/usr/bin/jq -n '{transport_batch_size:2}' > "$fixture/state/auto-offer-policy.json"

cat > "$fixture/scripts/reconcile-youdo-ambiguous.zsh" <<'EOF'
#!/bin/zsh
print -r -- reconcile >> "${YOUDO_WORKSPACE}/state/call-log"
/usr/bin/jq -cn '{ok:true}'
EOF
cat > "$fixture/scripts/scan-youdo-new-tasks.zsh" <<'EOF'
#!/bin/zsh
print -r -- scan >> "${YOUDO_WORKSPACE}/state/call-log"
/usr/bin/jq -cn '{ok:true,task_ids:["15120196"]}'
EOF
cat > "$fixture/scripts/scan-youdo-inbox.zsh" <<'EOF'
#!/bin/zsh
print -r -- inbox >> "${YOUDO_WORKSPACE}/state/call-log"
/usr/bin/jq -cn '{ok:true,new_count:0,items:[],chat_send:false}'
EOF
cat > "$fixture/scripts/sync-youdo-crm.zsh" <<'EOF'
#!/bin/zsh
print -r -- crm >> "${YOUDO_WORKSPACE}/state/call-log"
/usr/bin/jq -cn '{ok:true,deal_count:0,message_received_count:0}'
EOF
cat > "$fixture/scripts/capture-youdo-offer-position.zsh" <<'EOF'
#!/bin/zsh
print -r -- position >> "${YOUDO_WORKSPACE}/state/call-log"
/usr/bin/jq -cn '{ok:true}'
EOF
/bin/chmod 700 "$fixture/scripts/"*.zsh

cat > "$fixture/bin/openclaw" <<'EOF'
#!/bin/zsh
set -euo pipefail
print -r -- offer-agent >> "${YOUDO_WORKSPACE}/state/call-log"
now=$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)
/usr/bin/jq --arg now "$now" '
  .tasks["15120196"] = {
    task_id:"15120196",eligibility:"eligible",state:"confirmed",
    offer_id:"67027252",price_minor:1400000,draft_path:"drafts/15120196.md",
    resolved_at:$now
  }
' "${YOUDO_WORKSPACE}/state/youdo-operations.json" > "${YOUDO_WORKSPACE}/state/youdo-operations.json.tmp"
/bin/mv "${YOUDO_WORKSPACE}/state/youdo-operations.json.tmp" "${YOUDO_WORKSPACE}/state/youdo-operations.json"
EOF
/bin/chmod 700 "$fixture/bin/openclaw"

out=$(YOUDO_PATH_PREFIX="$fixture/bin" YOUDO_WORKSPACE="$fixture" zsh "$fixture/scripts/run-youdo-auto-offer-if-new.zsh")
printf '%s' "$out" | /usr/bin/jq -e '.ok == true and .processed_count == 1' >/dev/null

log=$(/bin/cat "$fixture/state/call-log")
expected=$'reconcile\nscan\noffer-agent\ninbox\ncrm'
[[ $log == "$expected" ]] || {
  print -u2 "order was:"
  print -u2 "$log"
  print -u2 "expected:"
  print -u2 "$expected"
  exit 1
}

/usr/bin/jq -e '.tasks["15120196"].first_seen != null and .tasks["15120196"].stages.detect.ended_at != null' \
  "$fixture/state/youdo-task-timings.json" >/dev/null

/usr/bin/jq -cn '{ok:true}'
