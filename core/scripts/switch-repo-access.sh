#!/bin/bash
#
# Forge — switch repo_access between private-solo and shared/public modes.
#
# Updates:
#   - manifest.md repo_access value
#   - .gitignore "framework-public-ignore" block
#   - git index (untracks framework files when switching to shared/public)
#
# Does NOT rewrite history. If framework files are already on an upstream
# branch, the script stops and asks the user to perform a history rewrite or
# create a fresh shared/public branch.
#
# Usage:
#   scripts/switch-repo-access.sh <public|private-shared|private-solo> [--commit]
#

set -euo pipefail

TARGET_MODE=""
COMMIT_CHANGES=false

for arg in "$@"; do
    case "$arg" in
        public|private-shared|private-solo) TARGET_MODE="$arg" ;;
        --commit) COMMIT_CHANGES=true ;;
    esac
done

if [ -z "$TARGET_MODE" ]; then
    echo "Usage: scripts/switch-repo-access.sh <public|private-shared|private-solo> [--commit]"
    exit 1
fi

PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
MANIFEST="$PROJECT_DIR/manifest.md"
GITIGNORE="$PROJECT_DIR/.gitignore"
HELPER="$PROJECT_DIR/scripts/framework-state-mode.sh"

if [ ! -f "$MANIFEST" ]; then
    echo "switch-repo-access: manifest.md not found at $MANIFEST"
    echo "Run forge install.sh first to bootstrap the project."
    exit 1
fi

if [ ! -f "$GITIGNORE" ]; then
    echo "switch-repo-access: .gitignore not found"
    exit 1
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "switch-repo-access: tracked/staged changes must be clean before switching modes"
        echo "Commit or stash them first."
        exit 1
    fi
fi

# 1. manifest.md — replace repo_access line, append if missing
awk -F= -v mode="$TARGET_MODE" '
    BEGIN { done=0 }
    /^repo_access=/ { print "repo_access=" mode; done=1; next }
    { print }
    END { if (!done) print "repo_access=" mode }
' "$MANIFEST" > "$MANIFEST.tmp"
mv "$MANIFEST.tmp" "$MANIFEST"

# 2. .gitignore — toggle the framework-public-ignore block.
#    Inside the block, only lines that look like a gitignore path are toggled.
#    A path = starts with optional `# ` followed by `.claude/`, `CLAUDE.md`,
#    `memory/`, `tasks/`. Free-form human comments stay untouched.
awk -v enable="$TARGET_MODE" '
    BEGIN {
        inside=0
        uncomment=(enable=="public" || enable=="private-shared")
        path_re="^(\\.claude/|CLAUDE\\.md|memory/|tasks/)"
    }
    /^# >>> framework-public-ignore$/ { inside=1; print; next }
    /^# <<< framework-public-ignore$/ { inside=0; print; next }
    {
        if (inside) {
            line=$0
            if (substr(line, 1, 2) == "# ") {
                rest = substr(line, 3)
                if (rest ~ path_re) {
                    if (uncomment) { line = rest }
                }
            } else if (line ~ path_re) {
                if (!uncomment) { line = "# " line }
            }
            print line
            next
        }
        print
    }
' "$GITIGNORE" > "$GITIGNORE.tmp"
mv "$GITIGNORE.tmp" "$GITIGNORE"

# 3. git index manipulation (only inside a real repo)
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if [ "$TARGET_MODE" = "public" ] || [ "$TARGET_MODE" = "private-shared" ]; then
        # Local-only paths in shared/public mode: .claude/, CLAUDE.md, memory/, tasks/
        # manifest.md stays tracked — it's the source of truth for repo_access
        # so a fresh checkout knows which mode the repo is in.
        if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
            if git log --oneline '@{u}' -- .claude CLAUDE.md memory tasks 2>/dev/null | grep -q .; then
                echo "switch-repo-access: upstream history already contains framework files."
                echo "Stop. Use a history rewrite or create a fresh shared/public branch."
                exit 2
            fi
        fi
        git rm -r --cached --ignore-unmatch .claude CLAUDE.md memory tasks >/dev/null 2>&1 || true
    fi

    if [ "$TARGET_MODE" = "public" ] || [ "$TARGET_MODE" = "private-shared" ]; then
        git add -- "$GITIGNORE" "$MANIFEST" 2>/dev/null || true
    else
        git add -- "$MANIFEST" "$GITIGNORE"
    fi

    if [ "$COMMIT_CHANGES" = true ] && ! git diff --cached --quiet; then
        git commit -m "chore(repo-access): switch to $TARGET_MODE mode"
    fi
fi

echo "switch-repo-access: repo_access set to $TARGET_MODE"
if [ -x "$HELPER" ]; then
    echo "switch-repo-access: framework-state mode now = $("$HELPER" should-commit-framework-state 2>/dev/null || echo unknown)"
fi

if [ "$TARGET_MODE" = "public" ] || [ "$TARGET_MODE" = "private-shared" ]; then
    echo "switch-repo-access: framework files were untracked from the index when possible."
    echo "switch-repo-access: use a clean branch or rewrite history if those files were already pushed."
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && ! git diff --cached --quiet; then
    echo "switch-repo-access: staged transition detected."
    echo "switch-repo-access: commit it now or rerun with --commit for an explicit mode-switch commit."
fi
