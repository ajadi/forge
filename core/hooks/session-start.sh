#!/bin/bash
# SessionStart hook: Load project context at session start
set +e

echo "=== Multi-Agent Dev System — Session Context ==="

# Current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -n "$BRANCH" ]; then
    echo "Branch: $BRANCH"
    echo ""
    echo "Recent commits:"
    git log --oneline -5 2>/dev/null | while read -r line; do
        echo "  $line"
    done
fi

# Open tasks from backlog.md
if [ -f "backlog.md" ]; then
    OPEN_TASKS=$(grep -c '^\- \[ \]' backlog.md 2>/dev/null | tr -d '\r' || echo 0)
    DONE_TASKS=$(grep -c '^\- \[x\]' backlog.md 2>/dev/null | tr -d '\r' || echo 0)
    TOTAL=$(( ${OPEN_TASKS:-0} + ${DONE_TASKS:-0} ))
    if [ "$TOTAL" -gt 0 ]; then
        echo ""
        echo "Backlog: ${DONE_TASKS}/${TOTAL} done, ${OPEN_TASKS} open"
    fi
fi

# Open questions from tz.md
if [ -f "tz.md" ]; then
    OQ_COUNT=$(grep -c '⏳ open' tz.md 2>/dev/null || echo 0)
    if [ "$OQ_COUNT" -gt 0 ]; then
        echo ""
        echo "⚠️  Open questions in tz.md: ${OQ_COUNT}"
        grep -n '⏳ open' tz.md 2>/dev/null | head -5 | while read -r line; do
            echo "  $line"
        done
    fi
fi

# In-progress tasks (pipeline incomplete)
IN_PROGRESS=$(grep -rl 'status: in_progress' tasks/*.md 2>/dev/null | head -3)
if [ -n "$IN_PROGRESS" ]; then
    echo ""
    echo "In-progress tasks:"
    echo "$IN_PROGRESS" | while read -r f; do
        echo "  $(basename $f)"
    done
fi

# Uncommitted changes
MODIFIED=$(git diff --name-only 2>/dev/null)
STAGED=$(git diff --staged --name-only 2>/dev/null)
if [ -n "$MODIFIED" ] || [ -n "$STAGED" ]; then
    echo ""
    echo "Uncommitted changes:"
    [ -n "$STAGED" ]   && echo "$STAGED"   | while read -r f; do echo "  [staged]   $f"; done
    [ -n "$MODIFIED" ] && echo "$MODIFIED" | while read -r f; do echo "  [unstaged] $f"; done
fi

echo "==========================================="

# Check if dream consolidation is needed
DREAM_STATE=".claude/dream-state.json"
if [ -f "$DREAM_STATE" ]; then
    DREAM_PY=""
    if command -v python3 >/dev/null 2>&1; then DREAM_PY="python3"
    elif command -v python >/dev/null 2>&1; then DREAM_PY="python"
    fi
    DREAM_CHECK=$($DREAM_PY -c "
import json, sys
from datetime import datetime, timezone

try:
    with open('$DREAM_STATE') as f:
        d = json.load(f)
    count = d.get('session_count', 0)
    last_run = d.get('last_run')
    
    hours_since = 999
    if last_run:
        last_dt = datetime.fromisoformat(last_run.replace('Z','+00:00'))
        hours_since = (datetime.now(timezone.utc) - last_dt).total_seconds() / 3600
    
    if count >= 5 and hours_since >= 24:
        print(f'DREAM_NEEDED: {count} sessions, {int(hours_since)}h since last consolidation')
    elif count >= 10:
        print(f'DREAM_NEEDED: {count} sessions since last consolidation (overdue)')
except Exception as e:
    pass
" 2>/dev/null)
    
    if [ -n "$DREAM_CHECK" ]; then
        echo ""
        echo "💭 Auto Dream: $DREAM_CHECK"
        echo "   Run /f-dream to consolidate memory before starting work."
    fi
fi

exit 0