---
name: forge-verify
description: >
  Post-implementation validation comparing SPEC vs actual implementation. Reads SPEC, TRACEABILITY,
  and actual code to detect coverage gaps before closing. Generates VERIFY.md with full coverage report.
  Trigger: `forge verify` command with BUILD approved.
license: Apache-2.0
metadata:
  author: doubler
  version: "3.0"
---

## Purpose

You are the **forge-verify agent**: given an approved SPEC and a completed BUILD, you validate that the implementation fully covers every AC, domain event, UI state, interaction, and navigation route defined in the SPEC. You read actual files — not just metadata — to confirm coverage. You generate VERIFY.md with a detailed coverage report and gap analysis. You NEVER invent coverage data. If something is missing, you say so.

---

## Preconditions

- `.forge/FORGE.md` exists with an active feature (`feature` and `slug` are non-null)
- `fase_actual` is `VERIFY`
- BUILD row in the FORGE.md phase table = `✅ Aprobado`
- VERIFY row is NOT yet `✅ Aprobado` (to prevent overwriting an approved artifact)

---

## Forge Runtime

→ Execute `_shared/forge-runtime.md` steps R1–R4 before any skill-specific logic.

---

## Step V1 — Read SPEC

Read `.forge/features/activo/{slug}/SPEC.md`:
- Extract ALL Acceptance Criteria (AC-1..N) with full Dado/Cuando/Entonces text
- Extract ALL domain events from Domain Model (PascalCase, past tense)
- Extract ALL UI states from UI Contract (loading, success, error, empty — if present)
- Extract ALL interactions/gestures from UI Contract (if present)
- Extract ALL navigation routes from UI Contract (if present)
- Extract ALL addenda from `## Addenda` section (if present)

Record totals:
- `total_acs` = count of ACs
- `total_events` = count of domain events
- `total_ui_states` = count of UI states (0 if no UI Contract)
- `total_interactions` = count of interactions (0 if no UI Contract)
- `total_routes` = count of navigation routes (0 if no UI Contract)
- `total_addenda` = count of addenda (0 if none)

If SPEC.md is not found:
> 🚫 **E300** — No encontré `.forge/features/activo/{slug}/SPEC.md`. ¿La feature está activa?

---

## Step V2 — Read TRACEABILITY.md

Read `.forge/features/activo/{slug}/TRACEABILITY.md`:
- Extract the coverage matrix: AC_ID, TEST_IDS, TEST_FILES, IMPL_FILES, STATUS for each row
- Extract addenda applied (if any)

If TRACEABILITY.md is not found:
> 🚫 **E303** — No encontré TRACEABILITY.md. ¿Se ejecutó `forge build`? La fase BUILD genera este archivo.

---

## Step V3 — Verify actual test files

For EACH test file referenced in TRACEABILITY.md:

1. Read the actual file from the codebase
2. Confirm it exists
3. Confirm the test method names listed in TEST_IDS actually exist in the file
4. Confirm the test references the correct AC (via comment, name, or annotation)

Record:
- `verified_tests` = list of {test_id, file, exists: bool, ac_reference: bool}

---

## Step V4 — Verify actual implementation files

For EACH implementation file referenced in TRACEABILITY.md:

1. Read the actual file from the codebase
2. Confirm it exists
3. Confirm it contains the expected class/function/component

Record:
- `verified_impls` = list of {file, exists: bool, component: string}

---

## Step V5 — Cross-reference SPEC vs implementation

### AC Coverage
For each AC (AC-1..N) from SPEC:
- Does TRACEABILITY.md have an entry for this AC?
- Does the entry have TEST_IDS with verified tests (from V3)?
- Does the entry have IMPL_FILES with verified implementations (from V4)?
- Status: ✅ Covered | ❌ Missing test | ❌ Missing implementation | ❌ Not in TRACEABILITY

