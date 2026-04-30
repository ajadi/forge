# Improvements from Krol's Course — v1.0 Status

Конкретные кейсы из курса `alexeykrol/coursevibecode`, применённые к Forge.
Все 14 улучшений реализованы в v1.0.

---

## P0 — Критичные улучшения

### 1. Убрать "FULL PIPELINE MANDATORY" из CLAUDE.md

**Проблема:** Правило "every task — no matter how small — MUST go through the full pipeline" противоречит L1-L4 роутингу в pm-ref.md. Агенты путаются — формально обязаны гнать однострочный фикс через BA → Decomposer → ... → RealityChecker.

**Что делает Кроль:** "Stability must precede automation" — не добавлять процесс ради процесса. Pipeline должен масштабироваться по задаче.

**Решение:** CLAUDE.md уже обновлён в `_forge/CLAUDE.md` — правило заменено на "PIPELINE BY COMPLEXITY" с таблицей L1-L4. L1 = Developer → RealityChecker → commit. Готово.

---

### 2. Добавить AGENTS.md — реестр ролей

**Проблема:** Нет единого места, где описано какой агент что делает, какие у него ограничения, и когда его вызывать. PM "знает" это из pm-ref.md, но другие агенты — нет.

**Что делает Кроль:** Playbook 09 — обязательный shared artifact `AGENTS.md` с ролями, правами, и зонами ответственности. "Organization emerges from shared artifacts + protocols."

**Решение:** Создать `.claude/AGENTS.md`:
```markdown
# Agent Roster

| Agent | Role | Model | When to use | Cannot do |
|-------|------|-------|-------------|-----------|
| pm | Orchestrator | opus | Every task | Never implements code |
| developer | Executor | sonnet | L1-L4 implementation | Cannot modify pm-ref.md |
| code-reviewer | Reviewer | sonnet | L2+ after developer | Read-only, no edits |
| reality-checker | Gate | sonnet | Final check before commit | Default NEEDS_WORK |
| ... | ... | ... | ... | ... |
```

---

### 3. Добавить Stop Rules в инструкции агентов

**Проблема:** Агенты знают ЧТО делать, но не знают КОГДА остановиться. Developer может начать рефакторить соседний код. Code-reviewer может уйти в философию.

**Что делает Кроль:** Playbook 07 — Block 6 "Stop Rule" обязателен в каждой инструкции. "When agents must pause instead of proceeding."

**Решение:** Добавить в каждый agent.md секцию:
```markdown
## Stop rules
- STOP if task scope expands beyond spec
- STOP if touching files not listed in task.files
- STOP if encountering unclear business logic (report OQ-XXX)
- STOP if changes exceed 200 lines (reassess complexity)
```

---

### 4. Handoff контракт между агентами

**Проблема:** Формат передачи работы между агентами не формализован. Developer пишет "done", но code-reviewer не знает что именно проверять.

**Что делает Кроль:** "Each role returns results via defined contract: completed items, affected files, remaining questions, validation points."

**Решение:** Стандартизировать секцию handoff в task file:
```markdown
## handoff: [agent_name]
status: DONE | NEEDS_WORK | BLOCKED
files_changed:
  - path/to/file.ts (lines 42-67)
remaining_questions: none | [list]
validation_points:
  - [что проверить следующему агенту]
delegate_to: [next_agent] | none
```

---

## P1 — Важные улучшения

### 5. Лестница автономии (Autonomy Ladder)

**Проблема:** Forge имеет бинарный подход: либо `bypassPermissions`, либо нет. Нет промежуточных уровней.

**Что делает Кроль:** 6 стадий автономии с метриками регрессии и автоматическим откатом:
1. Read/explain only
2. Plan proposals (no execution)
3. Single narrow modifications
4. Familiar workflow execution
5. Multi-role coordination
6. Full delegation

**Решение:** Добавить в pm-ref.md секцию "Autonomy Levels":
- Новый проект / новый тип задачи → начинать с Level 3 (plan + narrow execution)
- После 5 успешных задач без NEEDS_WORK → повысить до Level 4
- Если 2 подряд NEEDS_WORK → понизить на уровень
- Логировать уровень в progress.log

---

### 6. Метрики регрессии автономии

