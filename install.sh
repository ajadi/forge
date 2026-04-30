#!/bin/bash
# Forge v2.1 — modular multi-agent framework installer
#
# Usage:
#   bash install.sh [target_dir] [--ext ext1,ext2,...] [--all]
#                   [--preset solo|small-team|full]
#                   [--name "Project name"]
#                   [--rollback] [--apply-proposal]
#                   [--list]
#
# What it does:
#   - Creates .claude/ structure with agents/commands/hooks/rules/skills.
#   - Installs scripts/ (switch-repo-access, framework-state-mode, lib/).
#   - Generates manifest.md (project metadata + repo_access).
#   - Backs up existing CLAUDE.md / settings.json / manifest.md / .gitignore
#     to .claude/backup-TIMESTAMP/ before writing.
#   - Merges existing CLAUDE.md additively via merge_claude_md.py.
#     On hard conflict: writes .claude/CLAUDE.md.merge-proposal.md and stops.
#
# Recovery:
#   bash install.sh --rollback         # restore previous CLAUDE.md / settings / manifest / .gitignore
#   bash install.sh --apply-proposal   # apply .claude/CLAUDE.md.merge-proposal.md

set -uo pipefail
# (no -e: we handle errors per step so partial install can be rolled back)

# Ensure Python writes UTF-8 — Windows defaults to cp1252, which breaks merger
# output when CLAUDE.md contains arrows/emoji.
export PYTHONIOENCODING=utf-8

FORGE_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="."
EXTENSIONS=""
INSTALL_ALL=false
PRESET=""
PROJECT_NAME=""
DO_ROLLBACK=false
DO_APPLY_PROPOSAL=false
DO_LIST=false

# --- arg parsing ---
ARGS=("$@")
i=0
while [ $i -lt ${#ARGS[@]} ]; do
  case "${ARGS[$i]}" in
    --ext)              EXTENSIONS="${ARGS[$((i+1))]}"; i=$((i+2)) ;;
    --all)              INSTALL_ALL=true; i=$((i+1)) ;;
    --preset)           PRESET="${ARGS[$((i+1))]}"; i=$((i+2)) ;;
    --name)             PROJECT_NAME="${ARGS[$((i+1))]}"; i=$((i+2)) ;;
    --rollback)         DO_ROLLBACK=true; i=$((i+1)) ;;
    --apply-proposal)   DO_APPLY_PROPOSAL=true; i=$((i+1)) ;;
    --list)             DO_LIST=true; i=$((i+1)) ;;
    --*)                echo "WARN: unknown flag ${ARGS[$i]}, ignoring"; i=$((i+1)) ;;
    *)                  # first non-flag is target dir if not yet set
                        if [ "$TARGET" = "." ]; then TARGET="${ARGS[$i]}"; fi
                        i=$((i+1)) ;;
  esac
done

# --- --list mode ---
if $DO_LIST; then
  echo "Available extensions:"
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
  exit 0
fi

# Resolve TARGET to absolute path for safety
TARGET="$(cd "$TARGET" 2>/dev/null && pwd || echo "$TARGET")"
BACKUP_TAG=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$TARGET/.claude/backup-$BACKUP_TAG"

# Project name default = target dir basename
[ -z "$PROJECT_NAME" ] && PROJECT_NAME="$(basename "$TARGET")"

# --- helper: detect Python ---
detect_python() {
  if command -v python >/dev/null 2>&1 && python --version 2>&1 | grep -q "Python 3"; then
    echo "python"
  elif command -v python3 >/dev/null 2>&1; then
    echo "python3"
  else
    echo ""
  fi
}
PYTHON="$(detect_python)"

