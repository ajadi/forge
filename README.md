# Forge

Modular multi-agent development framework for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). **Version 2.4.**

Forge turns Claude Code into a full dev team: a PM agent orchestrates, specialized agents implement, review, test, and deploy. Four things keep it from drifting, losing state, or running up cost:

- **File-based memory** — project knowledge lives in plain `memory/*.md` files every agent greps before guessing. No external service, no daemon, nothing to install.
- **Mechanically enforced roles** — a `Write|Edit` guard hook stops PM and read-only agents from editing source. The boundaries `AGENTS.md` declares are actually enforced, not just documented.
- **Token economy** — large non-source reads are delegated to a cheap model (xAI Grok via [`coworker`](docs/coworker-setup.md)); noisy shell output is trimmed before it hits context. The reasoning model's context stays on code.
- **Long-session durability** — state survives compaction (dump + one-shot rehydrate), compaction happens earlier while context is still coherent, and an objective anchor + depth meter keep long runs on-task.

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
the skill runs `install.sh` for the current folder, no manual download.

Refresh after pulling a new Forge version with `bash forge/install-global.sh --update`
— it overwrites Forge's own agents/commands/rules/skills with the current version
and leaves your custom files untouched. (Plain `install-global.sh` skips anything
that already exists.)

> The global install ships only agents/commands/rules/skills. **Hooks and
> `settings.json` are not installed globally**, so the enforcement + token + durability
> hooks (`role-write-guard`, `coworker-read-gate`, `contract-reminder`, `rehydrate`,
> the PreCompact snapshot) activate only after a per-project `install.sh` / `/f-setup-project`.

### Install flags

| Flag | What |
|------|------|
| `--preset solo\|small-team\|full` | Pick a bundle |
| `--ext name1,name2` | Add specific extensions |
| `--name "..."` | Project name written into `manifest.md` |
| `--rollback` | Restore the last backup (`.claude/backup-TIMESTAMP/`) |
| `--apply-proposal` | Re-run merge after manually resolving `CLAUDE.md` conflicts |
| `--list` | List available presets and extensions |

The installer backs up `CLAUDE.md`, `settings.json`, `manifest.md`, and `.gitignore`
before any change. If your `CLAUDE.md` and the framework template have a hard
conflict, the install pauses and writes `.claude/CLAUDE.md.merge-proposal.md`
instead of overwriting your file.

### Repo access modes

After install, `manifest.md` holds `repo_access` (default `private-solo`).
For shared/public repos, switch BEFORE the first commit that contains framework state:

```bash
scripts/switch-repo-access.sh public --commit
scripts/switch-repo-access.sh private-shared --commit
```

The script untracks `.claude/`, `CLAUDE.md`, `memory/`, `tasks/` from the git index
and toggles the `framework-public-ignore` block in `.gitignore`. See
`.claude/rules/repo-access.md` for the full model.

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- Git Bash (Windows) — hooks use `#!/bin/bash`
- Python 3.9+ *(optional)* — only used to merge an existing `CLAUDE.md` / `settings.json` on install; without it those files are copied, not merged

## What It Does

Forge installs a `.claude/` directory into your project with agents, commands, hooks, and configs. After installation, Claude Code picks up the framework and operates as a multi-agent system.

**The PM agent** receives your task, assesses complexity (L1-L4), and routes it through the matching pipeline:

| Level | What | Pipeline | Agents |
|-------|------|----------|--------|
| L1 | One-line fix | Developer → RealityChecker → commit | 3 |
| L2 | Small enhancement | Developer → CodeReviewer → RealityChecker → commit | 4 |
| L3 | Feature | Architect → Developer → CodeReviewer + SecurityAnalyst → UnitTester → RealityChecker → commit | 6+ |
| L4 | Major feature | Full pipeline with design panel (Consilium) | All |

The pipeline scales to the task — no full pipeline for a typo.

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

