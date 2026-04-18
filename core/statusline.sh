#!/usr/bin/env bash
# Claude Code Status Line
# Outputs: ctx% | model | tasks: X/Y [| ⚠️ N OQ]
set +e

input=$(cat)

# --- Parse JSON ---
if command -v jq &>/dev/null; then
    model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
    used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
    cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
else
    model=$(echo "$input" | grep -oE '"display_name"\s*:\s*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
    used_pct=$(echo "$input" | grep -oE '"used_percentage"\s*:\s*[0-9]+' | head -1 | sed 's/.*: *//')
    cwd=$(echo "$input" | grep -oE '"current_dir"\s*:\s*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
    [ -z "$model" ] && model="Unknown"
fi

# Normalize Windows paths
cwd=$(echo "$cwd" | sed 's|\\|/|g')
[ -z "$cwd" ] && cwd="."

# --- Context ---
if [ -n "$used_pct" ]; then
    ctx_label="ctx:${used_pct}%"
else
    ctx_label="ctx:--"
fi

# --- Task progress from backlog.md ---
tasks_label=""
BACKLOG="$cwd/backlog.md"
if [ -f "$BACKLOG" ]; then
    OPEN=$(grep -c '^\- \[ \]' "$BACKLOG" 2>/dev/null || echo 0)
    DONE=$(grep -c '^\- \[x\]' "$BACKLOG" 2>/dev/null || echo 0)
    TOTAL=$((OPEN + DONE))
    if [ "$TOTAL" -gt 0 ]; then
        tasks_label=" | tasks:${DONE}/${TOTAL}"
    fi
fi

# --- Open questions ---
oq_label=""
TZ="$cwd/tz.md"
if [ -f "$TZ" ]; then
    OQ=$(grep -c '⏳ open' "$TZ" 2>/dev/null || echo 0)
    [ "$OQ" -gt 0 ] && oq_label=" | ⚠️ OQ:${OQ}"
fi

# --- Assemble ---
printf "%s" "${ctx_label} | ${model}${tasks_label}${oq_label}"
