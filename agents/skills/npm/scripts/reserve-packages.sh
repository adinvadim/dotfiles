#!/usr/bin/env bash
set -euo pipefail
set +x
umask 077

usage() {
  cat <<'USAGE'
Usage:
  reserve-packages.sh [--dry-run] [--vault VAULT] [--item ITEM] [--account ACCOUNT] <package...>

Publishes 0.0.0 placeholder packages to npm to reserve names.

Security:
  Must run inside tmux. Defaults to the npmjs item in Service Vault, creates a
  temp npmrc, publishes packages, then deletes temp auth/work files. --account
  forces the my.1password.com desktop fallback. Secrets are never printed.

Defaults:
  vault:    Service Vault
  item:     npmjs
  account:  my.1password.com (fallback)
  registry: https://registry.npmjs.org/
USAGE
}

VAULT="${NPM_OP_VAULT:-Service Vault}"
ITEM="${NPM_OP_ITEM:-npmjs}"
ACCOUNT="${NPM_OP_ACCOUNT:-my.1password.com}"
FORCE_DESKTOP=0
REGISTRY="${NPM_REGISTRY:-https://registry.npmjs.org/}"
DRY_RUN=0
PACKAGES=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --vault)
      VAULT="${2:?missing vault}"
      shift 2
      ;;
    --item)
      ITEM="${2:?missing item}"
      shift 2
      ;;
    --account)
      ACCOUNT="${2:?missing account}"
      FORCE_DESKTOP=1
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      PACKAGES+=("$@")
      break
      ;;
    -*)
      echo "unknown flag: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      PACKAGES+=("$1")
      shift
      ;;
  esac
done

if [ "${#PACKAGES[@]}" -eq 0 ]; then
  usage >&2
  exit 2
fi

if [ -z "${TMUX:-}" ]; then
  echo "refusing to run: this script reads 1Password and must run inside a persistent tmux session" >&2
  exit 2
fi

for bin in op jq node npm; do
  command -v "$bin" >/dev/null 2>&1 || {
    echo "missing required binary: $bin" >&2
    exit 2
  }
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d /tmp/npm-reserve.XXXXXX)"
NPMRC="$WORK/npmrc"
cleanup() {
  rm -rf "$WORK"
  unset ITEM_JSON NPM_OTP
}
trap cleanup EXIT

# shellcheck source=npm-auth.sh
source "$SCRIPT_DIR/npm-auth.sh"

resolve_op_item
ensure_npm_auth
unset ITEM_JSON

who="$(npm_auth_whoami 2>"$WORK/npm-whoami.log" || true)"
if [ -z "$who" ]; then
  echo "npm auth check failed" >&2
  redact <"$WORK/npm-whoami.log" >&2
  exit 4
fi
echo "npm auth ok as $who"

cat > "$WORK/README.md" <<'EOF'
# Reserved package

This package name is reserved for a future project.

It does not provide a stable public API yet.
EOF

reserve_pkg() {
  local name="$1"
  if npm_authenticated view "$name" version >/dev/null 2>&1; then
    echo "already taken: $name"
    return 0
  fi
  if npm_authenticated access get status "$name" >/dev/null 2>&1; then
    echo "already reserved: $name"
    return 0
  fi

  local dir="$WORK/$name"
  mkdir -p "$dir"
  command cp -f "$WORK/README.md" "$dir/README.md"
  cat > "$dir/package.json" <<EOF
{
  "name": "$name",
  "version": "0.0.0",
  "description": "Reserved package name.",
  "license": "MIT",
  "private": false
}
EOF

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "would publish: $name"
    return 0
  fi

  local safe_name
  safe_name="$(printf "%s" "$name" | tr '/@' '__')"
  local log="$WORK/npm-publish-$safe_name.log"
  local otp
  otp="$(current_otp)"
  if npm_authenticated_with_optional_otp "$otp" publish "$dir" --access public >"$log" 2>&1; then
    echo "published: $name"
    return 0
  fi

  if grep -qiE 'otp|one-time|two-factor|2fa|EOTP' "$log"; then
    if [ -z "$otp" ]; then
      echo "$ITEM needs a TOTP field to reserve $name" >&2
      redact <"$log" >&2
      return 1
    fi
    echo "publish needs/failed OTP for $name; retrying once with fresh OTP" >&2
    sleep 31
    otp="$(current_otp)"
    if npm_authenticated_with_optional_otp "$otp" publish "$dir" --access public >"$log" 2>&1; then
      echo "published: $name"
      return 0
    fi
  fi

  echo "publish failed: $name" >&2
  if grep -qi 'previously published versions' "$log"; then
    echo "already reserved: $name"
    return 0
  fi
  redact <"$log" >&2
  return 1
}

failed=0
for pkg in "${PACKAGES[@]}"; do
  if ! reserve_pkg "$pkg"; then
    failed=1
  fi
done

if [ "$failed" -eq 0 ]; then
  echo "done"
else
  echo "done with publish failures; see lines above"
  exit 1
fi
