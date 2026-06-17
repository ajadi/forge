#!/bin/bash
# PreToolUse (Bash) hook: shrink the output of known-noisy commands to save
# tokens. For a small whitelist of safe, noisy commands it rewrites the command
# to a leaner form (preferred path), or — if rewrites are disabled — denies with
# leaner-command guidance (exit 2).
#
# FAIL OPEN on everything uncertain: kill-switch, unparseable input, ANY
# compound/redirected command, anything not in the whitelist, or a command
# already in lean form -> pass through unchanged (exit 0, no output).
#
# Kill-switches:
#   FORGE_BASH_FILTER=off   -> disable entirely (pass through)
#   FORGE_BASH_REWRITE=off  -> keep filtering but use deny-guidance (exit 2)
#                              instead of rewriting the command in place.
set +e

# --- kill-switch ---
[ "${FORGE_BASH_FILTER:-on}" = "off" ] && exit 0

INPUT=$(cat)

# --- extract command (jq -> python -> grep fallback; matches other hooks) ---
if command -v jq >/dev/null 2>&1; then
    CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
elif command -v python3 >/dev/null 2>&1; then
    CMD=$(printf '%s' "$INPUT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null || true)
elif command -v python >/dev/null 2>&1; then
    CMD=$(printf '%s' "$INPUT" | python -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null || true)
else
    CMD=$(printf '%s' "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
        | sed 's/"command"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

# no command -> pass through
[ -z "$CMD" ] && exit 0

# --- only SIMPLE commands are safe to rewrite. Anything with a pipe, redirect,
#     chaining or substitution is passed through untouched (changing semantics
#     would be worse than the token cost). ---
case "$CMD" in
    *'&&'*|*'||'*|*';'*|*'|'*|*'>'*|*'<'*|*'`'*|*'$('*) exit 0 ;;
esac

# trim leading/trailing whitespace
CMD_TRIM=$(printf '%s' "$CMD" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')

NEW=""
NOTE=""

# --- bare git commands: rewrite to a lean equivalent (exact match only, so a
#     command that already carries flags is left alone). ---
case "$CMD_TRIM" in
    "git status")              NEW="git status --short --branch" ;;
    "git log")                 NEW="git log --oneline -20"
                               NOTE="(last 20 as oneline; pass a range/-p for more)" ;;
    "git diff")                NEW="git diff --stat"
                               NOTE="(--stat overview; diff a path for full hunks)" ;;
    "git diff --cached"|"git diff --staged")
                               NEW="git diff --stat --cached"
                               NOTE="(--stat overview of staged changes)" ;;
    "git branch")              NEW="git branch | head -50" ;;
esac

# --- package installs: prefix-match, cap output to the tail ---
if [ -z "$NEW" ]; then
    if printf '%s' "$CMD_TRIM" | grep -qE '^(npm|pnpm) (install|i|ci)([[:space:]]|$)' \
       || printf '%s' "$CMD_TRIM" | grep -qE '^yarn (install|add)([[:space:]]|$)' \
       || printf '%s' "$CMD_TRIM" | grep -qE '^pip3? install([[:space:]]|$)'; then
        NEW="$CMD_TRIM 2>&1 | tail -20"
        NOTE="(output capped to last 20 lines)"
    fi
fi

# --- recursive ls listings ---
if [ -z "$NEW" ]; then
    if printf '%s' "$CMD_TRIM" | grep -qE '^ls[[:space:]].*-[A-Za-z]*R'; then
        NEW="$CMD_TRIM | head -100"
        NOTE="(output capped to first 100 lines)"
    fi
fi

# nothing matched, or already identical -> pass through
[ -z "$NEW" ] && exit 0
[ "$NEW" = "$CMD_TRIM" ] && exit 0

# --- FALLBACK: rewrites disabled -> deny with guidance ---
if [ "${FORGE_BASH_REWRITE:-on}" = "off" ]; then
    echo "token-saver: run the leaner form instead -> $NEW  $NOTE"
    exit 2
fi

# --- PREFERRED: rewrite the command in place (one-shot, exit 0) ---
# NEW is built from a fixed whitelist (charset: letters, digits, space, - | & >),
# so JSON interpolation is safe; still prefer jq when available.
if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -cn --arg c "$NEW" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",updatedInput:{command:$c}}}' 2>/dev/null && exit 0
fi
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","updatedInput":{"command":"%s"}}}\n' "$NEW"
exit 0
