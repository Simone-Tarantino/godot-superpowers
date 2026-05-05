#!/usr/bin/env bash
# Stop hook — run gdlint over scripts/ and autoload/ in the project root.
# Truncates each lint run to the first 10 lines so noise stays bounded;
# prints a footer when more lines exist so Claude knows results are partial.
set -u

project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$project_dir" 2>/dev/null || exit 0

if ! command -v gdlint >/dev/null 2>&1; then
    exit 0
fi

for d in scripts autoload; do
    if [ -d "$d" ]; then
        echo "lint $d:"
        out=$(gdlint "$d" 2>&1 || true)
        total=$(printf '%s\n' "$out" | wc -l | tr -d ' ')
        printf '%s\n' "$out" | head -10
        if [ "$total" -gt 10 ]; then
            remaining=$((total - 10))
            echo "... (showing first 10 lines; ${remaining} more — run 'gdlint $d' to see all)"
        fi
    fi
done
