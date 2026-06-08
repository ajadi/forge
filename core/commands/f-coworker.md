---
description: Delegate a bulk read / summarize to coworker (grok) — keep the reasoning model's context free
argument-hint: "<question> -- <path> [more paths...]"
allowed-tools: Bash, Read, Agent
---

# Delegate to coworker (grok)

$ARGUMENTS

Interpret the arguments above as a QUESTION plus one or more file PATHS (the `--` separator is optional; infer paths from tokens that look like file paths). Then delegate the read to the cheap off-subscription grok model instead of pulling the files into your own context:

```bash
coworker ask --paths <path1> [<path2> ...] --allow-code --profile code --question "<question>"
```

## Rules
- **Batch all paths into one `--paths` list.** This is the main use: several files that are each under the read-gate's per-file threshold but together would bloat context. The gate is per-file and stateless — it will not catch the cumulative load; this command does.
- Default `--profile code` (non-reasoning grok, cheapest). For cross-file synthesis or call-graph-style reasoning use `--profile digest` (reasoning grok).
- Relay coworker's answer concisely. Do **not** re-read the files yourself afterwards.
- Source code you must reason over line-by-line: read it directly instead — coworker is for bulk / non-critical reads.
- If coworker is unavailable (not installed / `🟥` out of credits / `COWORKER_READ_GATE=off`), say so and fall back to reading directly.

## Fallback (grok down)
If `coworker` is unavailable — not installed, `🟥` out of credits (`.grok-broke` flag), or the call exits non-zero — do NOT read the files on the main (expensive) model. Spawn a **Haiku** subagent (Agent tool, `subagent_type: general-purpose`, `model: haiku`) to read the given paths and answer the question, then prefix your reply to the user with `⚠️ grok unavailable — fell back to Haiku.` so they know the fallback fired.
