export const meta = {
  name: 'f-audit',
  description: 'Adaptive multi-agent code audit: scout the project, fan out finders over discovered dimensions, dedup, batch-verify per dimension (adversarial), report ranked findings with token cost.',
  phases: [
    { title: 'Scout', detail: 'map the project + pick audit dimensions' },
    { title: 'Find', detail: 'one finder per discovered dimension (parallel)' },
    { title: 'Verify', detail: 'one verifier per dimension confirms its findings (batch, refute-default)' },
  ],
}

// ---- knobs (from the skill via args) ----
const A = (typeof args !== 'undefined' && args) ? args : {}
const TARGET = A.target || '.'
const SCOPE = A.scope || 'full'          // full | diff | <path>
const DEPTH = A.depth || 'standard'      // quick | standard | thorough
const FOCUS = A.focus || 'all'           // all | security | correctness | performance | portability
const FLOOR = DEPTH === 'quick' ? 'high' : (DEPTH === 'thorough' ? 'low' : 'medium')
const MAX_DIMS = DEPTH === 'quick' ? 5 : (DEPTH === 'thorough' ? 12 : 8)
const MAX_PER_DIM = DEPTH === 'thorough' ? 10 : 6

const SEV = ['critical', 'high', 'medium', 'low']

const SCOUT_SCHEMA = {
  type: 'object', additionalProperties: false, required: ['stack_summary', 'dimensions'],
  properties: {
    stack_summary: { type: 'string' },
    dimensions: { type: 'array', items: {
      type: 'object', additionalProperties: false, required: ['key', 'hunt', 'paths'],
      properties: {
        key: { type: 'string', description: 'short slug' },
        hunt: { type: 'string', description: 'what to look for in this dimension, tuned to the stack' },
        paths: { type: 'array', items: { type: 'string' }, description: 'concrete files/dirs/globs to inspect' },
      } } },
  },
}
const FINDINGS_SCHEMA = {
  type: 'object', additionalProperties: false, required: ['findings'],
  properties: { findings: { type: 'array', items: {
    type: 'object', additionalProperties: false,
    required: ['file', 'line', 'severity', 'category', 'title', 'detail', 'suggested_fix'],
    properties: {
      file: { type: 'string' }, line: { type: 'string' },
      severity: { type: 'string', enum: SEV },
      category: { type: 'string', enum: ['broken', 'bug', 'security', 'inconsistent', 'weak', 'inefficient', 'portability'] },
      title: { type: 'string' }, detail: { type: 'string' }, suggested_fix: { type: 'string' },
    } } } },
}
const VERDICT_SCHEMA = {
  type: 'object', additionalProperties: false, required: ['verdicts'],
  properties: { verdicts: { type: 'array', items: {
    type: 'object', additionalProperties: false, required: ['i', 'real', 'severity', 'reason'],
    properties: {
      i: { type: 'number', description: 'the #index of the finding being judged' },
      real: { type: 'boolean', description: 'true only if reproducible from the actual file' },
      severity: { type: 'string', enum: SEV.concat(['not-a-bug']) },
      reason: { type: 'string' },
    } } } },
}

const EXCLUDE = 'EXCLUDE generated/vendored/build dirs: node_modules, dist, build, out, .venv, venv, vendor, target, .next, coverage, and *.lock / minified files.'

// ---- Scout ----
phase('Scout')
const scout = await agent(
  `You scout a codebase for a multi-agent audit. Project: ${TARGET}. Scope: ${SCOPE}. Focus: ${FOCUS}.\n` +
  `Map languages, frameworks, entry points, source dirs, and test setup using ls/glob/grep — do NOT read large files whole. ${EXCLUDE}\n` +
  `Then propose UP TO ${MAX_DIMS} audit dimensions that genuinely apply to THIS stack and focus (e.g. input-validation, auth, error-handling, concurrency, resource-leaks, API-contract, config/secrets, build/install portability, tests). For each: a short key, what to hunt, and concrete paths/globs. Order by expected risk.`,
  { phase: 'Scout', schema: SCOUT_SCHEMA }
)
const dims = (scout.dimensions || []).slice(0, MAX_DIMS)
if (!dims.length) return { error: 'scout found no auditable dimensions', stack: scout.stack_summary }
log(`scouted ${dims.length} dimensions: ${dims.map(d => d.key).join(', ')}`)

