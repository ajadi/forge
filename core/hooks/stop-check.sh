#!/usr/bin/env bash
# stop-check.sh
# Runs at end of every agent turn (Stop hook).
# Reads stdin JSON, checks if task is incomplete, nudges Claude to continue.

INPUT=$(cat)

# If stop_hook_active is true — Claude already tried to continue, don't loop
if echo "$INPUT" | grep -q '"stop_hook_active":true'; then
    exit 0
fi

# Check if any task file has in_progress status without a reality-checker section
# This catches cases where Claude stopped mid-pipeline
if [ -d "tasks" ]; then
    for file in tasks/TASK-*.md; do
        [ -f "$file" ] || continue
        if grep -q "status: in_progress" "$file" && ! grep -qi "## reality" "$file"; then
            basename_file=$(basename "$file")
            echo "Task $basename_file is in_progress but pipeline incomplete. Continue the pipeline."
            exit 1
        fi
    done
fi

exit 0
