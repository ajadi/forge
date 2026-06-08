#!/bin/bash
# Forge — global install: copy framework into ~/.claude/ so it's available
# in any directory without a per-project install.
#
# Usage:
#   bash install-global.sh            # install (skip files that already exist)
#   bash install-global.sh --update   # refresh: overwrite Forge's OWN files with
#                                      #   the current version; your customs are kept
#   bash install-global.sh --rollback # restore previous ~/.claude/
#
# What it does:
#   - Backs up ~/.claude/ to ~/.claude/.backup-TIMESTAMP/.
#   - Copies core/agents, core/commands, core/skills, core/rules into
#     ~/.claude/{agents,commands,skills,rules}/. Default is additive (won't touch
#     files that already exist). With --update, files that ALSO ship in Forge core
#     are overwritten with the current version; files unique to you are never
#     visited (they're not in the source), so customs survive either way.
#   - Copies the f-setup-project skill so /f-setup-project becomes available
#     in any project that opens Claude Code with this global layer loaded.
#
# NOT installed globally: hooks/ and settings.json. The enforcement + token
# hooks (role-write-guard, coworker-read-gate, contract-reminder, the guards and
# the PreCompact snapshot) and their wiring live in settings.json and only take
# effect after a PER-PROJECT install (`install.sh` / `/f-setup-project`). The
# global layer is just the agent/command/skill/rule bootstrap.
#
# After install, in any new directory:
#   mkdir my-new-project && cd my-new-project
#   # In Claude Code:  /f-setup-project   (or just say "set up the framework")

set -uo pipefail

FORGE_DIR="$(cd "$(dirname "$0")" && pwd)"
GLOBAL_DIR="$HOME/.claude"
BACKUP_TAG=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$GLOBAL_DIR/.backup-$BACKUP_TAG"

DO_ROLLBACK=false
DO_UPDATE=false
for arg in "$@"; do
  case "$arg" in
    --rollback) DO_ROLLBACK=true ;;
    --update)   DO_UPDATE=true ;;
  esac
done

if $DO_ROLLBACK; then
  echo "=== Forge global rollback ==="
  if [ ! -d "$GLOBAL_DIR" ]; then
    echo "ERROR: $GLOBAL_DIR not found"; exit 1
  fi
  last_backup=$(find "$GLOBAL_DIR" -maxdepth 1 -type d -name '.backup-*' 2>/dev/null | sort | tail -1)
  if [ -z "$last_backup" ]; then
    echo "ERROR: no backup at $GLOBAL_DIR/.backup-*"; exit 1
  fi
  echo "Restoring from: $last_backup"
  for sub in agents commands skills rules; do
    if [ -d "$last_backup/$sub" ]; then
      rm -rf "$GLOBAL_DIR/$sub"
      cp -r "$last_backup/$sub" "$GLOBAL_DIR/$sub"
      echo "  restored: $sub/"
    fi
  done
  echo "Rollback done. Backup preserved at $last_backup"
  exit 0
fi

echo "=== Forge global install ==="
echo "Source:      $FORGE_DIR"
echo "Destination: $GLOBAL_DIR"
$DO_UPDATE && echo "Mode:        --update (overwrite Forge's own files; customs kept)"
echo ""

mkdir -p "$GLOBAL_DIR"/{agents,commands,skills,rules}

# Backup what's there
mkdir -p "$BACKUP_DIR"
n=0
for sub in agents commands skills rules; do
  if [ -d "$GLOBAL_DIR/$sub" ] && [ "$(ls -A "$GLOBAL_DIR/$sub" 2>/dev/null)" ]; then
    cp -r "$GLOBAL_DIR/$sub" "$BACKUP_DIR/"
    n=$((n+1))
  fi
done
echo "Backed up $n existing dir(s) to $BACKUP_DIR"

# Copy by file. Default: skip existing (protect user customs). With --update:
# overwrite — these are Forge's own files; files unique to you aren't in $src so
# this loop never visits them, and they survive regardless.
GLOBAL_COPY_FAILED=0
copy_additive() {
  local src="$1" dst="$2"
  [ -d "$src" ] || return 0
  for f in "$src"/*; do
    [ -e "$f" ] || continue
    base=$(basename "$f")
    if [ -e "$dst/$base" ] && ! $DO_UPDATE; then
      echo "  skipped (exists): $dst/$base"
    elif [ -e "$dst/$base" ]; then
      if cp -r "$f" "$dst/"; then
        echo "  updated: $dst/$base"
      else
        echo "  ERROR: failed to copy $f -> $dst/"
        GLOBAL_COPY_FAILED=1
      fi
    else
      if cp -r "$f" "$dst/"; then
        echo "  copied: $dst/$base"
      else
        echo "  ERROR: failed to copy $f -> $dst/"
        GLOBAL_COPY_FAILED=1
      fi
    fi
  done
}

echo ""
echo "[agents]"
copy_additive "$FORGE_DIR/core/agents"   "$GLOBAL_DIR/agents"
echo ""
echo "[commands]"
copy_additive "$FORGE_DIR/core/commands" "$GLOBAL_DIR/commands"
echo ""
echo "[rules]"
copy_additive "$FORGE_DIR/core/rules"    "$GLOBAL_DIR/rules"
echo ""
echo "[skills]"
copy_additive "$FORGE_DIR/core/skills"   "$GLOBAL_DIR/skills"

# Stash a pointer to forge checkout so /f-setup-project can find it
echo "$FORGE_DIR" > "$GLOBAL_DIR/.forge-checkout"

echo ""
if [ "$GLOBAL_COPY_FAILED" -eq 1 ]; then
  echo "Global install FAILED — one or more files could not be copied (see errors above)."
  exit 1
fi
echo "Global install complete."
echo "Forge checkout pointer: $GLOBAL_DIR/.forge-checkout"
echo ""
echo "Next steps:"
echo "  1. In any new project directory, open Claude Code."
echo "  2. Run /f-setup-project (or say 'set up forge') — the skill will run"
echo "     install.sh from $FORGE_DIR for the current directory."
echo ""
echo "NOTE: hooks + settings.json are NOT installed globally. Enforcement hooks"
echo "      (role-write-guard, coworker-read-gate, contract-reminder, etc.) only"
echo "      activate after a per-project install.sh / /f-setup-project."
echo ""
echo "Refresh after a Forge upgrade: bash install-global.sh --update"
echo "Rollback: bash install-global.sh --rollback"
