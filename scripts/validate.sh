#!/usr/bin/env bash
# Plugin self-check. Run before commit / publish.
# Verifies: JSON validity, hooks parity, skill frontmatter, agent frontmatter,
# no broken cross-skill references.
set -euo pipefail

cd "$(dirname "$0")/.."
fail=0

echo "== JSON validity =="
required_json=(.claude-plugin/plugin.json .claude-plugin/marketplace.json .claude-plugin/mcp-meta.json hooks/hooks.json settings.json .mcp.json settings.local.json.example)
optional_json=(settings.local.json)

for f in "${required_json[@]}"; do
    if [ ! -f "$f" ]; then
        echo "  FAIL $f missing"
        fail=1
        continue
    fi
    if jq empty "$f" >/dev/null 2>&1; then
        echo "  OK  $f"
    else
        echo "  FAIL $f invalid JSON"
        fail=1
    fi
done

for f in "${optional_json[@]}"; do
    if [ ! -f "$f" ]; then
        echo "  SKIP $f not present (optional, gitignored — see settings.local.json.example)"
        continue
    fi
    if jq empty "$f" >/dev/null 2>&1; then
        echo "  OK  $f"
    else
        echo "  FAIL $f invalid JSON"
        fail=1
    fi
done

echo "== Plugin / marketplace version coherence =="
plugin_version=$(jq -r '.version' .claude-plugin/plugin.json)
marketplace_version=$(jq -r '.plugins[0].version' .claude-plugin/marketplace.json)
if [ "$plugin_version" = "$marketplace_version" ]; then
    echo "  OK  both at $plugin_version"
else
    echo "  FAIL plugin.json=$plugin_version, marketplace.json=$marketplace_version — bump them in lock-step"
    fail=1
fi

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

echo "== Catalog count drift (docs ↔ filesystem) =="
real_skills=$(find skills -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')
real_agents=$(ls agents/*.md 2>/dev/null | wc -l | tr -d ' ')

# Match `<number> <noun>` and verify the number equals expected
check_count() {
    local file="$1" expected="$2" noun="$3"
    while IFS=: read -r lineno content; do
        n=$(echo "$content" | grep -oE "[0-9]+ $noun\b" | grep -oE '[0-9]+' | head -1)
        if [ -n "$n" ] && [ "$n" != "$expected" ]; then
            echo "  FAIL $file:$lineno claims $n $noun, real is $expected"
            fail=1
        fi
    done < <(grep -nE "[0-9]+ $noun\b" "$file" 2>/dev/null || true)
}

drift_before=$fail
check_count CLAUDE.md "$real_skills" "skills"
check_count CLAUDE.md "$real_agents" "subagents"
check_count README.md "$real_skills" "skills"
check_count README.md "$real_agents" "subagents"
check_count .claude-plugin/marketplace.json "$real_skills" "skills"
check_count .claude-plugin/marketplace.json "$real_agents" "subagents"

if [ "$fail" = "$drift_before" ]; then
    echo "  OK  CLAUDE.md / README.md / marketplace.json claim $real_skills skills + $real_agents subagents"
fi

echo "== Hook reminder wording drift =="
# Live docs (not CHANGELOG) must reference the current hook output wording.
# Real hook prints: "verifier: dispatch file-verifier on <N> file(s) [<paths>]"
hook_drift=0
for f in README.md CLAUDE.md skills/using-godot-superpowers/SKILL.md skills/subagent-dev-mode/SKILL.md; do
    if [ -f "$f" ] && grep -q 'verifier reminder' "$f"; then
        echo "  FAIL $f references stale 'verifier reminder' wording — current hook output is 'verifier: dispatch file-verifier on <N> file(s)'"
        fail=1
        hook_drift=1
    fi
done
[ "$hook_drift" -eq 0 ] && echo "  OK  live docs reference current hook wording"

echo "== Authoritative source callout coverage =="
missing=()
# Code-emitting skills must carry the standard callout
for f in skills/*/SKILL.md; do
    name=$(basename "$(dirname "$f")")
    case "$name" in
        game-brainstorming|writing-game-plan|gdd-writer|update-docs|using-godot-superpowers) continue ;;  # design / docs only
    esac
    if ! grep -q '\*\*Authoritative source\*\*' "$f"; then
        missing+=("$f")
    fi
done
for f in agents/*.md; do
    name=$(basename "$f" .md)
    case "$name" in
        addon-curator|export-engineer|playtest-analyst|game-designer) ;; # still emit examples — keep checked
    esac
    if ! grep -q '\*\*Authoritative source\*\*' "$f"; then
        missing+=("$f")
    fi
done
if [ ${#missing[@]} -eq 0 ]; then
    echo "  OK  all code-emitting skills/agents carry the callout"
else
    for f in "${missing[@]}"; do
        echo "  FAIL $f missing Authoritative source callout"
    done
    fail=1
fi

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
