# Forge

Modular multi-agent development framework for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). **Version 2.3.**

Forge turns Claude Code into a full dev team: PM orchestrates, agents implement, review, test, and deploy. Three things keep it from drifting or running up cost:

- **File-based memory** — project knowledge lives in plain `memory/*.md` files every agent greps before guessing. No external service, no daemon, nothing to install.
- **Mechanically enforced roles** — a `Write|Edit` guard hook stops PM and read-only agents from editing source code. The boundaries `AGENTS.md` declares are now actually enforced, not just documented.
- **Token economy** — large non-source reads (docs, logs, boilerplate) are delegated to a cheap model (xAI Grok via [`coworker`](docs/coworker-setup.md)), keeping the reasoning model's context for code.

## Quick Start

```bash
# Clone
git clone https://github.com/ajadi/forge.git

# Install into your project (choose a preset)
bash forge/install.sh /path/to/your/project --preset solo         # 13 agents (core)
bash forge/install.sh /path/to/your/project --preset small-team   # core + ext-security
bash forge/install.sh /path/to/your/project --preset full         # 37 agents

# Or pick specific extensions
bash forge/install.sh /path/to/your/project --ext security,frontend

# Then open your project in Claude Code and run:
# /f-start
```

### Global install (optional)

Install Forge once into `~/.claude/` so it's available in any project:

```bash
bash forge/install-global.sh
```

After that, in a fresh directory open Claude Code and run `/f-setup-project` —
the skill will run `install.sh` for the current folder, no manual download.

After pulling a new Forge version, refresh the global layer with
`bash forge/install-global.sh --update` — it overwrites Forge's own
agents/commands/rules/skills with the current version and leaves your custom
files untouched. (Plain `install-global.sh` skips anything that already exists.)

> Note: the global install ships only agents/commands/rules/skills. **Hooks and
> `settings.json` are not installed globally**, so the enforcement + token hooks
> (`role-write-guard`, `coworker-read-gate`, `contract-reminder`, the PreCompact
> snapshot) activate only after a per-project `install.sh` / `/f-setup-project`.

### Install flags

| Flag | What |
|------|------|
| `--preset solo\|small-team\|full` | Pick a bundle |
| `--ext name1,name2` | Add specific extensions |
| `--name "..."` | Project name written into `manifest.md` |
| `--rollback` | Restore the last backup (`.claude/backup-TIMESTAMP/`) |
| `--apply-proposal` | Re-run merge after manually resolving `CLAUDE.md` conflicts |
| `--list` | List available presets and extensions |

The installer creates a backup of `CLAUDE.md`, `settings.json`, `manifest.md`,
and `.gitignore` before any change. If your `CLAUDE.md` and the framework
template have a hard conflict, the install pauses and writes
`.claude/CLAUDE.md.merge-proposal.md` instead of overwriting your file.

### Repo access modes

After install, `manifest.md` holds `repo_access` (default `private-solo`).
For shared/public repos, switch BEFORE the first commit that contains
framework state:

```bash
scripts/switch-repo-access.sh public --commit
scripts/switch-repo-access.sh private-shared --commit
```

The script untracks `.claude/`, `CLAUDE.md`, `memory/`, `tasks/` from the git
index and toggles the `framework-public-ignore` block in `.gitignore`. See
`.claude/rules/repo-access.md` for the full model.

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- Git Bash (Windows) — hooks use `#!/bin/bash`
- Python 3.9+ *(optional)* — only used to merge an existing `CLAUDE.md` / `settings.json` on install; without it those files are copied, not merged

## What It Does

Forge installs a `.claude/` directory into your project with agents, commands, hooks, and configs. After installation, Claude Code automatically picks up the framework and operates as a multi-agent system.

**The PM agent** receives your task, assesses complexity (L1-L4), and routes it through the appropriate pipeline:

| Level | What | Pipeline | Agents |
|-------|------|----------|--------|
| L1 | One-line fix | Developer -> RealityChecker -> commit | 3 |
| L2 | Small enhancement | Developer -> CodeReviewer -> RealityChecker -> commit | 4 |
| L3 | Feature | Architect -> Developer -> CodeReviewer + SecurityAnalyst -> UnitTester -> RealityChecker -> commit | 6+ |
| L4 | Major feature | Full pipeline with design panel (Consilium) | All |

