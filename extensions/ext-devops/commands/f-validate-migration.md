---
description: Validate a DB migration for production safety — checks rollback plan, data loss risk, lock duration
argument-hint: "[migration file path]"
---

$ARGUMENTS is the migration file path to validate.

Use the migration-validator agent to check the migration for:
- rollback plan completeness
- data loss risks
- lock duration and production impact

Run before applying any DB migration to production.
