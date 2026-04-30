#!/bin/bash
# Stop hook: checkpoint conversation to MemPalace
# Fires at Stop event — saves agent diary entry every N exchanges
set +e

SAVE_INTERVAL="${MEMPAL_SAVE_INTERVAL:-15}"
STATE_DIR="${MEMPAL_STATE_DIR:-${HOME}/.mempalace/hook_state}"
CHECKPOINT_FILE="$STATE_DIR/last_checkpoint"

mkdir -p "$STATE_DIR"

# Check if mempalace is available (try python3 first, then python)
PYTHON=""
if python3 -c "import mempalace" 2>/dev/null; then
  PYTHON="python3"
elif python -c "import mempalace" 2>/dev/null; then
  PYTHON="python"
else
  exit 0
fi

# Convert path for Windows-native Python (Git Bash uses /c/... but Windows Python needs C:/...)
if command -v cygpath >/dev/null 2>&1; then
  PY_CHECKPOINT_FILE=$(cygpath -m "$CHECKPOINT_FILE")
else
  PY_CHECKPOINT_FILE="$CHECKPOINT_FILE"
fi

# Count exchanges since last save
if [ -f "$CHECKPOINT_FILE" ]; then
  last_msgs=$($PYTHON -c "import json; print(json.load(open(r'$PY_CHECKPOINT_FILE')).get('msgs', 0))" 2>/dev/null || echo 0)
else
  last_msgs=0
fi

current_msgs=$((last_msgs + 1))

# Update counter
echo "{\"ts\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"msgs\": $current_msgs}" > "$CHECKPOINT_FILE"

# If enough exchanges accumulated, signal save
if [ "$current_msgs" -ge "$SAVE_INTERVAL" ]; then
  # Reset counter
  echo "{\"ts\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"msgs\": 0}" > "$CHECKPOINT_FILE"
  # Block to trigger palace save
  echo '{"decision": "block", "reason": "Time to save session memories. Call mempalace_diary_write with a summary of this session before stopping."}'
  exit 0
fi

# Allow normal stop
echo '{}'
exit 0
