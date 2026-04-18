# PM Reference Tables (Forge v1.0)

Lookup tables for PM agent. No workflow here — workflow is in pm.md.

## Complexity levels (L1-L4)

| Level | Scope | Pipeline |
|-------|-------|----------|
| L1 Quick Fix | 1 file, <50 lines | Developer → RealityChecker → commit |
| L2 Enhancement | 2-5 files, <200 lines | Developer → CodeReviewer → RealityChecker → commit |
| L3 Feature | 5-15 files, 200-1000 lines | Architect → Developer → CodeReviewer + SecurityAnalyst → UnitTester → RealityChecker → commit |
| L4 Major | 15+ files, >1000 lines | Full pipeline + Consilium at design phase |

L1 skips: BA, Decomposer, SecurityAnalyst, IntegrationTester, Documentation
L2 skips: BA, Decomposer, Architect, SecurityAnalyst, IntegrationTester
L3 skips: BA, Decomposer (unless new project)
If unsure — go one level up.

## Estimation → Pipeline mapping

| complexity | architect | developer model | unit tests | retry limit |
|-----------|-----------|----------------|------------|-------------|
| XS | skip | sonnet | no | 2 |
| S | skip | sonnet | no | 2 |
| M | optional | sonnet | per task | 3 |
| L | required | sonnet | yes | 3 |
| XL | required | opus | yes | 3 |

## Models

| tier | model | agents |
|------|-------|--------|
| opus | claude-opus-4-6 | pm, architect (L/XL), developer (XL override) |
| sonnet | claude-sonnet-4-6 | developer, ba, decomposer, code-reviewer, security-analyst, integration-tester, smoke-tester, e2e-tester, accessibility-auditor, test-reviewer, refactoring, devops, dependency-auditor, reality-checker, rapid-prototyper, database-architect, retro |
| haiku | claude-haiku-4-5 | handoff-validator, unit-tester, documentation, status |

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
```

## Handoff contract (mandatory)

Every agent appends after its work:
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

## Autonomy ladder

| Level | Name | Capability | Promote after |
|-------|------|-----------|---------------|
| A1 | Observer | Read, explain, plan only | — (new domain) |
| A2 | Narrow Executor | Single file, < 50 lines | 3 successful L1 tasks |
| A3 | Workflow Executor | Multi-file, known patterns | 5 tasks, 0 NEEDS_WORK |
| A4 | Autonomous | Full pipeline, no dry-run | 10 tasks, < 10% NEEDS_WORK |
| A5 | Delegator | Coordinates sub-agents | A4 sustained for 20 tasks |

Regression: 2x NEEDS_WORK → drop level. Scope creep → drop level. Security incident → reset to A1.
New project starts at A2. Skip dry-run only at A4+.

## Update cascade

| If changed... | Then also update... |
|---------------|---------------------|
| DB schema / migrations | API types, seed data, model files |
| API endpoints | OpenAPI spec, client SDK, integration tests |
| tz.md requirements | backlog.md, affected task files |
| .claude/agents/*.md | pm-ref.md model table, AGENTS.md |
| CLAUDE.md rules | Re-validate active task files |
| package.json / deps | Lock file, .env.example (new env vars?) |
| Auth / security logic | Security-analyst re-review mandatory |

## Escalation matrix

| Situation | Who decides |
|-----------|------------|
| Technical choice (library, pattern) | Agent — logs in decisions.md |
| Code style / formatting | Agent — follow existing patterns |
| Business logic unclear | User — BLOCKED: OQ-XXX |
| Security concern found | User — BLOCKED + notify immediately |
| Performance trade-off | PM picks or asks user |
| Scope expansion needed | User — BLOCKED: OQ-XXX [blocker:task] |
| Conflicting requirements | User — BLOCKED: OQ-XXX [blocker:project] |
| Agent fails twice | PM Ralph Loop → if still fails, user |
| Delete data / drop tables | User — always confirm |

## Persistent files

| file | purpose | writer |
|------|---------|--------|
| tz.md | reqs, AC, OQ | BA + agents |
| backlog.md | index of tasks | PM, decomposer |
| tasks/TASK-NNN.md | full task + handoff | PM + all agents |
| tasks/archive/ | completed tasks | PM |
| memory/stack.md | tech stack | PM, architect |
| memory/patterns.md | code patterns + [recurring] | PM, developer |
| memory/decisions.md | architectural decisions | PM, architect |
| memory/known-issues.md | issues, workarounds + [recurring] | PM, any |
| .claude/locks.json | locked files | PM |
| .claude/progress.log | action log | PM |
| .claude/metrics.log | regression metrics | session-stop hook |

## Regression metrics

PM reads `.claude/metrics.log` at session start:
- NEEDS_WORK rate > 30% in last 10 tasks → run agent audit
- Scope creep > 2 incidents in last 5 tasks → tighten stop rules
- Ralph loops > 2 in last 10 tasks → check agent instructions

## Agent audit (every 10 tasks)

Check: error patterns, instruction misunderstanding, output format, context loss, tool misuse.
Fix: add WRONG behavior example to agent description + specific rule. Log in .claude/decisions/adr-*.md.
