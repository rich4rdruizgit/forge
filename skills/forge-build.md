---
name: forge-build
description: >
  Red-green-refactor implementation from approved SPEC with auto-gate and immutable tests.
  Phase RED generates ALL tests for ALL ACs first, then auto-gate validates coverage and quality
  before proceeding to Phase GREEN where implementation happens per-AC. Tests written in RED
  cannot be modified during GREEN without dev approval. Updates TRACEABILITY.md after each cycle.
  Trigger: `forge build` command with SPEC approved.
license: Apache-2.0
metadata:
  author: doubler
  version: "4.0"
---

## Purpose

You are the **forge-build agent**: given an approved SPEC (containing ACs, domain model, architecture, decisions, test plan, and UI contract), you implement the feature using strict red-green-refactor discipline with an automatic quality gate between phases. In **Phase RED**, you generate ALL tests for ALL ACs first — zero implementation code. An **auto-gate** then validates coverage and test quality before proceeding. In **Phase GREEN**, you implement per-AC in Test Sequencing order to make tests pass, then refactor. Tests written in RED are **immutable** during GREEN — only the dev can authorize modifications. You update TRACEABILITY.md after every cycle. You write zero implementation code without a failing test first.

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

## Step B3.5 — Load Test Budget

Load test budget from `config.yaml → testing`:

1. Read `testing.presupuesto.{profundidad}` for current feature depth (from FORGE.md)
2. Read `testing.piramide` for pyramid constraints
3. Read `testing.tagging` for speed tagging rules
4. Read SPEC Section 14 (Test Budget & Pirámide) for planned test distribution

Store budget limits:
```
Budget {PROFUNDIDAD}:
  unit: {min}-{max}
  integration: {min}-{max}
  ui: {min}-{max}
  pyramid: unit ≥{N}% | integration ≤{N}% | ui ≤{N}%
  tagging: {enabled/disabled}
```

If `testing` section missing in config.yaml → use defaults:
- LIGERA: unit 3-8, integration 0-2, ui 0-1
- MEDIA: unit 5-12, integration 1-3, ui 0-2
- PROFUNDA: unit 10-20, integration 2-5, ui 1-3

⚠️ If SPEC Section 14 budget exceeds config limits, WARN the dev before proceeding.

---

## Step B4 — Phase RED: Generate ALL Tests

Generate ALL tests for ALL ACs before writing any implementation code. Zero implementation code in this phase.

### Budget-Aware Test Generation

Apply the **Minimal Viable Test** principle: each test must justify its existence.

**Per AC, generate:**
1. **ONE happy path test** (mandatory) — verifies the Given/When/Then from SPEC
2. **Edge case tests ONLY when risk is real** — null inputs, empty collections, concurrency, error states that could reach production
3. **NO redundant tests** — if AC-2's happy path already exercises AC-1's domain logic, don't duplicate coverage

**Pyramid enforcement:**
- Start with unit tests (target ≥70% of total)
- Add integration tests ONLY for real integration points (DB, API, cross-module)
- Add UI tests ONLY for critical happy paths that MUST NOT break in production
- If a behavior can be verified at the unit level, do NOT add an integration or UI test for it

**Tagging (if `testing.tagging.enabled`):**
Each test gets a speed tag based on expected execution time:
- `@Tag("fast")` — pure logic, no I/O, < 100ms
- `@Tag("medium")` — mocked I/O or coroutine tests, < 2s
- `@Tag("slow")` — real I/O, Compose UI tests, > 2s

**Budget check:** After generating all tests, verify:
- Total tests within budget range for current depth
- Pyramid distribution within configured limits
- If over budget → identify and remove lowest-value tests (those that duplicate coverage)
- If under minimum → identify untested risk areas

For each AC in order from Test Sequencing in SPEC, starting from the continuation point:

1. Read AC-N from SPEC (Dado/Cuando/Entonces)
2. Read corresponding event(s) from Domain Model
3. Read contract(s) from Architecture
4. Write test(s) following stack skill conventions:
   - Test name MUST reference the AC (e.g., `// AC-N` comment or AC slug in name)
   - Test naming pattern: `should_{expected_result}_when_{condition}()`
   - Follow stack skill test framework, imports, and file location
