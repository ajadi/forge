# coworker — read-delegation setup

Forge delegates **large non-source reads** (docs, specs, logs, generated/boilerplate)
to [`coworker`](https://github.com/Arcanada-one/coworker), a cheap-model CLI
(DeepSeek / Moonshot). This keeps the reasoning model's context for source code.

The `coworker-read-gate` hook (`.claude/hooks/coworker-read-gate.sh`) enforces it on
the `Read` tool. It **fails open** — if `coworker` is not installed or configured,
reads are allowed normally — so this setup is optional but recommended.

> Exact flag/field names below may differ by `coworker` version. Confirm against
> `coworker --help` and the repo README; the structure is what matters.

## 1. Install

```bash
pip install git+https://github.com/Arcanada-one/coworker
coworker --version
```

## 2. API keys — environment variables only

**Never commit keys.** Set them in your shell profile / environment:

```bash
# DeepSeek
export DEEPSEEK_API_KEY="sk-..."
# Moonshot (Kimi)
export MOONSHOT_API_KEY="sk-..."
```

On Windows (PowerShell), set them as user environment variables instead:

```powershell
setx DEEPSEEK_API_KEY "sk-..."
setx MOONSHOT_API_KEY "sk-..."
```

## 3. Providers & profiles

`coworker` reads provider/profile config (typically `~/.coworker/providers.yaml`
and `profiles.yaml`, or a project-local equivalent). Reference these by name, with
the actual secret pulled from the env var — no inline keys.

`providers.yaml` (example shape):

```yaml
providers:
  deepseek:
    base_url: https://api.deepseek.com
    api_key_env: DEEPSEEK_API_KEY
    model: deepseek-chat
  moonshot:
    base_url: https://api.moonshot.cn/v1
    api_key_env: MOONSHOT_API_KEY
    model: moonshot-v1-128k
```

`profiles.yaml` (example shape — a cheap profile for read/summarize):

```yaml
profiles:
  read:                # used by the read-gate delegation
    provider: deepseek
    max_tokens: 2048
    temperature: 0
```

## 4. Signal passthrough (so `git push` doesn't hang)

`coworker`'s real-toolkit (`rtk`) can intercept shell calls. Enable it and allow the
**signal/no-op commands to pass straight through** — otherwise interactive or
network commands like `git push` block waiting on the wrapper.

```bash
coworker rtk enable
```

Passthrough allowlist (commands `coworker` must NOT intercept — they run directly):

```
git push
git pull
git status
git rev-parse
gh pr
gh release
gh run
```

Add these to the `rtk` allowlist per `coworker rtk --help` (e.g. an
`allow:`/`passthrough:` list in the rtk config). Verify with a dry run:

```bash
git status        # must return immediately, not via the wrapper
git rev-parse HEAD
```

## 5. How Forge uses it

- Agents (esp. `business-analyst`, `context-summarizer`) delegate large non-source
  reads:
  ```bash
  coworker ask "summarize the auth flow described here" --file docs/architecture.md
  ```
- The read-gate hook blocks an in-context `Read` of a large non-source file and
  prints the exact `coworker ask` command to run instead.

## 6. Tuning the gate

Environment variables (all optional):

| Var | Default | Meaning |
|-----|---------|---------|
| `COWORKER_READ_GATE` | `on` | set `off` to disable the gate entirely |
| `COWORKER_TOKEN_DIVISOR` | `4` | bytes-per-token estimate (`est_tokens = bytes / divisor`) |
| `COWORKER_DELEGATE_TOKENS` | `10000` | non-source reads at/above this → delegate to coworker |
| `COWORKER_GREP_TOKENS` | `100000` | non-source reads at/above this → grep-only (blocked) |

Source files (code) are always exempt regardless of size.
