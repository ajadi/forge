---
name: f-audit
description: Launch an adaptive multi-agent audit swarm over a project to find real bugs, security holes, broken/dead code, performance and portability issues. EXPLICIT-INVOKE ONLY (user types /f-audit or asks for a swarm/rai of agents to audit) — it is expensive (spawns a Workflow with many sub-agents). Never auto-trigger.
---

# /f-audit — multi-agent project audit swarm

**EXPENSIVE + EXPLICIT-ONLY.** Run this ONLY when the user explicitly asks (e.g. `/f-audit`, "audit this with a swarm", "rai of agents to test project X"). Never auto-invoke — it spawns a Workflow with many sub-agents and can burn a large number of tokens.

## What it does
Adaptive audit: scout the project → fan out one finder per *discovered* dimension → dedup → batch-verify per dimension (adversarial, refute-default) → ranked, evidence-backed report + token cost. The engine is the bundled Workflow `audit.workflow.js`.

## Invocation / knobs
Parse the user's request into:
- **target** — repo path or `.` (default: current project)
- **scope** — `full` (whole repo) | `diff` (only changes vs main) | `<path>` (a subdir/file). Default `full`.
- **depth** — `quick` (fewer dimensions, criticals only) | `standard` | `thorough` (more finders, includes low). Default `standard`.
- **focus** — `all` | `security` | `correctness` | `performance` | `portability`. Default `all`.

Examples: `/f-audit` → standard full audit of the current project. `/f-audit ../api --scope diff --depth quick --focus security`.

## How to run (orchestrator)
1. Confirm this is an explicit user request (cost!). If depth is unspecified on a large repo, default to `standard` and say so.
2. Invoke the bundled Workflow (background; you are notified on completion):
   ```
   Workflow({ scriptPath: ".claude/skills/f-audit/audit.workflow.js",
              args: { target, scope, depth, focus } })
   ```
3. When it completes, present the report: findings ranked by severity (critical→low) with `file:line`, category, why-it-matters, suggested fix, confidence; plus raw-vs-confirmed counts.
4. **Always report the swarm's token usage** from the completion notification (`subagent_tokens`, `agent_count`) — the user tracks this.

## Cost discipline
- `quick` for a fast PR/diff pass; `thorough` only when explicitly asked.
- The engine already economizes: adaptive dimensions (no wasted finders), read-discipline (grep, not whole-file reads), a severity floor + per-dimension caps, dedup before verify, and **one verifier per dimension** (not one per finding — the single biggest token saver).
- See `severity-rubric.md` for what is / isn't worth reporting.