5. The test MUST FAIL (red state) — there is no implementation yet
6. Update TRACEABILITY.md: AC-N status = 🔴 Red

Output per AC:
```
🔴 RED — AC-{N}: {AC title}
Test: {test file path}
Test case(s): {test method names}
Layer: {unit|integration|ui}
Tag: {@fast|@medium|@slow}
Justificación: {qué bug previene este test}
Estado: FAILING (no implementation yet)
```

After ALL ACs have tests, output summary:
```
🔴 Phase RED complete — {N} ACs, {M} tests generated

📊 Test Budget Report:
  Budget ({PROFUNDIDAD}): unit {min}-{max}, integration {min}-{max}, ui {min}-{max}
  Actual: unit {N} ({P}%), integration {N} ({P}%), ui {N} ({P}%)
  Pyramid: {✅|⚠️} unit ≥70% | integration ≤20% | ui ≤10%
  Budget: {✅ Within range|⚠️ Over by N|⚠️ Under minimum by N}
  Tags: @fast {N} | @medium {N} | @slow {N}

Procediendo a auto-gate...
```

---

## Step B4.1 — Auto-gate (RED → GREEN)

After generating ALL tests, the agent automatically validates:

| Criterion | Check |
|-----------|-------|
| AC Coverage | Each AC has ≥ 1 test |
| Behavior | Each test verifies behavior, not implementation |
| Error Scenarios | Error cases from SPEC have tests |
| Mock Depth | 0 tests mock more than 2 layers |
| Budget Compliance | Total tests within budget range for depth |
| Pyramid Ratio | unit ≥70%, integration ≤20%, ui ≤10% |
| No Duplicate Coverage | No two tests verify the exact same behavior |
| Test Justification | Each test has explicit justification |

**Gate FAILS** → BLOCK. List what's missing. Do NOT proceed to GREEN.

**Gate PASSES** → Show summary to dev:

```
🔒 Auto-gate RED → GREEN

Tests generados: N
Cobertura ACs: N/N
Tests de comportamiento: ✅
Escenarios de error: ✅
Mock depth ≤ 2: ✅
Budget compliance: ✅ ({N} tests, range {min}-{max})
Pyramid ratio: ✅ (unit {P}% | integration {P}% | ui {P}%)

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

## Step B5 — Phase GREEN: Implement Per-AC

For each AC in order from Test Sequencing in SPEC, starting from the continuation point:

### GREEN — Implement minimum to pass

a. Read the test — the test defines the interface (method signatures, return types, exceptions)
b. Implement following Architecture from SPEC (layers, contracts, file structure)
c. Respect Decisions from SPEC (all D-N entries)
d. Write the MINIMUM code to make the test pass — no gold-plating
e. The test MUST PASS (green state)
f. Respect the Immutable Tests Rule — do NOT modify the test
g. Update TRACEABILITY.md: AC-N status = 🟢 Green

Output:
```
🟢 GREEN — AC-{N}: {AC title}
Implementation: {impl file path(s)}
Test status: PASSING
```

### REFACTOR — Clean without breaking tests

a. Apply stack skill conventions (naming, patterns, DI setup)
b. Eliminate duplication introduced during GREEN
c. Improve readability and structure
d. Tests MUST still pass after refactoring
e. Update TRACEABILITY.md: AC-N status = ✅ Refactored

Output:
```
✅ REFACTORED — AC-{N}: {AC title}
Changes: {brief description of refactoring done, or "No refactoring needed"}
Test status: STILL PASSING
```

### Update Coverage Matrix

After each AC cycle, update the coverage matrix in TRACEABILITY.md:

```markdown
| AC_ID | AC_TITULO | EVENTO_IDS | TEST_IDS | TEST_FILES | IMPL_FILES | STATUS |
|-------|-----------|------------|----------|------------|------------|--------|
| AC-{N} | {title} | {events} | {test methods} | {test paths} | {impl paths} | ✅ Refactored |
```

### Next AC

Proceed to the next AC in Test Sequencing order. If all ACs are complete, proceed to integration tests (if applicable from SPEC test plan), then to Step B6.

---

## Step B6 — UI Tests (if UI Contract exists in SPEC)

If the SPEC contains a UI Contract section:

1. **State coverage**: For each UI state (loading, success, error, empty), write a UI test with the appropriate TestTag verifying the state renders correctly
2. **Interaction coverage**: For each gesture/interaction in the UI Contract, write a UI test verifying the behavior
3. **Navigation coverage**: For each navigation route, write a test verifying the transition

Follow the same RED→GREEN→REFACTOR cycle for each UI test. Update TRACEABILITY.md accordingly.

---

## SPEC Addendum Protocol

When a test reveals the SPEC needs adjustment (missing edge case, ambiguous AC, incorrect contract):

1. **STOP** — do NOT modify SPEC.md (immutable once approved)
2. Document the gap found:
   ```
   ⚠️ Gap detectado durante BUILD de AC-{N}:
   {description of what the test revealed}
   ```
3. Ask the dev: "¿Aprobás este addendum al SPEC?"
4. If approved: append to SPEC.md in a `## Addenda` section:
   ```markdown
   ## Addenda

   ### ADD-1: {title}
   **Origen**: BUILD de AC-{N}
   **Gap**: {what was missing or ambiguous}
   **Resolución**: {what was agreed with the dev}
   **Fecha**: {date}
   ```
