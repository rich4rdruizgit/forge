---
name: forge-build-red
description: >
  Red phase sub-skill for forge-build. Generates ALL tests for ALL ACs using risk-based analysis,
  runs auto-gate validation. Designed to run as a sub-agent with fresh context.
license: Apache-2.0
metadata:
  author: doubler
  version: "1.0"
---

## Purpose

This is the **RED phase** extracted from `forge-build` for sub-agent execution. It reads the approved SPEC and generates ALL tests for ALL ACs before any implementation code exists. After generating tests, it runs the auto-gate validation to ensure coverage and quality meet the required criteria. Zero implementation code is written — only tests and TRACEABILITY.md.

---

## Preconditions

- `.forge/FORGE.md` exists with an active feature (`feature` and `slug` are non-null)
- `fase_actual` is `BUILD`
- SPEC row in the FORGE.md phase table = `✅ Aprobado`
- BUILD row is NOT yet `✅ Aprobado` (to prevent overwriting an approved artifact)

---

## Forge Runtime

→ Execute `_shared/forge-runtime.md` steps R0–R4 before any skill-specific logic.

---

## Step B1 — Load stack skill

1. Read `.forge/config.yaml` → get `stack` value
2. Look for `.forge/stack-skills/{stack}.md`
3. If file does not exist:
   STOP. Output error:
   "❌ No existe skill para el stack '{stack}'.
   Creá `.forge/stack-skills/{stack}.md` usando la plantilla en `.forge/stack-skills/TEMPLATE.md`
   y completá todas las secciones antes de continuar."
4. Load the file. Use its sections to determine:
   - Test framework and imports
   - File naming convention
   - Test method naming convention
   - Test file location
   - Implementation patterns (DI, async model, layer conventions)

**CRITICAL**: Read the stack skill BEFORE generating any code. Apply ALL naming conventions, test patterns, and anti-patterns from the stack skill. If any convention in the stack skill conflicts with your defaults — the stack skill WINS.

---

## Step B2 — Read approved SPEC

Read `.forge/features/activo/{slug}/SPEC.md`:
- Extract ALL Acceptance Criteria (AC-1..N) with full Dado/Cuando/Entonces text
- Extract Domain Model: events, commands, aggregates
- Extract Architecture: layers, contracts, file structure
- Extract Decisions: all D-N entries
- Extract Test Plan: test strategy and conventions
- Extract Test Sequencing: the layer-ordered AC processing sequence
- Extract UI Contract: states (loading, success, error, empty), interactions, navigation routes (if present)

If SPEC.md is not found:
> 🚫 **E200** — No encontré `.forge/features/activo/{slug}/SPEC.md`. ¿La feature está activa?

---

## Step B3 — Determine continuation point

Read `.forge/features/activo/{slug}/TRACEABILITY.md` if it exists:
- Find the last AC with status `✅ Refactored`
- The next AC in Test Sequencing order is the continuation point
- If TRACEABILITY.md does not exist or has no entries: start from the first AC in Test Sequencing

Output:
```
📍 Punto de continuación: AC-{N} — {AC title}
ACs completados: {M}/{total}
```

---

## Step B3.5 — Load Test Constraints

Load test ceilings and pyramid constraints from `config.yaml → testing`:

1. Read `testing.presupuesto.{profundidad}` for current feature depth (from FORGE.md) — these are CEILINGS (maximums), not targets
2. Read `testing.piramide` for pyramid as economic constraint
3. Read `testing.tagging` for speed tagging rules
4. Read SPEC Section 14 (Test Budget & Pirámide) for planned test distribution

Load max ceilings and pyramid constraints:
```
Constraints {PROFUNDIDAD}:
  unit: max {N}
  integration: max {N}
  ui: max {N}
  pyramid: unit ≥{N}% | integration ≤{N}% | ui ≤{N}%
  tagging: {enabled/disabled}
```

If `testing` section missing in config.yaml → use defaults (as ceilings):
- LIGERA: unit max 8, integration max 2, ui max 1
- MEDIA: unit max 12, integration max 3, ui max 2
- PROFUNDA: unit max 20, integration max 5, ui max 3

⚠️ If SPEC Section 14 budget exceeds config ceilings, WARN the dev before proceeding.

---

## Step B4 — Phase RED: Risk-Based Test Generation

Generate tests based on production risk analysis. Zero implementation code in this phase.

### Test Generation Process

For each AC in order from Test Sequencing in SPEC, starting from the continuation point:

1. Read AC-N from SPEC (Dado/Cuando/Entonces)
2. Read corresponding event(s) from Domain Model
3. Read contract(s) from Architecture

For each AC, analyze:
1. **¿Qué puede fallar en producción con este AC?** — identify concrete failure scenarios
2. **¿Este riesgo ya está cubierto por otro test en esta suite?** — if yes, skip and document why
3. **¿En qué capa se puede verificar este riesgo al menor costo?** — unit > integration > UI (pyramid as economic constraint)
4. **Escribir el test** — only if steps 1-3 justify it

