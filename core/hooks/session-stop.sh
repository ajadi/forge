#!/bin/bash
# Stop hook: Log session summary + collect regression metrics
set +e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "handoffs" 2>/dev/null

RECENT_COMMITS=$(git log --oneline --since="8 hours ago" 2>/dev/null)
MODIFIED=$(git diff --name-only 2>/dev/null)
STAGED=$(git diff --staged --name-only 2>/dev/null)

# Only log if something happened
if [ -z "$RECENT_COMMITS" ] && [ -z "$MODIFIED" ] && [ -z "$STAGED" ]; then
    exit 0
fi

# --- Session log ---
{
    echo "## Session End: $TIMESTAMP"
    if [ -n "$RECENT_COMMITS" ]; then
        echo "### Commits"
        echo "$RECENT_COMMITS"
    fi
    if [ -n "$STAGED" ] || [ -n "$MODIFIED" ]; then
        echo "### Uncommitted Changes"
        [ -n "$STAGED" ]   && echo "$STAGED"   | while read -r f; do echo "  [staged]   $f"; done
        [ -n "$MODIFIED" ] && echo "$MODIFIED" | while read -r f; do echo "  [unstaged] $f"; done
    fi
    echo "---"
    echo ""
} >> "handoffs/session-log.md" 2>/dev/null

# --- Regression metrics ---
METRICS_FILE=".claude/metrics.log"
NEEDS_WORK_COUNT=0
SCOPE_CREEP_COUNT=0
RALPH_LOOPS=0
TASKS_DONE=0

# Count NEEDS_WORK in active task files
if [ -d "tasks" ]; then
    NEEDS_WORK_COUNT=$(grep -rl "NEEDS_WORK" tasks/TASK-*.md 2>/dev/null | wc -l | tr -d ' ')
    TASKS_DONE=$(ls tasks/archive/TASK-*.md 2>/dev/null | wc -l | tr -d ' ')
fi

# Count scope creep (files changed outside spec.files) from progress.log
if [ -f ".claude/progress.log" ]; then
    SCOPE_CREEP_COUNT=$(grep -c "scope_creep" .claude/progress.log 2>/dev/null || echo 0)
    RALPH_LOOPS=$(grep -c "ralph_loop" .claude/progress.log 2>/dev/null || echo 0)
fi

echo "$TIMESTAMP | needs_work:$NEEDS_WORK_COUNT | scope_creep:$SCOPE_CREEP_COUNT | ralph_loops:$RALPH_LOOPS | tasks_done:$TASKS_DONE" >> "$METRICS_FILE" 2>/dev/null

# --- Dream state ---
DREAM_STATE=".claude/dream-state.json"
if [ -f "$DREAM_STATE" ]; then
    CURRENT_COUNT=$(python3 -c "import json,sys; d=json.load(open('$DREAM_STATE')); print(d.get('session_count',0))" 2>/dev/null || echo 0)
    NEW_COUNT=$((CURRENT_COUNT + 1))
    LAST_RUN=$(python3 -c "import json,sys; d=json.load(open('$DREAM_STATE')); print(d.get('last_run') or '')" 2>/dev/null || echo "")
    echo "{\"last_run\": \"$LAST_RUN\", \"session_count\": $NEW_COUNT}" > "$DREAM_STATE"
fi

exit 0
