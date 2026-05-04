#!/usr/bin/env bash
# Plugin self-check. Run before commit / publish.
# Verifies: JSON validity, hooks parity, skill frontmatter, agent frontmatter,
# no broken cross-skill references.
set -euo pipefail

cd "$(dirname "$0")/.."
fail=0

echo "== JSON validity =="
for f in .claude-plugin/plugin.json hooks/hooks.json settings.json settings.local.json .mcp.json; do
    if jq empty "$f" >/dev/null 2>&1; then
        echo "  OK  $f"
    else
        echo "  FAIL $f"
        fail=1
    fi
done

echo "== Hooks parity (settings.json ↔ hooks/hooks.json) =="
if diff <(jq -S '{hooks: .hooks}' settings.json) <(jq -S '.' hooks/hooks.json) >/dev/null; then
    echo "  OK  in sync"
else
    echo "  FAIL drift detected. Run scripts/sync-hooks.sh"
    fail=1
fi

echo "== Skill frontmatter =="
for f in skills/*/SKILL.md; do
    if ! head -1 "$f" | grep -q '^---$'; then
        echo "  FAIL $f missing frontmatter"
        fail=1
        continue
    fi
    name=$(awk '/^---$/{c++; next} c==1 && /^name:/{print $2; exit}' "$f")
    desc=$(awk '/^---$/{c++; next} c==1 && /^description:/{$1=""; print; exit}' "$f")
    if [ -z "$name" ] || [ -z "$desc" ]; then
        echo "  FAIL $f missing name or description"
        fail=1
    else
        echo "  OK  $f"
    fi
done

echo "== Agent frontmatter =="
for f in agents/*.md; do
    if ! head -1 "$f" | grep -q '^---$'; then
        echo "  FAIL $f missing frontmatter"
        fail=1
        continue
    fi
    name=$(awk '/^---$/{c++; next} c==1 && /^name:/{print $2; exit}' "$f")
    if [ -z "$name" ]; then
        echo "  FAIL $f missing name"
        fail=1
    else
        echo "  OK  $f"
    fi
done

echo "== Broken cross-skill references =="
broken=$(grep -rEn '\.\./([a-z0-9-]+)/SKILL\.md' skills/ | while read -r line; do
    target=$(echo "$line" | grep -oE '\.\./[a-z0-9-]+/SKILL\.md' | head -1)
    src_dir=$(dirname "$(echo "$line" | cut -d: -f1)")
    abs="$src_dir/$target"
    if [ ! -f "$abs" ]; then
        echo "$line"
    fi
done)
if [ -n "$broken" ]; then
    echo "$broken"
    fail=1
else
    echo "  OK  all relative SKILL.md links resolve"
fi

echo "== Summary =="
if [ $fail -eq 0 ]; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi
