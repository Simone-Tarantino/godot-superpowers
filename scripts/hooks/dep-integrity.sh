#!/usr/bin/env bash
# PostToolUse Edit|Write — quick dependency integrity check on .tscn/.tres files.
# Greps every `[ext_resource ... path="res://..."]` line and verifies the target
# file exists on disk. Reports missing references — does NOT fail the tool call.
#
# Why this is cheap and useful: Godot loads scenes by path; a missing ext_resource
# only surfaces at runtime as "Corrupt scene" or silently with a missing texture.
# Catching the broken path at write-time is much cheaper than the editor reload.
set -u

# Source shared helpers (path normalization).
source "$(dirname "$0")/_lib.sh"

paths_raw="${CLAUDE_FILE_PATHS:-}"
[ -z "$paths_raw" ] && exit 0

project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"

IFS=',' read -ra paths <<< "$paths_raw"

# Helper: turn `res://foo/bar.png` into `<project_dir>/foo/bar.png`.
resolve_res() {
    local res_path="$1"
    case "$res_path" in
        res://*) printf '%s/%s' "$project_dir" "${res_path#res://}" ;;
        *)       printf '%s' "$res_path" ;;
    esac
}

issues=0
for f in "${paths[@]}"; do
    f="${f#"${f%%[![:space:]]*}"}"
    f="${f%"${f##*[![:space:]]}"}"
    [ -z "$f" ] && continue
    case "$f" in
        *.tscn|*.tres) ;;
        *) continue ;;
    esac
    f=$(_hook_normalize_path "$f")
    [ -f "$f" ] || continue

    # Each ext_resource line carries `path="res://..."`. Extract the value once
    # per line, dedupe, then check existence.
    while IFS= read -r ref; do
        [ -z "$ref" ] && continue
        abs=$(resolve_res "$ref")
        if [ ! -e "$abs" ]; then
            echo "dep-integrity: $f references missing $ref"
            issues=$((issues + 1))
        fi
    done < <(grep -oE '\[ext_resource[^]]*path="[^"]+"' "$f" \
                | grep -oE 'path="[^"]+"' \
                | sed -E 's/^path="//; s/"$//' \
                | sort -u)
done

if [ "$issues" -gt 0 ]; then
    echo "dep-integrity: $issues missing reference(s) — fix before running scene"
fi

exit 0
