#!/bin/bash
# PostToolUse (Bash) hook: watch coworker/Grok calls for "out of credits".
#
# xAI exposes no balance API, so we can't read remaining credits — but when the
# account runs dry, a `coworker ask` call fails with a billing error. This hook
# detects that, flags it loudly (🟥 shown in the statusline + a banner), and
# tells the agent to stop delegating. On a later SUCCESSFUL coworker call it
# clears the flag (recovered after top-up).
#
# Never blocks (PostToolUse, exit 0). Best-effort string match — tune the
# signatures below if xAI's error wording changes.
set +e

INPUT=$(cat)
PROJ="${CLAUDE_PROJECT_DIR:-.}"
mkdir -p "$PROJ/.claude" 2>/dev/null

# Extract the bash command that ran.
if command -v jq >/dev/null 2>&1; then
    CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
else
    CMD=$(printf '%s' "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
        | sed 's/"command"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

# Only care about coworker invocations.
printf '%s' "$CMD" | grep -q "coworker" || exit 0

# Billing / no-credit signatures (case-insensitive). Matched against the tool
# output/error portion only to avoid false positives from the payload context.
# Extract tool output; fall back to full input only when extraction fails.
if command -v jq >/dev/null 2>&1; then
    TOOL_OUT=$(printf '%s' "$INPUT" | jq -r '(.tool_response // .output // .error // "") | tostring' 2>/dev/null)
elif command -v python3 >/dev/null 2>&1; then
    TOOL_OUT=$(printf '%s' "$INPUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("tool_response") or d.get("output") or d.get("error") or "")' 2>/dev/null || true)
elif command -v python >/dev/null 2>&1; then
    TOOL_OUT=$(printf '%s' "$INPUT" | python -c 'import json,sys; d=json.load(sys.stdin); print(d.get("tool_response") or d.get("output") or d.get("error") or "")' 2>/dev/null || true)
else
    TOOL_OUT="$INPUT"
fi
# Require credit-specific phrasing; anchor 402 to HTTP/payment context.
BILLING_RE='no credits|out of credits|does(n.?t| not) have any credits|exceeded your (credit|quota)|insufficient (credit|fund)|HTTP 402|status code 402|payment required'

if printf '%s' "$TOOL_OUT" | grep -qiE "$BILLING_RE"; then
    echo "$(date +%s) | coworker billing error on: $CMD" > "$PROJ/.claude/.grok-broke" 2>/dev/null
    echo ""
    echo "🟥 ============================================================"
    echo "🟥  GROK / coworker: OUT OF CREDITS (billing error on the call)."
    echo "🟥  Top up at https://console.x.ai. Until then, DO NOT delegate"
    echo "🟥  to coworker — read needed files directly (cost falls back to"
    echo "🟥  the main model). The read-gate will stop suggesting coworker."
    echo "🟥 ============================================================"
else
    # Successful coworker call — record activity for the statusline and clear
    # any stale out-of-credits flag (recovered after a top-up).
    date +%s > "$PROJ/.claude/.grok-last" 2>/dev/null
    rm -f "$PROJ/.claude/.grok-broke" 2>/dev/null
fi

exit 0
