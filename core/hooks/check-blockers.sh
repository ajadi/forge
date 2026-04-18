#!/bin/bash
# PostToolUse hook: check for blockers after agent completion
# Fires after Agent tool use — detects OQ blockers added during agent work
set +e

INPUT=$(cat)

# Count open OQs in tz.md
current_oq=$(grep -c '⏳ open' tz.md 2>/dev/null | tr -d '\r' || echo 0)
previous_oq=$(cat .claude/.oq-state 2>/dev/null | tr -d '\r' || echo 0)

# If new OQs were added during agent work, warn
if [ "$current_oq" -gt "$previous_oq" ]; then
  new_count=$((current_oq - previous_oq))
  echo "⚠ $new_count new Open Question(s) added during agent work — check tz.md before continuing"
fi

# Update state
echo "$current_oq" > .claude/.oq-state

exit 0
