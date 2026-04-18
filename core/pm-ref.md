# PM Reference (Forge v1.0)

> Team roster and escalation rules → .claude/AGENTS.md

## Full pipeline
```
BA → tz.md (architect estimation: XS/S/M/L/XL per REQ)
Decomposer → backlog.md index + tasks/TASK-NNN.md files
PM: dry-run → OQ check → stale locks → git checkpoint → lock files
HandoffValidator → [Architect: L/XL or new API/DB/schema] → Developer
[web UI] SmokeTester
Bash: lint bisect + test suite
CodeReviewer + SecurityAnalyst (parallel, diff-aware) [retry ≤3]
UnitTester + IntegrationTester (parallel) [business logic only] → TestReviewer [>5 tests]
Documentation → changelog-agent → RealityChecker
git commit → archive task file → unlock → progress.log → tz.md REQ ✅ → memory
[phase complete] git tag → retro (3 questions to user)
```

Lightweight routes:
```
docs only:    BA → documentation → reality-checker
audit only:   dependency-auditor → reality-checker
refactor:     refactoring → code-reviewer → reality-checker
spike:        rapid-prototyper → (CONFIRMED) → task in backlog
```

## Estimation → Pipeline mapping

| complexity | architect | developer model | unit tests | retry limit |
|-----------|-----------|----------------|------------|-------------|
| XS | skip | sonnet | no | 2 |
| S | skip | sonnet | no | 2 |
| M | optional | sonnet | per task | 3 |
| L | required | sonnet | yes | 3 |
| XL | required | opus | yes | 3 |

Architect always required: new endpoints, DB schema changes, cross-service deps, security-sensitive.

## OQ priority format
```
OQ-XXX [blocker:project] — blocks all, answer first
OQ-XXX [blocker:track]   — blocks specific track
OQ-XXX [blocker:task]    — blocks one task only
```
Show user ordered: project → track → task.

## Watchdog
Partial failure if: response <100 words without status code OR no section appended to task file.
Log to progress.log. Retry. Max 2 watchdog retries (separate from gate retries).

## Targeted re-delegation
On NEEDS_WORK: read "delegate to" section in reality-checker output.
Delegate only named agents. No full pipeline restart.
After fixes → reality-checker only.

## Lint bisect
```bash
git diff HEAD~1 --name-only | xargs -I{} sh -c '[lint_cmd] {} 2>&1 && echo OK:{} || echo FAIL:{}'
```
Pass developer only FAIL files + errors.

## Phase retro
After `git tag phase-N-complete` — ask user:
1. What went wrong? → known-issues.md
2. Recurring patterns? → patterns.md with [recurring] tag
3. Change next phase? → decisions.md

## Backlog rotation

Trigger: when all tasks in a phase are [x] AND `git tag phase-N-complete` is created.

Steps:
1. Append completed phase section from backlog.md to backlog-archive.md (create if missing)
2. Remove the completed phase section from backlog.md
3. Update progress counter in backlog.md header
4. Log rotation to .claude/progress.log

Keep backlog.md lean: only active + upcoming phases. Archive is append-only.

## Models

| tier | model | agents |
|------|-------|--------|
| opus | claude-opus-4-6 | pm, architect (L/XL tasks), developer (XL override) |
| sonnet | claude-sonnet-4-6 | developer, ba, decomposer, code-reviewer, security-analyst, integration-tester, smoke-tester, e2e-tester, accessibility-auditor, test-reviewer, refactoring, devops, dependency-auditor, reality-checker, rapid-prototyper, database-architect |
| haiku | claude-haiku-4-5 | handoff-validator, unit-tester, documentation, status |

PM can override model in agent instruction for non-standard tasks.

## Agent audit (every 10 tasks)
If agent consistently underperforms:
1. error patterns — what do failing tasks have in common?
2. instruction misunderstanding — wrong role/task?
3. output format — structural issues?
4. context loss — large tasks degrading?
5. tool misuse — wrong tools?

Fix: add example of WRONG behavior to description + specific rule to prompt body. Log in .claude/decisions/adr-*.md.