No more "FULL PIPELINE MANDATORY" for a typo fix. The pipeline scales to the task.

## Architecture

```
You (user)
 |
 v
Orchestrator (Claude Code) ── reads CLAUDE.md rules
 |
 v
PM agent (opus) ── reads pm-ref.md, AGENTS.md
 |
 +-- Developer (sonnet) ── implements, runs self-check
 +-- Code Reviewer (sonnet) ── diff-aware review
 +-- Security Analyst (sonnet) ── OWASP/STRIDE audit
 +-- Reality Checker (sonnet) ── final gate, default NEEDS_WORK
 +-- Architect (opus) ── designs L3-L4 solutions
 +-- ... (37 agents total)
 |
 v
memory/*.md ── flat-file project memory for all agents
 +-- stack.md · patterns.md · decisions.md · known-issues.md
 +-- agents grep before stating facts, append after tasks
 +-- superseded facts marked ~~strikethrough~~, never deleted
```

### Key Design Principles

- **PM never implements** — only orchestrates and delegates (enforced by the `role-write-guard` hook, not just convention)
- **Reference passing** — agents get file paths, not file contents
- **Handoff contracts** — standardized format between agents (status, files_changed, validation_points)
- **Stop rules** — every agent knows exactly when to halt; the Stop hook gates mid-pipeline exits
- **Autonomy ladder** (A1-A5) — agents earn more freedom with proven reliability
- **File-based memory** — agents grep `memory/*.md` before guessing facts, append findings after tasks
- **Token economy** — large non-source reads delegated to a cheap model so the reasoning model's context stays on code

## Memory System (flat files)

Forge keeps persistent project knowledge in plain Markdown under `memory/`. No external service, no
daemon, no embeddings — just files agents read and append.

| File | What it holds | Written by |
|------|---------------|------------|
| `memory/stack.md` | Tech stack, build/test/lint commands | onboarding, PM, architect |
| `memory/patterns.md` | Code patterns + `[recurring]` tags | developer, retro |
| `memory/decisions.md` | Architectural decisions | architect, retro, reflect |
| `memory/known-issues.md` | Issues, workarounds + `[recurring]` tags | retro, any agent |

### Memory Protocol

1. **Before facts**: `grep memory/*.md` for the relevant entry — never guess.
2. **After a task**: append genuinely new facts under a dated heading in the right file.
3. **When facts change**: mark the obsolete line `~~strikethrough~~` with a reason and add the corrected fact below — append-only, never silently overwrite.
4. **Cold start**: an empty `memory/` on a fresh project is not an error — it seeds itself as tasks close.

### How Agents Use Memory

| Agent | How it uses `memory/` |
|-------|------------------------|
| **developer** | Greps `patterns.md` for prior conventions before implementing |
| **dream** | Consolidates `memory/*.md`: finds contradictions, marks stale facts, cross-references the codebase |
| **retro** | Writes phase retrospective findings, tags recurring patterns |
| **reflect** | Records lasting proposals in `decisions.md` / `patterns.md` |
| **onboarding** | Populates `stack.md`, `patterns.md`, `decisions.md`, `known-issues.md` from the existing project |
| **pm** | Greps `memory/*.md` for project context on session start |

## Structure

```
forge/
  core/                     # Always installed
    AGENTS.md               # Team roster: roles, models, boundaries
    agents/                 # 13 core agents
    commands/               # 10 slash commands (/f-fix, /f-start, /f-autopilot, etc.)
    hooks/                  # Session lifecycle, git validation, metrics
    rules/                  # Modular doctrine: repo-access, commit-policy, production-safety
    scripts/                # switch-repo-access, framework-state-mode, lib/merge_claude_md.py
    skills/                 # next-task, status, f-setup-project
    templates/              # tz-template, adr-template, manifest.md.tmpl, gitignore.tmpl
    pm-ref.md               # Pipeline reference
    settings.json           # Base permissions, hooks

  extensions/               # Install per project need
    ext-security/           # security-analyst, dependency-auditor
    ext-frontend/           # smoke-tester, e2e-tester, ui-designer, ux-interviewer, a11y
    ext-devops/             # devops, env-manager, git-workflow, migration-validator
    ext-quality/            # performance-profiler, refactoring, test-reviewer, integration-tester
    ext-docs/               # documentation, changelog-agent
    ext-planning/           # estimator, consilium
    ext-reflection/         # reflect, dream, optimizer, onboarding, retro

  presets/                  # Quick-start configurations
```