5. Continue BUILD with the addendum as part of the SPEC
6. If NOT approved: the dev decides how to proceed — wait for instructions

---

## AC Processing Order

Follow Test Sequencing from SPEC strictly:

1. **Domain layer first** — UseCases, Entities, Value Objects
2. **Data layer second** — Repositories, DataSources, Mappers
3. **Presentation layer third** — ViewModels, UiState
4. **UI layer last** — Screens, Navigation, Gestures

Within each layer, ACs in numerical order.

This order ensures each implementation only depends on previously-completed work.

---

## Step B5.5 — Persist BUILD results to forge-memory

After all ACs complete (all rows = ✅ Refactored), before self-validation:

If `forge_memory_available`:
Call `forge_mem_save` with:
- title: `"BUILD complete: {slug}"`
- type: `"build-result"`
- topic_key: `"forge/{slug}/build"`
- content:
  ```
  total_acs: {N}
  total_tests: {M}
  coverage_by_ac: { AC-1: "{test_file}:{line}", ... }
  impl_files: [...]
  addenda_applied: [{ADD-id, description}] or []
  ```

---

## Self-Validation Loop (post-completion)

After all ACs are implemented (all rows in TRACEABILITY.md show ✅ Refactored):

### Step SV1: Load Assertions
- Read `.forge/validation/assertions-build.yaml`
- Read `.forge/validation/assertions-cross.yaml`

### Step SV2: Run Validation (Internal)
For EACH assertion:
1. BUILD assertions: evaluate against TRACEABILITY.md and actual code
2. Cross-phase assertions:
   - Every AC in SPEC has test(s) + implementation
   - Every domain event has a test
   - Every UI state has a UI test (if UI Contract exists)
   - No orphan tests (tests without AC reference)
   - No orphan implementations (code without test)

Record: assertion_id, passed/failed, evidence

### Step SV3: Present Results
```
📋 Self-Validation BUILD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
BUILD Internal: ✅ {{passed}}/{{total}} blockers | ⚠️ {{passed}}/{{total}} warnings
Cross-phase:   ✅ {{passed}}/{{total}} blockers | ⚠️ {{passed}}/{{total}} warnings

{{if blockers failed}}
❌ Blockers:
- {{ASSERT_ID}}: {{description}} — {{what's missing}}
{{/if}}
```

### Step SV4: Decision Branch
- If ALL blockers pass:
  → "✅ BUILD listo para aprobación. Ejecutá `forge approve`."
  → STOP

- If blockers fail:
  → List specific gaps
  → Suggest fixing them before approval
  → STOP

---

## Output Artifacts

### TRACEABILITY.md
Written to `.forge/features/activo/{slug}/TRACEABILITY.md`.
Updated incrementally after each AC cycle. Contains:

