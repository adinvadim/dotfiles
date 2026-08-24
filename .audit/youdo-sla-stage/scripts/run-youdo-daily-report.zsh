#!/bin/zsh
set -euo pipefail

workspace=${YOUDO_WORKSPACE:-/Users/mini/.openclaw/workspace-freelancer}
report_date=${1:-$(TZ=Asia/Makassar /bin/date -v-1d +%Y-%m-%d)}
attempt_limit=${YOUDO_DAILY_PACKAGE_ATTEMPTS:-3}
retry_delay=${YOUDO_DAILY_RETRY_DELAY_SECONDS:-15}
tmp_dir=

cleanup() {
  [[ -z ${tmp_dir:-} ]] || /bin/rm -rf "$tmp_dir" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

fail_json() {
  /usr/bin/jq -cn --arg error "$1" '{ok:false,error:$error,llm_calls:0}' >&2
  exit "${2:-2}"
}

[[ $attempt_limit == <-> && $attempt_limit -gt 0 ]] || fail_json invalid_attempt_limit
[[ $retry_delay == <-> ]] || fail_json invalid_retry_delay
[[ -x "$workspace/scripts/build-youdo-daily-report-input.zsh" ]] || fail_json input_builder_missing
[[ -x "$workspace/scripts/write-youdo-daily-report.zsh" ]] || fail_json report_writer_missing
[[ -x "$workspace/scripts/youdo-exec.zsh" ]] || fail_json youdo_wrapper_missing

tmp_dir=$(/usr/bin/mktemp -d "$workspace/state/.youdo-daily-run.XXXXXX")
input_path="$tmp_dir/input.json"
package_path="$tmp_dir/packages.json"

"$workspace/scripts/build-youdo-daily-report-input.zsh" "$report_date" > "$input_path"
/usr/bin/jq -e '.ok == true and (.missing_classification_task_ids|type) == "array" and (.missing_classification_task_ids|length) == 0' "$input_path" >/dev/null \
  || fail_json payment_classification_incomplete

package_ok=false
for (( attempt=1; attempt<=attempt_limit; attempt++ )); do
  if "$workspace/scripts/youdo-exec.zsh" cli --timeout 60s --account personal --json offer package list > "$package_path" \
      && /usr/bin/jq -e '.ok == true and (.data|type) == "array"' "$package_path" >/dev/null 2>&1; then
    package_ok=true
    break
  fi
  if (( attempt < attempt_limit && retry_delay > 0 )); then
    /bin/sleep $((retry_delay * attempt))
  fi
done
[[ $package_ok == true ]] || fail_json live_package_list_failed 3

"$workspace/scripts/write-youdo-daily-report.zsh" "$report_date" "$package_path"
