#!/bin/bash
# PreToolUse (Bash) hook: Guard dangerous git commit patterns
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

# Only check git commit commands
echo "$CMD" | grep -qE '^git commit' || exit 0

# Block --no-verify
if echo "$CMD" | grep -q '\-\-no-verify'; then
    echo "❌ BLOCKED: git commit --no-verify bypasses hooks. Remove the flag."
    exit 2
fi

# Block committing .env files
if git diff --staged --name-only 2>/dev/null | grep -qE '(^|/)\.env($|\.)'; then
    echo "❌ BLOCKED: .env file staged for commit. Unstage it first: git restore --staged .env"
    exit 2
fi

# Warn: empty commit message
if echo "$CMD" | grep -qE 'git commit -m[[:space:]]*["'"'"']["'"'"']'; then
    echo "❌ BLOCKED: Empty commit message."
    exit 2
fi

exit 0
