---
paths:
  - "**/deploy/**"
  - "**/infra/**"
  - "**/production/**"
  - "**/.env.production"
  - "**/Dockerfile"
  - "**/docker-compose.prod*"
  - "**/.github/workflows/**"
  - "**/.gitlab-ci.yml"
---

# Rule: Production Safety

## Principle

Anything touching production requires explicit user confirmation. Everything
else runs autonomously per the L1-L4 pipeline.

## Requires user confirmation

- Deploy to production server
- Production database changes (migrations, data fixes)
- DNS / domain / SSL changes
- Production environment variables
- `git push` to main/master when main is the production branch
- Package publication (`npm publish`, PyPI upload, crate publish)
- CI/CD pipeline changes that affect production deploys

## Full autonomy (don't ask)

- File creation / edits / deletes inside the project
- Running tests (unit, integration, E2E)
- Local git: commit, branch, merge (except production push)
- Staging deploys
- Local development & dependency installs
- Refactoring, doc updates

## How to ask

Short. No filler:

```
Production deploy ready:
- [what gets deployed]
- [changes summary]
Proceed? (y/n)
```

## Migration safety

Before any production migration, the migration-validator agent (ext-devops)
runs a checklist:

- Rollback plan present
- No silent data loss
- Lock duration estimated
- Deploy window matches business hours rule (if any)

PM blocks the deploy if migration-validator returns `NEEDS_WORK`.
