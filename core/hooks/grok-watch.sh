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

# Billing / no-credit signatures (case-insensitive). Matched against the whole
# payload (which includes the tool response/output).
BILLING_RE='no credits|out of credits|insufficient|quota|payment required|402|billing|does(n.?t| not) have any credits|exceeded your'

if printf '%s' "$INPUT" | grep -qiE "$BILLING_RE"; then
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
