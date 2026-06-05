#!/bin/bash
# PreToolUse (Read) hook: delegate large non-source reads to `coworker`.
#
# Rationale: keep the reasoning model's context for source code. Docs, data,
# logs, lock files and other boilerplate that are large get pushed to the cheap
# `coworker` model (xAI Grok) for read+summarize, or are forced to
# grep-only when truly huge.
#
# File-gate: SOURCE files are always allowed here (reasoning roles read their
# own code). The size thresholds apply ONLY to non-source content.
#
# Token estimate: est_tokens = bytes / COWORKER_TOKEN_DIVISOR (default 4).
#   est_tokens >= COWORKER_GREP_TOKENS  (default 100000) -> deny, grep-only
#   est_tokens >= COWORKER_DELEGATE_TOKENS (default 10000) -> deny, use coworker
#   otherwise -> allow
#
# FAIL OPEN: if `coworker` is not installed/configured, or anything is
# uncertain (no path, unreadable file, parse failure), the Read is ALLOWED.
# Disable entirely with COWORKER_READ_GATE=off.
#
# Block convention matches the other Forge PreToolUse hooks: message on stdout,
# exit 2 to deny, exit 0 to allow.
set +e

# --- opt-out ---
[ "${COWORKER_READ_GATE:-on}" = "off" ] && exit 0

# --- fail open if coworker is unavailable ---
command -v coworker >/dev/null 2>&1 || exit 0

INPUT=$(cat)

# --- extract file_path ---
if command -v jq >/dev/null 2>&1; then
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)
else
    FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
        | sed 's/"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi
[ -z "$FILE_PATH" ] && exit 0

# Normalize Windows backslashes so Git Bash can stat the file (tr '\134'='\',
# then squeeze repeated slashes so the jq and grep-fallback forms — the latter
# yields JSON-escaped doubled backslashes — normalize identically).
NORM_PATH=$(printf '%s' "$FILE_PATH" | tr '\134' '/' | tr -s '/')
[ -f "$NORM_PATH" ] || exit 0

# --- classify source vs non-source by extension ---
ext="${NORM_PATH##*.}"
ext="$(echo "$ext" | tr '[:upper:]' '[:lower:]')"
case "$ext" in
    ts|tsx|js|jsx|mjs|cjs|py|go|rs|java|kt|kts|scala|c|cc|cpp|cxx|h|hpp|hh|cs|rb|php|swift|m|mm|sh|bash|zsh|sql|vue|svelte|dart|ex|exs|erl|clj|cljs|hs|lua|r|pl|pm|gradle|groovy|proto|tf)
        # SOURCE — reasoning roles read their own code. Always allow.
        exit 0
        ;;
esac

# --- estimate token size of non-source file ---
DIVISOR="${COWORKER_TOKEN_DIVISOR:-4}"
DELEGATE_TOKENS="${COWORKER_DELEGATE_TOKENS:-10000}"
GREP_TOKENS="${COWORKER_GREP_TOKENS:-100000}"

BYTES=$(wc -c < "$NORM_PATH" 2>/dev/null | tr -d ' ')
[ -z "$BYTES" ] && exit 0
[ "$DIVISOR" -gt 0 ] 2>/dev/null || DIVISOR=4
EST_TOKENS=$((BYTES / DIVISOR))
EST_K=$((EST_TOKENS / 1000))

if [ "$EST_TOKENS" -ge "$GREP_TOKENS" ]; then
    echo "BLOCKED (coworker-read-gate): '$FILE_PATH' is ~${EST_K}k tokens — too large to read whole."
    echo "Do NOT read the entire file. Either:"
    echo "  - grep for the specific section you need:  grep -n '<pattern>' \"$FILE_PATH\""
    echo "  - or delegate a targeted question:         coworker ask \"<question about this file>\" --file \"$FILE_PATH\""
    echo "Then continue with the extracted answer. (Source files are exempt from this gate.)"
    exit 2
fi

if [ "$EST_TOKENS" -ge "$DELEGATE_TOKENS" ]; then
    echo "BLOCKED (coworker-read-gate): '$FILE_PATH' is ~${EST_K}k tokens of non-source content."
    echo "Delegate this read to coworker instead of spending reasoning context:"
    echo "  coworker ask \"summarize / extract what you need from this file\" --file \"$FILE_PATH\""
    echo "Use the returned summary. (Source code is exempt; set COWORKER_READ_GATE=off to disable.)"
    exit 2
fi

exit 0
