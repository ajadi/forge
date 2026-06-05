#!/bin/bash
# PreToolUse (Write|Edit) hook: enforce the role boundaries declared in AGENTS.md.
#
# The roster says "PM never implements", "reviewers read-only", "developer cannot
# modify pm-ref/CLAUDE/agent defs", "unit-tester only touches tests" — but nothing
# used to ENFORCE it. This hook does.
#
# Who is acting: the SubagentStart hook (log-agent.sh) writes the current agent to
# `.claude/.current-agent` as "<epoch> <name>". This guard reads it. Missing or
# older than ROLE_GUARD_TTL (default 1800s) ⇒ treated as PM-inline (the orchestrator
# itself). NOTE: under parallel subagents this marker is last-writer-wins and may
# misattribute — a documented limitation of the marker approach.
#
# Classification (path relative to project root):
#   FW       = framework state anyone may write (.claude/, tasks/, memory/, handoffs/,
#              docs/, scripts/, logs/, tz.md, backlog.md, manifest.*, *.log, locks.json,
#              CLAUDE.md, AGENTS.md, pm-ref.md)  -> allowed (task files, handoffs, memory)
#   AGENTDEF = framework definitions impl agents must NOT touch (CLAUDE.md, pm-ref.md,
#              .claude|core|extensions agents/)
#   TEST     = test files
#   DOC      = .md/.rst/.txt or docs/
#   SOURCE   = anything else (product code)
#
# Block convention matches the other Forge PreToolUse hooks: message on stdout,
# exit 2 to deny, exit 0 to allow. FAILS OPEN on any uncertainty.
# Disable entirely with ROLE_WRITE_GUARD=off.
set +e

[ "${ROLE_WRITE_GUARD:-on}" = "off" ] && exit 0

INPUT=$(cat)

# --- target path ---
if command -v jq >/dev/null 2>&1; then
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)
else
    FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
        | sed 's/"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi
[ -z "$FILE_PATH" ] && exit 0   # no path -> fail open

# --- relativize to project root (case-insensitive; Windows drive letters vary) ---
# Normalize backslashes via tr (octal \134 = '\') — version-independent, unlike
# the ${var//\\//} parameter expansion whose behavior varies across bash builds.
# tr '\134'='\' -> '/', then squeeze repeated slashes. The grep JSON fallback
# (used when jq is absent) yields JSON-escaped doubled backslashes; squeezing
# makes single- and double-separator forms normalize identically.
PROJ="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PROJ_N=$(printf '%s' "$PROJ" | tr '\134' '/' | tr -s '/')
FP_N=$(printf '%s' "$FILE_PATH" | tr '\134' '/' | tr -s '/')
proj_l=$(printf '%s' "$PROJ_N" | tr 'A-Z' 'a-z')
fp_l=$(printf '%s' "$FP_N" | tr 'A-Z' 'a-z')
case "$fp_l/" in
    "$proj_l"/*) REL="${FP_N:${#PROJ_N}}"; REL="${REL#/}" ;;
    *)           REL="$FP_N" ;;   # outside project root
esac
# Still absolute? path is outside the project tree -> fail open (git guards cover that)
case "$REL" in
    /*|[A-Za-z]:*) exit 0 ;;
esac
rel_l=$(printf '%s' "$REL" | tr 'A-Z' 'a-z')

# --- who is acting ---
TTL="${ROLE_GUARD_TTL:-1800}"
AGENT="pm-inline"
MARKER="$PROJ_N/.claude/.current-agent"
if [ -f "$MARKER" ]; then
    M_TS=$(awk '{print $1}' "$MARKER" 2>/dev/null)
    M_AGENT=$(awk '{print $2}' "$MARKER" 2>/dev/null)
    NOW=$(date +%s)
    if [ -n "$M_TS" ] && [ -n "$M_AGENT" ] && [ $((NOW - M_TS)) -lt "$TTL" ] 2>/dev/null; then
        AGENT="$M_AGENT"
    fi
fi

# --- classify path ---
is() { printf '%s' "$rel_l" | grep -qE "$1"; }

FW=false; AGENTDEF=false; TEST=false; DOC=false
is '^\.claude/|^tasks/|^memory/|^handoffs/|^docs/|^scripts/|^logs/|^tz\.md$|^backlog\.md$|^manifest\.(md|json)$|^\.gitignore$|^claude\.md$|^agents\.md$|^pm-ref\.md$|^forge-upgrade-progress\.md$|locks\.json$|\.log$' && FW=true
is '^claude\.md$|^pm-ref\.md$|^\.claude/pm-ref\.md$|^\.claude/agents/|^core/agents/|^extensions/[^/]+/agents/|^agents\.md$|^\.claude/agents\.md$' && AGENTDEF=true
is '(^|/)(tests?|__tests__|specs?|e2e)/|\.(test|spec)\.[a-z0-9]+$|_test\.[a-z0-9]+$|(^|/)test_[^/]*\.py$' && TEST=true
is '\.(md|mdx|rst|txt|adoc)$|^docs/' && DOC=true

# --- role sets ---
READONLY_NOSRC=" pm architect code-reviewer reality-checker business-analyst security-analyst dependency-auditor status handoff-validator accessibility-auditor performance-profiler test-reviewer estimator consilium migration-validator smoke-tester e2e-tester ux-interviewer ui-designer "
IMPL=" developer database-architect devops env-manager refactoring rapid-prototyper git-workflow decomposer optimizer onboarding dream reflect retro context-summarizer "
TESTER=" unit-tester integration-tester "
DOCWRITER=" documentation changelog-agent "
in_set() { case "$1" in *" $AGENT "*) return 0;; *) return 1;; esac; }

deny() { echo "BLOCKED (role-write-guard): $1"; exit 2; }

# 1) framework definitions: impl/test/doc agents may never edit them
if $AGENTDEF && { in_set "$IMPL" || in_set "$TESTER" || in_set "$DOCWRITER"; }; then
    deny "agent '$AGENT' cannot modify framework definitions ('$REL'). CLAUDE.md / pm-ref.md / agent defs are owned by the human + PM. Report the needed change instead."
fi

# 2) framework state (task files, handoffs, memory, settings, docs, logs): allow for all
$FW && exit 0

# 3) product source — apply the role's boundary
if [ "$AGENT" = "pm-inline" ]; then
    deny "PM does not implement. Source file '$REL' must be written by the developer agent — spawn it via the Agent tool, or STOP and report. If agent-spawn is unavailable, do NOT write source yourself: tell the user and halt. PM may only edit framework state (.claude/, tasks/, memory/, tz.md, backlog.md)."
fi
if in_set "$READONLY_NOSRC"; then
    deny "agent '$AGENT' is read-only / non-implementing per AGENTS.md. It cannot edit source ('$REL'). Report findings to PM; PM delegates the fix to developer."
fi
if in_set "$TESTER"; then
    $TEST && exit 0
    deny "agent '$AGENT' may only write test files; '$REL' is production source. Report the needed production change to PM (developer implements it)."
fi
if in_set "$DOCWRITER"; then
    $DOC && exit 0
    deny "agent '$AGENT' writes docs only; it cannot change code ('$REL')."
fi

# IMPL agents and anything unrecognized -> allow (fail open)
exit 0
