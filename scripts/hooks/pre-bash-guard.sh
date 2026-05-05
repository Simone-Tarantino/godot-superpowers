#!/usr/bin/env bash
# PreToolUse Bash — block obviously destructive shell + git commands.
# Exit 2 = block + surface stderr to the model.
#
# Bypass: set CLAUDE_GIT_OVERRIDE=1 to skip the git-specific checks
# (the destructive shell-pattern check ALWAYS applies — no override).
set -u

cmd="${CLAUDE_COMMAND:-}"
[ -z "$cmd" ] && exit 0

# Destructive shell patterns (rm -rf /, sudo rm, fork bomb, raw disk writes, mkfs).
# Always enforced — no override.
if printf '%s' "$cmd" | grep -qE '(rm -rf /|rm -rf ~|sudo rm|chmod 777|:\(\)\{ :\|:\& \};:|> /dev/sda|mkfs)'; then
    echo 'BLOCKED: destructive shell pattern' >&2
    exit 2
fi

# Git checks may be bypassed for an explicit user-confirmed operation.
if [ "${CLAUDE_GIT_OVERRIDE:-}" = "1" ]; then
    exit 0
fi

# Destructive git operations only.
# Allowed: `git checkout <branch>`, `git checkout -b <name>`, `git restore --staged <path>`,
# and all read-only/log/diff/status/show/fetch/stash/commit/add commands.
#
# Blocked patterns:
#   reset --hard
#   clean -<flags-incl-f>           (e.g. -f, -fd, -xdf)
#   push --force / -f / --force-with-lease
#   branch -D <name>                (force delete)
#   reflog expire --expire=now
#   gc --prune=now
#   checkout -- <path>              (discard worktree, `--` separator)
#   checkout .                      (discard all worktree changes)
#   checkout *                      (glob discard)
#   restore --worktree <path>       (explicit worktree discard)
#   restore <path>                  (no flag — defaults to discarding worktree)
git_block_re='(^|[ ;&|])git[[:space:]]+('
git_block_re+='reset[[:space:]]+--hard\b'
git_block_re+='|clean[[:space:]]+-[a-zA-Z]*f'
git_block_re+='|push[[:space:]]+([^;&|]*[[:space:]])?(-f([[:space:]]|$)|--force(-with-lease)?\b)'
git_block_re+='|branch[[:space:]]+-D\b'
git_block_re+='|reflog[[:space:]]+expire[[:space:]]+--expire=now\b'
git_block_re+='|gc[[:space:]]+--prune=now\b'
git_block_re+='|checkout[[:space:]]+(--([[:space:]]|$)|\.([[:space:]]|$)|\*)'
git_block_re+='|restore[[:space:]]+(--worktree\b|[^-])'
git_block_re+=')'

if printf '%s' "$cmd" | grep -qE "$git_block_re"; then
    echo 'BLOCKED: destructive git command — set CLAUDE_GIT_OVERRIDE=1 with explicit user confirmation to override' >&2
    exit 2
fi

exit 0
