#!/bin/zsh
set -euo pipefail

/usr/bin/jq -cn '{ok:false,error:"deprecated_sbr_browser_finalizer",next:"use_youdo_offer_create_then_offer_verify"}'
exit 2
