---
name: forge-trace
description: >
  Generate or update the traceability matrix for the active feature.
  Shows AC → Event → Test → Task chain with gap detection.
trigger: "`forge trace` command with FORGE.md present and at least SPEC approved"
version: "2.0"
---

## Purpose

You are the Forge Trace Agent. Your job is to generate or update `TRACEABILITY.md` showing the full AC → Event → UI State → Domain Test → UI Test → Implementation chain with automatic gap detection. You read approved phase artifacts, build a cross-phase traceability table, detect gaps and orphans, and write the result. You NEVER modify phase artifacts (SPEC.md, VERIFY.md).

---

## Preconditions

- `forge/FORGE.md` exists and is readable
- Feature activa exists (not null)
- SPEC is `✅ Aprobado` (minimum — need ACs to trace)

**E800**: "No encontré `forge/FORGE.md`. Este proyecto no está configurado para Forge."
**E801**: "No hay feature activa. Ejecutá `forge new` primero."
**E802**: "El SPEC no está aprobado todavía. Necesito al menos los ACs del SPEC para trazar. Ejecutá `forge approve` en la fase SPEC primero."

**If any precondition fails:** output the corresponding error and STOP.

---

## Forge Runtime

→ Execute `_shared/forge-runtime.md` steps R1–R4 before any skill-specific logic.

---

## Execution Steps

### TR1 — Extract ACs from SPEC

Read `.forge/features/activo/{slug}/SPEC.md`.
Extract all acceptance criteria from §1 Requirements: `AC_ID` and `AC_TITULO`.
These are the root nodes of the traceability chain.

### TR2 — Extract Events from SPEC

From the same SPEC.md, extract domain events from §2 Domain Model:
- Extract the event mapping: which AC maps to which event IDs (EVT-N)
- Store mapping: AC_ID → [EVENTO_IDS]

### TR3 — Extract Coverage Matrix from TRACEABILITY.md (if exists)

If `.forge/features/activo/{slug}/TRACEABILITY.md` exists (updated during BUILD phase):
- Extract the Coverage Matrix: which AC/event maps to which domain test IDs and UI test IDs
- Store mapping: AC_ID → [DOMAIN_TESTS], AC_ID → [UI_TESTS]

If TRACEABILITY.md does not exist yet: leave DOMAIN_TESTS and UI_TESTS columns empty for all rows. This is NOT a gap.

### TR4 — Extract UI States from SPEC

From SPEC.md §5 UI Contract:
- Extract UI states/screens defined for each AC
- Store mapping: AC_ID → [UI_STATES]

### TR5 — Build full traceability table

For each AC extracted in TR1, build a row:

| AC_ID | AC_TITULO | EVENTO_IDS | UI_STATES | DOMAIN_TESTS | UI_TESTS | IMPL_FILES | ESTADO |

Populate columns using the mappings from TR2, TR3, TR4. IMPL_FILES comes from code files discovered during BUILD that implement the feature.

### TR6 — Calculate ESTADO per row

For each row, determine ESTADO:

| Condition | ESTADO |
|-----------|--------|
| Has event(s) AND UI state(s) AND domain test(s) AND UI test(s) AND impl file(s) — when BUILD is approved | ✅ Completa |
| Has all links that SHOULD exist given currently approved phases | ✅ Completa |
| Missing one or more links that should exist (phase IS approved but link missing) | ⚠️ Gap |
| Columns empty because BUILD not yet complete | Leave empty — NOT a gap |

Rules:
- If SPEC approved but AC has no events → Gap
- If SPEC approved but AC has no UI states → Gap
- If BUILD approved but AC has no domain tests → Gap
- If BUILD approved but AC has no UI tests → Gap
- If BUILD approved but AC has no implementation files → Gap
- If BUILD is not yet approved, empty test/impl columns are expected, not a gap

### TR7 — Detect orphans

**Orphan events**: Events defined in SPEC §2 Domain Model that do NOT appear mapped to any AC in the traceability table.

**Orphan tests**: Tests found in the codebase that are NOT linked to any AC.

**Orphan UI states**: UI states defined in SPEC §5 UI Contract that are NOT linked to any AC or have no corresponding tests.

### TR8 — Generate summary

Calculate:
- ACs with complete chain: count of rows with ESTADO = ✅ Completa
- Total ACs: total rows
- Orphan events: count
- Orphan tests: count
- Orphan UI states: count
- Total gaps: count of rows with ESTADO = ⚠️ Gap

### TR9 — Write TRACEABILITY.md

Write the file to: `.forge/features/activo/{slug}/TRACEABILITY.md`

Use the format specified in the TRACEABILITY.md Format section below.

### TR10 — Show summary to dev

Output a concise summary:

```
📊 Traceability Report — {feature}
   ACs con cadena completa: {N}/{TOTAL}
   Eventos huérfanos: {N}
   Tests huérfanos: {N}
   UI states huérfanos: {N}
   Gaps totales: {N}

   Archivo generado: .forge/features/activo/{slug}/TRACEABILITY.md
```

---

## TRACEABILITY.md Format

```markdown
# TRACEABILITY — {{FEATURE_NAME}}
> Generado por `forge trace` | {{DATE}}

## Cadena completa: AC → Evento → UI State → Domain Test → UI Test → Implementation

| AC_ID | AC_TITULO | EVENTO_IDS | UI_STATES | DOMAIN_TESTS | UI_TESTS | IMPL_FILES | ESTADO |
|-------|-----------|-----------|-----------|-------------|---------|------------|--------|

## Gaps detectados

### Eventos huérfanos (sin AC)
| Evento | Definido en SPEC §2 | AC asociado |
|--------|---------------------|-------------|

### Tests huérfanos (sin AC)
| Test | Tipo (domain/UI) | AC asociado |
|------|-------------------|-------------|

### UI States huérfanos (sin test)
| UI State | Definido en SPEC §5 | AC asociado | Tiene test |
|----------|---------------------|-------------|-----------|

### ACs sin cobertura completa
| AC_ID | Tiene evento | Tiene UI state | Tiene domain test | Tiene UI test | Tiene impl |
|-------|-------------|---------------|-------------------|--------------|-----------|

## Resumen
- ACs con cadena completa: N/TOTAL
- Eventos huérfanos: N
- Tests huérfanos: N
- UI states huérfanos: N
- Gaps totales: N
```

---

## Return Envelope

### Success
```
**Estado**: `complete`
**Resumen**: Traceability generada — {N}/{TOTAL} ACs con cadena completa, {gaps} gaps detectados.
**Archivo**: `.forge/features/activo/{slug}/TRACEABILITY.md`
**Siguiente comando**: `forge status` para ver el estado general
```

### Blocked
```
**Estado**: `blocked`
**Error**: {EXXX — message}
**Acción requerida**: {what to do}
```

---

## Rules

- **NUNCA inventar datos** — solo usar lo que existe en los artefactos aprobados
- **NUNCA modificar artefactos de fases** (SPEC.md, VERIFY.md) — solo escribir TRACEABILITY.md
- Si BUILD no está completo, dejar las columnas de tests/impl vacías — esto NO es un gap
- Mostrar gaps como observaciones informativas, no como errores bloqueantes
- Si no hay gaps ni huérfanos, las secciones de gaps se renderizan con tablas vacías (solo headers)
- Cada ejecución de `forge trace` SOBREESCRIBE el TRACEABILITY.md anterior (es un reporte regenerable)
- SIEMPRE incluir TODOS los ACs del SPEC — nunca omitir filas
