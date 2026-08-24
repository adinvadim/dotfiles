#!/bin/zsh
set -euo pipefail

# Per-offer actor. Not the account HasLegalEntity profile toggle.

if [[ $# -gt 0 && $1 != - ]]; then
  task=$1
else
  task=$(/bin/cat)
fi

zsh "${0:A:h}/classify-youdo-offer-actor.zsh" "$task"
