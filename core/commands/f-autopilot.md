---
description: Autopilot — run the backlog end-to-end unattended; PM chains tasks and only halts on hard stops, then notifies you
---

Unattended autopilot run. Use when you're stepping away and want Forge to work
through the backlog on its own.

This OVERRIDES the default "one task per session, stop after each" rule. Confirm
the user really wants unattended execution before starting (they invoked this
command, so a one-line "starting autopilot — I'll run the backlog and stop only
on questions/regressions/deploys" is enough; do not ask for per-task dry-runs).

Steps:

1. Write the autopilot flag so PM and the statusline know:
   ```bash
   echo "$(date +%s) | autopilot: $ARGUMENTS" > .claude/.autopilot
   ```
2. Run the `pm` agent in autopilot mode (see pm.md "Autopilot mode"): PM selects
   the next ready task, runs the full pipeline through reality-check + commit,
   and instead of stopping, picks the next ready task and continues — looping
   until a HARD STOP.

HARD STOPS (PM clears `.claude/.autopilot`, then STOPS and reports — the Claude
Code push notification fires on idle so you're pinged):
- Open OQ / BLOCKED (business logic unclear — needs your answer)
- Test regression, or a Ralph-loop that exhausted retries
- A production-deploy step (never auto-deploy — see production-safety.md)
- No ready tasks left (backlog done) — report "autopilot complete: N tasks"

Guardrail for this run: **run to the end of the backlog** (no task/budget cap).
All quality gates and the role-write-guard / stop-check hooks stay active — they
are what makes unattended execution safe.

$ARGUMENTS may carry a note (e.g. "only the auth track") — pass it as scope to PM.