# --- helper: backup files that may be overwritten ---
backup_existing() {
  mkdir -p "$BACKUP_DIR"
  local n=0
  for rel in "CLAUDE.md" ".claude/settings.json" "manifest.md" ".gitignore"; do
    if [ -f "$TARGET/$rel" ]; then
      mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
      cp "$TARGET/$rel" "$BACKUP_DIR/$rel"
      n=$((n+1))
    fi
  done
  {
    echo "Backup created: $(date)"
    echo "Forge version: 2.1.0"
    echo "Source: $FORGE_DIR"
    echo "Target: $TARGET"
    echo "Files backed up: $n"
  } > "$BACKUP_DIR/manifest.txt"
  if [ "$n" -gt 0 ]; then
    echo "  Backed up $n existing file(s) to $BACKUP_DIR"
  else
    # Empty backup dir — keep it for traceability but mark
    echo "(fresh install — no files to back up)" >> "$BACKUP_DIR/manifest.txt"
  fi
}

# --- helper: rollback ---
do_rollback() {
  echo "=== Forge Rollback ==="
  if [ ! -d "$TARGET/.claude" ]; then
    echo "ERROR: no .claude/ in $TARGET — nothing to rollback"
    exit 1
  fi
  local last_backup
  last_backup=$(find "$TARGET/.claude" -maxdepth 1 -type d -name 'backup-*' 2>/dev/null | sort | tail -1)
  if [ -z "$last_backup" ]; then
    echo "ERROR: no backup found in $TARGET/.claude/backup-*"
    exit 1
  fi
  echo "Restoring from: $last_backup"
  local restored=0
  for rel in "CLAUDE.md" ".claude/settings.json" "manifest.md" ".gitignore"; do
    if [ -f "$last_backup/$rel" ]; then
      cp "$last_backup/$rel" "$TARGET/$rel"
      echo "  restored: $rel"
      restored=$((restored+1))
    fi
  done
  echo "Rollback complete — restored $restored file(s)"
  echo "Backup preserved: $last_backup"
  exit 0
}

# --- helper: apply CLAUDE.md merge proposal ---
do_apply_proposal() {
  echo "=== Forge: apply CLAUDE.md merge proposal ==="
  local proposal="$TARGET/.claude/CLAUDE.md.merge-proposal.md"
  if [ ! -f "$proposal" ]; then
    echo "ERROR: no proposal at $proposal"
    exit 1
  fi
  if [ -z "$PYTHON" ]; then
    echo "ERROR: Python 3 required to apply proposal — install Python and retry"
    exit 1
  fi
  # Apply = re-run merge once user has manually resolved hard conflicts in their CLAUDE.md.
  # The merger will succeed if conflicts are gone; otherwise it produces a fresh proposal.
  local merger="$FORGE_DIR/core/scripts/lib/merge_claude_md.py"
  local template="$FORGE_DIR/CLAUDE.md"
  if "$PYTHON" "$merger" merge "$TARGET/CLAUDE.md" "$template" > "$TARGET/CLAUDE.md.merged.tmp" 2>/dev/null; then
    backup_existing
    mv "$TARGET/CLAUDE.md.merged.tmp" "$TARGET/CLAUDE.md"
    rm -f "$proposal"
    echo "  CLAUDE.md merged (backup at $BACKUP_DIR)"
    exit 0
  else
    rm -f "$TARGET/CLAUDE.md.merged.tmp"
    echo "ERROR: hard conflicts still present — edit CLAUDE.md to resolve, then retry"
    "$PYTHON" "$merger" check "$TARGET/CLAUDE.md" "$template" 2>&1 || true
    exit 2
  fi
}

if $DO_ROLLBACK; then do_rollback; fi
if $DO_APPLY_PROPOSAL; then do_apply_proposal; fi

# --- preset resolution ---
case "$PRESET" in
  solo)       EXTENSIONS="" ;;
  small-team) EXTENSIONS="ext-security" ;;
  full)       INSTALL_ALL=true ;;
  "")         ;;
  *)          echo "ERROR: unknown preset '$PRESET' (use --list)"; exit 1 ;;
esac

echo "=== Forge Installer v2.1 ==="
echo "Source:  $FORGE_DIR"
echo "Target:  $TARGET"
echo "Project: $PROJECT_NAME"
echo ""