**Проблема:** Нет способа понять, работают ли агенты хорошо или деградируют. "Agent audit every 10 tasks" — слишком редко и ручной процесс.

**Что делает Кроль:** Автоматические метрики:
- Return rate (сколько раз reality-checker вернул NEEDS_WORK)
- Scope creep rate (сколько раз developer тронул файлы вне spec)
- Escalation clarity (были ли OQ понятными или мусорными)

**Решение:** Добавить в `session-stop.sh` hook автоматический сбор:
```bash
# Append to .claude/metrics.log
echo "$(date -Is) | returns: $(grep -c NEEDS_WORK tasks/TASK-*.md 2>/dev/null || echo 0) | scope_creep: ... | escalations: ..."
```
Dream agent читает metrics.log при консолидации.

---

### 7. Ralph Loop — перезапуск застрявших агентов

**Проблема:** Если агент зацикливается или деградирует в контексте, единственный вариант — ручной retry. 2 retry max — но иногда проблема в контексте, а не в задаче.

**Что делает Кроль:** "Ralph Loop" — при застревании агента переинжектировать оригинальный промпт в чистый контекст. Не retry того же, а fresh start с теми же инструкциями.

**Решение:** В PM добавить правило:
```
If agent returns incomplete result twice:
1. Save agent's partial output to task file
2. Spawn FRESH agent (new context) with:
   - Original task spec
   - "Previous attempt notes: [partial output summary]"
   - "Do NOT repeat: [what failed]"
3. This is NOT a retry — it's a context reset
```

---

### 8. Update Rules — каскадное обновление файлов

**Проблема:** Когда architect меняет схему БД, developer может не знать что нужно обновить миграции, тесты, и документацию.

**Что делает Кроль:** Block 7 "Update Rule" — "which dependent files require sync after major changes."

**Решение:** Добавить в pm-ref.md:
```markdown
## Update cascade
| If changed... | Then also update... |
|---------------|---------------------|
| DB schema | migrations, seed data, API types |
| API endpoints | OpenAPI spec, client SDK, tests |
| tz.md requirements | backlog.md, affected task files |
| .claude/agents/*.md | pm-ref.md model table |
| CLAUDE.md rules | All active task files (re-validate) |
```

---

### 9. Verification Loop в Developer

**Проблема:** Developer пишет код и отдаёт дальше. Нет self-check перед передачей.

**Что делает Кроль:** "Build verification loops into the harness — agents should test their own output before returning results."

**Решение:** Добавить в developer.md:
```markdown
## Pre-handoff self-check
Before writing handoff section, verify:
1. `git diff --stat` — changes match task.files list
2. No TODO/FIXME/HACK left in changed lines
3. No hardcoded secrets, URLs, or credentials
4. If task has tests — run them, report result
5. Changed lines count — if > expected, flag for PM
```

---

## P2 — Полезные улучшения

### 10. Progressive Tool Disclosure

**Проблема:** Все 40+ агентов загружаются в контекст сразу. Это тратит токены и путает модель.

**Что делает Кроль:** "Load skills and context dynamically as needed, not upfront."

**Решение:** Модульная структура `_forge` уже решает это на уровне установки. Дополнительно можно в settings.json использовать conditional agent loading — но это зависит от возможностей Claude Code runtime.

---

### 11. Разделение постоянных правил и временных задач

**Проблема:** CLAUDE.md содержит и правила фреймворка, и проект-специфичные инструкции. При копировании шаблона приходится чистить.

**Что делает Кроль:** "Keep permanent rules separate from temporary tasks. Instructions answer 'how we typically work here', not 'what needs doing now'."

**Решение:** 
- `_forge/CLAUDE.md` — только правила фреймворка (неизменные)
- Проект добавляет свои правила в `CLAUDE.md` ниже, под заголовком `## Project-specific rules`
- Задачи — только в tasks/, никогда в CLAUDE.md

---

### 12. Минимальная жизнеспособная команда (MVT)

**Проблема:** Forge определяет 41 агента. Для solo-разработчика это overkill. Кроль показывает, что минимум = 3 роли.

**Что делает Кроль:** "Coordinator + Executor + Reviewer — minimum viable team."

