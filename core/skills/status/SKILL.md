---
name: status
description: Show current project status — backlog progress, active tasks, open questions. Use when the user asks about project state, what's done, what's in progress, or what's next.
user-invocable: true
allowed-tools: Read, Glob
model: haiku
---

Show a concise project snapshot. Read these files (skip missing ones):

1. `backlog.md` — count `- [ ]` (open) and `- [x]` (done) tasks
2. `tasks/*.md` (not archive/) — find any with `status: in_progress`
3. `tz.md` — count `⏳ open` questions

Output format:
```
📊 Project Status

Backlog: X done / Y total (Z open)
In progress: TASK-NNN — [name]   (or "none")
Open questions: N   (or skip if 0)

Next ready: TASK-NNN (priority) — [one-line description]
```

Keep it under 10 lines. No verbose explanations.
