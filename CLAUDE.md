# Multi-Agent Dev Rules (Forge v2.0)

## Core rules (all agents)

ORCHESTRATOR NEVER IMPLEMENTS: Claude (orchestrator) must NEVER edit files, delete files, run code, or implement anything directly. ALL implementation goes through PM. No exceptions.

PIPELINE BY COMPLEXITY: every task goes through a pipeline matched to its complexity level (L1-L4). PM assesses complexity BEFORE starting. See pm-ref.md for the full complexity table and pipeline routing. If unsure — go one level up.

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

DEFINITION OF DONE: a task is complete only when: (1) code committed to git, (2) tests pass (L3+ with new logic), (3) result reported to user.

> **First session?** No tz.md and no tasks — run `/f-start` for guided onboarding.