## Task file template
```markdown
# TASK-NNN: [name]

## spec
agent: developer|database-architect|devops|architect
track: [name]
complexity: XS|S|M|L|XL
priority: high|medium|low
depends_on: TASK-NNN | none
files: [list]
req: REQ-NNN

description:
[what + acceptance criteria]

## context
[relevant memory excerpts — paths not content]

---
```

## Backlog index format
```markdown
# Backlog

> created: [date] · project: [name] · progress: 0/N done

## Phase 1: [name]
- [ ] TASK-001 [S] feat/auth · track:auth · deps:none → tasks/TASK-001.md
- [x] TASK-002 [M] feat/users · track:users · deps:TASK-001 → tasks/archive/TASK-002.md

## Phase 2: [name]
...
```

## Persistent files

| file | purpose | writer |
|------|---------|--------|
| tz.md | reqs, AC, OQ | BA + agents |
| backlog.md | index of tasks (links only) | PM, decomposer |
| tasks/TASK-NNN.md | full task + handoff | PM + all agents |
| tasks/archive/ | completed tasks | PM |
| memory/stack.md | tech stack | PM, architect |
| memory/patterns.md | code patterns + [recurring] | PM, developer |
| memory/decisions.md | architectural decisions | PM, architect |
| memory/known-issues.md | issues, workarounds + [recurring] | PM, any agent |
| .claude/decisions/adr-*.md | detailed ADRs | architect |
| .claude/locks.json | locked files with timestamp | PM |
| .claude/progress.log | action log + watchdog events | PM |

## New agents in v0.7

| agent | model | when to run |
|-------|-------|-------------|
| ux-interviewer | sonnet | once per project, before ui-designer |
| ui-designer | sonnet | once per project, after ux-interviewer |
| changelog-agent | haiku | end of every task pipeline (before git commit) |
| estimator | sonnet | after decomposer, once per project/phase |
| onboarding | sonnet | once when adopting system on existing project |
| git-workflow | sonnet | replaces PM git steps when using branch workflow |
| env-manager | haiku | when adding env vars or before deploy |
| performance-profiler | sonnet | after implementation for perf-sensitive tasks |
| migration-validator | sonnet | before applying DB migrations to production |
| context-summarizer | haiku | when task file > 200 lines or CONTEXT_OVERFLOW |

## Design workflow
```
ux-interviewer → design-brief.md
ui-designer    → design-spec.md
[all frontend tasks] developer reads design-spec.md automatically
```

## Feature addition workflow
User: "I want to add X" → PM triggers BA in amend mode → tz.md updated → decomposer for new tasks only

## changelog-agent position in pipeline
```
... → Documentation → changelog-agent → RealityChecker → git commit
```

## Auto-deploy
After all gates pass (smoke, lint, review, testing, reality-checker) → deploy to production. Deploy credentials and server info should be stored in a project-specific memory file (never commit actual secrets to git). Verify healthy + HTTP 200 after deploy.

## Complexity levels (L1-L4)

Assess complexity BEFORE starting pipeline. Use this table:

| Level | Description | Scope | Pipeline |
|-------|-------------|-------|----------|
| L1 | Quick Fix | 1 file, <50 lines | Developer → RealityChecker → commit |
| L2 | Enhancement | 2-5 files, <200 lines | Developer → CodeReviewer → RealityChecker → commit |
| L3 | Feature | 5-15 files, 200-1000 lines | Architect → Developer → CodeReviewer + SecurityAnalyst → UnitTester → RealityChecker → commit |
| L4 | Major Feature | 15+ files, >1000 lines | Full pipeline + Consilium at design phase |

L1 skips: BA, Decomposer, SecurityAnalyst, IntegrationTester, Documentation
L2 skips: BA, Decomposer, Architect, SecurityAnalyst, IntegrationTester
L3 skips: BA, Decomposer (unless new project)
L4: full pipeline, Consilium runs before Developer

PM assesses complexity at task start. Write `complexity: L1/L2/L3/L4` in task file header.
If unsure — go one level up.

## Handoff contract (mandatory)

Every agent appends a standardized handoff section to the task file after its work:

