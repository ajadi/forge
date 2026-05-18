#!/bin/bash
# PreCompact hook: nudges agent to save memories before context compression.
# Blocks the FIRST attempt per session so the agent can call mempalace_diary_write.
# Any retry within 30 minutes is automatically allowed — no manual flag needed.
set +e

STAMP=".claude/.precompact-ts"
NOW=$(date +%s)

if [ -f "$STAMP" ]; then
  LAST=$(cat "$STAMP")
  ELAPSED=$((NOW - LAST))
  if [ "$ELAPSED" -lt 1800 ]; then
    rm -f "$STAMP"
    exit 0
  fi
fi

# Check if mempalace is available; if not, allow compaction immediately
python3 -c "import mempalace" 2>/dev/null || python -c "import mempalace" 2>/dev/null || exit 0

echo "$NOW" > "$STAMP"
echo '{"decision": "block", "reason": "Context compression imminent. Call mempalace_diary_write with key facts, decisions, and unfinished work from this session. Then run /compact again — the next attempt will go through automatically."}'
exit 0
