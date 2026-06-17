#!/bin/bash
# PreCompact hook: dump session state before context compression so nothing
# valuable is lost to summarization.
#
# Two safety nets:
#   1. Everything is printed to STDOUT (PreCompact hook output is fed into the
#      compaction so the summarizer sees it).
#   2. The SAME snapshot is written to a durable file on disk
#      (handoffs/precompact-<ts>.md). Even if the summary drops it, the agent can
#      recover full state by reading that file after compaction.
#
# This hook NEVER blocks compaction (always exit 0). The old MemPalace
# pre-compact hook blocked compaction until an external save succeeded — that is
# exactly what used to wedge compaction, and it is gone.
set +e

mkdir -p "handoffs" 2>/dev/null
TS=$(date +%Y%m%d_%H%M%S)
SNAP="handoffs/precompact-${TS}.md"

# emit: write a line to BOTH stdout and the durable snapshot file.
emit() { printf '%s\n' "$*"; printf '%s\n' "$*" >> "$SNAP" 2>/dev/null; }

emit "=== SESSION STATE BEFORE COMPACTION ==="
emit "Timestamp: $(date)"

# --- In-progress tasks ---
emit ""
emit "## In-Progress Tasks"
IN_PROGRESS_FOUND=false
for f in tasks/TASK-*.md; do
    [ -f "$f" ] || continue
    if grep -q 'status: in_progress' "$f" 2>/dev/null; then
        IN_PROGRESS_FOUND=true
        TASK_NAME=$(head -1 "$f" | sed 's/^# //')
        LAST_SECTION=$(grep '^## ' "$f" | tail -1)
        emit "  $f — $TASK_NAME"
        emit "    Last section: $LAST_SECTION"
    fi
done
[ "$IN_PROGRESS_FOUND" = false ] && emit "  (none)"

# --- Files modified this session ---
emit ""
emit "## Modified Files (git working tree)"
CHANGED=$(git diff --name-only 2>/dev/null)
STAGED=$(git diff --staged --name-only 2>/dev/null)
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null)
[ -n "$STAGED" ]    && while read -r f; do [ -n "$f" ] && emit "  [staged]   $f"; done <<< "$STAGED"
[ -n "$CHANGED" ]   && while read -r f; do [ -n "$f" ] && emit "  [unstaged] $f"; done <<< "$CHANGED"
[ -n "$UNTRACKED" ] && while read -r f; do [ -n "$f" ] && emit "  [new]      $f"; done <<< "$UNTRACKED"
[ -z "$CHANGED" ] && [ -z "$STAGED" ] && [ -z "$UNTRACKED" ] && emit "  (clean)"

# --- Open OQs ---
emit ""
emit "## Open Questions (tz.md)"
if [ -f "tz.md" ]; then
    OQ_LINES=$(grep -n '⏳ open' tz.md 2>/dev/null)
    if [ -n "$OQ_LINES" ]; then
        while read -r line; do [ -n "$line" ] && emit "  $line"; done <<< "$OQ_LINES"
    else
        emit "  (none)"
    fi
else
    emit "  (tz.md not found)"
fi

# --- Locked files ---
emit ""
emit "## Locked Files (locks.json)"
if [ -f "locks.json" ]; then
    while read -r line; do emit "  $line"; done < "locks.json"
elif [ -f ".claude/locks.json" ]; then
    while read -r line; do emit "  $line"; done < ".claude/locks.json"
else
    emit "  (none)"
fi

# --- Recovery + operating contract (survives compaction) ---
emit ""
emit "## Recovery"
emit "Full snapshot saved to: $SNAP — read it to restore state if anything is missing."
emit "After compaction: check in-progress tasks above and continue the pipeline."
emit ""
emit "## Operating contract (survives compaction)"
emit "- PM orchestrates and delegates; PM NEVER writes source itself (enforced by role-write-guard.sh)."
emit "- Source edits go through the developer agent only. code-reviewer / architect / reality-checker are read-only."
emit "- Pass file paths between agents, never file contents. Each agent appends its own handoff section."
emit "- Every task ends through reality-check; record progress in tasks/ + backlog.md before stopping."
emit "- Memory is flat files: grep memory/*.md before stating project facts; append, mark stale with ~~strikethrough~~."
emit "=== END SESSION STATE ==="

echo "Compaction at $(date) -> $SNAP" >> "handoffs/compaction-log.txt" 2>/dev/null

# Write pending marker for rehydrate.sh (post-compact context restore, one-shot).
# SNAP is a relative path; rehydrate.sh resolves it against CLAUDE_PROJECT_DIR.
echo "$(date +%s) $SNAP" > "${CLAUDE_PROJECT_DIR:-.}/.claude/.precompact-ts" 2>/dev/null

exit 0
