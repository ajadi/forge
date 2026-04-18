#!/bin/bash
# PreToolUse (Bash) hook: Guard dangerous git push patterns
# Input: JSON on stdin with tool_name and tool_input.command
set +e

INPUT=$(cat)

# Extract command
if command -v jq >/dev/null 2>&1; then
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
else
    CMD=$(echo "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
        | sed 's/"command"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

# Only check git push commands
echo "$CMD" | grep -qE '^git push' || exit 0

# Block force push (but allow --force-with-lease)
# Strip --force-with-lease first, then check for plain --force or -f
STRIPPED=$(echo "$CMD" | sed 's/--force-with-lease//g')
if echo "$STRIPPED" | grep -qE '(^| )--force( |$)|(^| )-f( |$)'; then
    echo "❌ BLOCKED: Force push is not allowed. Use --force-with-lease if you really need to overwrite."
    exit 2
fi

# Warn: pushing directly to main/master
if echo "$CMD" | grep -qE ' (main|master)$'; then
    echo "⚠️  WARNING: Pushing directly to main/master branch."
    echo "   If this is intentional, the push will proceed."
fi

exit 0
