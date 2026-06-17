#!/bin/bash
# UserPromptSubmit hook: lightweight session depth meter. Counts user turns per
# session and emits an unobtrusive soft-warning when the count crosses a
# threshold — it NEVER blocks. session-start.sh resets the counter to 0 each
# session; statusline.sh renders the live value.
#
# FORGE_DEPTH_SOFT (default 40) = soft threshold. Warns at the threshold and at
# every multiple after it. Set FORGE_DEPTH_SOFT=0 to disable the warning.
set +e

PROJ="${CLAUDE_PROJECT_DIR:-.}"
PROJ=$(printf '%s' "$PROJ" | tr '\134' '/' | tr -s '/')
CFILE="${PROJ}/.claude/.turn-count"

# read current count (default 0; strip anything non-numeric defensively)
N=0
[ -f "$CFILE" ] && N=$(tr -cd '0-9' < "$CFILE" 2>/dev/null)
[ -z "$N" ] && N=0

N=$((N + 1))
echo "$N" > "$CFILE" 2>/dev/null

SOFT="${FORGE_DEPTH_SOFT:-40}"
echo "$SOFT" | grep -qE '^[0-9]+$' || exit 0      # non-numeric -> no warning
[ "$SOFT" -eq 0 ] 2>/dev/null && exit 0           # disabled

if [ $((N % SOFT)) -eq 0 ] 2>/dev/null; then
    echo "[forge depth] ${N} turns this session — consider checkpointing (commit progress, then a fresh session / clear keeps context sharp and cheap). Soft notice only; nothing blocked."
fi
exit 0
