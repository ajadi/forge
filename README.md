# Forge

Modular multi-agent development framework for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Forge turns Claude Code into a full dev team: PM orchestrates, agents implement, review, test, and deploy. You choose how many agents you need — from 3 (solo) to 36 (full pipeline).

## Quick Start

```bash
# Clone
git clone https://github.com/ajadi/forge.git

# Install into your project (choose a preset)
bash forge/install.sh /path/to/your/project --preset solo        # 3 agents
bash forge/install.sh /path/to/your/project --preset small-team   # 14 agents
bash forge/install.sh /path/to/your/project --preset full         # 36 agents

# Or pick specific extensions
bash forge/install.sh /path/to/your/project --ext security,frontend

# Then open your project in Claude Code and run:
# /f-start
```

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
 +-- ... (36 agents total)
```

### Key Design Principles

- **PM never implements** — only orchestrates and delegates
- **Reference passing** — agents get file paths, not file contents
- **Handoff contracts** — standardized format between agents (status, files_changed, validation_points)
- **Stop rules** — every agent knows exactly when to halt
- **Autonomy ladder** (A1-A5) — agents earn more freedom with proven reliability

## Structure

```
forge/
  core/                     # Always installed
    AGENTS.md               # Team roster: roles, models, boundaries
    agents/                 # 13 core agents
    commands/               # 11 slash commands (/f-fix, /f-start, etc.)
    hooks/                  # Session lifecycle, git validation, metrics
    skills/                 # next-task, status
    templates/              # tz-template (requirements), adr-template (decisions)
    pm-ref.md               # Pipeline reference
    settings.json           # Base permissions and hooks

  extensions/               # Install per project need
    ext-security/           # security-analyst, dependency-auditor
    ext-frontend/           # smoke-tester, e2e-tester, ui-designer, ux-interviewer, a11y
    ext-devops/             # devops, env-manager, git-workflow, migration-validator
    ext-quality/            # performance-profiler, refactoring, test-reviewer, integration-tester
    ext-docs/               # documentation, changelog-agent
    ext-planning/           # estimator, consilium
    ext-reflection/         # reflect, dream, optimizer, onboarding

  presets/                  # Quick-start configurations
  domain-examples/          # Example of project-specific agents (VPN domain)
```

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
| **ext-reflection** | reflect, dream, optimizer, onboarding | Long-running projects |

## Key Commands

| Command | What it does |
|---------|-------------|
| `/f-start` | Guided onboarding for new project |
| `/f-fix TASK-XXX` | Quick fix — run PM on a specific task |
| `/f-hotfix` | Emergency fix bypassing normal pipeline |
| `/f-ba` | Business analyst — collect requirements |
| `/f-decompose` | Break feature into tasks |
| `/f-status` | Show project progress |
| `/f-next-task` | What to work on next |
| `/f-spike` | Technical spike to validate hypothesis |

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

## Installation Details

```bash
# See all options
bash install.sh --list

# What gets installed
bash install.sh /my/project --preset full
#   .claude/agents/        <- 36 agent definitions
#   .claude/commands/      <- 28 slash commands
#   .claude/hooks/         <- 7 lifecycle hooks
#   .claude/skills/        <- 2 custom skills
#   .claude/templates/     <- requirement + ADR templates
#   .claude/AGENTS.md      <- team roster
#   .claude/pm-ref.md      <- pipeline reference
#   .claude/settings.json  <- permissions + hook config
#   .claude/statusline.sh  <- status bar script
#   CLAUDE.md              <- project rules (only if not exists)
#   memory/                <- persistent knowledge
#   tasks/                 <- task tracking
```

The installer **never overwrites** existing `CLAUDE.md` — your project rules are safe.

## Adding Domain-Specific Agents

See `domain-examples/` for how to create project-specific agents. Copy the format:

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

## Credits

Pipeline design inspired by ideas from [alexeykrol/coursevibecode](https://github.com/alexeykrol/coursevibecode) — autonomy ladder, stop rules, handoff contracts, Ralph Loop, escalation matrix.

## License

MIT
