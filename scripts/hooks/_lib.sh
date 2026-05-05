#!/usr/bin/env bash
# Shared helpers for PostToolUse hook scripts. Source — do not execute.
#
# Why a shared lib: the four PostToolUse hooks (`gdformat-gd.sh`, `check-tscn.sh`,
# `dep-integrity.sh`, `verifier-reminder.sh`) all consume `CLAUDE_FILE_PATHS` and
# need identical split + trim + project-root normalization. Keeping the logic in
# one place removes drift between hooks and makes path-normalization fixes a
# one-line edit.
#
# Functions:
#   _hook_normalize_path <path>
#       Print the absolute form of <path>. If <path> is already absolute (starts
#       with `/`), echo as-is. Otherwise rebase onto $CLAUDE_PROJECT_DIR (falling
#       back to $PWD).
#
# Usage in hook scripts (keeps existing `IFS=','` split structure):
#
#   source "$(dirname "$0")/_lib.sh"
#   IFS=',' read -ra paths <<< "${CLAUDE_FILE_PATHS:-}"
#   for f in "${paths[@]}"; do
#       f="${f#"${f%%[![:space:]]*}"}"; f="${f%"${f##*[![:space:]]}"}"
#       [ -z "$f" ] && continue
#       f=$(_hook_normalize_path "$f")
#       ...
#   done

_hook_normalize_path() {
    local p="$1"
    local root="${CLAUDE_PROJECT_DIR:-$PWD}"
    case "$p" in
        /*) printf '%s' "$p" ;;
        *)  printf '%s/%s' "$root" "$p" ;;
    esac
}
