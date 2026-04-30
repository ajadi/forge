#!/bin/bash
#
# Forge framework state mode helper.
#
# Centralizes repo_access decisions for framework-managed paths in a project
# that has Forge installed. Read by hooks (pre-compact, validate-commit) to
# decide whether framework state should be committed or kept local.
#
# Framework-managed paths (forge):
#   .claude/        — agents, commands, hooks, AGENTS.md, pm-ref.md, settings.json
#   CLAUDE.md       — project doctrine
#   manifest.md     — project metadata (this file holds repo_access)
#   memory/         — long-term memory files (decisions, patterns)
#   tasks/          — task files (TASK-XXX.md)
#
# Modes:
#   private-solo    — framework state committed to git (single-user repo)
#   private-shared  — framework state stays local (team repo)
#   public          — framework state stays local (open-source repo)
#

set -euo pipefail

PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
MANIFEST="$PROJECT_DIR/manifest.md"

get_repo_access() {
    if [ -f "$MANIFEST" ]; then
        local value
        value=$(awk -F= '/^repo_access=/{print $2; exit}' "$MANIFEST" 2>/dev/null || true)
        if [ -n "${value:-}" ]; then
            printf '%s\n' "$value"
            return 0
        fi
    fi
    printf 'private-solo\n'
}

is_shared_mode() {
    case "$(get_repo_access)" in
        public|private-shared) return 0 ;;
        *) return 1 ;;
    esac
}

list_framework_paths() {
    printf '%s\n' ".claude" "CLAUDE.md" "manifest.md" "memory" "tasks"
}

# Paths that must be untracked in shared/public mode.
# Note: manifest.md stays tracked — it's the source of truth for repo_access
# and lets a fresh checkout know the repo's policy.
list_local_only_paths() {
    printf '%s\n' ".claude" "CLAUDE.md" "memory" "tasks"
}

list_tracked_framework_paths() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        return 0
    fi
    git ls-files -- .claude CLAUDE.md memory tasks 2>/dev/null || true
}

should_commit_framework_state() {
    if is_shared_mode; then
        printf 'false\n'
    else
        printf 'true\n'
    fi
}

check_safe_mode() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        return 0
    fi
    if ! is_shared_mode; then
        return 0
    fi
    local tracked
    tracked="$(list_tracked_framework_paths)"
    if [ -n "$tracked" ]; then
        echo "framework-state: BLOCKER"
        echo "repo_access=$(get_repo_access), but framework files are still tracked:"
        echo "$tracked"
        echo "Run: scripts/switch-repo-access.sh $(get_repo_access)"
        return 2
    fi
    return 0
}

usage() {
    cat <<'EOF'
Usage: framework-state-mode.sh <command>

Commands:
  repo-access                    Print current repo_access value
  is-shared-mode                 Exit 0 if repo_access is public/private-shared
  should-commit-framework-state  Print true/false
  framework-paths                List all framework-managed paths
  local-only-paths               List paths that must stay local in shared/public mode
  tracked-framework-paths        List currently tracked local-only framework files
  check-safe-mode                Validate that shared/public mode has no tracked local-only files
EOF
}

COMMAND="${1:-}"

case "$COMMAND" in
    repo-access)                     get_repo_access ;;
    is-shared-mode)                  is_shared_mode ;;
    should-commit-framework-state)   should_commit_framework_state ;;
    framework-paths)                 list_framework_paths ;;
    local-only-paths)                list_local_only_paths ;;
    tracked-framework-paths)         list_tracked_framework_paths ;;
    check-safe-mode)                 check_safe_mode ;;
    *)                               usage; exit 1 ;;
esac
