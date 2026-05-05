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

# Skills exempt from the `allowed-tools` requirement (intentional design):
#   - using-godot-superpowers: auto-loaded dispatcher (paths-based trigger)
#   - subagent-dev-mode: orchestration that invokes Agent across the full toolset
#   - game-brainstorming: hard-gate skill where allowed-tools caused interaction issues
ALLOWED_TOOLS_EXEMPT=(using-godot-superpowers subagent-dev-mode game-brainstorming)

# Skills that never emit Godot 4.x API code (design / docs / config-only).
# Single source of truth for both the callout-presence skip and the
# callout-absence enforcement loops below.
DESIGN_ONLY_SKILLS=(game-brainstorming writing-game-plan gdd-writer update-docs codebase-survey feature-spec feature-plan setup-git-godot export-config)

# Helper: return 0 if $1 is in array named $2.
_in_array() {
    local needle="$1" arr_name="$2"
    eval "local arr=( \"\${${arr_name}[@]}\" )"
    local v
    for v in "${arr[@]}"; do
        [ "$v" = "$needle" ] && return 0
    done
    return 1
}

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
        continue
    fi
    # `allowed-tools` required unless skill is on the exempt list.
    if ! _in_array "$name" ALLOWED_TOOLS_EXEMPT; then
        if ! awk '/^---$/{c++; next} c==1 && /^allowed-tools:/{found=1; exit} END{exit !found}' "$f"; then
            echo "  FAIL $f missing allowed-tools (not in exempt list)"
            fail=1
            continue
        fi
    fi
    echo "  OK  $f"
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

# Anchored count check: only verify counts at canonical positions, not anywhere
# in prose. The anchor regex MUST contain a single capture group `([0-9]+)`
# enclosed in surrounding context — sed extracts that group and compares it.
check_count_anchored() {
    local file="$1" anchor_re="$2" expected="$3" label="$4"
    if [ ! -f "$file" ]; then
        echo "  FAIL $file missing (count anchor: $label)"
        fail=1
        return
    fi
    local line n=""
    line=$(grep -E "$anchor_re" "$file" | head -1)
    if [ -z "$line" ]; then
        echo "  FAIL $file: no line matches anchor /$anchor_re/ ($label)"
        fail=1
        return
    fi
    # Bash regex captures the (...) group from the anchor — delimiter-free.
    if [[ "$line" =~ $anchor_re ]]; then
        n="${BASH_REMATCH[1]}"
    fi
    if [ -z "$n" ]; then
        echo "  FAIL $file: anchor /$anchor_re/ matched but capture group empty ($label)"
        fail=1
        return
    fi
    if [ "$n" != "$expected" ]; then
        echo "  FAIL $file: $label claims $n, real is $expected"
        fail=1
    fi
}

drift_before=$fail
# CLAUDE.md: tree comments + catalog headers
check_count_anchored CLAUDE.md '├── agents/[^#]*# ([0-9]+) subagents'  "$real_agents" "tree comment (agents)"
check_count_anchored CLAUDE.md '├── skills/[^#]*# ([0-9]+) skills'     "$real_skills" "tree comment (skills)"
check_count_anchored CLAUDE.md '## Skill catalog \(([0-9]+)\)'         "$real_skills" "Skill catalog header"
check_count_anchored CLAUDE.md '## Agent catalog \(([0-9]+)\)'         "$real_agents" "Agent catalog header"
# README.md: H3 headers
check_count_anchored README.md '### ([0-9]+) skills'                  "$real_skills" "skills H3 header"
check_count_anchored README.md '### ([0-9]+) subagents'               "$real_agents" "subagents H3 header"
# marketplace.json: description prefix
check_count_anchored .claude-plugin/marketplace.json '"description": "([0-9]+) skills,' "$real_skills" "description (skills)"
check_count_anchored .claude-plugin/marketplace.json 'skills, ([0-9]+) subagents,'      "$real_agents" "description (subagents)"

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
# Code-emitting skills must carry the standard callout. Skip set:
#   - DESIGN_ONLY_SKILLS (design / docs / config-only — never emit Godot API)
#   - using-godot-superpowers (the dispatcher itself — canonical home of the rule)
for f in skills/*/SKILL.md; do
    name=$(basename "$(dirname "$f")")
    if [ "$name" = "using-godot-superpowers" ] || _in_array "$name" DESIGN_ONLY_SKILLS; then
        continue
    fi
    if ! grep -q '\*\*Authoritative source\*\*' "$f"; then
        missing+=("$f")
    fi
done
for f in agents/*.md; do
    # No agent is exempt from the callout: addon-curator, export-engineer,
    # playtest-analyst, and game-designer all cite class names or example
    # snippets and must carry the rule. Mirror the skill loop above without
    # any skip cases.
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

echo "== Authoritative source callout absence in design-only skills =="
# These skills never emit Godot code; carrying the callout wastes tokens and
# contradicts the documented policy. Source of truth: DESIGN_ONLY_SKILLS array
# above. The `using-godot-superpowers` dispatcher is the canonical home of the
# rule and is intentionally NOT in DESIGN_ONLY_SKILLS (it must keep the rule).
unwanted=()
for name in "${DESIGN_ONLY_SKILLS[@]}"; do
    f="skills/$name/SKILL.md"
    if [ -f "$f" ] && grep -q '\*\*Authoritative source\*\*' "$f"; then
        unwanted+=("$f")
    fi
done
if [ ${#unwanted[@]} -eq 0 ]; then
    echo "  OK  design-only skills do not carry the redundant callout"
else
    for f in "${unwanted[@]}"; do
        echo "  FAIL $f carries the Authoritative source callout but is exempt — remove the blockquote (rule lives in using-godot-superpowers)"
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

echo "== Feature-trail path conventions (skill bodies cite the canonical paths) =="
# Each feature-trail skill must reference its canonical output path inside its body.
declare -a feature_path_checks=(
    "skills/codebase-survey/SKILL.md|docs/features/<YYYY-MM-DD>-<slug>-survey.md"
    "skills/feature-spec/SKILL.md|docs/features/<YYYY-MM-DD>-<slug>-feature.md"
    "skills/feature-plan/SKILL.md|docs/plans/<YYYY-MM-DD>-<slug>-feature-plan.md"
)
path_drift=0
for entry in "${feature_path_checks[@]}"; do
    file="${entry%%|*}"
    needle="${entry##*|}"
    if [ ! -f "$file" ]; then
        echo "  FAIL $file missing"
        fail=1
        path_drift=1
        continue
    fi
    if ! grep -qF "$needle" "$file"; then
        echo "  FAIL $file does not cite canonical path '$needle'"
        fail=1
        path_drift=1
    fi
done
[ "$path_drift" -eq 0 ] && echo "  OK  all feature-trail skills cite their canonical output paths"

echo "== Summary =="
if [ $fail -eq 0 ]; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi
