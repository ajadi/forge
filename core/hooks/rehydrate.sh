#!/bin/bash
# UserPromptSubmit hook: post-compact rehydration (one-shot).
#
# After compaction, pre-compact.sh writes .claude/.precompact-ts with
# "<epoch> <snapshot_path>" (snapshot_path is relative to project dir).
# This hook injects a critical excerpt from that snapshot EXACTLY ONCE
# per compaction event, then records the epoch in .claude/.rehydrated-ts
# so subsequent turns are silent.
#
# Fail-open on every branch: if anything is missing or unreadable, exit 0
# silently. Never block the user's turn.
set +e

PROJ="${CLAUDE_PROJECT_DIR:-.}"
# Normalize PROJ path (Windows backslashes -> forward slashes)
PROJ=$(printf '%s' "$PROJ" | tr '\134' '/' | tr -s '/')
PENDING_MARKER="${PROJ}/.claude/.precompact-ts"
DONE_MARKER="${PROJ}/.claude/.rehydrated-ts"

# No pending marker -> nothing to rehydrate
[ -f "$PENDING_MARKER" ] || exit 0

# Read pending marker: "<epoch> <snapshot_path>"
PENDING_LINE=$(cat "$PENDING_MARKER" 2>/dev/null)
[ -z "$PENDING_LINE" ] && exit 0

P_EPOCH=$(echo "$PENDING_LINE" | awk '{print $1}')
SNAP_PATH=$(echo "$PENDING_LINE" | awk '{print $2}')

# Validate epoch is numeric
echo "$P_EPOCH" | grep -qE '^[0-9]+$' || exit 0

# Read done marker epoch (default 0)
D_EPOCH=0
if [ -f "$DONE_MARKER" ]; then
    D_EPOCH=$(cat "$DONE_MARKER" 2>/dev/null | awk '{print $1}')
    echo "$D_EPOCH" | grep -qE '^[0-9]+$' || D_EPOCH=0
fi

# Already rehydrated for this compaction? -> silently skip
[ "$P_EPOCH" -le "$D_EPOCH" ] 2>/dev/null && exit 0

# Normalize snapshot path (Windows backslashes -> forward slashes)
SNAP_PATH=$(printf '%s' "$SNAP_PATH" | tr '\134' '/' | tr -s '/')

# Resolve relative snapshot path against project dir
case "$SNAP_PATH" in
    /*) : ;;  # already absolute
    *)  SNAP_PATH="${PROJ}/${SNAP_PATH}" ;;
esac

# Snapshot missing? Consume the marker silently and exit
if [ ! -f "$SNAP_PATH" ]; then
    echo "$P_EPOCH" > "$DONE_MARKER" 2>/dev/null
    exit 0
fi

# Emit critical excerpt (one-shot injection into context)
echo "[forge rehydrate] context was compacted — restoring critical state (once):"
echo ""

# Extract sections from snapshot: In-Progress Tasks through just before
# Operating contract — this single range already covers Modified Files,
# Open Questions, Locked Files and Recovery (which precede the contract in
# the snapshot). Capped at 40 lines.
awk '
    /^## In-Progress Tasks/ { in_range=1 }
    in_range && /^## Operating contract/ { in_range=0; next }
    in_range && /^=== END/ { in_range=0; next }
    in_range { print }
' "$SNAP_PATH" 2>/dev/null | head -40

# Then the operating contract section (heading "## Operating contract (survives compaction)").
awk '
    /^## Operating contract/ { in_range=1 }
    in_range && /^## / && !/^## Operating contract/ { in_range=0; next }
    in_range && /^=== END/ { in_range=0; next }
    in_range { print }
' "$SNAP_PATH" 2>/dev/null | head -15

echo ""
echo "(Full snapshot: $SNAP_PATH)"

# Mark as rehydrated (monotonic epoch prevents repeat injections)
echo "$P_EPOCH" > "$DONE_MARKER" 2>/dev/null

exit 0
