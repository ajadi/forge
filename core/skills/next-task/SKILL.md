---
name: next-task
description: Show which task to work on next based on priority and dependencies. Use when the user asks "what should I do next", "what's the next task", or "what should we work on".
user-invocable: true
allowed-tools: Read, Glob
model: haiku
---

Read `backlog.md`. Find the best next task:

1. Skip tasks with `status: done` or `status: in_progress`
2. Skip tasks where `depends_on` tasks are not yet done
3. Skip tasks whose track is locked in `locks.json`
4. Among remaining: sort by priority (high > medium > low), then by shortest estimated effort

Output:
```
▶ Next task: TASK-NNN — [name]
   Priority: high/medium/low | Track: [track] | Complexity: XS/S/M/L/XL
   Why: [one sentence — unblocks most / highest priority / etc.]

Also ready:
   • TASK-NNN — [name] (priority)
   • TASK-NNN — [name] (priority)
```

If nothing is ready (all blocked or done): say so clearly with reason.
