#!/usr/bin/env bash
# shellcheck disable=SC2329
# npm-auth.sh: sourced 1Password -> npm auth helpers shared by the npm skill
# scripts. Service-account access to Service Vault is preferred; the configured
# desktop account is the automatic fallback when no service token is available.
# Never prints secret values.

# Callers set: VAULT ITEM ACCOUNT FORCE_DESKTOP REGISTRY WORK NPMRC SCRIPT_DIR.

redact() {
  sed -E 's/(npm_[A-Za-z0-9_]+)/npm_REDACTED/g; s/[0-9]{6}/OTP_REDACTED/g'
}

current_otp() {
  op_item_get --otp 2>/dev/null | tr -d '[:space:]' || true
}

# Run registry operations away from caller-local npm config. The token stays in
# the temporary npmrc instead of entering argv or the lifecycle environment.
npm_authenticated() {
  (cd "$WORK" && NPM_CONFIG_USERCONFIG="$NPMRC" npm --registry "$REGISTRY" "$@")
}

npm_auth_whoami() {
  npm_authenticated whoami
}

npm_authenticated_with_optional_otp() {
  local otp="$1"
  shift
  if [[ "$otp" =~ ^[0-9]{6}$ ]]; then
    NPM_CONFIG_OTP="$otp" npm_authenticated "$@"
  else
    npm_authenticated "$@"
  fi
}

# Reads the item JSON exactly once and defines op_item_get for OTP refreshes.
# env -u keeps the service token out of desktop op calls.
resolve_op_item() {
  if [ "$FORCE_DESKTOP" -eq 0 ] && [ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]; then
    ITEM_JSON="$(op item get "$ITEM" --vault "$VAULT" --format json)"
    op_item_get() {
      op item get "$ITEM" --vault "$VAULT" "$@"
    }
    op_item_edit_json() {
      op item edit "$ITEM" --vault "$VAULT" >/dev/null
    }
    echo "1Password access: service account ($VAULT)"
  else
    if [ -z "$ACCOUNT" ]; then
      echo "no service-account token or desktop account configured" >&2
      return 2
    fi
    env -u OP_SERVICE_ACCOUNT_TOKEN op signin --account "$ACCOUNT" >/dev/null
    ITEM_JSON="$(env -u OP_SERVICE_ACCOUNT_TOKEN op item get "$ITEM" --account "$ACCOUNT" --format json)"
    op_item_get() {
      env -u OP_SERVICE_ACCOUNT_TOKEN op item get "$ITEM" --account "$ACCOUNT" "$@"
    }
    op_item_edit_json() {
      env -u OP_SERVICE_ACCOUNT_TOKEN op item edit "$ITEM" --account "$ACCOUNT" >/dev/null
    }
    echo "1Password access: desktop fallback ($ACCOUNT)"
  fi
  echo "op auth ok; reading npm item once: $ITEM"
}

# Persist a newly created registry session through an all-JSON pipeline. The
# token stays out of argv, logs, and extra files; a failed cache write does not
# invalidate the already-authenticated command.
persist_registry_token() {
  if ! printf '%s' "$ITEM_JSON" |
    node "$SCRIPT_DIR/npm-auth-cache.mjs" update "$NPMRC" "$REGISTRY" |
    op_item_edit_json; then
    echo "warning: npm auth works, but registry session cache update failed" >&2
    return 1
  fi
  if ! op_item_get --format json |
    node "$SCRIPT_DIR/npm-auth-cache.mjs" verify "$NPMRC" "$REGISTRY"; then
    echo "warning: npm auth works, but registry session cache verification failed" >&2
    return 1
  fi
  echo "npm auth: cached registry session in 1Password"
}

# Writes an authenticated NPMRC. Reuses the stored registry_token session when
# it still passes whoami; otherwise runs npm-auth-login.mjs (hardened field
# selection) with a fresh six-digit OTP. A valid stored registry_token bypasses
# password login and does not require TOTP for read-only registry commands.
ensure_npm_auth() {
  local token login_log="$WORK/npm-login.log"
  LOGIN_USED_OTP=0
  NPM_OTP=""
  token="$(printf '%s' "$ITEM_JSON" | jq -r '[.fields[]? | select((.label // "") == "registry_token") | .value // empty][0] // empty')"
  if [ -n "$token" ]; then
    local auth_host="${REGISTRY#*://}"
    auth_host="${auth_host%%/*}"
    printf '//%s/:_authToken=%s\n' "$auth_host" "$token" >"$NPMRC"
    if npm_auth_whoami >/dev/null 2>&1; then
      echo "npm auth: reused stored registry session"
      return 0
    fi
  fi
  NPM_OTP="$(current_otp)"
  case "$NPM_OTP" in
    [0-9][0-9][0-9][0-9][0-9][0-9]) ;;
    *)
      echo "$ITEM has no working registry_token or six-digit TOTP field" >&2
      echo "add one of those concealed fields in 1Password, then retry" >&2
      return 3
      ;;
  esac
  printf '%s' "$ITEM_JSON" |
    NPM_OTP="$NPM_OTP" NPMRC="$NPMRC" REGISTRY="$REGISTRY" \
    node "$SCRIPT_DIR/npm-auth-login.mjs" >"$login_log" 2>&1 || {
    echo "npm registry login failed" >&2
    redact <"$login_log" >&2
    return 3
  }
  redact <"$login_log"
  LOGIN_USED_OTP=1
  persist_registry_token || true
}

# npm publish rejects the TOTP already consumed by loginCouch; wait out the
# window when login just used it, then return a code usable for NPM_CONFIG_OTP.
fresh_command_otp() {
  local otp
  otp="$(current_otp)"
  if [ -z "$otp" ]; then
    return 0
  fi
  if [ "$LOGIN_USED_OTP" -eq 1 ] && [ "$otp" = "$NPM_OTP" ]; then
    local attempt
    for ((attempt = 0; attempt < 20; attempt++)); do
      sleep 2
      otp="$(current_otp)"
      if [ "$otp" != "$NPM_OTP" ]; then
        break
      fi
    done
  fi
  printf '%s' "$otp"
}
