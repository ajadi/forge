---
description: Create a structured bug report from description, or analyze a file for potential bugs.
argument-hint: "[description] OR analyze [path]"
allowed-tools: Read, Glob, Grep, Write
---



## Usage

- `/bug-report [description]` — create report from user's description
- `/bug-report analyze [path]` — scan file/directory for potential bugs

---

## Mode 1: From description

1. Parse the description for key info
2. Search codebase with Grep/Glob for related files to add context
3. Generate the report:

```markdown
# Bug Report

## Summary
**Title**: [Concise title]
**ID**: BUG-[NNNN]
**Severity**: [S1-Critical / S2-Major / S3-Minor / S4-Trivial]
**Priority**: [P1-Immediate / P2-Next Sprint / P3-Backlog / P4-Wishlist]
**Status**: Open
**Reported**: [Date]

## Classification
- **Category**: [Logic / UI / API / DB / Auth / Performance / Crash / Data]
- **System**: [Which subsystem is affected]
- **Frequency**: [Always / Often >50% / Sometimes 10-50% / Rare <10%]
- **Regression**: [Yes/No/Unknown]

## Environment
- **Commit/Version**: [git rev-parse --short HEAD]
- **Platform**: [OS / runtime]
- **Context**: [Relevant state — user role, data conditions, etc.]

## Reproduction Steps
**Preconditions**: [Required state]

1. [Step 1]
2. [Step 2]
3. [Step 3]

**Expected**: [What should happen]
**Actual**: [What actually happens]

## Technical Context
- **Likely affected files**: [From codebase search]
- **Related systems**: [Other systems that may be involved]
- **Possible root cause**: [If identifiable]

## Notes
[Additional context]
```

4. Ask user: "Save to `handoffs/bugs/BUG-[NNNN].md`?"
5. If yes — write file and suggest adding a task to backlog via `/new-task`

---

## Mode 2: Analyze file

1. Read the target file(s)
2. Identify potential bugs:
   - Null/undefined references
   - Off-by-one errors
   - Race conditions / concurrency issues
   - Unhandled edge cases and error paths
   - Resource leaks
   - Incorrect state transitions
   - SQL injection / XSS / other security issues
3. For each finding — generate a mini bug report with:
   - Line reference
   - Trigger scenario
   - Recommended fix
4. Ask user which findings to save as full bug reports
