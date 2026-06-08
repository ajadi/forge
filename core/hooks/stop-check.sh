#!/usr/bin/env bash
# stop-check.sh
# Stop hook. Hard gate: don't let the turn end mid-pipeline or with uncommitted
# source changes that were never recorded against a task / the backlog.
# Block convention: message on stdout, exit 2 to block the stop. FAILS OPEN.
set +e

INPUT=$(cat)

# If we already blocked once this turn, don't loop.
# Use whitespace-tolerant match; prefer python/jq when available for JSON correctness.
_stop_active=false
if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -e '.stop_hook_active == true' >/dev/null 2>&1 && _stop_active=true
elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$INPUT" | python3 -c 'import json,sys; exit(0 if json.load(sys.stdin).get("stop_hook_active") else 1)' 2>/dev/null && _stop_active=true
elif command -v python >/dev/null 2>&1; then
    printf '%s' "$INPUT" | python -c 'import json,sys; exit(0 if json.load(sys.stdin).get("stop_hook_active") else 1)' 2>/dev/null && _stop_active=true
else
    printf '%s' "$INPUT" | grep -qE '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && _stop_active=true
fi
[ "$_stop_active" = "true" ] && exit 0

# --- Gate 1: a task is in_progress but never reached reality-check ---
if [ -d "tasks" ]; then
    for file in tasks/TASK-*.md; do
        [ -f "$file" ] || continue
        if grep -q "status: in_progress" "$file" && ! grep -qi "## reality" "$file"; then
            echo "Task $(basename "$file") is in_progress but the pipeline is incomplete (no reality-check). Continue the pipeline before stopping."
            exit 2
        fi
    done
fi

# --- Gate 2: product source changed in the working tree, but no task/backlog progress recorded ---
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

CHANGED=$( { git diff --name-only 2>/dev/null; git diff --staged --name-only 2>/dev/null; \
            git ls-files --others --exclude-standard 2>/dev/null; } | sort -u )
[ -z "$CHANGED" ] && exit 0

# Framework state / non-product paths — changes here are not "source changes".
# (scripts/ is intentionally NOT here: scripts are product code that should be
# recorded against a task, matching role-write-guard's classification.)
FW_RE='^\.claude/|^tasks/|^memory/|^handoffs/|^docs/|^logs/|^tz\.md$|^backlog\.md$|^manifest\.(md|json)$|^\.gitignore$|^CLAUDE\.md$|^AGENTS\.md$|^pm-ref\.md$|^FORGE-UPGRADE-PROGRESS\.md$|\.log$'

SOURCE_CHANGED=$(printf '%s\n' "$CHANGED" | grep -vE "$FW_RE")
[ -z "$SOURCE_CHANGED" ] && exit 0   # only framework state changed → fine

# Progress is "recorded" if backlog.md or a task file is among the changes.
if printf '%s\n' "$CHANGED" | grep -qE '^backlog\.md$|^tasks/TASK-.*\.md$'; then
    exit 0
fi

echo "Uncommitted source changes exist but no task was advanced and backlog.md was not updated:"
printf '%s\n' "$SOURCE_CHANGED" | sed 's/^/  - /' | head -20
echo "Record progress (update the task file + backlog.md) or commit via the pipeline before stopping."
exit 2
