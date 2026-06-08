#!/bin/bash
# PreToolUse (Bash) hook: Guard dangerous git push patterns
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

# Only check commands that contain a git push invocation
printf '%s' "$CMD" | grep -qE '(^|[[:space:];|&])git push([[:space:]]|$)' || exit 0

# Block force push (but allow --force-with-lease)
# Strip --force-with-lease first, then check for plain --force, grouped short flags
# containing 'f' (e.g. -fu), and force-refspec pushes (e.g. +main, +HEAD:main).
STRIPPED=$(printf '%s' "$CMD" | sed 's/--force-with-lease//g')
if printf '%s' "$STRIPPED" | grep -qE '(^|[[:space:]])--force([[:space:]]|$)' \
   || printf '%s' "$STRIPPED" | grep -qE '(^|[[:space:]])-[A-Za-z]*f[A-Za-z]*([[:space:]]|$)' \
   || printf '%s' "$CMD" | grep -qE '(^|[[:space:]])\+[^ ]'; then
    echo "❌ BLOCKED: Force push is not allowed. Use --force-with-lease if you really need to overwrite."
    exit 2
fi

# Warn: pushing directly to main/master
if printf '%s' "$CMD" | grep -qE ' (main|master)$'; then
    echo "⚠️  WARNING: Pushing directly to main/master branch."
    echo "   If this is intentional, the push will proceed."
fi

exit 0
