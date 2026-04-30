# Multi-Agent Dev Rules (Forge v2.1)

## Core rules (all agents)

ORCHESTRATOR NEVER IMPLEMENTS: Claude (orchestrator) must NEVER edit files, delete files, run code, or implement anything directly. ALL implementation goes through PM. No exceptions.

PIPELINE BY COMPLEXITY: every task goes through a pipeline matched to its complexity level (L1-L4). PM assesses complexity BEFORE starting. See `.claude/pm-ref.md` for the full complexity table and pipeline routing. If unsure — go one level up.

<important if="you encounter unclear business logic or missing requirements">
AMBIGUITY: if business logic unclear → add OQ-XXX to tz.md → return PM: `BLOCKED: OQ-XXX [blocker: task|track|project]`. Never assume. Never continue.
Ambiguity = undefined behavior / conflicting requirements / missing edge case.
Not ambiguity = technical choice / framework default behavior.
</important>

<important if="you are about to pass file content to another agent or include it inline">
REFERENCE PASSING: pass file paths, not content. Agent reads itself.
</important>

<important if="you are about to write to tasks/ or append to a task file">
TASK FILES: PM creates `tasks/TASK-XXX.md`. Each agent appends its own section only. Never overwrite other sections.
</important>

TRACKS: same track = sequential. different tracks = parallel. PM owns locks.json.

<important if="you are about to read a large file or pass file contents">
TOKEN BUDGET: read diffs not full files. Use `git diff HEAD~1 -- <file>` for review tasks. If context overflows → reply `CONTEXT_OVERFLOW: need only [sections]`.
</important>

CODING: minimal changes only. No over-engineering. Tests required for new logic (L3+). Secrets via env vars only.

AGENTS: always spawn subagents with `mode: "bypassPermissions"`. No permission prompts to user from subagents.

BACKGROUND: always run agents with `run_in_background: true`. Stay available to the user while agents work. For independent tasks, launch multiple agents in parallel.

PARALLEL COORDINATION: orchestrator owns conflict resolution. Before launching parallel PM agents: check file overlap. No overlap → parallel. Overlap → sequential.

AUTONOMOUS EXECUTION: once the user gives a task, execute it to completion without asking for confirmation at intermediate steps. Only stop if genuinely blocked (BLOCKED: OQ-XXX).

MEMORY PROTOCOL: All agents use MemPalace (MCP server) for memory operations. On session start, call `mempalace_status` to load protocol. Before stating facts about the project, search palace via `mempalace_search`. After sessions, write diary via `mempalace_diary_write`. Palace is the primary memory backend. If MemPalace is unavailable, agents fall back to memory/*.md files.

- **Cold-start (palace empty / `wings: {}`)**: not an error. Continue normally; PM may seed the wing on first task close via `mempalace_add_drawer`. Do NOT run `mempalace init` from inside the agent — it's interactive and produces low-quality entity suggestions for typical Forge projects.

DEFINITION OF DONE: a task is complete only when: (1) code committed to git, (2) tests pass (L3+ with new logic), (3) result reported to user.

## Modular rules

Operational policies live in `.claude/rules/` and load lazily by topic:

- `.claude/rules/repo-access.md` — `private-solo` / `private-shared` / `public` modes; controls whether framework state is committed.
- `.claude/rules/commit-policy.md` — what to commit per mode, what never to commit, pre-push checks.
- `.claude/rules/production-safety.md` — production deploy is the only hard stop that requires user confirmation.

Read the relevant rule before acting in its domain. The list above is the canonical index.

## Project metadata

- `manifest.md` (project root) — `project_name`, `repo_access`, framework version. Source of truth for repo-access mode.
- `scripts/switch-repo-access.sh` — safe transition between modes. Don't edit `.gitignore` or untrack framework files by hand.
- `scripts/framework-state-mode.sh` — read-only helper used by hooks.

> **First session?** No tz.md and no tasks — run `/f-start` for guided onboarding.
