---
name: forge-build-green
description: >
  Green+Refactor phase sub-skill for forge-build. Implements per-AC in Test Sequencing order
  to make tests pass, then refactors. Designed to run as a sub-agent with fresh context.
  Receives AC batch assignment from orchestrator.
license: Apache-2.0
metadata:
  author: doubler
  version: "1.0"
---

## Purpose

This is the **GREEN+REFACTOR phase** extracted from `forge-build.md` for sub-agent execution. The sub-agent receives a batch of ACs to implement, reads existing test files from disk (generated during Phase RED), and implements the minimum code to make tests pass. After each AC passes, it refactors. Tests written in RED are **immutable** during GREEN — only the dev can authorize modifications.

This skill is designed to run with fresh context. The orchestrator provides AC batch assignments and file references; the sub-agent reads everything directly from disk.

---

## Preconditions

- `.forge/FORGE.md` exists with an active feature (`feature` and `slug` are non-null)
- `fase_actual` is `BUILD`
- SPEC row in the FORGE.md phase table = `✅ Aprobado`
- BUILD row is NOT yet `✅ Aprobado` (to prevent overwriting an approved artifact)
- TRACEABILITY.md exists with RED tests generated
- Auto-gate passed (tests exist and are valid)

---

## Forge Runtime

→ Execute `_shared/forge-runtime.md` steps R0–R4 before any skill-specific logic. Execute R5 after all skill-specific logic is complete.

---

## Input Contract

When launched as a sub-agent, the orchestrator provides:

- **ac_batch**: List of AC IDs to implement in this batch (e.g., ["AC-1", "AC-2", "AC-3"])
- **context_refs**: Paths to SPEC.md, TRACEABILITY.md, config.yaml, stack skill
- **addenda**: Any approved addenda from previous batches (may be empty)

The sub-agent reads all files directly from disk. The orchestrator does NOT pass file contents.

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

**If an `input_contract` was provided by the orchestrator** (standard execution):
- Use the `ac_batch` from the input contract directly as the list of ACs to implement.
- Do NOT read TRACEABILITY.md to derive the batch — the orchestrator already determined it.

**If no `input_contract` is present** (standalone execution — fallback):
- Read `.forge/features/activo/{slug}/TRACEABILITY.md` if it exists.
- Find the last AC with status `✅ Refactored`.
- The next AC in Test Sequencing order is the continuation point.
- Select ACs with status `🔴 Red` that do not yet have an implementation (no IMPL_FILES entry) as the batch to process.
- If TRACEABILITY.md does not exist or has no entries: start from the first AC in Test Sequencing.

Output:
```
📍 Punto de continuación: AC-{N} — {AC title}
ACs completados: {M}/{total}
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

Proceed to the next AC in Test Sequencing order. If all ACs are complete, proceed to integration tests (if applicable from SPEC test plan), then to Step B5.5.

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

## Addenda Protocol

If during implementation you discover a gap in the SPEC that prevents completing an AC:

1. STOP implementation at that AC
2. Document the gap clearly: what's missing, which AC is blocked, what decision is needed
3. Return with `status: needs_input` and the gap details in `pending_decisions`
4. The orchestrator will present this to the dev and re-launch with the approved addendum

Do NOT modify SPEC.md yourself. Do NOT guess the answer. STOP and return.

---

## Return Contract

When running as a sub-agent, output this structured result at the end:

```yaml
status: complete | partial | needs_input
summary: "{N}/{M} ACs implementados en este batch."
artifacts_written:
  - path: .forge/features/activo/{slug}/TRACEABILITY.md
    action: updated
  - path: {each implementation file path}
    action: created | modified
metrics:
  acs_completed: {N}/{batch_size}
  files_created: {N}
  files_modified: {N}
next_recommended: "forge build" | "forge approve"
pending_decisions:
  - type: addendum
    ac: "AC-N"
    description: "..."
    options: ["A", "B"]
risks: []
```

---

## Rules

### REGLA ABSOLUTA — TEST ANTES DE IMPLEMENTACION

**NUNCA escribir código de implementación sin un test que falle primero. NUNCA. El test define la interfaz — la implementación la satisface.**

Violación de esta regla = BUILD inválido. El AC debe rehacerse desde RED.

---

- SIEMPRE cargar el skill de stack (Step B1) antes de generar cualquier código
- SIEMPRE leer SPEC.md completo antes de empezar el ciclo
- SIEMPRE actualizar TRACEABILITY.md después de cada fase del ciclo (GREEN, REFACTOR)
- SIEMPRE seguir el orden de Test Sequencing del SPEC — domain → data → presentation → UI
- SIEMPRE respetar las Decisions del SPEC — no contradecirlas
- NUNCA modificar SPEC.md aprobado — usar el protocolo de addendum
- NUNCA generar código sin AC que lo justifique
- NUNCA modificar tests escritos en RED durante GREEN — ver "Regla de Tests Inmutables"
- NUNCA modificar tests ya escritos en un ciclo anterior (a menos que un addendum lo requiera)
- NUNCA declarar un AC como ✅ Refactored si los tests no pasan
- Si el stack skill define convenciones que difieren de tus defaults → el stack skill gana

### Error cases

| Condition | Response |
|-----------|----------|
| SPEC not `✅ Aprobado` | Block. E204. |
| BUILD already `✅ Aprobado` | Block. E201. Suggest `forge verify`. |
| No active feature | Block. E202. Suggest `forge new`. |
| Stack skill file not found | Block. E203. Output error with instructions to create it. |
| SPEC.md not found | Block. E200. |
| Implementation does not pass test in GREEN phase | Review implementation against SPEC. Fix implementation, NOT the test. If conflict with SPEC, use addendum protocol. |
| Test appears to have genuine error in GREEN | STOP. Ask dev for permission to modify. Log as "Dev adjustment" in TRACEABILITY.md if approved. |