// ---- Find (parallel, one finder per dimension) ----
phase('Find')
const found = await parallel(dims.map(d => () =>
  agent(
    `Audit ONE dimension of the project at ${TARGET}.\nDimension "${d.key}": ${d.hunt}\nPaths: ${(d.paths || []).join(', ')}. Scope: ${SCOPE}. ${EXCLUDE}\n` +
    `Report only REAL, high-signal problems with severity >= ${FLOOR}; ignore style. READ DISCIPLINE: grep/targeted reads, never whole large files. Each finding needs an exact file:line, why it matters, and a concrete fix. Return at most the ${MAX_PER_DIM} most significant.`,
    { label: `find:${d.key}`, phase: 'Find', schema: FINDINGS_SCHEMA }
  ).then(r => (r.findings || []).map(f => ({ dimension: d.key, ...f }))).catch(() => [])
))
const all = found.filter(Boolean).flat()

// ---- Dedup across dimensions (barrier justified: needs all findings) ----
const seen = new Set(); const deduped = []
for (const f of all) {
  const norm = (f.title || '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim().slice(0, 60)
  const k = (f.file || '') + '|' + norm
  if (seen.has(k)) continue
  seen.add(k); deduped.push(f)
}
log(`findings: ${all.length} raw -> ${deduped.length} after dedup`)

// ---- Verify (batch per dimension: ONE verifier confirms all of its findings) ----
phase('Verify')
const byDim = {}
for (const f of deduped) { if (!byDim[f.dimension]) byDim[f.dimension] = []; byDim[f.dimension].push(f) }
const groups = await parallel(Object.keys(byDim).map(dim => () => {
  const items = byDim[dim]
  const listing = items.map((f, i) => `#${i}: [${f.severity}/${f.category}] ${f.file}:${f.line} — ${f.title} :: ${f.detail}`).join('\n')
  return agent(
    `Adversarially verify these ${items.length} audit findings for dimension "${dim}" (project ${TARGET}). For EACH finding, READ the actual file and confirm STRICTLY from its contents. Default real=false if you cannot reproduce the exact problem; re-rate severity honestly. Return one verdict per #index.\n\n${listing}`,
    { label: `verify:${dim}`, phase: 'Verify', schema: VERDICT_SCHEMA }
  ).then(v => (v.verdicts || []).map(vd => ({ ...(items[vd.i] || {}), verdict: vd }))).catch(() => [])
}))
const verified = groups.flat().filter(x => x && x.verdict && x.verdict.real && x.file)

const ord = { critical: 0, high: 1, medium: 2, low: 3 }
verified.sort((a, b) => (ord[a.verdict.severity] ?? 9) - (ord[b.verdict.severity] ?? 9))
const by_severity = verified.reduce((m, f) => { const s = f.verdict.severity; m[s] = (m[s] || 0) + 1; return m }, {})

return {
  target: TARGET, scope: SCOPE, depth: DEPTH, focus: FOCUS,
  dimensions: dims.map(d => d.key),
  raw_findings: all.length, after_dedup: deduped.length, confirmed: verified.length, by_severity,
  output_tokens_in_workflow: budget.spent(),
  findings: verified.map(f => ({
    severity: f.verdict.severity, dimension: f.dimension, file: f.file, line: f.line,
    category: f.category, title: f.title, detail: f.detail, suggested_fix: f.suggested_fix,
    verify_note: f.verdict.reason,
  })),
}
