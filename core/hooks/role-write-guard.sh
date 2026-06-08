#!/bin/bash
# PreToolUse (Write|Edit) hook: enforce the role boundaries declared in AGENTS.md.
#
# Identity (who is acting), in priority order:
#   1. The `agent_type` / `agent_name` field the hook receives on stdin — when the
#      runtime provides it this is authoritative, per-call and race-free (the main
#      orchestrator omits it => pm-inline).
#   2. Fallback: the `.claude/.current-agent` marker written by log-agent.sh on
#      SubagentStart (TTL ROLE_GUARD_TTL, default 1800s; stale/absent => pm-inline).
#      Used only on runtimes that don't surface agent identity to PreToolUse. This
#      path is last-writer-wins and can misattribute under parallel subagents.
#
# Decision (path relative to project root):
#   PROTECTED (hooks, settings, statusline, .gitignore, agent defs, doctrine, the
#     marker itself) -> DENY for every agent incl. pm-inline. Only the human edits
#     the enforcement surface; otherwise an agent could neuter the guard.
#   FW (framework STATE: .claude/ state, tasks/, memory/, handoffs/, tz.md,
#     backlog.md, manifest.*) -> allow for all (task files, handoffs, memory).
#   Otherwise product source -> role rules: pm-inline & read-only roles denied;
#     testers only test files; doc-writers only docs; impl agents allowed.
#
# Block convention: message on stdout, exit 2 to deny, exit 0 to allow. FAILS OPEN
# on uncertainty. Disable entirely with ROLE_WRITE_GUARD=off.
#
# Known limitation: classification is on the path string, not the resolved target,
# so a symlink under a framework dir (created via Bash) pointing at source is not
# caught — symlink creation needs Bash, which this Write|Edit hook does not gate.
set +e

[ "${ROLE_WRITE_GUARD:-on}" = "off" ] && exit 0

INPUT=$(cat)

# --- target path + acting agent (single jq pass when available) ---
if command -v jq >/dev/null 2>&1; then
    FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)
    STDIN_AGENT=$(printf '%s' "$INPUT" | jq -r '.agent_type // .agent_name // ""' 2>/dev/null)
else
    FILE_PATH=$(printf '%s' "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
        | sed 's/"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//')
    STDIN_AGENT=$(printf '%s' "$INPUT" | grep -oE '"agent_type"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
        | sed 's/.*:[[:space:]]*"//;s/"$//')
    [ -z "$STDIN_AGENT" ] && STDIN_AGENT=$(printf '%s' "$INPUT" | grep -oE '"agent_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
        | sed 's/.*:[[:space:]]*"//;s/"$//')
fi
[ -z "$FILE_PATH" ] && exit 0   # no path -> fail open

