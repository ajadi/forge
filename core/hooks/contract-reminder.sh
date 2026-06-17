#!/bin/bash
# UserPromptSubmit hook: inject a tiny operating-contract delta every turn, so the
# pipeline discipline doesn't drift over a long session. stdout from a
# UserPromptSubmit hook is added to the model's context. Keep it SHORT.
set +e

# Current in-progress task + its last stage (best-effort, local files only).
ACTIVE="(no in-progress task)"
FILE=""
if [ -d "tasks" ]; then
    for f in tasks/TASK-*.md; do
        [ -f "$f" ] || continue
        if grep -q 'status: in_progress' "$f" 2>/dev/null; then
            NAME=$(head -1 "$f" | sed 's/^# *//' | tr -d '\r\n' | tr -d '\000-\037' | cut -c1-80)
            STAGE=$(grep '^## ' "$f" | tail -1 | sed 's/^## *//' | tr -d '\r\n' | tr -d '\000-\037' | cut -c1-40)
            ACTIVE="${NAME} — last stage: ${STAGE:-none}"
            FILE="$f"
            break
        fi
    done
fi

echo "[forge contract] PM orchestrates & delegates; it never writes source itself. Source edits go through the developer agent only. code-reviewer / architect / reality-checker are read-only. Record progress in tasks/ + backlog.md before stopping."
echo "[forge active] ${ACTIVE}"

# Objective anchor: surface the active task's goal + done-criteria so a long
# session doesn't drift from what it set out to do. Only when a task is active;
# both lines are best-effort and silently omitted if not found.
if [ -n "$FILE" ]; then
    OBJ=$(awk '/^##[[:space:]]+([Ss]pec|[Oo]bjective|[Gg]oal)([[:space:]]|$)/{f=1;next} f&&NF{print;exit}' "$FILE" 2>/dev/null | tr -d '\r' | tr -d '\000-\037' | cut -c1-120)
    DONE=$(grep -iE '^(AC|done|acceptance|definition of done)[:.]' "$FILE" 2>/dev/null | head -1 | tr -d '\r' | tr -d '\000-\037' | cut -c1-120)
    [ -n "$OBJ" ]  && echo "[forge objective] ${OBJ}"
    [ -n "$DONE" ] && echo "[forge done-when] ${DONE}"
fi
exit 0
