#!/usr/bin/env bash
# PostToolUse Edit|Write — run `godot --headless --check-only` on every .tscn path.
# On non-zero exit, surfaces the actual error lines (filtered) instead of the engine banner.
set -u

# Source shared helpers (path normalization).
source "$(dirname "$0")/_lib.sh"

paths_raw="${CLAUDE_FILE_PATHS:-}"
[ -z "$paths_raw" ] && exit 0

if ! command -v godot >/dev/null 2>&1; then
    echo "check-tscn: skipped (godot CLI not on PATH — install Godot 4.x and add to PATH to enable)"
    exit 0
fi

project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"

# Glob-safe split on commas (preserves spaces, no filename expansion).
IFS=',' read -ra paths <<< "$paths_raw"

for f in "${paths[@]}"; do
    f="${f#"${f%%[![:space:]]*}"}"
    f="${f%"${f##*[![:space:]]}"}"
    [ -z "$f" ] && continue
    case "$f" in
        *.tscn) ;;
        *) continue ;;
    esac
    f=$(_hook_normalize_path "$f")
    if [ ! -f "$f" ]; then
        echo "tscn check skipped (missing): $f"
        continue
    fi
    out=$(godot --headless --check-only --path "$project_dir" "$f" 2>&1)
    rc=$?
    if [ $rc -ne 0 ]; then
        echo "tscn check failed: $f"
        # Filter out engine banner; keep only error-bearing lines (with context).
        # When the filter matches nothing, fall back to the tail of the output
        # (errors usually land at the end, not buried in the Vulkan/audio banner).
        filtered=$(echo "$out" | grep -iE "error|corrupt|failed|missing|cannot" -B 1 -A 3 | head -30)
        if [ -n "$filtered" ]; then
            echo "$filtered"
        else
            echo "$out" | tail -20
        fi
    fi
done
