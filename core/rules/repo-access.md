# Rule: Repo Access

## Why this exists

Forge installs a lot of state into a project: agents, hooks, palace memory,
task files, retrospectives, decision logs. In a single-user repo that's fine
— it's the agent's working memory. In a shared or public repo it's a leak:
internal reasoning, half-baked plans, and timestamps end up in branch history
where reviewers and outsiders can read them.

`repo_access` tells Forge whether framework state is allowed in git.

## Where it's set

`manifest.md` at the project root:

```
project_name=...
repo_access=private-solo
framework=forge
```

## Modes

### `private-solo`
Single-user repo. Framework state is committed to git — your full working
context becomes part of history. This is the default after `install.sh`.

**What is committed:** `.claude/`, `CLAUDE.md`, `manifest.md`, `memory/`, `tasks/`.

### `private-shared`
Team repo where teammates don't run Forge. Framework state stays local — git
sees only the product (source code, docs, configs).

### `public`
Open-source / public repo. Same effect as `private-shared`: framework state is
local-only.

## How to switch modes

```bash
scripts/switch-repo-access.sh public --commit
scripts/switch-repo-access.sh private-shared --commit
scripts/switch-repo-access.sh private-solo --commit
```

The script:
1. Updates `repo_access=` in `manifest.md`.
2. Toggles the `framework-public-ignore` block in `.gitignore`.
3. In shared/public mode: runs `git rm --cached` on framework paths.
4. Commits the transition (with `--commit`).

## Hard stop: framework files already pushed

If `repo_access` was `private-solo` and `.claude/` / `memory/` / `tasks/`
already exist in upstream history, `.gitignore` alone won't clean them up.
The switch script detects this and aborts. Options:

- Cut a fresh branch from before the framework commits.
- `git filter-repo` / `git filter-branch` to rewrite history (destructive — coordinate with collaborators).

## Agent behavior by mode

| Action | private-solo | private-shared / public |
|---|---|---|
| Commit framework files | Yes | No (local-only) |
| `pre-compact` hook commits framework state | Yes | No — hook stops if framework still tracked |
| `validate-push` blocks framework leak | No | Yes |
| MemPalace diary / palace lives in repo | Yes | No (lives in `.claude/`, gitignored) |

## Quick check

```bash
scripts/framework-state-mode.sh repo-access
scripts/framework-state-mode.sh check-safe-mode
```

Exit code 0 = safe. Exit code 2 = shared/public mode but framework files are
still tracked — run `switch-repo-access.sh` again.
