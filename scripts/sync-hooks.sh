#!/usr/bin/env bash
# Source-of-truth: settings.json. Mirror its `hooks` block to hooks/hooks.json.
# Plugin-mode installs read hooks/hooks.json by Claude Code convention — plugin.json
# does NOT declare a `hooks` field, the file is auto-discovered. Drop-in installs
# read settings.json directly. Run this whenever the `hooks` block in settings.json
# changes; the validator (scripts/validate.sh) and CI catch drift.
set -euo pipefail

cd "$(dirname "$0")/.."
jq '{hooks: .hooks}' settings.json > hooks/hooks.json
echo "synced hooks/hooks.json from settings.json"