## Hooks

Installed into `.claude/hooks/` and wired in `.claude/settings.json`. All hooks fail open / never wedge the session.

| Hook | Event | What it does |
|------|-------|-------------|
| `session-start.sh` · `detect-gaps.sh` | SessionStart | Load context; warn on missing framework files |
| `contract-reminder.sh` | UserPromptSubmit | Re-inject the operating contract + active task each turn |
| `validate-commit.sh` · `validate-push.sh` | PreToolUse(Bash) | Block `--no-verify`, force-push, staged `.env`, etc. |
| `coworker-read-gate.sh` | PreToolUse(Read) | Delegate large non-source reads to coworker/Grok; source exempt; fails open |
| `role-write-guard.sh` | PreToolUse(Write\|Edit) | Enforce AGENTS.md boundaries: PM/read-only roles can't edit source; developer can't edit framework defs; testers only touch tests |
| `check-blockers.sh` | PostToolUse(Task) | Detect open OQs after an agent runs |
| `grok-watch.sh` | PostToolUse(Bash) | Detect "out of credits" on coworker/Grok calls → flag 🟥 + record Grok activity for the statusline |
| `log-agent.sh` | SubagentStart | Audit log + write `.claude/.current-agent` marker — agent **and model** (used by the write-guard and the statusline) |
| `pre-compact.sh` | PreCompact | Dump full session state to context **and** a durable `handoffs/precompact-<ts>.md`; never blocks |
| `stop-check.sh` · `session-stop.sh` | Stop | Gate: block stopping mid-pipeline or with unrecorded source changes; log metrics |

**Tuning knobs (env vars):** `COWORKER_READ_GATE=off`, `COWORKER_DELEGATE_TOKENS`, `COWORKER_GREP_TOKENS`, `COWORKER_TOKEN_DIVISOR`, `ROLE_WRITE_GUARD=off`, `ROLE_GUARD_TTL`.

## Core Agents (always installed)

| Agent | Role | Model |
|-------|------|-------|
| pm | Orchestrator — routes tasks, manages pipeline | opus |
| developer | Implements code from task spec | sonnet |
| code-reviewer | Diff-aware code review (read-only) | sonnet |
| reality-checker | Final quality gate, default NEEDS_WORK | sonnet |
| architect | Solution design for L3-L4 tasks (read-only) | opus |
| business-analyst | Requirements interview, creates tz.md | sonnet |
| decomposer | Breaks features into parallelizable tasks | sonnet |
| handoff-validator | Validates task file before pipeline starts | haiku |
| unit-tester | Writes and runs unit tests | sonnet |
| database-architect | DB schema, migrations, query optimization | sonnet |
| rapid-prototyper | Technical spikes in isolated worktree | sonnet |
| context-summarizer | Compresses large task files | sonnet |
| status | Project state snapshot (read-only) | haiku |

## Extensions

| Extension | Agents | Best for |
|-----------|--------|----------|
| **ext-security** | security-analyst, dependency-auditor | Web apps, APIs, auth |
| **ext-frontend** | smoke-tester, e2e-tester, ui-designer, ux-interviewer, accessibility-auditor | Frontend, UI/UX |
| **ext-devops** | devops, env-manager, git-workflow, migration-validator | Deployed services, CI/CD |
| **ext-quality** | performance-profiler, refactoring, test-reviewer, integration-tester | Large codebases |
| **ext-docs** | documentation, changelog-agent | Open-source, team projects |
| **ext-planning** | estimator, consilium | L3-L4 tasks, team planning |
| **ext-reflection** | reflect, dream, optimizer, onboarding, retro | Long-running projects |

## Key Commands

