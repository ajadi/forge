# Forge

Modular multi-agent development framework for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with built-in semantic memory powered by [MemPalace](https://github.com/MemPalace/mempalace).

Forge turns Claude Code into a full dev team: PM orchestrates, agents implement, review, test, and deploy. MemPalace gives every agent persistent semantic memory with 96.6% recall — no more grep on flat files.

## Quick Start

```bash
# Clone
git clone https://github.com/ajadi/forge.git

# Install into your project (choose a preset)
bash forge/install.sh /path/to/your/project --preset solo        # 3 agents
bash forge/install.sh /path/to/your/project --preset small-team   # 13 agents (core only)
bash forge/install.sh /path/to/your/project --preset full         # 37 agents

# Or pick specific extensions
bash forge/install.sh /path/to/your/project --ext security,frontend

# Then open your project in Claude Code and run:
# /f-start
```

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- Python 3.9+ (for MemPalace memory backend)
- `pip install mempalace` (installed automatically by `install.sh`)

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
MemPalace (MCP server) ── semantic memory for all agents
 +-- 29 MCP tools (search, store, knowledge graph)
 +-- Hybrid search: BM25 + vector (96.6% recall)
 +-- Agent diaries (per-agent memory isolation)
 +-- Knowledge graph (temporal entity relationships)
 +-- Auto-save hooks (Stop + PreCompact)
```

### Key Design Principles

- **PM never implements** — only orchestrates and delegates
- **Reference passing** — agents get file paths, not file contents
- **Handoff contracts** — standardized format between agents (status, files_changed, validation_points)
- **Stop rules** — every agent knows exactly when to halt
- **Autonomy ladder** (A1-A5) — agents earn more freedom with proven reliability
- **Semantic memory** — agents search palace before guessing facts, write diary after sessions

## Memory System (MemPalace)

Forge v2.0 uses [MemPalace](https://github.com/MemPalace/mempalace) as its built-in memory backend. Every agent can:

| Operation | MCP Tool | What it does |
|-----------|----------|-------------|
| **Search** | `mempalace_search` | Hybrid semantic + keyword search across all memories |
| **Store** | `mempalace_add_drawer` | Save verbatim content in wing/room/drawer hierarchy |
| **Diary** | `mempalace_diary_write` | Per-agent timestamped diary entries |
| **Knowledge Graph** | `mempalace_kg_add` | Store entity relationships with temporal validity |
| **Query facts** | `mempalace_kg_query` | Get all facts about an entity, optionally at a point in time |
| **Navigate** | `mempalace_traverse` | Walk the memory graph to find connected ideas |

### Memory Protocol

1. **On wake-up**: Call `mempalace_status` (loads protocol + palace stats)
2. **Before facts**: Search palace first via `mempalace_search` — never guess
3. **After session**: Write diary via `mempalace_diary_write`
4. **When facts change**: Invalidate old + add new via knowledge graph

### How Agents Use Memory

| Agent | How it uses palace |
|-------|--------------------|
| **developer** | Searches for relevant patterns before implementing |
| **dream** | Consolidates palace: finds contradictions, invalidates stale facts, cross-references |
| **retro** | Stores phase retrospective findings, tracks recurring patterns via knowledge graph |
| **reflect** | Writes task analysis to diary, records patterns in knowledge graph |
| **onboarding** | Populates palace with project stack, patterns, and entity relationships |
| **pm** | Loads project context from palace on session start |

### Auto-Save Hooks

- **Stop hook** (`mempal-save.sh`): Checkpoints conversation every 15 exchanges
- **PreCompact hook** (`mempal-precompact.sh`): Emergency save before context compression — nothing is lost

### Graceful Degradation

If MemPalace is not installed or the MCP server is unavailable:
- All hooks exit silently (no errors, no blocks)
- Agents fall back to `grep memory/*.md` for pattern search
- dream/retro/reflect agents fall back to flat file operations
- The pipeline works fully — just without semantic memory

## Structure

```
forge/
  core/                     # Always installed
    AGENTS.md               # Team roster: roles, models, boundaries
    agents/                 # 13 core agents
    commands/               # 11 slash commands (/f-fix, /f-start, etc.)
    hooks/                  # Session lifecycle, git validation, metrics, MemPalace auto-save
    skills/                 # next-task, status
    templates/              # tz-template (requirements), adr-template (decisions)
    pm-ref.md               # Pipeline reference
    settings.json           # Base permissions, hooks, MCP server config

  extensions/               # Install per project need
    ext-security/           # security-analyst, dependency-auditor
    ext-frontend/           # smoke-tester, e2e-tester, ui-designer, ux-interviewer, a11y
    ext-devops/             # devops, env-manager, git-workflow, migration-validator
    ext-quality/            # performance-profiler, refactoring, test-reviewer, integration-tester
    ext-docs/               # documentation, changelog-agent
    ext-planning/           # estimator, consilium
    ext-reflection/         # reflect, dream, optimizer, onboarding, retro

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
| **ext-reflection** | reflect, dream, optimizer, onboarding, retro | Long-running projects |

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
| `/f-dream` | Run memory consolidation (MemPalace) |
| `/f-reflect` | Post-task reflection and learning |
| `/f-spike` | Technical spike to validate hypothesis |
| `/f-new-task` | Create a new task file |
| `/f-scope-check` | Check for scope creep vs tz.md |
| `/f-bug-report` | Structured bug report |

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
- **Context overflow** -> PreCompact hook saves to MemPalace before compression, nothing lost

## Installation Details

```bash
# See all options
bash install.sh --list

# What gets installed
bash install.sh /my/project --preset full
#   .claude/agents/        <- 37 agent definitions
#   .claude/commands/      <- 28 slash commands
#   .claude/hooks/         <- 11 lifecycle hooks (including MemPalace auto-save)
#   .claude/skills/        <- 2 custom skills
#   .claude/templates/     <- requirement + ADR templates
#   .claude/AGENTS.md      <- team roster
#   .claude/pm-ref.md      <- pipeline reference
#   .claude/settings.json  <- permissions, hooks, MCP server config
#   .claude/statusline.sh  <- status bar script
#   CLAUDE.md              <- project rules (only if not exists)
#   tasks/                 <- task tracking
#   + MemPalace            <- pip install + MCP server registration
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

## What's New in v2.0

- **MemPalace integration** — semantic memory backend with 29 MCP tools, replacing flat `memory/*.md` files
- **Auto-save hooks** — conversation checkpoints every 15 exchanges + emergency save before context compression
- **Knowledge graph** — temporal entity relationships (who works on what, when facts changed)
- **Agent diaries** — per-agent isolated memory with timestamped entries
- **Graceful degradation** — everything works without MemPalace (falls back to flat files)
- **Windows support** — hooks detect `python` vs `python3`, installer auto-installs Python via winget
- **Token optimizations** — conditional palace search (L2+ only), AGENTS.md lazy-loaded, complexity table deduplicated
- **New hooks** — `detect-gaps.sh` (missing files warning), `check-blockers.sh` (OQ detection after agent runs)

### Upgrading from v1.0

```bash
# Re-run the installer — it won't overwrite your CLAUDE.md
bash forge/install.sh /path/to/your/project --preset full

# Install MemPalace
pip install mempalace

# Register MCP server
claude mcp add mempalace -- python -m mempalace.mcp_server
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `mempalace` MCP tools not available | Run `pip install mempalace` and `claude mcp add mempalace -- python -m mempalace.mcp_server` |
| Hooks error on Windows | Ensure Git Bash is the default shell. Hooks use `#!/bin/bash`. |
| `python3` not found | On Windows, Python installs as `python`, not `python3`. Forge handles this automatically. |
| Agent says "MemPalace unavailable" | Check MCP server: `claude mcp list`. If missing, re-register. Agents will fall back to flat files. |
| install.sh exits with error | Run with `bash -x install.sh ...` for debug output. Common cause: empty extension directories. |
| Dream agent triggers on every session | Increase threshold: edit `session-start.sh` line with `5+` sessions to a higher number. |

## Credits

- Pipeline design inspired by ideas from [alexeykrol/coursevibecode](https://github.com/alexeykrol/coursevibecode) — autonomy ladder, stop rules, handoff contracts, Ralph Loop, escalation matrix.
- Memory system powered by [MemPalace](https://github.com/MemPalace/mempalace) — local-first semantic memory with hybrid search and knowledge graphs.

## License

MIT