- **PM never implements** — only orchestrates and delegates (enforced by `role-write-guard`, not just convention)
- **Reference passing** — agents get file paths, not file contents
- **Handoff contracts** — standardized format between agents (status, files_changed, validation_points)
- **Stop rules** — every agent knows when to halt; the Stop hook gates mid-pipeline exits
- **Autonomy ladder** (A1-A5) — agents earn more freedom with proven reliability
- **File-based memory** — agents grep `memory/*.md` before guessing, append findings after tasks
- **Token economy** — large non-source reads delegated to a cheap model; noisy command output trimmed
- **Durability** — live state is dumped before compaction and rehydrated once after, so long sessions don't lose the thread

## Memory System (flat files)

Forge keeps persistent project knowledge in plain Markdown under `memory/`. No external service, no daemon, no embeddings — just files agents read and append.

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

## Structure

```
forge/
  core/                     # Always installed
    AGENTS.md               # Team roster: roles, models, boundaries
    agents/                 # 13 core agents
    commands/               # Core slash commands (/f-fix, /f-start, /f-autopilot, ...)
    hooks/                  # Session lifecycle, durability, guards, token economy
    rules/                  # Modular doctrine: repo-access, commit-policy, production-safety
    scripts/                # switch-repo-access, framework-state-mode, lib/merge_claude_md.py
    skills/                 # f-next-task, f-status, f-setup-project, f-audit
    templates/              # tz-template, adr-template, manifest.md.tmpl, gitignore.tmpl
    docs/                   # setup guides (e.g. coworker-setup.md)
    pm-ref.md               # Pipeline reference
    settings.json           # Base permissions, hooks
    statusline.sh           # Status bar script

  extensions/               # Install per project need
    ext-security/           # security-analyst, dependency-auditor
    ext-frontend/           # smoke-tester, e2e-tester, ui-designer, ux-interviewer, a11y
    ext-devops/             # devops, env-manager, git-workflow, migration-validator (+ ssh-mcp-ft MCP)
    ext-quality/            # performance-profiler, refactoring, test-reviewer, integration-tester
    ext-docs/               # documentation, changelog-agent
    ext-planning/           # estimator, consilium
    ext-reflection/         # reflect, dream, optimizer, onboarding, retro, platform-sync

  presets/                  # Quick-start configurations
```

## Hooks

Installed into `.claude/hooks/` and wired in `.claude/settings.json`. **Every hook fails open / never wedges the session.**

| Hook | Event | What it does |
|------|-------|-------------|
| `session-start.sh` · `detect-gaps.sh` | SessionStart | Load context; reset the turn counter; warn on missing framework files |
| `contract-reminder.sh` | UserPromptSubmit | Re-inject the operating contract + active task; **anchor the task's objective + done-criteria** so long sessions don't drift |
| `rehydrate.sh` | UserPromptSubmit | **After compaction**, one-shot re-inject of critical state (tasks, files, OQs, contract) from the durable snapshot — then stays silent |
| `turn-counter.sh` | UserPromptSubmit | **Session depth meter** — counts turns, soft-warns at `FORGE_DEPTH_SOFT` (default 40) to checkpoint; statusline shows `d:N` |
| `validate-commit.sh` · `validate-push.sh` | PreToolUse(Bash) | Block `--no-verify`, force-push, staged `.env`, etc. |
| `bash-filter.sh` | PreToolUse(Bash) | **Trim noisy commands** (`git status/log/diff`, `npm/pip install`, `ls -R`) to lean forms — token saver; only simple commands, fails open |
| `coworker-read-gate.sh` | PreToolUse(Read) | Delegate large non-source reads to coworker/Grok; source exempt; fails open |
| `role-write-guard.sh` | PreToolUse(Write\|Edit) | Enforce AGENTS.md boundaries: PM/read-only roles can't edit source; developer can't edit framework defs; testers only touch tests |
| `check-blockers.sh` | PostToolUse(Task) | Detect open OQs after an agent runs |
| `grok-watch.sh` | PostToolUse(Bash) | Detect coworker/Grok "out of credits" → flag 🟥 + statusline marker |
| `log-agent.sh` | SubagentStart | Audit log + write `.claude/.current-agent` (agent **and** model — used by the write-guard and the statusline) |
| `pre-compact.sh` | PreCompact | Dump full session state to context **and** a durable `handoffs/precompact-<ts>.md`; write the rehydrate marker; never blocks |
| `stop-check.sh` · `session-stop.sh` | Stop | Gate: block stopping mid-pipeline or with unrecorded source changes; log metrics |