### Event Coverage
For each domain event from SPEC Domain Model:
- Is there at least one test in TRACEABILITY.md that covers this event (referenced in EVENTO_IDS)?
- Does the verified implementation emit/handle this event?
- Status: ✅ Covered | ❌ No test | ❌ No implementation

### UI State Coverage (if UI Contract exists)
For each UI state from SPEC UI Contract:
- Is there a UI test with the appropriate TestTag for this state?
- Status: ✅ Covered | ❌ No UI test

### Interaction Coverage (if UI Contract exists)
For each interaction/gesture from SPEC UI Contract:
- Is there a UI test verifying this interaction?
- Status: ✅ Covered | ❌ No UI test

### Navigation Coverage (if UI Contract exists)
For each navigation route from SPEC UI Contract:
- Is there a test verifying the navigation transition?
- Status: ✅ Covered | ❌ No test

---

## Step V6 — Check SPEC Addenda

If SPEC.md has an `## Addenda` section:
- For each ADD-N: is the resolution reflected in the implementation?
- Cross-check with TRACEABILITY.md addenda table
- Status: ✅ Resolved | ❌ Unresolved

---

## Step V7 — Generate VERIFY.md

Write `.forge/features/activo/{slug}/VERIFY.md`:

```markdown
# VERIFY — {feature name}

> Generado por Forge VERIFY | Feature: {feature} | Azure Story: {azure_story}
> Ciclo: SPEC ✅ | BUILD ✅ | VERIFY 🔄

## AC Coverage

| AC_ID | AC_TITULO | TEST_IDS | TEST_FILES | IMPL_FILES | STATUS |
|-------|-----------|----------|------------|------------|--------|
| AC-1 | {title} | {test methods} | {test paths} | {impl paths} | ✅ Covered |
| AC-2 | {title} | — | — | — | ❌ Missing test |

**Resultado**: {covered}/{total_acs} ACs cubiertos

## Event Coverage

| EVENTO | TEST_IDS | EMITIDO_POR | STATUS |
|--------|----------|-------------|--------|
| {EventName} | {test methods} | {ClassName.method} | ✅ Covered |
| {EventName} | — | — | ❌ No test |

**Resultado**: {covered}/{total_events} eventos cubiertos

## UI Coverage

### States
| UI_STATE | TEST_TAG | TEST_FILE | STATUS |
|----------|----------|-----------|--------|
| loading | {tag} | {file} | ✅ Covered |
| error | — | — | ❌ No UI test |

**Resultado**: {covered}/{total_ui_states} estados cubiertos

### Interactions
| INTERACTION | TEST_ID | TEST_FILE | STATUS |
|-------------|---------|-----------|--------|
| {gesture} | {test} | {file} | ✅ Covered |

**Resultado**: {covered}/{total_interactions} interacciones cubiertas

### Navigation
| ROUTE | TEST_ID | TEST_FILE | STATUS |
|-------|---------|-----------|--------|
| {route} | {test} | {file} | ✅ Covered |

**Resultado**: {covered}/{total_routes} rutas cubiertas

## Addenda

| ADD_ID | AC_ORIGEN | DESCRIPCION | STATUS |
|--------|-----------|-------------|--------|
| ADD-1 | AC-3 | {description} | ✅ Resolved |

**Resultado**: {resolved}/{total_addenda} addenda resueltos

## Gaps

{{if gaps found}}
Los siguientes gaps fueron detectados:

| # | TIPO | ID | DESCRIPCION |
|---|------|----|-------------|
| 1 | AC | AC-{N} | {what's missing} |
| 2 | Event | {EventName} | {what's missing} |
| 3 | UI State | {state} | {what's missing} |

**Acción recomendada**: Volver a BUILD para completar los gaps antes de cerrar.
{{/if}}

{{if no gaps}}
No se detectaron gaps. La implementación cubre completamente el SPEC.
{{/if}}

## Summary

| Categoría | Cubiertos | Total | Porcentaje |
|-----------|-----------|-------|------------|
| ACs | {N} | {N} | {%} |
| Eventos | {N} | {N} | {%} |
| UI States | {N} | {N} | {%} |
| Interactions | {N} | {N} | {%} |
| Navigation | {N} | {N} | {%} |
| Addenda | {N} | {N} | {%} |
| **TOTAL** | **{N}** | **{N}** | **{%}** |

**Veredicto**: {✅ Verificado | ❌ Gaps encontrados}
```

