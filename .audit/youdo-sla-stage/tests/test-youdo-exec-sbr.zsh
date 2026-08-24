#!/bin/zsh
set -euo pipefail

stage=${0:A:h:h}
fixture=$(/usr/bin/mktemp -d)
cleanup() { /bin/rm -rf "$fixture"; }
trap cleanup EXIT INT TERM

/bin/mkdir -p "$fixture/bin" "$fixture/state" "$fixture/scripts"
/bin/cp "$stage/scripts/youdo-exec.zsh" "$fixture/scripts/youdo-exec.zsh"
/bin/chmod 700 "$fixture/scripts/youdo-exec.zsh"

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

/usr/bin/jq -cn '{ok:true}'
