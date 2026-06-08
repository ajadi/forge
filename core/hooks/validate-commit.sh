#!/bin/bash
# PreToolUse (Bash) hook: Guard dangerous git commit patterns
# Input: JSON on stdin with tool_name and tool_input.command
set +e

INPUT=$(cat)

# Extract command (jq → python → grep fallback; handles JSON escaping + BOM)
if command -v jq >/dev/null 2>&1; then
    CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
elif command -v python3 >/dev/null 2>&1; then
    CMD=$(printf '%s' "$INPUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("command",""))' 2>/dev/null || true)
elif command -v python >/dev/null 2>&1; then
    CMD=$(printf '%s' "$INPUT" | python -c 'import json,sys; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("command",""))' 2>/dev/null || true)
else
    CMD=$(printf '%s' "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
        | sed 's/"command"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

# Only check commands that contain a git commit invocation (handles compound/prefixed commands)
printf '%s' "$CMD" | grep -qE '(^|[[:space:];|&])git commit([[:space:]]|$)' || exit 0

# Isolate ONLY the `git commit` segment(s) of a (possibly compound) command, and
# strip quoted strings (the commit message etc.) so flag-like text inside a
# message cannot trip the --no-verify guard.
COMMIT_SEG=$(printf '%s' "$CMD" | tr ';|&' '\n\n\n' | grep -E '^[[:space:]]*git commit')
COMMIT_FLAGS=$(printf '%s' "$COMMIT_SEG" | sed -E 's/"[^"]*"//g; s/'"'"'[^'"'"']*'"'"'//g')

# Block --no-verify (real flag only — quoted message text was stripped above)
if printf '%s' "$COMMIT_FLAGS" | grep -q '\-\-no-verify'; then
    echo "❌ BLOCKED: git commit --no-verify bypasses hooks. Remove the flag."
    exit 2
fi

# Block committing .env files (uses the staged diff, not the command string)
if git diff --staged --name-only 2>/dev/null | grep -qE '(^|/)\.env($|\.)'; then
    echo "❌ BLOCKED: .env file staged for commit. Unstage it first: git restore --staged .env"
    exit 2
fi

# Warn: empty commit message (commit segment, quotes intact so -m "" is visible)
if printf '%s' "$COMMIT_SEG" | grep -qE 'git commit -m[[:space:]]*["'"'"']["'"'"']'; then
    echo "❌ BLOCKED: Empty commit message."
    exit 2
fi

exit 0
