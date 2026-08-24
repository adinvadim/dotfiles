#!/bin/zsh
set -euo pipefail

export PATH=/Users/mini/.openclaw/workspace/tools/youdo-cli:/Users/mini/.local/bin:/Users/mini/bin:/opt/homebrew/bin:/usr/bin:/bin
export YOUDO_BROWSER_HEADLESS=1
export AGENT_BROWSER_EXECUTABLE_PATH='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
export AGENT_BROWSER_PROXY=http://127.0.0.1:7897
export AGENT_BROWSER_USER_AGENT='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36'
export AGENT_BROWSER_ARGS=--disable-blink-features=AutomationControlled

workspace=${YOUDO_WORKSPACE:-/Users/mini/.openclaw/workspace-freelancer}
lock_dir="$workspace/state/.youdo-browser-session.lock"
lock_owned=false
cleanup() {
  if [[ $lock_owned == true ]]; then
    /bin/rm -f "$lock_dir/pid" 2>/dev/null || true
    /bin/rmdir "$lock_dir" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

wait_started=$(/bin/date -u +%s)
while ! /bin/mkdir "$lock_dir" 2>/dev/null; do
  owner=$(/bin/cat "$lock_dir/pid" 2>/dev/null || true)
  modified=$(/usr/bin/stat -f %m "$lock_dir" 2>/dev/null || printf 0)
  now_epoch=$(/bin/date -u +%s)
  lock_age=$((now_epoch - modified))
  wait_age=$((now_epoch - wait_started))

  if [[ $owner != <-> ]] || ! /bin/kill -0 "$owner" 2>/dev/null || (( lock_age >= 720 )); then
    if [[ $owner != <-> && $lock_age -lt 2 ]]; then
      /bin/sleep 1
      continue
    fi
    /bin/rm -f "$lock_dir/pid" 2>/dev/null || true
    /bin/rmdir "$lock_dir" 2>/dev/null || true
    continue
  fi
  if (( wait_age >= 110 )); then
    /usr/bin/jq -cn '{ok:false,error:"youdo_browser_session_busy",retryable:true}'
    exit 75
  fi
  /bin/sleep 1
done
lock_owned=true
printf '%s\n' $$ > "$lock_dir/pid"

youdo_bin=${YOUDO_BIN:-/Users/mini/.local/bin/youdo}

tool=${1:-}
[[ $# -gt 0 ]] && shift
case $tool in
  cli)
    typeset -a cli_args
    cli_args=()
    saw_offer=0
    saw_create=0
    for arg in "$@"; do
      case $arg in
        offer) saw_offer=1; cli_args+=("$arg") ;;
        create)
          if (( saw_offer )); then
            saw_create=1
          fi
          cli_args+=("$arg")
          ;;
        --sbr|--sbr=true|--sbr=false) ;;
        *) cli_args+=("$arg") ;;
      esac
    done
    if (( saw_create )); then
      cli_args+=(--sbr)
    fi
    "$youdo_bin" "${cli_args[@]}"
    ;;
  browser)
    /Users/mini/.openclaw/workspace/tools/youdo-cli/agent-browser "$@"
    ;;
  *)
    /usr/bin/jq -cn '{ok:false,error:"usage: youdo-exec.zsh cli|browser <args>"}'
    exit 2
    ;;
esac
