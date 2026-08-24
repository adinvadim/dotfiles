#!/bin/zsh
set -euo pipefail

stage=${0:A:h:h}
manifest="$stage/state/youdo-deployment-manifest.json"
test_count=0

for test_file in "$stage"/tests/test-*.zsh; do
  zsh "$test_file" >/dev/null
  (( test_count += 1 ))
done
zsh -n "$stage"/scripts/*.zsh "$stage"/tests/*.zsh "$stage"/tests/fixtures/*.zsh
ruby -e 'require "yaml"; text=File.read(ARGV[0]); front=text.split(/^---\s*$\n/)[1]; YAML.safe_load(front, permitted_classes: [], aliases: false)' \
  "$stage/skills/youdo-daily-report/SKILL.md"
/usr/bin/jq -e '.schema_version == 1 and (.artifacts|keys|length) == 25' "$manifest" >/dev/null

/usr/bin/jq -r '.artifacts | to_entries[] | select(.key != "cli") | [.key,.value] | @tsv' "$manifest" \
  | while IFS=$'\t' read -r artifact_rel expected_sha; do
      actual_sha=$(/usr/bin/shasum -a 256 "$stage/$artifact_rel" | /usr/bin/awk '{print $1}')
      [[ $actual_sha == $expected_sha ]] || {
        print -u2 "artifact hash mismatch: $artifact_rel"
        exit 1
      }
    done

/usr/bin/jq -cn --arg revision "$(/usr/bin/jq -r .revision "$manifest")" --argjson tests "$test_count" \
  '{ok:true,revision:$revision,tests:$tests,syntax:true,skill_frontmatter:true,artifact_hashes:true}'
