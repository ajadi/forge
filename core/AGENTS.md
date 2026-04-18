# Agent Roster

> Auto-generated for Forge v2.0. PM reads this to understand team capabilities.
> Each agent reads this to understand its boundaries and neighbors.

## Core Agents

| Agent | Role | Model | When to use | Cannot do |
|-------|------|-------|-------------|-----------|
| pm | Orchestrator | opus | Every task — routes, delegates, gates | Never implements code, never edits source files |
| developer | Executor | sonnet | L1-L4 implementation | Cannot modify pm-ref.md, CLAUDE.md, or agent definitions |
| code-reviewer | Reviewer | sonnet | L2+ after developer | Read-only — no code edits, no fixes |
| reality-checker | Gate | sonnet | Final check before commit | Read-only — default NEEDS_WORK, PASS requires evidence |
| architect | Designer | opus | L3-L4, new API/DB/schema | Read-only — no implementation, no code |
| business-analyst | Analyst | sonnet | Project start, new features | Cannot make business decisions — only surfaces questions |
| decomposer | Planner | sonnet | New project, major feature | Cannot implement tasks it creates |
| handoff-validator | Validator | haiku | Before pipeline starts | Read-only — validates task file completeness |
| unit-tester | Tester | sonnet | L3+ with business logic | Cannot change production code — only test files |
| database-architect | DB Designer | sonnet | DB schema changes, migrations | Cannot deploy migrations to production |
| rapid-prototyper | Spike Runner | sonnet | Technical uncertainty | Code is throwaway — cannot commit to main |
| context-summarizer | Compressor | sonnet | Task file > 200 lines | Cannot compress ## spec or ## context sections |
| status | Reporter | haiku | Project state snapshot | Read-only — no modifications |

## Extension Agents

### ext-security
| Agent | Role | Model | Cannot do |
|-------|------|-------|-----------|
| security-analyst | Auditor | sonnet | Read-only — no code fixes |
| dependency-auditor | CVE Scanner | sonnet | Cannot upgrade packages — only reports |

### ext-frontend
| Agent | Role | Model | Cannot do |
|-------|------|-------|-----------|
| smoke-tester | UI Verifier | sonnet | Cannot fix UI issues |
| e2e-tester | Flow Tester | sonnet | Cannot modify production code |
| ui-designer | Design System | sonnet | Cannot implement — only produces design-spec.md |
| ux-interviewer | UX Discovery | sonnet | Cannot make design decisions without user input |
| accessibility-auditor | A11y Auditor | sonnet | Read-only — reports issues only |

### ext-devops
| Agent | Role | Model | Cannot do |
|-------|------|-------|-----------|
| devops | Infra Builder | sonnet | Cannot deploy to production without PM approval |
| env-manager | Env Sync | haiku | Cannot write actual secrets |
| git-workflow | Branch Manager | sonnet | Cannot merge without reality-checker PASSED |
| migration-validator | Migration Safety | sonnet | Read-only — validates, cannot modify migrations |

### ext-quality
| Agent | Role | Model | Cannot do |
|-------|------|-------|-----------|
| performance-profiler | Perf Analyzer | sonnet | Read-only — reports metrics, no fixes |
| refactoring | Debt Reducer | sonnet | Cannot change behavior — only structure |
| test-reviewer | Test Auditor | haiku | Read-only — reviews test quality |
| integration-tester | Integration Tester | sonnet | Cannot change production code |

### ext-docs
| Agent | Role | Model | Cannot do |
|-------|------|-------|-----------|
| documentation | Doc Writer | haiku | Cannot change code — only docs |
| changelog-agent | Changelog Writer | haiku | Cannot modify code or tests |

### ext-planning
| Agent | Role | Model | Cannot do |
|-------|------|-------|-----------|
| estimator | Timeline Builder | sonnet | Cannot modify tasks or backlog |
| consilium | Design Panel | sonnet | Read-only — multi-perspective advice only |

### ext-reflection
| Agent | Role | Model | Cannot do |
|-------|------|-------|-----------|
| reflect | Retrospective | sonnet | Can only propose changes, never apply |
| dream | Memory Consolidator | sonnet | Cannot delete memory without marking superseded |
| optimizer | Framework Auditor | sonnet | Structural changes = propose only, never apply |
| retro | Phase Retrospective | sonnet | Append-only to memory files, never overwrite |
| onboarding | Project Scanner | sonnet | Cannot overwrite existing memory files |

## Handoff Contract

Every agent appends a standardized handoff section to the task file:

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

## Escalation Rules

| Situation | Who decides |
|-----------|------------|
| Technical choice (library, pattern) | Agent decides, logs in decisions.md |
| Business logic unclear | BLOCKED: OQ-XXX → user |
| Security concern found | BLOCKED + PM notifies user immediately |
| Performance trade-off | Agent proposes options, PM picks |
| Scope expansion needed | BLOCKED: OQ-XXX [blocker:task] |
| Conflicting requirements | BLOCKED: OQ-XXX [blocker:project] |
| Agent repeatedly fails (2x) | PM escalates to user with diagnostics |
