# Rule: Commit Policy

## Principle

Agents decide what to commit. Don't ask the user. Stage specific files —
never `git add .` or `git add -A`.

What gets committed depends on `manifest.md` → `repo_access`. See
`repo-access.md` for the model.

## Modes

### `private-solo`
Commit everything that isn't on the "never" list below. Framework state
(`.claude/`, `memory/`, `tasks/`, `CLAUDE.md`, `manifest.md`) goes in.

### `private-shared` / `public`
Commit only the product:

**Yes:**
- Source code (`src/`, `lib/`, `app/`, `pages/`)
- User-facing docs (`README.md`, `CHANGELOG.md`, `docs/`)
- Project configs (`package.json`, `pyproject.toml`, `tsconfig.json`)
- Migrations, schemas, production tests
- `.gitignore`, `LICENSE`

**No (framework state stays local):**
- `.claude/` — agents, hooks, settings, palace
- `memory/` — long-term notes, decisions
- `tasks/` — task files, retrospectives
- `CLAUDE.md` — project doctrine (treat as internal)

`scripts/switch-repo-access.sh` handles the `.gitignore` toggle and the
`git rm --cached` on framework paths. Don't edit `.gitignore` by hand.

## Never commit (any mode)

These files don't belong in git regardless of mode:

- `.env`, `.env.*` (except `.env.example`)
- `*.key`, `*.pem`, `*.p12`
- `credentials.json`, `secrets/`, `*secret*`
- `.claude/settings.local.json`
- `.claude/locks.json` — runtime lock state
- `.claude/metrics.log`, `.claude/logs/`
- `.claude/backup-*/`
- `.claude/CLAUDE.md.merge-proposal.md`
- `CLAUDE.local.md`
- `*.db`, `*.sqlite`, `*.sqlite3`
- `node_modules/`, `__pycache__/`, `.venv/`
- `dist/`, `build/`, `*.egg-info/`

If the project is missing these from `.gitignore`, add them automatically.

## Pre-push check

Before `git push`, scan `git diff --name-only origin/main..HEAD`:

- Any `.env*` / secret files? — `git rm --cached`, update `.gitignore`, warn user.
- In shared/public mode, any framework paths? — same: untrack and warn.
- Validate-push hook does this automatically when installed.

## Commit messages

- One commit per logical change.
- Imperative mood: "add X", "fix Y", "refactor Z".
- L1-L2 tasks: single commit per task.
- L3+: commit per agent handoff (developer commits implementation,
  unit-tester commits tests, etc.). PM owns commit timing.
