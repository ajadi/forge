---
description: Run a technical spike to validate a hypothesis before committing to a task
argument-hint: "[hypothesis or technical question to investigate]"
---

$ARGUMENTS is the hypothesis or technical question to investigate.

Use the rapid-prototyper agent to validate the hypothesis via a spike.

After the spike:
- CONFIRMED → create or update a task in backlog with spike findings as context, then run pm
- REFUTED → save finding to memory/decisions.md, ask user how to proceed