```markdown
## handoff: [agent_name]
status: DONE | NEEDS_WORK | BLOCKED
files_changed:
  - path/to/file.ts (lines 42-67) — [what changed]
remaining_questions: none | [list]
validation_points:
  - [what the next agent should verify]
delegate_to: [next_agent] | pm
```

PM validates handoff section exists and is well-formed before delegating to next agent.
Missing handoff → watchdog failure → retry.

## Ralph Loop (context reset)

If an agent returns incomplete or degraded results twice on the same task:

1. Do NOT retry with same context (3rd retry = same failure)
2. Save agent's partial output to task file under `## partial: [agent_name]`
3. Spawn FRESH agent (new context, clean session) with:
   - Original task spec from ## spec
   - Summary of previous attempt: "Previous attempt notes: [what was done, what failed]"
   - Anti-pattern instruction: "Do NOT repeat: [specific failure]"
4. Log ralph-loop event to progress.log
5. If fresh agent also fails → STOP, escalate to user

This is a context reset, not a retry. The agent gets a clean context window.

## Autonomy ladder

Agent autonomy grows with proven reliability. Track per-project, not globally.

| Level | Name | What agent can do | Promote after |
|-------|------|-------------------|---------------|
| A1 | Observer | Read, explain, plan only | — (starting level for new project types) |
| A2 | Narrow Executor | Single file edits, < 50 lines | 3 successful L1 tasks |
| A3 | Workflow Executor | Multi-file, follows known patterns | 5 successful tasks, 0 NEEDS_WORK |
| A4 | Autonomous | Full pipeline without dry-run confirmation | 10 successful tasks, < 10% NEEDS_WORK rate |
| A5 | Delegator | Can coordinate sub-agents | A4 sustained for 20 tasks |

### Autonomy regression triggers
- 2 consecutive NEEDS_WORK → drop one level
- scope creep detected (files changed outside spec.files) → drop one level
- BLOCKED with unclear OQ → drop one level
- Any security incident → reset to A1

### Tracking
Log autonomy level in progress.log:
```
[date] AUTONOMY: project=[name] level=A3 reason=[promote|demote] trigger=[event]
```

New project starts at A2. PM skips dry-run (Step 0.7) only at A4+.

## Update cascade

When a file changes, other files may need sync. PM checks this after developer handoff:

| If changed... | Then also update... |
|---------------|---------------------|
| DB schema / migrations | API types, seed data, model files |
| API endpoints | OpenAPI spec, client SDK, integration tests |
| tz.md requirements | backlog.md, affected task files |
| .claude/agents/*.md | pm-ref.md model table, AGENTS.md |
| CLAUDE.md rules | Re-validate active task files |
| package.json / deps | Lock file, .env.example (new env vars?) |
| Auth / security logic | Security-analyst re-review mandatory |

PM appends cascade checklist to developer handoff validation.

## Escalation matrix

Not all ambiguity is equal. Use this to decide agent-handles vs. human-handles:

| Situation | Action | Who decides |
|-----------|--------|------------|
| Technical choice (library, pattern) | Agent decides, logs in decisions.md | Agent |
| Code style / formatting | Follow existing patterns | Agent |
| Business logic unclear | BLOCKED: OQ-XXX → user | User |
| Security concern found | BLOCKED + notify user immediately | User |
| Performance trade-off | Agent proposes 2-3 options with pros/cons | PM picks or asks user |
| Scope expansion needed | BLOCKED: OQ-XXX [blocker:task] | User |
| Conflicting requirements | BLOCKED: OQ-XXX [blocker:project] | User |
| Agent fails twice (same issue) | Ralph Loop → if still fails, user | PM then user |
| Deploy to production | Auto-deploy if all gates pass | PM (auto) |
| Delete data / drop tables | Always ask user | User |

## Regression metrics

PM reads `.claude/metrics.log` at session start. If metrics show degradation:
- NEEDS_WORK rate > 30% in last 10 tasks → run agent audit
- Scope creep > 2 incidents in last 5 tasks → tighten stop rules
- Ralph loops > 2 in last 10 tasks → check agent instructions for ambiguity