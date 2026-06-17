---
description: Actualize Forge against Anthropic's live platform docs — fetch platform.claude.com, map Forge's current mechanisms, propose where native primitives should replace home-grown machinery. Propose-only; does live web fetches (explicit-invoke).
---

Run the platform-sync analysis via the platform-sync subagent.

$ARGUMENTS

Invoke the `platform-sync` subagent to fetch Anthropic's platform docs (starting from `platform.claude.com/llms.txt`), map Forge's current state from this repo, and return a prioritized report of adoption proposals — honestly split into directly-adoptable-now / pattern-level-only / API-only-not-applicable-in-Claude-Code.

Cheaper than `/f-audit` (single agent, no Workflow swarm) but still does live web fetches — explicit-invoke only, never auto-trigger. Propose-only: the report is for the user to act on; no framework files are edited.

Use subagent: platform-sync
Mode: bypassPermissions
