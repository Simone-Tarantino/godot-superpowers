#!/usr/bin/env bash
# PostToolUse Edit|Write — print a one-line reminder to dispatch file-verifier
# for every .gd / .tscn / .tres / .gdshader path written. Silent when the write
# happened inside a subagent (CLAUDE_AGENT_NAME or CLAUDE_SUBAGENT=1) — the
# orchestrator handles verifier dispatch in that case.
set -u

# Source shared helpers (path normalization).
source "$(dirname "$0")/_lib.sh"

# Skip when running inside a subagent — the orchestrator owns verifier dispatch.
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

if [ "${#matched[@]}" -eq 0 ]; then
    exit 0
fi

# Wording must match the hook-reminder regex enforced by scripts/validate.sh.
joined=""
for p in "${matched[@]}"; do
    joined+="$p "
done
joined="${joined% }"
echo "verifier: dispatch file-verifier on ${#matched[@]} file(s) [$joined]"
