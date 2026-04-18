#!/bin/bash
# SubagentStart hook: Audit log of all agent invocations
# Input: JSON on stdin with agent_name, agent_id fields
set +e

INPUT=$(cat)

# Parse agent name (jq preferred, grep fallback)
if command -v jq >/dev/null 2>&1; then
    AGENT_NAME=$(echo "$INPUT" | jq -r '.agent_name // "unknown"' 2>/dev/null)
else
    AGENT_NAME=$(echo "$INPUT" | grep -oE '"agent_name"[[:space:]]*:[[:space:]]*"[^"]*"' \
        | sed 's/"agent_name"[[:space:]]*:[[:space:]]*"//;s/"$//')
    [ -z "$AGENT_NAME" ] && AGENT_NAME="unknown"
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "handoffs" 2>/dev/null
echo "${TIMESTAMP} | ${AGENT_NAME}" >> "handoffs/agent-audit.log" 2>/dev/null

exit 0