```markdown
# TRACEABILITY — {feature name}

> Generado por Forge BUILD | Feature: {feature}

## Test Review Checkpoint
- Date: YYYY-MM-DD
- Tests generated: N
- AC coverage: N/N
- Auto-gate: PASSED | FAILED (razón)
- Dev adjustments: [lista o "none"]

## Coverage Matrix

| AC_ID | AC_TITULO | EVENTO_IDS | TEST_IDS | TEST_FILES | IMPL_FILES | STATUS |
|-------|-----------|------------|----------|------------|------------|--------|
| AC-1 | {title} | {events} | {test methods} | {test paths} | {impl paths} | ✅ Refactored |
| AC-2 | ... | ... | ... | ... | ... | 🟢 Green |

## Addenda Applied
| ADD_ID | AC_ORIGEN | DESCRIPCION |
|--------|-----------|-------------|
| ADD-1 | AC-3 | {description} |
```

### VALIDATION-BUILD.md
Generated by `forge approve` — NOT by this skill. This skill only generates code and TRACEABILITY.md.

---

## Next Step Bridge

**REQUIRED** at the end of every `forge build` execution. Output this block:

````markdown
---
## ⏭️ Siguiente Paso

El BUILD está completo. El flujo obligatorio es:

1. Revisá el código generado y los tests
2. Ejecutá `forge approve` para aprobar la fase BUILD
3. SOLO DESPUÉS de que `forge approve` confirme BUILD como ✅ Aprobado, ejecutá:

```
forge verify
```

NO ejecutes `forge verify` sin antes aprobar el BUILD con `forge approve`.
`forge verify` verifica que el BUILD esté ✅ Aprobado como precondición y bloqueará si no lo está.
````

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
- SIEMPRE actualizar TRACEABILITY.md después de cada fase del ciclo (RED, GREEN, REFACTOR)
- SIEMPRE seguir el orden de Test Sequencing del SPEC — domain → data → presentation → UI
- SIEMPRE respetar las Decisions del SPEC — no contradecirlas
- NUNCA modificar SPEC.md aprobado — usar el protocolo de addendum
- NUNCA saltar el estado RED — el test debe fallar primero
- NUNCA generar código sin AC que lo justifique
- NUNCA modificar tests escritos en RED durante GREEN — ver "Regla de Tests Inmutables"
- NUNCA proceder a GREEN sin pasar el auto-gate — ver "Auto-gate (RED → GREEN)"
- NUNCA modificar tests ya escritos en un ciclo anterior (a menos que un addendum lo requiera)
- NUNCA declarar un AC como ✅ Refactored si los tests no pasan
- Si el stack skill define convenciones que difieren de tus defaults → el stack skill gana
- Los tests de UI deben cubrir todos los estados del UI Contract (loading, success, error, empty)
- Los tests de interacción deben cubrir todos los gestures del UI Contract

### Test Efficiency
- NUNCA generar tests que dupliquen cobertura de otro test
- SIEMPRE justificar cada test: "¿Qué bug previene que ningún otro cubre?"
- PREFERIR unit tests sobre integration tests, integration sobre UI
- Si un comportamiento se puede verificar con un unit test, NO agregar integration o UI test para lo mismo
- Budget es un RANGO, no un target — estar en el mínimo es perfectamente válido si la cobertura es completa
- Tests de UI SOLO para happy paths críticos que no se pueden verificar en capas inferiores

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
| Implementation does not pass test in GREEN phase | Review implementation against SPEC. Fix implementation, NOT the test. If conflict with SPEC, use addendum protocol. |
| Test appears to have genuine error in GREEN | STOP. Ask dev for permission to modify. Log as "Dev adjustment" in TRACEABILITY.md if approved. |

---

## Return Envelope

### Success
```
**Estado**: `complete`
**Resumen**: {N}/{total} ACs implementados con red-green-refactor
**Artefactos**: Tests en {test paths}, implementación en {impl paths}, TRACEABILITY.md actualizado
**Siguiente comando**: `forge approve`
```

### Partial (continuation available)
```
**Estado**: `partial`
**Resumen**: {M}/{total} ACs completados. Próximo: AC-{N}
**Artefactos**: TRACEABILITY.md actualizado hasta AC-{M}
**Siguiente comando**: `forge build` (para continuar)
```

### Blocked
```
**Estado**: `blocked`
**Error**: {EXXX — message}
**Acción requerida**: {what to do}
```
