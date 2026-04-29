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

MEMORY PROTOCOL — agents use MemPalace (MCP) as primary memory; if MCP unavailable, silently fall back to `memory/*.md` files. Palace calls are best-effort: do NOT block on errors.

Required calls per role (skip silently if the tool isn't in your toolset OR returns an MCP-not-connected error):

1. **Wake-up (all agents)** — call `mempalace_status` once. On error → fallback mode for the rest of the session.
2. **Before stating past-project facts** (REQ wording, prior decision, why X was deferred, past task outcome): call `mempalace_search` (4–8 word focused query) OR `mempalace_kg_query` (if you have an entity name like `TASK-018`, `ETH130PL`, `REQ-010`). Wrong guess > slow lookup.
3. **End of work — diary write**:
   - PM at task close and phase end → `mempalace_diary_write` (task ID, commit hashes, key decisions, AC coverage, OQ raised).
   - business-analyst, decomposer, rapid-prototyper, context-summarizer at end of their session → same with role-relevant payload.
   - Other agents (developer, code-reviewer, unit-tester, etc.) → no diary write; PM owns the task-level diary.
4. **New material entity** (architect ADR, BA new REQ, database-architect schema change, rapid-prototyper REFUTED hypothesis): `mempalace_kg_add` with entity name, type, and relations to affected tasks/REQs.
5. **Fact change**: `mempalace_kg_invalidate` (old) + `mempalace_kg_add` (new).
6. **Before adding a new pattern/known-issue to memory**: `mempalace_check_duplicate` to avoid noise.

Fallback rules (MCP unavailable):
- Read `memory/decisions.md`, `memory/patterns.md`, `memory/known-issues.md`, `memory/stack.md` directly with `Read`/`Grep`.
- Write new entries with `Edit`/`Write` to those same files.
- Do NOT retry MCP, do NOT spend turns trying to reconnect. Surface "MCP unreachable" once at handoff, not as STOP.

DEFINITION OF DONE: a task is complete only when: (1) code committed to git, (2) tests pass (L3+ with new logic), (3) result reported to user.

> **First session?** No tz.md and no tasks — run `/f-start` for guided onboarding.
