#!/bin/bash
# Forge v0.9 — modular multi-agent framework installer
# Usage: bash install.sh [target_dir] [--ext ext1,ext2,...] [--all] [--preset solo|small-team|full] [--list]

set -euo pipefail

FORGE_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-.}"
EXTENSIONS=""
INSTALL_ALL=false
PRESET=""

shift 2>/dev/null || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ext)    EXTENSIONS="$2"; shift 2 ;;
    --all)    INSTALL_ALL=true; shift ;;
    --preset) PRESET="$2"; shift 2 ;;
    --list)   echo "Available extensions:"
              for d in "$FORGE_DIR"/extensions/ext-*/; do
                name=$(basename "$d")
                echo "  $name"
              done
              echo ""
              echo "Available presets:"
              for p in "$FORGE_DIR"/presets/*.txt; do
                name=$(basename "$p" .txt)
                desc=$(head -2 "$p" | tail -1 | sed 's/^# //')
                echo "  $name — $desc"
              done
              exit 0 ;;
    *)        shift ;;
  esac
done

# Resolve preset to extensions
case "$PRESET" in
  solo)       EXTENSIONS="" ;;  # core only
  small-team) EXTENSIONS="ext-security" ;;
  full)       INSTALL_ALL=true ;;
  "")         ;;  # no preset
  *)          echo "ERROR: Unknown preset '$PRESET'. Use --list to see available presets."; exit 1 ;;
esac

echo "=== Forge Installer ==="
echo "Source:  $FORGE_DIR"
echo "Target:  $TARGET"

# Ensure target .claude structure exists
mkdir -p "$TARGET/.claude"/{agents,commands,hooks,skills,decisions,templates}
mkdir -p "$TARGET"/{memory,tasks/archive}

# --- CORE ---
echo ""
echo "[core] Installing core agents, commands, hooks, configs..."

cp "$FORGE_DIR"/core/agents/*.md "$TARGET/.claude/agents/"
cp "$FORGE_DIR"/core/commands/*.md "$TARGET/.claude/commands/"
cp "$FORGE_DIR"/core/hooks/*.sh "$TARGET/.claude/hooks/"
cp "$FORGE_DIR"/core/pm-ref.md "$TARGET/.claude/"
cp "$FORGE_DIR"/core/statusline.sh "$TARGET/.claude/"
cp "$FORGE_DIR"/core/settings.json "$TARGET/.claude/"
cp "$FORGE_DIR"/core/templates/*.md "$TARGET/.claude/templates/" 2>/dev/null || true
cp "$FORGE_DIR"/core/AGENTS.md "$TARGET/.claude/AGENTS.md"

# Skills (preserve directory structure)
if [ -d "$FORGE_DIR/core/skills" ]; then
  cp -r "$FORGE_DIR"/core/skills/* "$TARGET/.claude/skills/" 2>/dev/null || true
fi

# CLAUDE.md — only if not exists (never overwrite project instructions)
if [ ! -f "$TARGET/CLAUDE.md" ]; then
  cp "$FORGE_DIR/CLAUDE.md" "$TARGET/CLAUDE.md"
  echo "  Created CLAUDE.md (project instructions)"
else
  echo "  CLAUDE.md already exists — skipped"
fi

echo "  Core: $(ls "$TARGET/.claude/agents/" | wc -l) agents, $(ls "$TARGET/.claude/commands/" | wc -l) commands"

# --- EXTENSIONS ---
install_ext() {
  local ext_name="$1"
  local ext_dir="$FORGE_DIR/extensions/$ext_name"

  if [ ! -d "$ext_dir" ]; then
    echo "  WARNING: Extension '$ext_name' not found, skipping"
    return
  fi

  echo "[ext] Installing $ext_name..."

  [ -d "$ext_dir/agents" ] && cp "$ext_dir"/agents/*.md "$TARGET/.claude/agents/" 2>/dev/null
  [ -d "$ext_dir/commands" ] && cp "$ext_dir"/commands/*.md "$TARGET/.claude/commands/" 2>/dev/null
  [ -d "$ext_dir/hooks" ] && cp "$ext_dir"/hooks/*.sh "$TARGET/.claude/hooks/" 2>/dev/null

  local agent_count=$(ls "$ext_dir/agents/" 2>/dev/null | wc -l)
  local cmd_count=$(ls "$ext_dir/commands/" 2>/dev/null | wc -l)
  echo "  $ext_name: $agent_count agents, $cmd_count commands"
}

if $INSTALL_ALL; then
  echo ""
  echo "Installing ALL extensions..."
  for ext_dir in "$FORGE_DIR"/extensions/ext-*/; do
    install_ext "$(basename "$ext_dir")"
  done
elif [ -n "$EXTENSIONS" ]; then
  echo ""
  IFS=',' read -ra EXT_LIST <<< "$EXTENSIONS"
  for ext in "${EXT_LIST[@]}"; do
    ext=$(echo "$ext" | xargs) # trim whitespace
    # Auto-prefix ext- if not present
    [[ "$ext" != ext-* ]] && ext="ext-$ext"
    install_ext "$ext"
  done
fi

# --- SUMMARY ---
echo ""
echo "=== Installation complete ==="
echo "  Agents:   $(ls "$TARGET/.claude/agents/" | wc -l)"
echo "  Commands: $(ls "$TARGET/.claude/commands/" | wc -l)"
echo "  Hooks:    $(ls "$TARGET/.claude/hooks/" | wc -l)"
echo ""
echo "Next steps:"
echo "  1. Review .claude/settings.json — adjust permissions for your project"
echo "  2. Run /f-start in Claude Code for guided onboarding"
echo "  3. Add domain-specific agents to .claude/agents/ as needed"
