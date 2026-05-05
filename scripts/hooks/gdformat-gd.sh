#!/usr/bin/env bash
# PostToolUse Edit|Write — run gdformat on every .gd path in CLAUDE_FILE_PATHS.
# Glob-safe split. Batches gdformat call (one process for all files).
# Skips silently if gdformat is missing (SessionStart hook already warned).
set -u

# Source shared helpers (path normalization).
source "$(dirname "$0")/_lib.sh"

paths_raw="${CLAUDE_FILE_PATHS:-}"
[ -z "$paths_raw" ] && exit 0

if ! command -v gdformat >/dev/null 2>&1; then
    echo "gdformat-gd: skipped (gdformat not on PATH — install gdtoolkit to enable)"
    exit 0
fi

# Glob-safe split on commas (preserves spaces, no filename expansion).
IFS=',' read -ra raw_paths <<< "$paths_raw"

gd_files=()
for f in "${raw_paths[@]}"; do
    f="${f#"${f%%[![:space:]]*}"}"
    f="${f%"${f##*[![:space:]]}"}"
    [ -z "$f" ] && continue
    case "$f" in
        *.gd) ;;
        *) continue ;;
    esac
    f=$(_hook_normalize_path "$f")
    if [ ! -f "$f" ]; then
        echo "format skipped (missing): $f"
        continue
    fi
    gd_files+=("$f")
done

if [ ${#gd_files[@]} -eq 0 ]; then
    exit 0
fi

if gdformat "${gd_files[@]}" >/dev/null 2>&1; then
    for f in "${gd_files[@]}"; do
        echo "formatted: $f"
    done
else
    # Re-run per-file to identify which one(s) failed (rare).
    for f in "${gd_files[@]}"; do
        if gdformat "$f" >/dev/null 2>&1; then
            echo "formatted: $f"
        else
            echo "format failed: $f"
        fi
    done
fi
