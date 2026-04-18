#!/bin/bash
# PreCompact hook: emergency save to MemPalace before context compression
# Always blocks to ensure memories are preserved before compression
set +e

# Check if mempalace is available
python3 -c "import mempalace" 2>/dev/null || python -c "import mempalace" 2>/dev/null || exit 0

echo '{"decision": "block", "reason": "Context compression imminent. Save important memories to palace now: call mempalace_diary_write with key facts, decisions, and unfinished work from this session."}'
exit 0
