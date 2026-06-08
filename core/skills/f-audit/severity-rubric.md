# f-audit — severity rubric & reporting bar

Report only REAL, evidence-backed problems. Every finding needs an exact `file:line` and a reason reproducible from the code.

## Severity
- **critical** — breaks safety/security or core functionality: exploitable vuln, data loss, auth bypass, a guard that does not actually guard, crash on normal input.
- **high** — wrong behaviour in common cases; a feature/path that silently fails; a portability break on a supported platform.
- **medium** — edge-case bug, real but narrow; a notable weakness or inefficiency with practical impact.
- **low** — minor correctness/consistency issue; report only when trivially certain (skipped below the run's severity floor).

## Categories
`broken` · `bug` · `security` · `inconsistent` · `weak` · `inefficient` · `portability`

## Do NOT report
- Style / formatting / naming preferences; subjective "could be cleaner".
- Issues in generated / vendored / lock files (node_modules, dist, build, .venv, vendor, *.lock, minified bundles).
- Speculative "might be a problem" without a concrete trigger — verification drops these.
- Duplicates of another finding (deduped before verify).
- Test-only smells, unless they hide a real product bug.

## Verification (adversarial, refute-default)
Each finding is re-checked against the actual file by a verifier that defaults to `real=false` unless it can reproduce the exact problem from the file contents, and re-rates severity. Unconfirmed findings are dropped from the report.
