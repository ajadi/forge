#!/bin/bash
# PreCompact hook: emergency save to MemPalace before context compression
# Blocks ONCE per session; after diary_write agent creates the flag file to unblock.
set +e

FLAG=".claude/.precompact-diary-saved"

# If flag exists, diary was written — allow compaction and clear flag
if [ -f "$FLAG" ]; then
  rm -f "$FLAG"
  exit 0
fi

# Check if mempalace is available; if not, allow
python3 -c "import mempalace" 2>/dev/null || python -c "import mempalace" 2>/dev/null || exit 0

echo '{"decision": "block", "reason": "Context compression imminent. Do both steps: (1) call mempalace_diary_write with key facts, decisions, and unfinished work from this session; (2) run: touch .claude/.precompact-diary-saved — this flag file is required to unblock compaction."}'
exit 0
