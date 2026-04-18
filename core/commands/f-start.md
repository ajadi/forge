---
description: Guided onboarding — detect project state and route to the right workflow. Run on first session or when starting fresh.
allowed-tools: Read, Glob, Grep
---

# Guided Onboarding

Entry point for new users. Ask first, then route to the right workflow.

---

## Step 1: Detect Project State (Silent)

Before saying anything, silently check:

- **tz.md exists?** — requirements are defined
- **backlog.md has tasks?** — grep for `TASK-` entries
- **tasks/ has files?** — Glob `tasks/TASK-*.md`
- **memory/ is populated?** — check memory/stack.md for non-empty content
- **tasks/archive/ has completed tasks?** — project is mid-flight

Store findings. Use them to validate user's answer and tailor recommendations.

---

## Step 2: Ask Where the User Is

> **Welcome to the Multi-Agent Dev System!**
>
> Before suggesting anything, let me understand where you're starting from:
>
> **A) New project** — no requirements, no code. Starting from scratch.
>
> **B) Have an idea** — rough concept in mind, but nothing formal yet.
>
> **C) Have requirements** — tz.md is written or nearly ready. Need tasks and execution.
>
> **D) Existing project** — already have code, tasks, or history. Want to connect the system or continue work.

Wait for the user's answer.

---

## Step 3: Route Based on Answer

### If A: New project

1. Acknowledge
2. Explain what the Business Analyst agent does (interviews you, asks clarifying questions, creates tz.md)
3. Recommend: run `business-analyst` agent → creates tz.md
4. Show path:
   - `business-analyst` → tz.md
   - `decomposer` → backlog.md + tasks/
   - `estimator` → timeline.md
   - `pm` → runs pipeline on first task

### If B: Have an idea

1. Ask them to describe it — even a few words is enough
2. Recommend: run `business-analyst` agent — it will interview you to shape the idea into tz.md
3. Show path:
   - `business-analyst` → tz.md
   - `decomposer` → backlog.md
   - `pm` → pipeline

### If C: Have requirements

1. Ask 2 questions:
   - Is tz.md already written, or needs to be created?
   - Is this the first run of decomposer, or do tasks already exist?
2. If tz.md exists but no tasks: run `decomposer` → then `estimator`
3. If tasks already exist: run `pm` directly (picks first unblocked task)
4. Show path:
   - `decomposer` → backlog.md + tasks/
   - `estimator` → timeline.md
   - `pm` → first task

### If D: Existing project

1. Share what you found in Step 1:
   - "I can see [N tasks in backlog / M completed / memory populated / tz.md present]..."
2. If memory is empty: recommend `onboarding` agent first (reads codebase, populates memory/)
3. If tasks exist: suggest running `pm` — it will show current status and pick up where things left off
4. If tz.md missing: recommend `business-analyst` in amend mode to document existing behavior
5. Show path:
   - `onboarding` agent — if memory is empty
   - `/status` — see current state
   - `pm` — continue work

---

## Step 4: Confirm Before Proceeding

After presenting the path, ask which step to take first.
Never auto-run the next agent.

> "Where would you like to start: [recommended first step], or something else?"

---

## Edge Cases

- **User picks D but project is empty**: "The project looks empty. Would path A or B be a better fit?"
- **User picks A but tasks/tz.md exist**: "I can see you already have [tz.md / tasks]. Do you want to start fresh, or continue?"
- **Already fully set up (tz.md + tasks + memory)**: Skip onboarding — "You're already set up. There are [N open tasks]. Run `pm` to continue?"
- **User doesn't fit any option**: Let them describe their situation and adapt.
