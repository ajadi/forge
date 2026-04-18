#!/bin/bash
# PreCompact hook: Dump session state before context compression
# Critical state must survive summarization
set +e

echo "=== SESSION STATE BEFORE COMPACTION ==="
echo "Timestamp: $(date)"

# --- In-progress tasks ---
echo ""
echo "## In-Progress Tasks"
IN_PROGRESS_FOUND=false
for f in tasks/TASK-*.md; do
    [ -f "$f" ] || continue
    if grep -q 'status: in_progress' "$f" 2>/dev/null; then
        IN_PROGRESS_FOUND=true
        TASK_NAME=$(head -1 "$f" | sed 's/^# //')
        LAST_SECTION=$(grep '^## ' "$f" | tail -1)
        echo "  $f — $TASK_NAME"
        echo "    Last section: $LAST_SECTION"
    fi
done
[ "$IN_PROGRESS_FOUND" = false ] && echo "  (none)"

# --- Files modified this session ---
echo ""
echo "## Modified Files (git working tree)"
CHANGED=$(git diff --name-only 2>/dev/null)
STAGED=$(git diff --staged --name-only 2>/dev/null)
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null)

[ -n "$STAGED" ]    && echo "$STAGED"    | while read -r f; do echo "  [staged]   $f"; done
[ -n "$CHANGED" ]   && echo "$CHANGED"   | while read -r f; do echo "  [unstaged] $f"; done
[ -n "$UNTRACKED" ] && echo "$UNTRACKED" | while read -r f; do echo "  [new]      $f"; done
[ -z "$CHANGED" ] && [ -z "$STAGED" ] && [ -z "$UNTRACKED" ] && echo "  (clean)"

# --- Open OQs ---
echo ""
echo "## Open Questions (tz.md)"
if [ -f "tz.md" ]; then
    OQ_LINES=$(grep -n '⏳ open' tz.md 2>/dev/null)
    if [ -n "$OQ_LINES" ]; then
        echo "$OQ_LINES" | while read -r line; do echo "  $line"; done
    else
        echo "  (none)"
    fi
else
    echo "  (tz.md not found)"
fi

# --- Locked files ---
echo ""
echo "## Locked Files (locks.json)"
if [ -f "locks.json" ]; then
    cat locks.json 2>/dev/null
else
    echo "  (none)"
fi

# --- Log compaction event ---
mkdir -p "handoffs" 2>/dev/null
echo "Compaction at $(date)" >> "handoffs/compaction-log.txt" 2>/dev/null

echo ""
echo "## Recovery"
echo "After compaction: check in-progress tasks above and continue pipeline."
echo "=== END SESSION STATE ==="
exit 0