### Decisión de Inclusión
Para cada test que escribas, documentar:
- **Riesgo**: qué falla de producción previene
- **Capa**: por qué esta capa y no una inferior
- **Único**: qué cubre que ningún otro test ya cubre

### Decisión de Exclusión
Si un AC no genera test, documentar:
- **AC-N**: por qué no necesita test propio
- **Cobertura**: qué test existente ya cubre este comportamiento

### NO redundant tests (PRIMARY RULE)
If AC-2's risk is already covered by AC-1's test, do NOT duplicate coverage. Document the cross-reference instead.

**Constraint económico (pirámide):**
- Unit tests: costo base — preferir siempre
- Integration tests: ~10x costo unit — solo para integraciones reales (DB, API, cross-module). Justificar: "¿por qué no unit?"
- UI tests: ~50x costo unit — solo para comportamientos que SOLO se pueden verificar en UI. Justificar: "¿por qué no integration o unit?"

**Tagging (if `testing.tagging.enabled`):**
Each test gets a speed tag based on expected execution time:
- `@Tag("fast")` — pure logic, no I/O, < 100ms
- `@Tag("medium")` — mocked I/O or coroutine tests, < 2s
- `@Tag("slow")` — real I/O, Compose UI tests, > 2s

Write test(s) following stack skill conventions:
- Test name MUST reference the AC (e.g., `// AC-N` comment or AC slug in name)
- Test naming pattern: `should_{expected_result}_when_{condition}()`
- Follow stack skill test framework, imports, and file location
- The test MUST FAIL (red state) — there is no implementation yet
- Update TRACEABILITY.md: AC-N status = 🔴 Red

Output per AC (included):
```
🔴 RED — AC-{N}: {AC title}
Riesgo: {qué falla de producción previene}
Test: {test file path}
Test case(s): {test method names}
Capa: {unit|integration|ui} — {justificación de capa}
Tag: {@fast|@medium|@slow}
Estado: FAILING (no implementation yet)
```

Output per AC (excluded):
```
⏭️ SKIP — AC-{N}: {AC title}
Razón: {por qué no necesita test propio}
Cubierto por: {test que ya cubre este comportamiento}
```

**Sanity check:** After generating all tests, verify:
- Total tests does not exceed ceiling for current depth (config.yaml → testing.presupuesto.{profundidad})
- Pyramid distribution within configured limits
- If over ceiling → the agent MUST remove tests, starting with those whose risk justification is weakest
- If only 1 test for 5+ ACs → explain why each excluded AC doesn't need its own test

After ALL ACs have been analyzed, output summary:
```
🔴 Phase RED complete — {N} ACs analyzed, {M} tests generated, {K} ACs covered by existing tests

📊 Risk Analysis Report:
  Tests generados: {M} (ceiling: {max})
  ACs con test propio: {N}
  ACs cubiertos por otros tests: {K} (con justificación)
  Pirámide: unit {N} ({P}%) | integration {N} ({P}%) | ui {N} ({P}%)
  Constraint económico: {✅|⚠️}
  Tags: @fast {N} | @medium {N} | @slow {N}

Decisiones de exclusión:
- AC-{N}: {razón}
...

Procediendo a auto-gate...
```

---

## Step B4.1 — Auto-gate (RED → GREEN)

After generating ALL tests, the agent automatically validates:

| Criterion | Check |
|-----------|-------|
| Risk Coverage | Each test has a named production failure it prevents |
| Exclusion Defense | Each AC without a test has documented justification + cross-reference |
| Behavior | Each test verifies behavior, not implementation |
| Error Scenarios | Error cases from SPEC have tests OR documented justification for exclusion |
| Mock Depth | 0 tests mock more than 2 layers |
| Ceiling Compliance | Total tests ≤ ceiling for depth |
| Economic Constraint | If integration/UI tests exist, justification for why not unit |

**Gate FAILS** → BLOCK. List what's missing. Do NOT proceed to GREEN.

**Gate PASSES** → Show summary to dev:

```
🔒 Auto-gate RED → GREEN

Tests generados: {N} (ceiling: {max})
Risk coverage: ✅ (cada test previene falla concreta)
Exclusion defense: ✅ ({K} ACs sin test propio — justificados)
Tests de comportamiento: ✅
Escenarios de error: ✅ (con tests o justificación de exclusión)
Mock depth ≤ 2: ✅
Ceiling compliance: ✅ ({N} tests ≤ {max})
Economic constraint: ✅ (integration/UI justificados)

Decisiones de exclusión:
- AC-{N}: {razón} → cubierto por {test}
...

Gate: PASSED → procediendo a GREEN
```

Register checkpoint in TRACEABILITY.md (see "Test Review Checkpoint" format in Output Artifacts).