| Command | What it does |
|---------|-------------|
| `/f-start` | Guided onboarding for new project |
| `/f-fix TASK-XXX` | Quick fix — run PM on a specific task |
| `/f-hotfix` | Emergency fix bypassing normal pipeline |
| `/f-ba` | Business analyst — collect requirements |
| `/f-decompose` | Break feature into tasks |
| `/status` | Show project progress (skill) |
| `/next-task` | What to work on next (skill) |
| `/f-dream` | Run memory consolidation (audits `memory/*.md`) |
| `/f-reflect` | Post-task reflection and learning |
| `/f-spike` | Technical spike to validate hypothesis |
| `/f-new-task` | Create a new task file |
| `/f-scope-check` | Check for scope creep vs tz.md |
| `/f-bug-report` | Structured bug report |
| `/f-autopilot` | Run the backlog unattended end-to-end; halts only on questions/regressions/deploys, then pushes you |

## Autonomy Ladder

Agents earn autonomy with proven reliability. New projects start at A2.

| Level | Name | What agent can do | Promotion criteria |
|-------|------|-------------------|--------------------|
| A1 | Observer | Read and explain only | Starting level for unknown domains |
| A2 | Narrow Executor | Single file, < 50 lines | Default for new projects |
| A3 | Workflow Executor | Multi-file, follows known patterns | 5 tasks, 0 NEEDS_WORK |
| A4 | Autonomous | Full pipeline, no dry-run | 10 tasks, < 10% NEEDS_WORK |
| A5 | Delegator | Coordinates sub-agents | A4 sustained for 20 tasks |

**Auto-demotion triggers:** 2 consecutive NEEDS_WORK, scope creep, unclear escalation.

## How It Handles Failures

- **Agent stuck twice** -> Ralph Loop: fresh context restart with anti-pattern notes (not a retry)
- **Business logic unclear** -> BLOCKED: OQ-XXX, pipeline stops, user answers
- **Scope creep detected** -> Stop rule fires, autonomy level drops
- **Regression in tests** -> Immediate STOP, user notified
- **Metrics degrading** -> session-stop hook logs to `.claude/metrics.log`, dream agent reviews
- **Context overflow** -> PreCompact hook dumps live state to disk before compression, nothing lost

## Installation Details

```bash
# See all options
bash install.sh --list

# What gets installed
bash install.sh /my/project --preset full
#   .claude/agents/        <- 37 agent definitions
#   .claude/commands/      <- 27 slash commands (10 core + 17 ext)
#   .claude/hooks/         <- 13 lifecycle + guard hooks
#   .claude/rules/         <- 3 modular doctrine files
#   .claude/skills/        <- 3 custom skills (next-task, status, f-setup-project)
#   .claude/templates/     <- requirement + ADR templates
#   .claude/AGENTS.md      <- team roster
#   .claude/pm-ref.md      <- pipeline reference
#   .claude/settings.json  <- permissions, hooks
#   .claude/statusline.sh  <- status bar script
#   CLAUDE.md              <- project doctrine (additive merge if exists)
#   manifest.md            <- project metadata + repo_access mode
#   scripts/               <- switch-repo-access.sh, framework-state-mode.sh, lib/
#   tasks/                 <- task tracking
#   memory/                <- long-term notes (flat-file project memory)
```

The installer never silently overwrites existing files: every run snapshots
`CLAUDE.md`, `settings.json`, `manifest.md`, and `.gitignore` to
`.claude/backup-TIMESTAMP/`. `CLAUDE.md` is merged additively via
`scripts/lib/merge_claude_md.py`; on a hard conflict the install pauses and
writes `.claude/CLAUDE.md.merge-proposal.md` — nothing is overwritten until
you resolve. Use `--rollback` to restore the last backup.

## Adding Domain-Specific Agents

To add a project-specific agent, copy the standard agent format:

```markdown
---
name: my-domain-agent
description: What it does — one line
tools: Read, Edit, Bash, Grep, Glob
model: sonnet
permissionMode: bypassPermissions
---

Role: [what this agent does]

## Steps
[workflow]

## Stop rules
[when to halt]

## Rules
[constraints]
```

Place in `.claude/agents/` and add a matching command in `.claude/commands/` if needed.

## What's New in v2.3.1

