#!/usr/bin/env bash
# PostToolUse Edit|Write — count Godot writes per session and surface a
# verifier suggestion only once a milestone-sized batch has accumulated
# (default: 3+ writes). Single-file edits are noise — verifier dispatch
# costs more than a Read in main context for a one-off change.
#
# Silent inside subagents (CLAUDE_AGENT_NAME or CLAUDE_SUBAGENT=1) — the
# orchestrator owns verifier dispatch in that case.
#
# Threshold override: CLAUDE_VERIFIER_THRESHOLD=<int> (default 3, min 1).
# Counter file: $TMPDIR/godot-superpowers-writes-$CLAUDE_PROJECT_DIR-hash
set -u

source "$(dirname "$0")/_lib.sh"

if [ -n "${CLAUDE_AGENT_NAME:-}" ] || [ "${CLAUDE_SUBAGENT:-}" = "1" ]; then
    exit 0
fi

paths_raw="${CLAUDE_FILE_PATHS:-}"
[ -z "$paths_raw" ] && exit 0

IFS=',' read -ra paths <<< "$paths_raw"

matched=()
for f in "${paths[@]}"; do
    f="${f#"${f%%[![:space:]]*}"}"
    f="${f%"${f##*[![:space:]]}"}"
    [ -z "$f" ] && continue
    f=$(_hook_normalize_path "$f")
    case "$f" in
        *.gd|*.tscn|*.tres|*.gdshader) matched+=("$f") ;;
    esac
done

[ "${#matched[@]}" -eq 0 ] && exit 0

threshold="${CLAUDE_VERIFIER_THRESHOLD:-3}"
[ "$threshold" -lt 1 ] 2>/dev/null && threshold=1

# Project-scoped counter (one per CLAUDE_PROJECT_DIR). Reset on each
# `verifier-reset.sh` call or shell restart (file in $TMPDIR).
proj_hash=$(printf '%s' "${CLAUDE_PROJECT_DIR:-default}" | shasum -a 1 2>/dev/null | awk '{print $1}')
[ -z "$proj_hash" ] && proj_hash="default"
counter_file="${TMPDIR:-/tmp}/godot-superpowers-writes-${proj_hash}"
list_file="${TMPDIR:-/tmp}/godot-superpowers-writelist-${proj_hash}"

current=0
[ -f "$counter_file" ] && current=$(cat "$counter_file" 2>/dev/null || echo 0)
new_total=$((current + ${#matched[@]}))
echo "$new_total" > "$counter_file"

# Append matched paths to running list (deduped at print time).
for p in "${matched[@]}"; do
    echo "$p" >> "$list_file"
done

if [ "$new_total" -lt "$threshold" ]; then
    # Below threshold — silent; rely on user / dispatcher to call verifier
    # on demand for risky single-file edits.
    exit 0
fi

# Threshold reached — emit reminder once, then reset counter so the next
# batch must accumulate again. Wording preserved for validator regex.
joined=""
if [ -f "$list_file" ]; then
    while IFS= read -r p; do
        [ -z "$p" ] && continue
        joined+="$p "
    done < <(awk '!seen[$0]++' "$list_file")
fi
joined="${joined% }"
count=$(printf '%s\n' "$joined" | tr ' ' '\n' | grep -c .)

echo "verifier: dispatch file-verifier on ${count} file(s) [$joined]"

# Reset for next batch.
: > "$counter_file"
: > "$list_file"