# --- backup BEFORE any change ---
backup_existing

# --- MEMPALACE ---
echo ""
echo "[mempalace] Checking memory backend..."
if [ -n "$PYTHON" ]; then
  echo "  Python: $($PYTHON --version 2>&1)"
  if $PYTHON -c "import mempalace" 2>/dev/null; then
    echo "  MemPalace already installed"
  else
    echo "  Installing MemPalace..."
    $PYTHON -m pip install mempalace 2>/dev/null || {
      echo "  WARN: pip install mempalace failed — install manually"
    }
  fi
  if command -v claude >/dev/null 2>&1; then
    if claude mcp list 2>/dev/null | grep -q mempalace; then
      echo "  MCP server already registered"
    else
      claude mcp add mempalace -- $PYTHON -m mempalace.mcp_server 2>/dev/null \
        && echo "  MCP server registered" \
        || echo "  WARN: claude mcp add failed — register manually"
    fi
  else
    echo "  WARN: claude CLI not found — register MCP server manually after install"
  fi
else
  if command -v winget >/dev/null 2>&1; then
    echo "  Python not found — installing via winget..."
    winget install Python.Python.3.12 --accept-source-agreements --accept-package-agreements 2>/dev/null \
      && echo "  Python installed — restart terminal and re-run installer" \
      || echo "  WARN: winget install Python failed"
  else
    echo "  WARN: Python 3.9+ not found — install from https://python.org"
  fi
fi

# --- directory skeleton ---
mkdir -p "$TARGET/.claude"/{agents,commands,hooks,skills,decisions,templates,rules,logs/sessions,logs/migrations,logs/errors}
mkdir -p "$TARGET"/{memory,tasks/archive,scripts/lib}

# --- CORE ---
echo ""
echo "[core] Installing agents, commands, hooks, rules, scripts..."