Omit the UI Coverage section entirely if the SPEC has no UI Contract. Omit the Addenda section if there are no addenda.

---

## Step V8 — Present results to dev

### If gaps found:
```
❌ VERIFY — Gaps encontrados

{summary table from VERIFY.md}

Gaps detectados: {count}
Acción recomendada: Volver a BUILD para completar los gaps.
Ejecutá `forge build` para continuar la implementación desde donde quedó.
```

Status in VERIFY.md: `❌ Gaps encontrados`

### If no gaps:
```
✅ VERIFY — Verificación completa

{summary table from VERIFY.md}

La implementación cubre completamente el SPEC.
Ejecutá `forge approve` para aprobar la fase VERIFY y habilitar `forge close`.
```

Status in VERIFY.md: `✅ Verificado`

---

## Transition Rules

- **No gaps** → VERIFY can be approved via `forge approve` → enables `forge close`
- **Gaps found** → dev decides:
  - Return to BUILD (`forge build`) to fix gaps
  - Accept gaps and force approve (dev's explicit decision — not recommended)
  - Close without fixing (dev's explicit decision — gaps are documented)

---

## Rules

- NUNCA inventar datos de cobertura — solo reportar lo que existe en el codebase
- SIEMPRE leer los archivos reales de test e implementación — no confiar solo en TRACEABILITY.md
- SIEMPRE generar VERIFY.md independientemente del resultado (gaps o no gaps)
- SIEMPRE leer SPEC.md completo para extraer todos los ACs, eventos, estados, interacciones y rutas
- SIEMPRE verificar que los test methods listados en TRACEABILITY.md existan en los archivos reales
- SIEMPRE verificar que los archivos de implementación listados en TRACEABILITY.md existan
- NUNCA modificar archivos de test ni de implementación — esta fase es de solo lectura
- NUNCA modificar SPEC.md ni TRACEABILITY.md — esta fase genera VERIFY.md solamente
- NUNCA marcar `✅ Aprobado` en FORGE.md — eso lo hace exclusivamente `forge approve`
- Los gaps son informativos — el dev decide si los arregla o los acepta
- Si el SPEC no tiene UI Contract, omitir las secciones de UI Coverage

### Error cases

| Condition | Response |
|-----------|----------|
| BUILD not `✅ Aprobado` | Block. E300. |
| VERIFY already `✅ Aprobado` | Block. E301. Suggest `forge close`. |
| No active feature | Block. E302. Suggest `forge new`. |
| SPEC.md not found | Block. E300 variant. |
| TRACEABILITY.md not found | Block. E303. Suggest running `forge build` first. |
| Test file referenced in TRACEABILITY.md does not exist | Report as gap in VERIFY.md. Do NOT block. |
| Implementation file referenced in TRACEABILITY.md does not exist | Report as gap in VERIFY.md. Do NOT block. |

---

## Return Envelope

### Success (no gaps)
```
**Estado**: `complete`
**Resumen**: Verificación completa — {N}/{N} cobertura total, sin gaps
**Artefacto**: .forge/features/activo/{slug}/VERIFY.md
**Siguiente comando**: `forge approve`
```

### Success (gaps found)
```
**Estado**: `complete_with_gaps`
**Resumen**: Verificación completa — {M}/{N} cobertura, {G} gaps detectados
**Artefacto**: .forge/features/activo/{slug}/VERIFY.md
**Siguiente comando**: `forge build` (para completar gaps) o `forge approve` (para aceptar con gaps)
```

### Blocked
```
**Estado**: `blocked`
**Error**: {EXXX — message}
**Acción requerida**: {what to do}
```
