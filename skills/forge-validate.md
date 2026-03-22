---
name: forge-validate
description: >
  Dry-run validation of the current phase. Runs assertions with evidence,
  generates VALIDATION report, but does NOT modify FORGE.md state.
  Use for iteration before forge approve.
trigger: "`forge validate` command with FORGE.md present in project"
license: Apache-2.0
metadata:
  author: doubler
  version: "1.0"
---

## Purpose

You are the Forge validation runner. Your job is to execute ALL assertion checks against the current phase artifact and produce a VALIDATION report — without modifying FORGE.md or approving anything. This is a **non-destructive, read-only** operation designed for iteration: the developer runs `forge validate` to see what passes and what's missing, fixes gaps, and runs it again until clean. Only then do they run `forge approve`.

Think of this as `--dry-run` for `forge approve`, but with richer output: per-assertion evidence, severity levels, coverage metrics, and actionable guidance.

---

## Preconditions

Before executing anything, verify ALL of these:

1. `.forge/FORGE.md` exists — if not: output E001 and STOP
2. An active feature exists (`feature != null`) — if not: output E010 and STOP
3. `fase_actual` is one of: SPIKE, SPEC, BUILD, VERIFY — if null: block with "No hay fase activa para validar. Ejecutá `forge new` primero."
4. Artifact file exists at `.forge/features/activo/{slug}/{PHASE}.md` — if not: output E503 and STOP. For BUILD: verify TRACEABILITY.md exists.

**E001**: "No encontré `.forge/FORGE.md`. Este proyecto no está configurado para Forge."
**E010**: "No hay feature activa. Ejecutá `forge new \"nombre feature\"` para comenzar."
**E503**: "{PHASE}.md no encontrado. Ejecutá `forge {phase}` para generar el artefacto antes de validar."

---

## Forge Runtime

→ Execute `_shared/forge-runtime.md` steps R1–R4 before any skill-specific logic.

---

## Execution Steps

### V1 — Identify current phase and locate artifact(s)

Determine `{PHASE}` from `fase_actual`. Locate the artifact:
- **SPIKE**: `.forge/features/activo/{slug}/SPIKE.md`
- **SPEC**: `.forge/features/activo/{slug}/SPEC.md`
- **BUILD**: `.forge/features/activo/{slug}/TRACEABILITY.md` and any code files referenced within
- **VERIFY**: `.forge/features/activo/{slug}/VERIFY.md`

Read the full content of each located artifact into memory.

### V2 — Load assertion definitions

Load the assertion file for the current phase:
```
.forge/validation/assertions-{phase}.yaml
```

Where `{phase}` is lowercase: `spike`, `spec`, `build`, `verify`.

**Expected format** of each assertion in the YAML:
```yaml
assertions:
  - id: "SPIKE-01"
    description: "Problema del usuario definido"
    severity: blocker          # blocker | warning
    verification: >
      Artifact contains a non-empty "Problema" or "Problem" section
      with actual text (not just a header or placeholder).
    search_hints:
      - "## Problema"
      - "## Problem"
```

If the assertion file does not exist: fall back to the hardcoded checklists matching those in forge-approve (SPIKE items, SPEC items, BUILD items, VERIFY items per their respective checklists). Output a warning: "⚠️ No se encontró `.forge/validation/assertions-{phase}.yaml` — usando checklist built-in."

### V3 — Execute assertions

For EACH assertion in the loaded list:

```
a. Search artifact content for evidence matching the assertion's verification criteria
   and search_hints (if provided)
b. Record result:
   - assertion_id: string
   - description: string
   - severity: blocker | warning
   - passed: boolean
   - evidence: quoted text from artifact (max 200 chars) | "No se encontró evidencia"
   - source_file: which artifact file contained the evidence (relevant for BUILD phase with multiple files)
c. NEVER stop at first failure — run ALL assertions regardless of results
```

### V4 — Cross-phase assertions

Check which prior phases are `✅ Aprobado` in the FORGE.md phase table.

If ANY prior phase is approved:
1. Attempt to load `.forge/validation/assertions-cross.yaml`
2. If found, execute each cross-phase assertion:
   - These verify consistency BETWEEN phase artifacts (e.g., "every AC in SPIKE has a spec entry in SPEC", "every spec entry has traceability in BUILD")
   - Load the relevant prior phase artifacts as needed
   - Record results with the same structure as V3, adding `cross_phase: true`
3. If not found: skip cross-phase assertions silently

### V5 — Calculate summary metrics

Compute:
- `total`: total number of assertions executed (phase + cross-phase)
- `passed`: count of passed assertions
- `failed_blockers`: count of failed assertions with severity=blocker
- `failed_warnings`: count of failed assertions with severity=warning
- `score`: percentage of passed assertions (rounded to nearest integer)
- `blocker_score`: percentage of passed blockers out of total blockers (this is the gate metric)

### V6 — Meta-evaluation

Evaluate the quality of the validation itself:

1. **Non-discriminating assertions**: If ALL assertions pass, flag any that matched trivially (e.g., found a header but no real content). Output: "⚠️ {assertion_id} podría ser non-discriminating — verificá manualmente."
2. **Coverage gaps**: If the artifact has major sections not covered by any assertion, note them. Output: "📋 Secciones sin assertions: {list}"
3. This step is informational only — it does NOT affect pass/fail counts.

### V7 — Generate VALIDATION-{PHASE}.md

Write the validation report to:
```
.forge/features/activo/{slug}/VALIDATION-{PHASE}.md
```

Use the format defined in the Output Format section below.

**If a previous VALIDATION-{PHASE}.md exists**: overwrite it entirely. Each run produces a fresh report.

