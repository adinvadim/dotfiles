#!/bin/zsh
set -euo pipefail

export AGENT_BROWSER_EXECUTABLE_PATH='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
export AGENT_BROWSER_PROXY=http://127.0.0.1:7897
export AGENT_BROWSER_USER_AGENT='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36'
export AGENT_BROWSER_ARGS=--disable-blink-features=AutomationControlled

exec /opt/homebrew/bin/agent-browser \
  --session youdo-cli-personal \
  --session-name youdo-cli-personal \
  --profile '/Users/mini/Library/Application Support/youdo/accounts/personal/browser-profile' \
  --headed \
  --max-output 12000000 \
  open https://youdo.com/
