#!/usr/bin/env bash
set -euo pipefail
set +x
umask 077

usage() {
  cat <<'USAGE'
Usage:
  publish-package.sh [--vault VAULT] [--item ITEM] [--account ACCOUNT] [--access ACCESS] [--tag TAG]

Publishes the package in the current directory through a temporary authenticated
npmrc. Must run inside the persistent tmux session used for 1Password access.
Defaults to the npmjs item in Service Vault. If no service-account token is
available, it falls back to my.1password.com; --account forces that path.
USAGE
}

VAULT="${NPM_OP_VAULT:-Service Vault}"
ITEM="${NPM_OP_ITEM:-npmjs}"
ACCOUNT="${NPM_OP_ACCOUNT:-my.1password.com}"
FORCE_DESKTOP=0
REGISTRY="${NPM_REGISTRY:-https://registry.npmjs.org/}"
ACCESS="public"
TAG="latest"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --vault) VAULT="${2:?missing vault}"; shift 2 ;;
    --item) ITEM="${2:?missing item}"; shift 2 ;;
    --account) ACCOUNT="${2:?missing account}"; FORCE_DESKTOP=1; shift 2 ;;
    --access) ACCESS="${2:?missing access}"; shift 2 ;;
    --tag) TAG="${2:?missing tag}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -z "${TMUX:-}" ]; then
  echo "refusing to run: npm auth must stay inside one persistent tmux session" >&2
  exit 2
fi

for bin in op jq node npm; do
  command -v "$bin" >/dev/null 2>&1 || { echo "missing required binary: $bin" >&2; exit 2; }
done
test -f package.json || { echo "package.json not found in current directory" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$PWD"
WORK="$(mktemp -d /tmp/npm-publish.XXXXXX)"
NPMRC="$WORK/npmrc"
# shellcheck disable=SC2329 # invoked via trap EXIT
cleanup() {
  rm -rf "$WORK"
  unset ITEM_JSON NPM_OTP
}
trap cleanup EXIT

name="$(node -p 'require("./package.json").name')"
version="$(node -p 'require("./package.json").version')"
if npm view "$name@$version" version >/dev/null 2>&1; then
  echo "$name@$version is already published" >&2
  exit 5
fi

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

publish_log="$WORK/npm-publish.log"
otp="$(fresh_command_otp)"
if ! npm_authenticated_with_optional_otp "$otp" publish "$PACKAGE_DIR" --access "$ACCESS" --tag "$TAG" >"$publish_log" 2>&1; then
  if grep -qiE 'otp|one-time|two-factor|2fa|EOTP' "$publish_log"; then
    if [ -z "$otp" ]; then
      echo "$ITEM needs a TOTP field for npm publish" >&2
      redact <"$publish_log" >&2
      exit 6
    fi
    echo "publish OTP expired; retrying once with a fresh OTP" >&2
    sleep 31
    otp="$(current_otp)"
    npm_authenticated_with_optional_otp "$otp" publish "$PACKAGE_DIR" --access "$ACCESS" --tag "$TAG" >"$publish_log" 2>&1 || {
      redact <"$publish_log" >&2
      exit 6
    }
  else
    redact <"$publish_log" >&2
    exit 6
  fi
fi
redact <"$publish_log"

for _ in {1..12}; do
  published="$(npm view "$name@$version" version 2>/dev/null || true)"
  if [ "$published" = "$version" ]; then
    echo "registry version verified: $name@$published"
    exit 0
  fi
  sleep 5
done
echo "registry did not expose $name@$version in time" >&2
exit 7
