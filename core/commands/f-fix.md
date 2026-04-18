---
description: Quick fix — run pm agent on a specific task without full dry-run ceremony
---

$ARGUMENTS is the task ID (e.g. TASK-005) or a brief description of what to fix.

If task ID provided: read tasks/$ARGUMENTS.md and resume from current pipeline step.
If description provided: find matching pending task in backlog.md, then run pm agent on it.

Skip dry-run confirmation for fixes — go directly.
