#!/bin/bash
# UserPromptSubmit hook: inject a tiny operating-contract delta every turn, so the
# pipeline discipline doesn't drift over a long session. stdout from a
# UserPromptSubmit hook is added to the model's context. Keep it SHORT.
set +e

# Current in-progress task + its last stage (best-effort, local files only).
ACTIVE="(no in-progress task)"
if [ -d "tasks" ]; then
    for f in tasks/TASK-*.md; do
        [ -f "$f" ] || continue
        if grep -q 'status: in_progress' "$f" 2>/dev/null; then
            NAME=$(head -1 "$f" | sed 's/^# *//' | tr -d '\r\n' | tr -d '\000-\037' | cut -c1-80)
            STAGE=$(grep '^## ' "$f" | tail -1 | sed 's/^## *//' | tr -d '\r\n' | tr -d '\000-\037' | cut -c1-40)
            ACTIVE="${NAME} — last stage: ${STAGE:-none}"
            break
        fi
    done
fi

echo "[forge contract] PM orchestrates & delegates; it never writes source itself. Source edits go through the developer agent only. code-reviewer / architect / reality-checker are read-only. Record progress in tasks/ + backlog.md before stopping."
echo "[forge active] ${ACTIVE}"
exit 0