cp "$FORGE_DIR"/core/agents/*.md      "$TARGET/.claude/agents/"
cp "$FORGE_DIR"/core/commands/*.md    "$TARGET/.claude/commands/"
cp "$FORGE_DIR"/core/hooks/*.sh       "$TARGET/.claude/hooks/"
cp "$FORGE_DIR"/core/rules/*.md       "$TARGET/.claude/rules/"
cp "$FORGE_DIR"/core/pm-ref.md        "$TARGET/.claude/"
cp "$FORGE_DIR"/core/statusline.sh    "$TARGET/.claude/"
cp "$FORGE_DIR"/core/AGENTS.md        "$TARGET/.claude/AGENTS.md"
cp "$FORGE_DIR"/core/templates/*.md   "$TARGET/.claude/templates/" 2>/dev/null || true

# scripts/ — repo_access machinery + merger lib
cp "$FORGE_DIR"/core/scripts/framework-state-mode.sh "$TARGET/scripts/"
cp "$FORGE_DIR"/core/scripts/switch-repo-access.sh   "$TARGET/scripts/"
cp "$FORGE_DIR"/core/scripts/lib/merge_claude_md.py  "$TARGET/scripts/lib/"
chmod +x "$TARGET/scripts"/*.sh "$TARGET/.claude/hooks"/*.sh 2>/dev/null || true

# settings.json — copy if missing, otherwise merge missing hooks
install_settings() {
  if [ ! -f "$TARGET/.claude/settings.json" ]; then
    cp "$FORGE_DIR/core/settings.json" "$TARGET/.claude/settings.json"
    echo "  Created: .claude/settings.json"
  elif [ -n "$PYTHON" ]; then
    "$PYTHON" - "$TARGET/.claude/settings.json" "$FORGE_DIR/core/settings.json" <<'PY' 2>/dev/null || echo "  WARN: settings merge failed — manual review needed"
import json, sys
existing_path, template_path = sys.argv[1], sys.argv[2]
with open(existing_path) as f: existing = json.load(f)
with open(template_path) as f: template = json.load(f)
t_hooks = template.get('hooks', {}); e_hooks = existing.get('hooks', {})
added = 0
for k, v in t_hooks.items():
    if k not in e_hooks:
        e_hooks[k] = v; added += 1
existing['hooks'] = e_hooks
# Make sure mempalace MCP server entry exists
if 'mcpServers' in template:
    existing.setdefault('mcpServers', {})
    for k, v in template['mcpServers'].items():
        existing['mcpServers'].setdefault(k, v)
with open(existing_path, 'w') as f:
    json.dump(existing, f, indent=2); f.write('\n')
print(f"  settings.json: merged ({added} new hook entries)")
PY
  else
    echo "  WARN: settings.json exists but Python unavailable — skipping merge"
  fi
}
install_settings

# Patch MCP server python command to match detected interpreter
if [ -n "$PYTHON" ] && [ "$PYTHON" != "python" ] && [ -f "$TARGET/.claude/settings.json" ]; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|\"command\": \"python\"|\"command\": \"$PYTHON\"|" "$TARGET/.claude/settings.json" 2>/dev/null || true
  else
    sed -i "s|\"command\": \"python\"|\"command\": \"$PYTHON\"|" "$TARGET/.claude/settings.json" 2>/dev/null || true
  fi
fi

# Skills (preserve directory structure)
if [ -d "$FORGE_DIR/core/skills" ]; then
  cp -r "$FORGE_DIR"/core/skills/* "$TARGET/.claude/skills/" 2>/dev/null || true
fi

# --- manifest.md ---
if [ ! -f "$TARGET/manifest.md" ]; then
  sed "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" "$FORGE_DIR/core/templates/manifest.md.tmpl" > "$TARGET/manifest.md"
  echo "  Created: manifest.md (repo_access=private-solo)"
else
  echo "  manifest.md already exists — kept"
fi

# --- .gitignore ---
install_gitignore() {
  if [ ! -f "$TARGET/.gitignore" ]; then
    cp "$FORGE_DIR/core/templates/gitignore.tmpl" "$TARGET/.gitignore"
    echo "  Created: .gitignore"
    return
  fi
  # Append framework-public-ignore block if missing
  if ! grep -q "^# >>> framework-public-ignore" "$TARGET/.gitignore"; then
    echo "" >> "$TARGET/.gitignore"
    awk '/^# >>> framework-public-ignore/,/^# <<< framework-public-ignore/' \
      "$FORGE_DIR/core/templates/gitignore.tmpl" >> "$TARGET/.gitignore"
    echo "  Updated: .gitignore (added framework-public-ignore block)"
  fi
  # Append individual entries from template that aren't already present
  local added=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    [[ "$line" == \#* ]] && continue
    if ! grep -qF -- "$line" "$TARGET/.gitignore" 2>/dev/null; then
      echo "$line" >> "$TARGET/.gitignore"
      added=$((added+1))
    fi
  done < "$FORGE_DIR/core/templates/gitignore.tmpl"
  if [ "$added" -gt 0 ]; then
    echo "  Updated: .gitignore (+$added entries)"
  fi
}
install_gitignore

# --- CLAUDE.md (additive merge) ---
install_claude_md() {
  local existing="$TARGET/CLAUDE.md"
  local template="$FORGE_DIR/CLAUDE.md"
  local merger="$FORGE_DIR/core/scripts/lib/merge_claude_md.py"

  if [ ! -f "$existing" ]; then
    cp "$template" "$existing"
    echo "  Created: CLAUDE.md (project doctrine)"
    return 0
  fi

  if [ -z "$PYTHON" ]; then
    echo "  WARN: CLAUDE.md exists and Python unavailable — left untouched"
    echo "        Template at $template; merge manually."
    return 0
  fi

  if ! [ -f "$merger" ]; then
    echo "  WARN: merger script missing — CLAUDE.md left untouched"
    return 0
  fi

  if "$PYTHON" "$merger" check "$existing" "$template" >/dev/null 2>&1; then
    if "$PYTHON" "$merger" merge "$existing" "$template" > "$existing.merged.tmp" 2>/dev/null; then
      mv "$existing.merged.tmp" "$existing"
      echo "  CLAUDE.md: merged additively"
    else
      rm -f "$existing.merged.tmp"
      echo "  WARN: merger failed — CLAUDE.md left untouched"
    fi
  else
    "$PYTHON" "$merger" propose "$existing" "$template" \
      > "$TARGET/.claude/CLAUDE.md.merge-proposal.md" 2>/dev/null || true
    echo ""
    echo "  HARD CONFLICT in CLAUDE.md — install paused before overwrite."
    echo "  Proposal written to: .claude/CLAUDE.md.merge-proposal.md"
    echo "  Resolve options:"
    echo "    bash install.sh --apply-proposal   # re-run merge after manual fix"
    echo "    bash install.sh --rollback         # revert all install changes"
    echo "  CLAUDE.md was NOT modified."
    return 2
  fi
}
install_claude_md
CLAUDE_MD_RESULT=$?

agents_count=$(ls "$TARGET/.claude/agents/" 2>/dev/null | wc -l)
cmds_count=$(ls "$TARGET/.claude/commands/" 2>/dev/null | wc -l)
echo "  Core: $agents_count agents, $cmds_count commands"

# --- EXTENSIONS ---
install_ext() {
  local ext_name="$1"
  local ext_dir="$FORGE_DIR/extensions/$ext_name"
  if [ ! -d "$ext_dir" ]; then
    echo "  WARN: extension '$ext_name' not found, skipping"
    return
  fi
  echo "[ext] Installing $ext_name..."
  [ -d "$ext_dir/agents" ]   && cp "$ext_dir"/agents/*.md   "$TARGET/.claude/agents/"   2>/dev/null || true
  [ -d "$ext_dir/commands" ] && cp "$ext_dir"/commands/*.md "$TARGET/.claude/commands/" 2>/dev/null || true
  [ -d "$ext_dir/hooks" ]    && cp "$ext_dir"/hooks/*.sh    "$TARGET/.claude/hooks/"    2>/dev/null || true
  local ac cc
  ac=$(ls "$ext_dir/agents/"   2>/dev/null | wc -l)
  cc=$(ls "$ext_dir/commands/" 2>/dev/null | wc -l)
  echo "  $ext_name: $ac agents, $cc commands"
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
    ext=$(echo "$ext" | xargs)
    [[ "$ext" != ext-* ]] && ext="ext-$ext"
    install_ext "$ext"
  done
fi

# --- SUMMARY ---
echo ""
echo "=== Installation complete ==="
echo "  Agents:   $(ls "$TARGET/.claude/agents/" 2>/dev/null | wc -l)"
echo "  Commands: $(ls "$TARGET/.claude/commands/" 2>/dev/null | wc -l)"
echo "  Hooks:    $(ls "$TARGET/.claude/hooks/" 2>/dev/null | wc -l)"
echo "  Rules:    $(ls "$TARGET/.claude/rules/" 2>/dev/null | wc -l)"
echo ""
echo "Files:"
echo "  manifest.md         (repo_access mode)"
echo "  scripts/            (switch-repo-access, framework-state-mode)"
echo "  .claude/rules/      (modular doctrine)"
echo ""
if [ -d "$BACKUP_DIR" ]; then
  echo "Backup: $BACKUP_DIR"
  echo "Rollback: bash install.sh $TARGET --rollback"
  echo ""
fi
echo "Next steps:"
echo "  1. Review manifest.md — confirm repo_access (default: private-solo)"
echo "  2. If repo is shared/public, run scripts/switch-repo-access.sh BEFORE first commit"
echo "  3. Open project in Claude Code, run /f-start"

if [ "$CLAUDE_MD_RESULT" = "2" ]; then
  exit 2
fi
