#!/bin/bash
# SubagentStart hook: audit log + model-visibility marker.
# Input: JSON on stdin with agent_name / agent_type.
set +e

INPUT=$(cat)

# Parse agent name (jq preferred, grep fallback)
if command -v jq >/dev/null 2>&1; then
    AGENT_NAME=$(echo "$INPUT" | jq -r '.agent_name // .agent_type // "unknown"' 2>/dev/null)
else
    AGENT_NAME=$(echo "$INPUT" | grep -oE '"agent_(name|type)"[[:space:]]*:[[:space:]]*"[^"]*"' \
        | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//')
    [ -z "$AGENT_NAME" ] && AGENT_NAME="unknown"
fi

PROJ="${CLAUDE_PROJECT_DIR:-.}"

# Look up the agent's model from its frontmatter (model: opus|sonnet|haiku).
MODEL=$(awk -F':' '/^model:/{gsub(/[[:space:]]/,"",$2); print $2; exit}' \
    "$PROJ/.claude/agents/$AGENT_NAME.md" 2>/dev/null)
[ -z "$MODEL" ] && MODEL="?"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p "$PROJ/handoffs" "$PROJ/.claude" 2>/dev/null

# Audit log (now with model) + a visible timeline line.
echo "${TIMESTAMP} | ${AGENT_NAME} | ${MODEL}" >> "$PROJ/handoffs/agent-audit.log" 2>/dev/null
echo "▸ agent: ${AGENT_NAME} · model: ${MODEL}"

# Marker: "<epoch> <agent_name> <model>". role-write-guard reads field 1 (epoch)
# and field 2 (name); the appended model (field 3) is for the statusline and is
# backward-compatible. Last-writer-wins; stale after ROLE_GUARD_TTL.
echo "$(date +%s) ${AGENT_NAME} ${MODEL}" > "$PROJ/.claude/.current-agent" 2>/dev/null

exit 0
