---
description: Detect scope creep by comparing tz.md REQs against actual backlog and implementation. Flags additions, quantifies bloat, recommends cuts.
argument-hint: "[REQ-NNN | phase-N | all]"
allowed-tools: Read, Glob, Grep, Bash
---



## 1. Parse argument

- `REQ-NNN` — check scope for specific requirement
- `phase-N` — check all REQs in a backlog phase
- `all` — full project scope check (default if no argument)

## 2. Read original scope

From `tz.md`:
- Extract each REQ with its acceptance criteria and stated scope
- Note explicit out-of-scope items
- Note constraints (budget, deadline, tech limitations)

## 3. Read current scope

From `backlog.md` and `tasks/TASK-*.md`:
- List all tasks per REQ (via `req:` field in task spec)
- Check task descriptions for scope expansions vs original REQ
- Scan `tasks/TASK-*.md` for added acceptance criteria not in tz.md
- Check `progress.log` for WATCHDOG events (often caused by scope drift)

From codebase (if source exists):
- `git log --oneline` since first task commit
- Look for commits unlinked to any TASK

## 4. Compare and output

```markdown
## Scope Check: [REQ / Phase / Project]
Generated: [Date]

### Original Scope (from tz.md)
[List of REQs and their acceptance criteria]

### Current Scope (from backlog + tasks)
[List of tasks mapped to REQs]

### Scope Additions (not in original tz.md)
| Addition | Task | When Added | Justified? | Effort |
|----------|------|-----------|------------|--------|
| [item] | TASK-NNN | [date] | Yes/No/? | [size] |

### Scope Removals (in tz.md but dropped)
| Removed | Reason | Impact |
|---------|--------|--------|
| [REQ-NNN criterion] | [why] | [what's affected] |

### Bloat Score
- Original REQ criteria: N
- Current task count covering those REQs: N
- Tasks with no REQ link: N (potential gold-plating)
- Net scope change: +/-N%

### Risk
- Schedule Risk: Low/Medium/High — [reason]
- Quality Risk: Low/Medium/High — [reason]

### Recommendations
1. Cut: [tasks that can be removed without breaking REQ acceptance criteria]
2. Defer: [tasks that can move to next phase]
3. Flag: [items needing explicit user decision]
```

## 5. Verdict

- **On Track**: scope within 10% of tz.md
- **Minor Creep**: 10–25% — manageable with small adjustments
- **Significant Creep**: 25–50% — cut or extend timeline
- **Out of Control**: >50% — stop and re-plan with BA agent

## Rules
- Unlinked tasks (no `req:` field) are automatically flagged as potential scope creep
- Not all additions are bad — some are discovered requirements. They must be acknowledged.
- Always quantify: "+35% tasks" is actionable, "seems bigger" is not.
- Recommend cuts based on REQ acceptance criteria — preserve what's needed, cut nice-to-haves.
