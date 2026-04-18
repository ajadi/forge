# Requirements: [Product Name]

> **Version:** 1.0
> **Date:** [date]
> **Status:** draft | approved
> **Author:** business-analyst agent + [client name]

---

<!--
  AGENT INSTRUCTIONS (do not delete):

  Before starting any task — check the "❓ Open Questions" section.
  If there are unresolved questions (not marked ✅) — STOP.
  Report to PM: "Blocked: tz.md contains unresolved Open Questions."
  Development does not start until all Open Questions are closed.

  If during work you encounter ambiguity not covered by requirements:
  1. Add a new OQ-XXX entry to "❓ Open Questions"
  2. Return to PM: "Blocked: added OQ-XXX, requires client answer"
  3. Do NOT make a decision yourself. Do NOT continue on this task.

  ARCHIVING: PM moves completed REQs to tz-archive.md after task close.
  tz.md contains only: open REQs, open OQs, constraints, assumptions.
  tz-archive.md is never read by agents — history only.
-->

---

## 📋 Product Overview

**Product:** [One sentence — what this is]

**Problem:** [What problem it solves and for whom]

**MVP goal:** [What must work in the first version for the product to be useful]

---

## 👥 Users

| Role | Description | Permissions |
|------|-------------|-------------|
| [role] | [who this is] | [what they can do] |

**Expected audience:** [rough user count and load characteristics]

---

## ✅ Functional Requirements

<!--
  Each requirement must be:
  - Atomic: one action, one result
  - Testable: a concrete test can be written
  - With Acceptance Criteria: specific verifiable conditions
  - With priority: MUST (MVP) / SHOULD (important) / COULD (nice to have)
-->

### REQ-001 — [Requirement name]
- **Priority:** MUST / SHOULD / COULD
- **Description:** [User can / System must...]
- **Acceptance Criteria:**
  - [ ] [Specific verifiable condition 1]
  - [ ] [Specific verifiable condition 2]

### REQ-002 — [Requirement name]
- **Priority:** MUST
- **Description:** ...
- **Acceptance Criteria:**
  - [ ] ...

---

## ⚡ Non-Functional Requirements

| Category | Requirement | Metric |
|----------|-------------|--------|
| Performance | [requirement] | [specific number or N/A] |
| Security | [requirement] | — |
| Availability | [uptime or N/A] | — |
| Scalability | [expected growth] | — |

---

## 🔌 Integrations

| Service | Purpose | Type | Status |
|---------|---------|------|--------|
| [service] | [why] | REST API / Webhook / SDK | confirmed / TBD |

---

## 🛠 Technical Constraints

| Category | Value | Source |
|----------|-------|--------|
| Language / framework | [or "architect's choice"] | client |
| Database | [or "architect's choice"] | client |
| Cloud / hosting | [or "no preference"] | client |
| Existing code | [link or "from scratch"] | client |

---

## 🚫 Out of Scope

Explicitly excluded from this version:

- [Discussed but not in MVP]
- [May be in a future version]

---

## ❓ Open Questions (BLOCKERS)

<!--
  CRITICAL: This section must be empty (or all items ✅) before development starts.
  PM checks this section before every task.
  Agents add items here when they encounter ambiguity.
-->

| ID | Question | Who should answer | Status |
|----|----------|------------------|--------|
| OQ-001 | [question] | client / architect | ⏳ open |

*No open questions — ✅ section is empty*

---

## ⚠️ Assumptions (require client confirmation)

<!--
  Everything agents assume but have not received explicit confirmation for.
  Client must review and confirm each item.
-->

| ID | Assumption | Confirmed |
|----|-----------|-----------|
| AS-001 | [assumption] | ⏳ pending |

---

## 📅 Phases and Priorities

| Phase | Included (REQ-XXX) | Phase goal |
|-------|-------------------|------------|
| MVP (Phase 1) | REQ-001, REQ-002 | [minimum viable product] |
| Phase 2 | REQ-003, REQ-004 | [next meaningful step] |

---

## ✍️ Change History

| Date | Version | What changed |
|------|---------|-------------|
| [date] | 1.0 | Initial version |
