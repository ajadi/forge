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

# --- Active subagent + its model (which model is working right now) ---
# Reads the .current-agent marker (epoch name model) written by log-agent.sh.
# Shown only while fresh (< 600s) since there is no SubagentStop to clear it.
agent_label=""
MARKER="$cwd/.claude/.current-agent"
if [ -f "$MARKER" ]; then
    m_ts=$(awk '{print $1}' "$MARKER" 2>/dev/null)
    m_agent=$(awk '{print $2}' "$MARKER" 2>/dev/null)
    m_model=$(awk '{print $3}' "$MARKER" 2>/dev/null)
    now=$(date +%s)
    if [ -n "$m_ts" ] && [ -n "$m_agent" ] && [ $((now - m_ts)) -lt 600 ] 2>/dev/null; then
        agent_label=" | ▸${m_agent}·${m_model:-?}"
    fi
fi

# --- Grok / coworker delegation state ---
grok_label=""
if [ -f "$cwd/.claude/.grok-broke" ]; then
    grok_label=" | 🟥 grok:NO-CREDITS"
elif [ -f "$cwd/.claude/.grok-last" ]; then
    g_ts=$(cat "$cwd/.claude/.grok-last" 2>/dev/null)
    now=$(date +%s)
    [ -n "$g_ts" ] && [ $((now - g_ts)) -lt 120 ] 2>/dev/null && grok_label=" | ▸grok"
fi

# --- Autopilot indicator ---
auto_label=""
[ -f "$cwd/.claude/.autopilot" ] && auto_label=" | 🛫AUTO"

# --- Assemble ---
printf "%s" "${ctx_label} | ${model}${agent_label}${grok_label}${auto_label}${tasks_label}${oq_label}"
