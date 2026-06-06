# Multi-Agent Dev Rules (Forge v2.3)

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

LANGUAGE & HANDOFF DISCIPLINE: all inter-agent communication, handoff sections, task files, memory, and commit messages are written in **English** — no other natural language. Keep them **terse and structured**: fill only the handoff-contract fields (status / files_changed / validation_points / delegate_to), no narrative prose, no pleasantries, no restating the task. Brevity is mandatory; readability is preserved (plain English, never a private/encoded dialect).

USER LANGUAGE (mandatory): when replying to the user, **always answer in the same language the user wrote in** — mirror their language every turn. Never switch the user to English. This applies only to user-facing text; internal/inter-agent artifacts stay English per the rule above.

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

MEMORY PROTOCOL: Persistent memory lives in flat `memory/*.md` files (`stack.md`, `patterns.md`, `decisions.md`, `known-issues.md`). Before stating facts about the project, `grep memory/*.md` for the relevant entry — never guess. After a task, append genuinely new facts to the right file and mark superseded facts with `~~strikethrough~~` (append-only, never silently overwrite). An empty `memory/` on a fresh project is not an error — it seeds itself as tasks close.

DELEGATION & CACHE DISCIPLINE: Reserve the reasoning model's context for source code and decisions. Large non-source reads — docs, specs, logs, generated/boilerplate files — go to `coworker` (cheap model): `coworker ask --paths <path> --question "<question>" --allow-code`, then work from its answer. Source files you read directly. The `coworker-read-gate` hook enforces this on `Read` (blocks large non-source reads, exempts source); it fails open if `coworker` isn't installed and is disabled with `COWORKER_READ_GATE=off`. See `docs/coworker-setup.md`. Keep the system prompt / CLAUDE.md stable within a session so the prompt cache stays warm — don't rewrite framework files mid-task.

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
