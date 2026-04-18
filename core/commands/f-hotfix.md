---
description: Emergency fix workflow bypassing normal PM pipeline. Creates hotfix record, implements minimal fix, collects sign-offs.
argument-hint: "[bug description or BUG-ID]"
allowed-tools: Read, Glob, Grep, Write, Edit, Bash
context: fork
---



> **Explicit invocation only.** Do not auto-invoke based on context.

## 1. Assess severity

Read the description or BUG-ID. Determine:
- **S1 (Critical)**: data loss, security vulnerability, system unusable — fix immediately
- **S2 (Major)**: significant feature broken, workaround exists — fix within 24h
- **S3 or lower**: recommend normal `pm` pipeline instead, stop here

## 2. Create hotfix record

Write to `handoffs/hotfixes/hotfix-[YYYYMMDD]-[short-name].md`:

```markdown
# Hotfix: [Short Description]
Date: [Date]
Severity: [S1/S2]
Status: IN PROGRESS

## Problem
[What is broken and the impact]

## Root Cause
[To be filled during investigation]

## Fix
[To be filled during implementation]

## Testing
[What was tested and how]

## Approvals
- [ ] Fix reviewed by code-reviewer agent
- [ ] Regression check passed
- [ ] User approved deployment

## Rollback Plan
[How to revert if the fix causes new issues]
```

Ask user: "Write to `handoffs/hotfixes/hotfix-[date]-[name].md`?"

## 3. Create hotfix branch (if git initialized)

```bash
git checkout -b hotfix/[short-name]
```

## 4. Implement fix

Rules:
- **Minimum change** that resolves the issue — no cleanup, no refactoring, no opportunistic fixes
- Run targeted tests for the affected code after the fix
- Check for regressions in adjacent systems

## 5. Run code-reviewer agent

Pass only the changed files. Collect verdict.

## 6. Update record

Fill in root cause, fix details, test results.

## 7. Output summary

```
## Hotfix Summary
Severity: [S1/S2]
Root cause: [brief]
Fix: [brief]
Tests: [passed/failed]
Branch: hotfix/[name]
Next: [merge to main + backport to dev branch, or describe what's pending]
```

## Rules
- Hotfix = minimum change. No scope creep.
- Every hotfix must document rollback plan before deployment.
- After deploy: post-incident review within 48h (add to backlog as task).
- Merge to BOTH main and dev/feature branch if both exist.