- **Memory-layer indicator in the statusline** — shows `mem:palace` (MemPalace is the orchestrator's default long-term memory) or `mem:files` when it has fallen back to flat files (toggled by a `~/.claude/.mempalace-down` marker). Reflects the session/orchestrator memory backend; Forge pipeline agents always use flat `memory/*.md` regardless. Note: the statusline is a **CLI-only** feature — it renders in a terminal (incl. the VS Code integrated terminal via `claude`), not in the VS Code extension panel.

## What's New in v2.3

- **Autopilot** (`/f-autopilot`) — run the backlog unattended end-to-end. PM chains tasks (overriding the one-task-per-session default) and halts only on hard stops: an open question, a regression, a production deploy, or an empty backlog — then the Claude Code push notification pings you. All quality gates + the `role-write-guard`/`stop-check` hooks stay active, which is what makes unattended runs safe.
- **Model visibility** — `log-agent.sh` records each subagent's model; the statusline shows the active agent and its model (`▸developer·sonnet`), so you can see which model is working at any moment.
- **Grok out-of-credits alert** — xAI exposes no balance API, so `grok-watch.sh` (PostToolUse) detects the billing error when a `coworker` call fails, flags it (🟥 `grok:NO-CREDITS` in the statusline + a banner), and the read-gate stops suggesting delegation until you top up (reads fall back to the main model). Recovers automatically on the next successful coworker call.

## What's New in v2.2

**Memory: flat-file, MemPalace removed**
- Memory is now plain `memory/*.md` files only. No MCP server, no `pip install`, no embedding model, no auto-save hooks. The `mempal-save.sh` / `mempal-precompact.sh` hooks and the `mcpServers` block in `settings.json` are gone; `install.sh` no longer installs or registers anything Python-side beyond an optional `CLAUDE.md` merge.
- **dream / retro / reflect / onboarding** rewritten to read and append `memory/*.md` directly (grep + edit), marking superseded facts `~~strikethrough~~` instead of invalidating graph relationships.
- Python is now optional — only used to merge an existing `CLAUDE.md` / `settings.json` on install.

**Compaction that doesn't lose data**
- The old MemPalace `pre-compact` hook *blocked* compaction until an external save succeeded — fragile, and it used to wedge. Removed. `pre-compact.sh` now never blocks (always exits 0) and writes a full state snapshot (in-progress tasks, modified files, open OQs, locks, operating contract) to **both** the compaction context **and** a durable `handoffs/precompact-<ts>.md` file — recoverable even if the summary drops it.

**Token economy: read-delegation (coworker / Grok)**
- New `coworker-read-gate.sh` (PreToolUse `Read`): large non-source reads (docs/logs/boilerplate) are delegated to the cheap `coworker` model (xAI Grok) or forced to grep-only; **source files are exempt**; **fails open** if `coworker` isn't installed. See `docs/coworker-setup.md`. Keeps the reasoning model's context for code.

**Enforced role boundaries (no more pipeline drift)**
- `AGENTS.md` declared "PM never implements / reviewers read-only / developer can't touch framework defs" but nothing enforced it. New `role-write-guard.sh` (PreToolUse `Write|Edit`) **mechanically blocks** those writes: PM-inline and read-only roles cannot edit product source; developer cannot edit `CLAUDE.md` / `pm-ref.md` / agent defs; unit-tester only touches test files. The PM inline-fallback that used to "implement itself" is removed.
- `contract-reminder.sh` (UserPromptSubmit) re-injects a one-line operating contract + the active task each turn, so discipline doesn't drift over long sessions.
- `stop-check.sh` upgraded from a nudge to a gate: blocks stopping when a task is mid-pipeline, or when product source changed but no task/backlog progress was recorded.

## What's New in v2.1

**Install UX**

- **Backup + rollback** — every install snapshots `CLAUDE.md`, `settings.json`, `manifest.md`, `.gitignore` to `.claude/backup-TIMESTAMP/`. `bash install.sh --rollback` restores the latest snapshot in one command.
- **Additive `CLAUDE.md` merge** — vendored `merge_claude_md.py` walks H2 sections, merges lists/tables, preserves user-custom sections. Hard conflict produces `.claude/CLAUDE.md.merge-proposal.md` and pauses the install — your file is never overwritten silently. Resolve and rerun with `--apply-proposal`.
- **`manifest.md`** — single source of truth for `project_name`, `repo_access`, framework version. Created on first install.

**Repo access model**

- **`private-solo` / `private-shared` / `public`** — controls whether framework state (`.claude/`, `CLAUDE.md`, `memory/`, `tasks/`) is committed to git or kept local. Default `private-solo` matches the v2.0 behaviour; switch with `scripts/switch-repo-access.sh <mode> --commit`.
- **Switch script** untracks framework files from the git index, toggles the `framework-public-ignore` block in `.gitignore`, and stops if upstream history already contains framework files (asks for a history rewrite or fresh branch).

**Modular doctrine**

- `.claude/rules/` — operational policies split out of monolithic `CLAUDE.md`:
  - `repo-access.md` — full mode model
  - `commit-policy.md` — what to commit per mode, what never to commit
  - `production-safety.md` — production deploy is the only hard stop

**Global install**

- **`install-global.sh`** copies core into `~/.claude/` additively (won't clobber your custom agents/skills) and stashes a checkout pointer at `~/.claude/.forge-checkout`.
- **`/f-setup-project` skill** — in any fresh directory, open Claude Code and run `/f-setup-project`; the skill reads the pointer and runs `install.sh` for the current folder.

**Windows polish**

- Hooks use `#!/bin/bash` — run under Git Bash on Windows.
- `install.sh` detects `python` vs `python3` and, if Python is missing, offers a winget install (only needed for the optional `CLAUDE.md` merge).

## What's New in v2.0

- **Auto-save hooks** — session lifecycle hooks (`session-start`, `session-stop`, `pre-compact`) checkpoint and dump live state to disk
- **Windows support** — hooks detect `python` vs `python3`, installer auto-installs Python via winget
- **Token optimizations** — AGENTS.md lazy-loaded, complexity table deduplicated
- **New hooks** — `detect-gaps.sh` (missing files warning), `check-blockers.sh` (OQ detection after agent runs)

## Upgrading

### From v2.0 → v2.1

```bash
# Re-run the installer — your CLAUDE.md is merged additively, not overwritten.
# Backup is created automatically at .claude/backup-TIMESTAMP/.
bash forge/install.sh /path/to/your/project --preset full

# If hard conflicts in CLAUDE.md, resolve them and run:
bash forge/install.sh /path/to/your/project --apply-proposal

# Decide repo access mode (default private-solo). Shared/public repos:
scripts/switch-repo-access.sh public --commit
```

### From v2.x (with MemPalace) → v2.2

```bash
# Re-run the installer — memory is now flat-file only, nothing to install.
bash forge/install.sh /path/to/your/project --preset full

# Optional cleanup of the old MemPalace wiring, if it lingers:
claude mcp remove mempalace 2>/dev/null || true
# Existing memory/*.md files are kept as-is and remain the source of truth.
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Hooks error on Windows | Ensure Git Bash is the default shell. Hooks use `#!/bin/bash`. |
| `python3` not found | On Windows, Python installs as `python`, not `python3`. Forge handles this automatically (Python is only needed for the optional `CLAUDE.md` merge). |
| Empty `memory/` on first run | Not an error. Continue normally — memory files seed themselves as tasks close. |
| install.sh exits with code 2 | Hard conflict in `CLAUDE.md`. Read `.claude/CLAUDE.md.merge-proposal.md`, resolve, then `bash install.sh --apply-proposal`. Or `bash install.sh --rollback` to abort. |
| install.sh exits with other error | Run with `bash -x install.sh ...` for debug output. Common cause: empty extension directories. |
| Framework files leaked to public branch | `scripts/switch-repo-access.sh` blocks the switch when upstream history already contains framework files. Use `git filter-repo` to rewrite, or cut a fresh branch from before the framework commits. |
| Dream agent triggers on every session | Increase threshold: edit `session-start.sh` line with `5+` sessions to a higher number. |

## Credits

- Pipeline design inspired by ideas from [alexeykrol/coursevibecode](https://github.com/alexeykrol/coursevibecode) — autonomy ladder, stop rules, handoff contracts, Ralph Loop, escalation matrix.

## License

MIT
