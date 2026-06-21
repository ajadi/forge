# coworker — read-delegation setup

Forge delegates **large non-source reads** (docs, specs, logs, generated/boilerplate)
to [`coworker`](https://github.com/Arcanada-one/coworker), a cheap-model CLI backed by
**xAI Grok**. This keeps the reasoning model's context for source code.

The `coworker-read-gate` hook (`.claude/hooks/coworker-read-gate.sh`) enforces it on
the `Read` tool. **Forge never requires coworker** — the gate **fails open**: if
`coworker` is not installed/configured, every read is allowed normally. You opt in
for the token savings, which means standing up a second (paid) model. Full fail-open
behavior is in §8; out-of-credits handling in §9; what leaves your machine in §10.

> Everything below is verified against `coworker-cli` 0.7.0 (2026-06-05).

## 1. Install

```bash
pip install "git+https://github.com/Arcanada-one/coworker"   # installs the `coworker` command (+ openai)
coworker --help        # subcommands: ask, write, stats, debug, rtk
```

## 2. API key — environment variable only

**Never commit keys.** coworker reads the key from the env var named by the provider's
`env_key` (below). For xAI:

```bash
export XAI_API_KEY="xai-..."          # get one at https://console.x.ai
```
Windows (PowerShell), persist at user scope:
```powershell
setx XAI_API_KEY "xai-..."
setx PYTHONUTF8 "1"                    # coworker output/rtk help crash on cp125x consoles without this
setx PYTHONIOENCODING "utf-8"
setx COWORKER_DEFAULT_PROVIDER "xai"   # optional: default provider when a profile/flag doesn't set one
```

## 3. Config files (required)

coworker reads two YAML files from `$XDG_CONFIG_HOME/coworker/` — on Windows that is
`C:\Users\<you>\.config\coworker\`. Both are required; `ask`/`write` error if missing.

`providers.yaml` — OpenAI-compatible endpoints; the secret is pulled from `env_key`,
never inline. List the models a key can use:
`curl -s https://api.x.ai/v1/models -H "Authorization: Bearer $XAI_API_KEY"`.
For cheap read/summarize pick a **non-reasoning** model. Verified 2026-06-05:
`grok-4.20-0309-non-reasoning` (recommended), `grok-4.3`, `grok-4.20-0309-reasoning`.

```yaml
xai:
  base_url: https://api.x.ai/v1
  env_key: XAI_API_KEY
  default_model: grok-4.20-0309-non-reasoning
```

`profiles.yaml` — `system_prompt` + `recommended_provider` per profile (`ask` defaults
to profile `code`, `write` to `write`). Optional: `default_max_tokens_ask` /
`default_max_tokens_write`.

```yaml
code:
  recommended_provider: xai
  system_prompt: >
    Answer strictly from the corpus, concise and factual. If it's not in the
    corpus, say so. Do not invent details.
write:
  recommended_provider: xai
  system_prompt: >
    Generate the requested file body only — no commentary or code fences unless asked.
```

Provider resolution order: `--provider` flag → `profile.recommended_provider` →
`COWORKER_DEFAULT_PROVIDER` → `moonshot` (built-in default).

## 4. Usage

```bash
# Summarize / query a corpus (this is what the read-gate hook tells you to run):
coworker ask --paths docs/architecture.md --question "summarize the auth flow" --profile code

# Generate a file from a spec + context:
coworker write --spec "a CONTRIBUTING guide" --context README.md --target CONTRIBUTING.md

coworker stats --since 7d        # token/cost usage
```

**File gate:** by default `--paths`/`--context` accept only `.md` / `.markdown` / `.txt`.
For other text (logs, json, csv, yaml) add **`--allow-code`** (or `COWORKER_ALLOW_CODE=1`);
overrides are logged. The Forge read-gate's suggested command already includes `--allow-code`.

## 5. Forge integration

- The read-gate hook blocks an in-context `Read` of a large non-source file and prints the
  exact command: `coworker ask --paths "<file>" --question "<question>" --allow-code`.
- `business-analyst` and `context-summarizer` delegate large non-source reads the same way.
- Source files are always exempt — the reasoning model reads its own code.

## 6. RTK (optional shell-output compressor)

`coworker rtk {install,enable,disable,status,passthrough}` manages the **Rust Token Killer**,
which pipes shell tool output through `rtk` before it reaches Claude Code's context.

- It needs the separate **`rtk` binary** (NOT a pip package): download
  `rtk-x86_64-pc-windows-msvc.zip` from https://github.com/rtk-ai/rtk/releases and add to
  PATH, or `cargo install --git https://github.com/rtk-ai/rtk`.
- `coworker rtk enable` then **edits your live `~/.claude/settings.json`** to register the hook.
- `coworker rtk passthrough` manages the signal/bulk allowlist (git/gh control commands ship
  as defaults) so commands like `git push` pass straight through and don't hang.
- `coworker rtk status` reports binary + hook state.

RTK is independent of read-delegation — `ask`/`write` work without it.

## 7. Tuning the read-gate (env vars)

| Var | Default | Meaning |
|-----|---------|---------|
| `COWORKER_READ_GATE` | `on` | set `off` to disable the gate entirely |
| `COWORKER_TOKEN_DIVISOR` | `4` | bytes-per-token estimate (`est_tokens = bytes / divisor`) |
| `COWORKER_DELEGATE_TOKENS` | `5000` | non-source reads at/above this (~20 KB) → delegate to coworker. Lower = more aggressive savings; below ~2000 the per-call overhead outweighs the gain |
| `COWORKER_GREP_TOKENS` | `100000` | non-source reads at/above this → grep-only (blocked) |

Source files (code) are always exempt regardless of size.

## 8. How the gate decides (fail-open)

The gate's default action on *any* uncertainty is **allow the read** (`exit 0`). It
denies (`exit 2`) on exactly one confident path: a large non-source file, with
`coworker` available and the gate on. Every branch:

| Condition | Result |
|-----------|--------|
| `COWORKER_READ_GATE=off` | **allow** (kill-switch) |
| `coworker` not installed | **allow** ← this is why a fresh user is never blocked |
| `.claude/.grok-broke` marker present (out of credits, see §9) | **allow** |
| file path not extractable / file not statable | **allow** |
| extension is source code (`.ts .py .go .rs .java .sh …`) | **allow** (you read your own code) |
| size not measurable | **allow** |
| non-source, `est_tokens ≥ COWORKER_DELEGATE_TOKENS` (5k, ~20 KB) | **deny** → run `coworker ask …` |
| non-source, `est_tokens ≥ COWORKER_GREP_TOKENS` (100k) | **deny** → grep-only |
| otherwise (small non-source) | **allow** |

So you only ever see a block when you have deliberately installed `coworker`, left the
gate on, and tried to read a *large non-source* file in context. Source is never blocked.

## 9. Out of credits (grok-watch)

xAI exposes no balance API, so Forge detects exhaustion reactively:

- `grok-watch.sh` (PostToolUse Bash) inspects failed `coworker` calls. On a billing /
  "out of credits" error it writes the marker `.claude/.grok-broke`.
- While that marker exists: the read-gate **fails open** (reads run on the main model),
  and the statusline shows a 🟥 `grok:NO-CREDITS` flag so you know delegation is paused.
- It **auto-recovers**: the next *successful* `coworker` call clears the marker and the
  gate resumes. No manual reset needed after topping up.

You are never hard-blocked for being out of credits — delegation simply turns itself off.

## 10. Privacy — what leaves your machine

`coworker ask` / `coworker write` send the referenced corpus to **xAI's API** (your
key, your account). Know the boundary:

- **Source code is never sent** by the gate — it is exempt, so your code stays local.
- **Non-source content you delegate IS sent** to xAI (docs, logs, data). Don't delegate
  files containing secrets or sensitive data; the gate sizes files, it does not redact them.
- Keys live in env vars only (§2) — never in the repo.
- **RTK (§6) is local**: it compresses shell output through the on-machine `rtk` binary
  and does **not** call any API. Only `ask`/`write` reach xAI.

If a project must keep all content on-machine, simply don't install `coworker` (or set
`COWORKER_READ_GATE=off`) — Forge runs fully on the main model, flat-file memory and all.