# --- relativize to project root (normalize backslashes + squeeze slashes;
#     case-insensitive prefix compare for Windows drive letters) ---
PROJ="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PROJ_N=$(printf '%s' "$PROJ" | tr '\134' '/' | tr -s '/')
FP_N=$(printf '%s' "$FILE_PATH" | tr '\134' '/' | tr -s '/')
proj_l=$(printf '%s' "$PROJ_N" | tr 'A-Z' 'a-z')
fp_l=$(printf '%s' "$FP_N" | tr 'A-Z' 'a-z')
case "$fp_l/" in
    "$proj_l"/*) REL="${FP_N:${#PROJ_N}}"; REL="${REL#/}" ;;
    *)           REL="$FP_N" ;;
esac
# Outside the project tree -> fail open (git guards cover that).
case "$REL" in /*|[A-Za-z]:*) exit 0 ;; esac

deny() { echo "BLOCKED (role-write-guard): $1"; exit 2; }

# Reject path traversal — a `..` segment can dodge the `^`-anchored classifiers
# (e.g. tasks/../src/x.ts would look like framework state). Normalized paths only.
case "/$REL/" in *"/../"*) deny "path '$REL' contains a '..' segment; pass a normalized path." ;; esac

# REL is matched in ORIGINAL case for directory prefixes (so a product dir named
# Memory/ or Tasks/ is NOT mistaken for framework state); known filenames and
# extensions are matched case-insensitively.
cs() { printf '%s' "$REL" | grep -qE "$1"; }   # case-sensitive
ci() { printf '%s' "$REL" | grep -qiE "$1"; }   # case-insensitive

# 1) PROTECTED enforcement surface — denied for ALL agents (human-owned).
if cs '^\.claude/hooks/|^\.claude/agents/|^core/agents/|^extensions/.+/agents/|^\.claude/\.current-agent$' \
   || ci '^\.claude/settings(\.local)?\.json$|^\.claude/statusline\.sh$|^\.gitignore$|^claude\.md$|^pm-ref\.md$|^\.claude/pm-ref\.md$|^agents\.md$|^\.claude/agents\.md$'; then
    deny "'$REL' is protected enforcement/doctrine infrastructure (hooks, settings, agent defs, CLAUDE.md, pm-ref.md, .gitignore). Only the human edits these — report the needed change instead."
fi

# 2) framework STATE — task files, handoffs, memory, .claude state: allow for all.
if cs '^\.claude/|^tasks/|^memory/|^handoffs/' \
   || ci '^tz\.md$|^backlog\.md$|^manifest\.(md|json)$|^forge-upgrade-progress\.md$'; then
    exit 0
fi

# 3) product source — apply the acting role's boundary.
AGENT="$STDIN_AGENT"
if [ -z "$AGENT" ]; then
    # Fallback: marker file (only when the runtime didn't give us identity).
    TTL="${ROLE_GUARD_TTL:-1800}"
    MARKER="$PROJ_N/.claude/.current-agent"
    if [ -f "$MARKER" ]; then
        M_TS=$(awk '{print $1}' "$MARKER" 2>/dev/null)
        M_AGENT=$(awk '{print $2}' "$MARKER" 2>/dev/null)
        NOW=$(date +%s)
        if [ -n "$M_TS" ] && [ -n "$M_AGENT" ] && [ $((NOW - M_TS)) -lt "$TTL" ] 2>/dev/null; then
            AGENT="$M_AGENT"
        fi
    fi
fi
[ -z "$AGENT" ] && AGENT="pm-inline"

TEST=false; DOC=false
# Test-file classifier: standard dirs, named extensions, e2e dir, and smoke/e2e spec files anywhere.
ci '(^|/)(tests?|__tests__|specs?|e2e)/|\.(test|spec)\.[a-z0-9]+$|_test\.[a-z0-9]+$|(^|/)test_[^/]*\.py$|(^|/)smoke\.spec\.[a-z0-9]+$|(^|/)[^/]*\.e2e\.[a-z0-9]+$' && TEST=true
ci '\.(md|mdx|rst|txt|adoc)$|^docs/' && DOC=true
# Design deliverables written by ux-interviewer / ui-designer / estimator.
DESIGN_DOC=false
ci '(^|/)(design-brief|design-spec|timeline|estimate)\.(md|mdx)$' && DESIGN_DOC=true

# Read-only / non-implementing roles (cannot write product source at all).
READONLY_NOSRC=" pm architect code-reviewer reality-checker business-analyst security-analyst dependency-auditor status handoff-validator accessibility-auditor performance-profiler test-reviewer consilium decomposer optimizer onboarding dream reflect retro context-summarizer it-forums "
# Testers: may write test files only.
TESTER=" unit-tester integration-tester smoke-tester e2e-tester "
# Doc writers: may write docs only.
DOCWRITER=" documentation changelog-agent "
# Design / estimation roles: may write their own .md deliverables (design-brief, design-spec, timeline, estimate).
DESIGNER=" ux-interviewer ui-designer estimator "
# Implementation roles: explicitly allowed to write source.
IMPL=" developer database-architect devops env-manager refactoring rapid-prototyper git-workflow migration-validator "
in_set() { case "$1" in *" $AGENT "*) return 0;; *) return 1;; esac; }

if [ "$AGENT" = "pm-inline" ]; then
    deny "PM does not implement. Source file '$REL' must be written by the developer agent — spawn it via the Agent tool, or STOP and report. PM may only edit framework state (tasks/, memory/, tz.md, backlog.md, .claude state)."
fi
if in_set "$READONLY_NOSRC"; then
    deny "agent '$AGENT' is read-only / non-implementing per AGENTS.md and cannot edit source ('$REL'). Report findings to PM; PM delegates the fix to developer."
fi
if in_set "$TESTER"; then
    $TEST && exit 0
    deny "agent '$AGENT' may only write test files; '$REL' is production source. Report the needed change to PM."
fi
if in_set "$DOCWRITER"; then
    $DOC && exit 0
    deny "agent '$AGENT' writes docs only; it cannot change code ('$REL')."
fi
if in_set "$DESIGNER"; then
    $DESIGN_DOC && exit 0
    $DOC && exit 0
    deny "agent '$AGENT' may only write design/estimation deliverable docs (design-brief.md, design-spec.md, timeline.md, estimate.md); '$REL' is not one of those."
fi

# Explicit impl set -> allow.
if in_set "$IMPL"; then
    exit 0
fi

# Unknown/unclassified agent -> DENY with a clear message so the gap is visible.
deny "agent '$AGENT' is not classified in role-write-guard — add it to the appropriate role set (READONLY_NOSRC / TESTER / DOCWRITER / DESIGNER / IMPL) before it can write source files."