**Earlier compaction:** `settings.json` sets `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=60` — compaction fires while context is still coherent, and `rehydrate.sh` restores the critical excerpt right after.

**Tuning knobs (env vars):** `COWORKER_READ_GATE=off`, `COWORKER_DELEGATE_TOKENS`, `COWORKER_GREP_TOKENS`, `COWORKER_TOKEN_DIVISOR`, `ROLE_WRITE_GUARD=off`, `ROLE_GUARD_TTL`, `FORGE_BASH_FILTER=off`, `FORGE_BASH_REWRITE=off`, `FORGE_DEPTH_SOFT`.

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
| **ext-devops** | devops, env-manager, git-workflow, migration-validator (+ `ssh-mcp-ft` MCP server) | Deployed services, CI/CD |
| **ext-quality** | performance-profiler, refactoring, test-reviewer, integration-tester | Large codebases |
| **ext-docs** | documentation, changelog-agent | Open-source, team projects |
| **ext-planning** | estimator, consilium | L3-L4 tasks, team planning |
| **ext-reflection** | reflect, dream, optimizer, onboarding, retro, platform-sync | Long-running projects |

## Key Commands

| Command | What it does |
|---------|-------------|
| `/f-start` | Guided onboarding for a new project |
| `/f-fix TASK-XXX` | Quick fix — run PM on a specific task |
| `/f-hotfix` | Emergency fix bypassing normal pipeline |
| `/f-ba` | Business analyst — collect requirements |
| `/f-decompose` | Break a feature into tasks |
| `/f-status` | Show project progress (skill) |
| `/f-next-task` | What to work on next (skill) |
| `/f-audit` | Adaptive multi-agent project audit swarm (skill) |
| `/f-dream` | Run memory consolidation (audits `memory/*.md`) |
| `/f-reflect` | Post-task reflection and learning |
| `/f-platform-sync` | Actualize Forge against Anthropic's live platform docs (propose-only) |
| `/f-spike` | Technical spike to validate a hypothesis |
| `/f-new-task` | Create a new task file |
| `/f-scope-check` | Check for scope creep vs tz.md |
| `/f-bug-report` | Structured bug report |
| `/f-autopilot` | Run the backlog unattended end-to-end; halts only on questions/regressions/deploys, then pushes you |

> **Naming convention:** all user-invocable Forge skills and commands use the `f-` prefix (the Forge namespace) to avoid collision with Claude Code's built-in and third-party commands. Internal agents (e.g. the `status` agent) and scripts (`statusline.sh`) keep their plain names.

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

- **Agent stuck twice** → Ralph Loop: fresh context restart with anti-pattern notes (not a retry)
- **Business logic unclear** → BLOCKED: OQ-XXX, pipeline stops, user answers
- **Scope creep detected** → Stop rule fires, autonomy level drops
- **Regression in tests** → immediate STOP, user notified
- **Metrics degrading** → session-stop hook logs to `.claude/metrics.log`, dream agent reviews
- **Context overflow** → PreCompact dumps live state to disk; `rehydrate.sh` restores it after compaction — nothing lost

## Installation Details

```bash
# See all options
bash install.sh --list

# What gets installed (full preset)
bash install.sh /my/project --preset full
#   .claude/agents/        <- 37 agent definitions
#   .claude/commands/      <- core + extension slash commands
#   .claude/hooks/         <- 16 lifecycle / durability / guard / token hooks
#   .claude/rules/         <- 3 modular doctrine files
#   .claude/skills/        <- f-next-task, f-status, f-setup-project, f-audit
#   .claude/templates/     <- requirement + ADR templates
#   .claude/AGENTS.md      <- team roster
#   .claude/pm-ref.md      <- pipeline reference
#   .claude/settings.json  <- permissions, hooks
#   .claude/statusline.sh  <- status bar script
#   CLAUDE.md              <- project doctrine (additive merge if exists)
#   manifest.md            <- project metadata + repo_access mode
#   scripts/               <- switch-repo-access.sh, framework-state-mode.sh, lib/
#   tasks/  memory/        <- task tracking + flat-file project memory
```

