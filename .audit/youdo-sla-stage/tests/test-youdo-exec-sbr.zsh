#!/bin/zsh
set -euo pipefail

stage=${0:A:h:h}
fixture=$(/usr/bin/mktemp -d)
cleanup() { /bin/rm -rf "$fixture"; }
trap cleanup EXIT INT TERM

/bin/mkdir -p "$fixture/bin" "$fixture/state" "$fixture/scripts"
/bin/cp "$stage/scripts/youdo-exec.zsh" "$fixture/scripts/youdo-exec.zsh"
/bin/cp "$stage/scripts/classify-youdo-offer-actor.zsh" "$fixture/scripts/classify-youdo-offer-actor.zsh"
/bin/chmod 700 "$fixture/scripts/youdo-exec.zsh" "$fixture/scripts/classify-youdo-offer-actor.zsh"

cat > "$fixture/bin/youdo" <<'EOF'
#!/bin/zsh
print -r -- ${(j: :)argv}
EOF
/bin/chmod 700 "$fixture/bin/youdo"

argv=$(YOUDO_WORKSPACE="$fixture" YOUDO_BIN="$fixture/bin/youdo" "$fixture/scripts/youdo-exec.zsh" cli --account personal --json offer create 15120001 --payment package --price 10000 --text-file drafts/1.md)
[[ $argv == *'--sbr'* ]] || { print -u2 "missing --sbr on omitted flag: $argv"; exit 1; }

forced=$(YOUDO_WORKSPACE="$fixture" YOUDO_BIN="$fixture/bin/youdo" "$fixture/scripts/youdo-exec.zsh" cli offer create 15120001 --sbr=false --price 1)
[[ $forced == *'--sbr=false'* ]] && { print -u2 "wrapper kept --sbr=false: $forced"; exit 1; }
[[ $forced == *'--sbr'* ]] || { print -u2 "missing forced --sbr: $forced"; exit 1; }

list=$(YOUDO_WORKSPACE="$fixture" YOUDO_BIN="$fixture/bin/youdo" "$fixture/scripts/youdo-exec.zsh" cli offer list)
[[ $list == *'--sbr'* ]] && { print -u2 "list should not force --sbr: $list"; exit 1; }
[[ $list == *'--legal-entity'* ]] && { print -u2 "list should not force --legal-entity: $list"; exit 1; }

personal=$(YOUDO_TASK_JSON='{"id":"15109030","isB2B":false}' YOUDO_WORKSPACE="$fixture" YOUDO_BIN="$fixture/bin/youdo" "$fixture/scripts/youdo-exec.zsh" cli offer create 15109030 --price 1)
[[ $personal == *'--sbr'* ]] || { print -u2 "personal create dropped --sbr: $personal"; exit 1; }
[[ $personal == *'--legal-entity'* ]] && { print -u2 "personal create requested legal-entity: $personal"; exit 1; }

business=$(YOUDO_TASK_JSON='{"id":"15121387","isB2B":true}' YOUDO_WORKSPACE="$fixture" YOUDO_BIN="$fixture/bin/youdo" "$fixture/scripts/youdo-exec.zsh" cli offer create 15121387 --price 1)
[[ $business == *'--sbr'* ]] || { print -u2 "business create dropped --sbr: $business"; exit 1; }
[[ $business == *'--legal-entity'* ]] || { print -u2 "business create missing --legal-entity: $business"; exit 1; }

forced_personal=$(YOUDO_TASK_JSON='{"id":"15109030","isB2B":false}' YOUDO_WORKSPACE="$fixture" YOUDO_BIN="$fixture/bin/youdo" "$fixture/scripts/youdo-exec.zsh" cli offer create 15109030 --legal-entity --price 1)
[[ $forced_personal == *'--legal-entity'* ]] && { print -u2 "personal task kept --legal-entity: $forced_personal"; exit 1; }

/usr/bin/jq -cn '{ok:true}'