### V8 — Show summary to developer

Output a concise summary to the console:

**If blocker_score is 100%:**
```
✅ Validación completa: {passed}/{total} assertions passed ({score}%).
{failed_warnings} warnings (no blockers).
→ Estás listo para ejecutar `forge approve`.
Reporte completo: .forge/features/activo/{slug}/VALIDATION-{PHASE}.md
```

**If blocker_score is < 100%:**
```
❌ Validación incompleta: {passed}/{total} assertions passed ({score}%).
{failed_blockers} blockers / {failed_warnings} warnings.

Blockers pendientes:
- [ ] {assertion_id}: {description} — {guidance on where to add it}
...

Corregí los blockers y ejecutá `forge validate` de nuevo.
Reporte completo: .forge/features/activo/{slug}/VALIDATION-{PHASE}.md
```

---

## Output Format — VALIDATION-{PHASE}.md

```markdown
# Validation Report: {PHASE}

**Feature**: {feature} ({slug})
**Fase**: {fase_actual}
**Fecha**: {YYYY-MM-DD HH:mm}
**Resultado**: {PASS | FAIL}

---

## Resumen

| Métrica             | Valor               |
|---------------------|---------------------|
| Total assertions    | {total}             |
| Passed              | {passed}            |
| Failed (blockers)   | {failed_blockers}   |
| Failed (warnings)   | {failed_warnings}   |
| Score               | {score}%            |
| Blocker score       | {blocker_score}%    |

---

## Assertions — {PHASE}

| ID       | Descripción                        | Severidad | Estado | Evidencia                         |
|----------|------------------------------------|-----------|--------|-----------------------------------|
| {id}     | {description}                      | {sev}     | ✅ / ❌ | {evidence snippet or "No encontrada"} |
| ...      | ...                                | ...       | ...    | ...                               |

## Assertions — Cross-Phase

> Solo se ejecutan si hay fases previas aprobadas.

| ID         | Descripción                        | Fases     | Estado | Evidencia                         |
|------------|------------------------------------|-----------|--------|-----------------------------------|
| {id}       | {description}                      | {phases}  | ✅ / ❌ | {evidence snippet}                |

_(Si no hay cross-phase assertions, mostrar: "No aplica — no hay fases previas aprobadas o no se encontró assertions-cross.yaml.")_

## Meta-evaluación

{Output from V6 — non-discriminating warnings, coverage gaps, or "Sin observaciones."}

## Próximos pasos

{If PASS: "Ejecutá `forge approve` para aprobar la fase."}
{If FAIL: Bulleted list of each failed blocker with guidance on what to add/fix.}
```

---

## Rules

- **NUNCA modificar FORGE.md** — esta skill es 100% read-only respecto a FORGE.md. No cambia estado, no aprueba fases, no toca la tabla de fases.
- **NUNCA aprobar la fase** — la única skill autorizada para escribir `✅ Aprobado` es `forge-approve`. Esta skill no tiene esa capacidad.
- **SIEMPRE ejecutar TODAS las assertions** — nunca parar en el primer fallo. El developer necesita ver el panorama completo en un solo paso.
- **SIEMPRE mostrar evidencia para cada assertion** — no basta con pass/fail. Mostrar qué texto del artefacto satisfizo la assertion, o "No se encontró evidencia" si falló.
- **Si el blocker_score es 100%** → sugerir `forge approve` como próximo paso.
- **Si hay blockers failed** → listar exactamente qué falta y orientar al developer sobre dónde agregarlo en el artefacto.
- **SIEMPRE sobreescribir** el VALIDATION-{PHASE}.md previo si existe — cada ejecución es un snapshot fresco.

---

## Differences from `forge approve`

| Aspecto                        | `forge validate`                          | `forge approve`                          |
|--------------------------------|-------------------------------------------|------------------------------------------|
| Modifica FORGE.md              | ❌ Nunca                                  | ✅ Escribe aprobación y avanza fase      |
| Aprueba la fase                | ❌ Nunca                                  | ✅ Si el checklist pasa                  |
| Para en primer fallo           | ❌ Ejecuta TODAS las assertions           | ❌ También lista todos los faltantes     |
| Genera reporte                 | ✅ VALIDATION-{PHASE}.md con evidencia    | ❌ Solo output en consola                |
| Carga assertions desde YAML    | ✅ `.forge/validation/assertions-{phase}.yaml` | ❌ Checklist hardcoded                  |
| Cross-phase assertions         | ✅ Si hay fases previas aprobadas         | ❌ No verifica cruce entre fases         |
| Meta-evaluación                | ✅ Evalúa calidad de las assertions       | ❌ No aplica                             |
| Severity levels                | ✅ blocker / warning                      | ❌ Todo es blocker implícito             |
| Cuándo usar                    | Iterando antes de aprobar                 | Listo para cerrar la fase                |

---

## Return Envelope

### Success (all blockers pass)
```
**Estado**: `pass`
**Resumen**: Validación {PHASE} completa — {passed}/{total} assertions passed ({score}%). {failed_warnings} warnings.
**Artefacto**: .forge/features/activo/{slug}/VALIDATION-{PHASE}.md
**Siguiente comando**: `forge approve`
```

### Fail (blockers pending)
```
**Estado**: `fail`
**Resumen**: Validación {PHASE} incompleta — {failed_blockers} blockers pendientes.
**Artefacto**: .forge/features/activo/{slug}/VALIDATION-{PHASE}.md
**Acción requerida**: Corregí los {failed_blockers} blockers y ejecutá `forge validate` de nuevo.
```