The installer never silently overwrites: every run snapshots `CLAUDE.md`,
`settings.json`, `manifest.md`, and `.gitignore` to `.claude/backup-TIMESTAMP/`.
`CLAUDE.md` is merged additively via `scripts/lib/merge_claude_md.py`; on a hard
conflict the install pauses and writes `.claude/CLAUDE.md.merge-proposal.md` —
nothing is overwritten until you resolve. Use `--rollback` to restore the last backup.

## Adding Domain-Specific Agents

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

## What's New in v2.4 — long-session durability + token economy

- **Post-compact rehydration** (`rehydrate.sh`, UserPromptSubmit) — after a compaction, `pre-compact.sh` leaves a marker and a durable `handoffs/precompact-<ts>.md` snapshot; `rehydrate.sh` re-injects the critical excerpt (in-progress tasks, modified files, open OQs, locks, operating contract) **exactly once**, then goes silent. The lossy summary is backstopped by exact state.
- **Earlier compaction** — `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` lowered `70 → 60`, so compaction fires while context is still coherent rather than at the brink.
- **Objective anchor** (`contract-reminder.sh`) — each turn also surfaces the active task's objective + done-criteria, so a long session doesn't lose sight of what it set out to do.
- **Session depth meter** (`turn-counter.sh` + statusline `d:N`) — counts turns per session and soft-warns at `FORGE_DEPTH_SOFT` (default 40) to checkpoint and start fresh. Never blocks.
- **Bash output filtering** (`bash-filter.sh`, PreToolUse Bash) — rewrites a small whitelist of noisy commands (`git status/log/diff`, `npm/pip install`, `ls -R`) to lean forms to save tokens; only simple commands, fails open, kill-switches `FORGE_BASH_FILTER` / `FORGE_BASH_REWRITE`.
- **`f-` namespace** — `next-task`/`status` skills renamed to `f-next-task`/`f-status`; the naming convention (all user-invocable commands prefixed `f-`) is documented in `pm-ref.md`.
- **`/f-platform-sync`** — propose-only command that actualizes Forge against Anthropic's live platform docs.

Earlier releases (v2.0–v2.3): flat-file memory, enforced role boundaries, coworker read-delegation, autopilot, backup/rollback install, repo-access modes, global install. See the git history for per-version detail.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Hooks error on Windows | Ensure Git Bash is the default shell. Hooks use `#!/bin/bash`. |
| `python3` not found | On Windows, Python installs as `python`. Forge handles this automatically (Python is only needed for the optional `CLAUDE.md` merge). |
| Empty `memory/` on first run | Not an error — memory files seed themselves as tasks close. |
| `install.sh` exits with code 2 | Hard conflict in `CLAUDE.md`. Read `.claude/CLAUDE.md.merge-proposal.md`, resolve, then `bash install.sh --apply-proposal`. Or `bash install.sh --rollback`. |
| `install.sh` other error | Run `bash -x install.sh ...` for debug output. Common cause: empty extension directories. |
| Framework files leaked to public branch | `scripts/switch-repo-access.sh` blocks the switch when upstream history already contains framework files. Use `git filter-repo` to rewrite, or cut a fresh branch. |
| A noisy command got rewritten unexpectedly | `bash-filter.sh` only touches a fixed whitelist of simple commands; disable with `FORGE_BASH_FILTER=off`. |

## Credits

- Pipeline design inspired by ideas from [alexeykrol/coursevibecode](https://github.com/alexeykrol/coursevibecode) — autonomy ladder, stop rules, handoff contracts, Ralph Loop, escalation matrix.

## License

MIT