**Решение:** Уже решено через core (13 агентов). Но можно пойти дальше — создать `_forge/presets/`:
```
presets/
  solo.txt        — pm, developer, reality-checker (3 agents)
  small-team.txt  — core (13 agents)
  full.txt        — core + all extensions (41 agents)
```
Install script: `bash install.sh /my/project --preset solo`

---

### 13. Self-Diagnosis Agent

**Проблема:** Нет агента, который отвечает на вопрос "почему последняя задача провалилась?" Reflect делает пост-мортем, но не диагностику в реальном времени.

**Что делает Кроль:** "Self-diagnosis — agents report on their own reliability."

**Решение:** Добавить в reality-checker расширенную диагностику:
```markdown
## diagnosis (when NEEDS_WORK)
root_cause: [code_error | scope_creep | context_loss | wrong_agent | unclear_spec]
pattern: [first_time | recurring]
recommendation: [specific fix, not generic]
```

---

### 14. Escalation Boundaries

**Проблема:** Правило "AMBIGUITY → BLOCKED" слишком бинарное. Не все неясности одинаково критичны.

**Что делает Кроль:** "Define clear decision trees for when agents handle autonomously vs. when humans intervene."

**Решение:** Добавить в pm-ref.md:
```markdown
## Escalation matrix
| Situation | Action |
|-----------|--------|
| Technical choice (library, pattern) | Agent decides, logs in decisions.md |
| Business logic unclear | BLOCKED: OQ-XXX |
| Security concern found | BLOCKED + notify user immediately |
| Performance trade-off | Agent proposes options, PM picks |
| Scope expansion needed | BLOCKED: OQ-XXX [blocker:task] |
| Conflicting requirements | BLOCKED: OQ-XXX [blocker:project] |
```

---

## Статус внедрения (v1.0)

| # | Улучшение | Статус | Где реализовано |
|---|-----------|--------|-----------------|
| 1 | Гибкий pipeline L1-L4 | DONE | CLAUDE.md, pm-ref.md |
| 2 | AGENTS.md — реестр ролей | DONE | core/AGENTS.md |
| 3 | Stop Rules на все агенты | DONE | Все 36 agent.md файлов |
| 4 | Handoff контракт | DONE | pm-ref.md, AGENTS.md, developer.md |
| 5 | Лестница автономии A1-A5 | DONE | pm-ref.md |
| 6 | Метрики регрессии | DONE | session-stop.sh → .claude/metrics.log |
| 7 | Ralph Loop | DONE | pm.md (Step 5.5), pm-ref.md |
| 8 | Update cascade | DONE | pm-ref.md, pm.md (Step 5.7) |
| 9 | Self-check в developer | DONE | developer.md (pre-handoff) |
| 10 | Progressive disclosure | DONE | Модульная структура _forge |
| 11 | Разделение правил/задач | DONE | CLAUDE.md = правила only |
| 12 | Presets solo/small/full | DONE | presets/, install.sh --preset |
| 13 | Self-diagnosis | DONE | reality-checker.md (diagnosis section) |
| 14 | Escalation matrix | DONE | pm-ref.md, AGENTS.md |

---

## P2 — Windows / first-install polish

### Pre-warm ONNX model + Windows UTF-8 env

**Problem:** Fresh installs on Windows hit two papercuts: (1) first `mempalace_add_drawer` MCP call times out while ChromaDB lazily downloads the 79 MB ONNX embedding model, and (2) the `mempalace` CLI crashes on cp1252 consoles when emitting Unicode arrows in help text. The MCP server itself doesn't crash but stores content with cp1252 mojibake in stored drawers.

**Solution:** `install.sh` now triggers the ONNX download immediately after `pip install mempalace`. `core/settings.json` adds `PYTHONIOENCODING=utf-8` and `PYTHONUTF8=1` to the MemPalace MCP server env. `CLAUDE.md` clarifies that empty-palace state on wake-up is not an error and that agents should NOT run interactive `mempalace init`.

**Source**: encountered during SFTT bootstrap, 2026-04-30. (Originally fixed in commit 75193c9 on branch `feat/agent-memory-protocol-explicit`; re-applied to v2.1 main on `fix/mempalace-windows-bootstrap-v2`.)
