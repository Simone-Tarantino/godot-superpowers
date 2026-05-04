#!/usr/bin/env bash
# Source-of-truth: settings.json. Mirror its hooks block to hooks/hooks.json.
# Plugin-mode installs read hooks/hooks.json (per .claude-plugin/plugin.json);
# drop-in installs read settings.json. Run this whenever hooks change in either file.
set -euo pipefail

cd "$(dirname "$0")/.."
jq '{hooks: .hooks}' settings.json > hooks/hooks.json
echo "synced hooks/hooks.json from settings.json"
