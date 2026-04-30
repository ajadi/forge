---
name: setup-project
description: Bootstrap Forge into the current project directory. Use when the user opens Claude Code in a fresh folder and says "set up forge" / "поставь фреймворк" / "setup project" / "/setup-project". Detects forge checkout via ~/.claude/.forge-checkout pointer (written by install-global.sh) and runs install.sh against $PWD.
---

# /setup-project

## When to use

User just opened Claude Code in a directory that has no `.claude/` yet, or
explicitly asks to install Forge. Triggers:

- `/setup-project`
- "set up forge" / "поставь фреймворк" / "новый проект"
- "install the framework here"

## Pre-flight checks

1. Resolve forge checkout location:
   - Read `~/.claude/.forge-checkout` first (created by `install-global.sh`).
   - If missing or path is invalid, ask the user to provide it once.

2. Verify required tools:
   - `bash` — required.
   - `python3` (or `python` 3.x) — required for additive `CLAUDE.md` merge.
   - `git` — recommended (not strictly required).

3. Check if Forge is already installed in $PWD:
   - If `.claude/agents/pm.md` exists → ask whether to upgrade or skip.

## Steps

```bash
FORGE_DIR=$(cat ~/.claude/.forge-checkout 2>/dev/null)
[ -z "$FORGE_DIR" ] && { echo "no checkout pointer"; exit 1; }

# Install with sensible defaults: solo preset, project name = $PWD basename
bash "$FORGE_DIR/install.sh" "$PWD" --preset solo --name "$(basename "$PWD")"
```

If user wants extensions, ask once which preset:

| Preset | What |
|---|---|
| solo | Core 13 agents only |
| small-team | Core + ext-security |
| full | All 37 agents |

Then re-run with `--preset <choice>`.

## Hard-conflict path

If `install.sh` exits with code 2:

1. Read `.claude/CLAUDE.md.merge-proposal.md`.
2. Show the user the conflict summary (sections affected, similarity scores).
3. Offer two options:
   - Resolve manually in `CLAUDE.md`, then run
     `bash "$FORGE_DIR/install.sh" --apply-proposal`.
   - Roll back the install entirely:
     `bash "$FORGE_DIR/install.sh" --rollback`.

Do not auto-pick — the user owns the resolution choice.

## After install

1. Show `manifest.md` content. Confirm `repo_access` (default `private-solo`).
2. If repo is shared/public, run
   `scripts/switch-repo-access.sh <mode> --commit` BEFORE the first commit
   that contains framework files.
3. Suggest `/f-start` for guided onboarding.

## Stop rules

- Do NOT modify the user's existing `CLAUDE.md` directly. Always go through
  `install.sh` so backup/merge/rollback contracts hold.
- Do NOT pick a non-default `repo_access` without asking — the wrong choice
  has irreversible consequences (framework state in shared history).
- If `~/.claude/.forge-checkout` is missing, ask the user once for the path
  to their forge checkout. Do not invent a default.
