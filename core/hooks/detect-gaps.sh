#!/bin/bash
# SessionStart hook: detect gaps in project setup
# Checks for missing required files and warns at session start
set +e

INPUT=$(cat)

warnings=""

# Check for tz.md (requirements)
[ ! -f "tz.md" ] && warnings="${warnings}\n⚠ No tz.md found — run /f-start or /f-ba to create requirements"

# Check for backlog.md (task tracking)
[ ! -f "backlog.md" ] && warnings="${warnings}\n⚠ No backlog.md found — run /f-decompose to create task backlog"

# Check for memory/stack.md (tech stack)
[ ! -f "memory/stack.md" ] && warnings="${warnings}\n⚠ No memory/stack.md — run /f-onboard to populate project memory"

# Check for stale locks
if [ -f ".claude/locks.json" ]; then
  lock_count=$(grep -c '"locked_at"' .claude/locks.json 2>/dev/null || echo 0)
  if [ "$lock_count" -gt 0 ]; then
    warnings="${warnings}\n⚠ locks.json has $lock_count active locks — check for abandoned tasks"
  fi
fi

if [ -n "$warnings" ]; then
  echo -e "$warnings"
fi

exit 0