If `forge_memory_available`:
Call `forge_mem_save` with:
- title: `"BUILD gate passed: {slug}"`
- type: `"build-checkpoint"`
- topic_key: `"forge/{slug}/build-gate"`
- content:
  ```
  red_tests: {N}
  ac_coverage: {N}/{total}
  auto_gate: PASSED
  test_files: [...]
  ```

---

## Regla de Tests Inmutables

Los tests escritos en RED **NO SE PUEDEN** modificar durante GREEN.

- Si un test falla en GREEN → arreglar la **IMPLEMENTACIÓN**, no el test
- Si el test tiene un error genuino → el agente pide permiso al dev:
  "Este test parece tener un error: [detalle]. ¿Lo modifico?"
- Solo el dev puede autorizar modificación de un test
- Cualquier modificación se registra en TRACEABILITY.md como "Dev adjustment"

---

## Output Artifacts

### TRACEABILITY.md
Written to `.forge/features/activo/{slug}/TRACEABILITY.md`.
Updated incrementally after each AC's RED phase. Contains:

```markdown
# TRACEABILITY — {feature name}

> Generado por Forge BUILD (RED phase) | Feature: {feature}

## Test Review Checkpoint
- Date: YYYY-MM-DD
- Tests generated: N
- AC coverage: N/N
- Auto-gate: PASSED | FAILED (razón)
- Dev adjustments: [lista o "none"]

## Coverage Matrix

| AC_ID | AC_TITULO | EVENTO_IDS | TEST_IDS | TEST_FILES | IMPL_FILES | STATUS |
|-------|-----------|------------|----------|------------|------------|--------|
| AC-1 | {title} | {events} | {test methods} | {test paths} | — | 🔴 Red |
| AC-2 | ... | ... | ... | ... | — | ⏭️ Covered by AC-1 |
```

---

## Return Contract

When running as a sub-agent, output this structured result at the end:

```yaml
status: complete | blocked
summary: "{N} tests generados para {M} ACs. Auto-gate: {passed|failed}."
artifacts_written:
  - path: .forge/features/activo/{slug}/TRACEABILITY.md
    action: created | updated
  - path: {each test file path}
    action: created
metrics:
  tests_generated: {N}
  unit: {N}
  integration: {N}
  ui: {N}
  acs_covered: {N}/{total}
  auto_gate: passed | failed
  exclusions_documented: {N}
next_recommended: "forge build" # to continue with GREEN phase
risks: []
```

If auto-gate FAILS, include the failing gate checks in `risks` and set status to `blocked`.

---

## Rules

### REGLA ABSOLUTA — TEST ANTES DE IMPLEMENTACION

**NUNCA escribir código de implementación sin un test que falle primero. NUNCA. El test define la interfaz — la implementación la satisface.**

Violación de esta regla = BUILD inválido. El AC debe rehacerse desde RED.

---

- SIEMPRE cargar el skill de stack (Step B1) antes de generar cualquier código
- SIEMPRE leer SPEC.md completo antes de empezar el ciclo
- SIEMPRE escribir el test ANTES de la implementación para cada AC
- SIEMPRE verificar que el test falle antes de implementar (estado RED)
- SIEMPRE actualizar TRACEABILITY.md después de cada fase del ciclo (RED)
- SIEMPRE seguir el orden de Test Sequencing del SPEC — domain → data → presentation → UI
- SIEMPRE respetar las Decisions del SPEC — no contradecirlas
- NUNCA modificar SPEC.md aprobado — usar el protocolo de addendum
- NUNCA saltar el estado RED — el test debe fallar primero
- NUNCA generar código sin AC que lo justifique
- NUNCA modificar tests escritos en RED durante GREEN — ver "Regla de Tests Inmutables"
- NUNCA proceder a GREEN sin pasar el auto-gate — ver "Auto-gate (RED → GREEN)"
- NUNCA modificar tests ya escritos en un ciclo anterior (a menos que un addendum lo requiera)
- Si el stack skill define convenciones que difieren de tus defaults → el stack skill gana

### Test Efficiency
- PREFERIR unit tests sobre integration tests, integration sobre UI
- Si un comportamiento se puede verificar con un unit test, NO agregar integration o UI test para lo mismo
- Tests de UI SOLO para happy paths críticos que no se pueden verificar en capas inferiores
- Toda exclusión es tan importante como toda inclusión — ambas requieren justificación

### Error cases

| Condition | Response |
|-----------|----------|
| SPEC not `✅ Aprobado` | Block. E200. |
| BUILD already `✅ Aprobado` | Block. E201. Suggest `forge verify`. |
| No active feature | Block. E202. Suggest `forge new`. |
| Stack skill file not found | Block. E203. Output error with instructions to create it. |
| SPEC.md not found | Block. E200 variant. |
| Test does not fail in RED phase | STOP. The test is invalid — it must fail without implementation. Fix the test. |
| Auto-gate fails | Block. List missing criteria. Fix tests before proceeding to GREEN. |
