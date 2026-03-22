---
name: forge-approve
description: >
  Validate the current phase using assertion-based checks with evidence,
  generate VALIDATION report, and write ✅ Aprobado to FORGE.md if all blockers pass.
  This is the ONLY skill that writes phase approval state. Advances fase_actual to the next phase.
  Trigger: `forge approve` command with FORGE.md present in project.
license: Apache-2.0
metadata:
  author: doubler
  version: "3.0"
---

## Purpose

You are the Forge phase gate. Your job is to execute ALL assertion checks against the current phase artifact, produce a VALIDATION report with per-assertion evidence, and ONLY THEN — if every blocker assertion passes — write `✅ Aprobado` to FORGE.md and advance to the next phase. If any blocker assertion fails, you STOP and list every failure with evidence. Warnings do not block approval. You NEVER modify artifact files — only FORGE.md and VALIDATION-{PHASE}.md.

---

## Preconditions

Before executing anything, verify ALL of these:

1. `.forge/FORGE.md` exists — if not: output E001 and STOP
2. An active feature exists (`feature != null`) — if not: output E010 and STOP
3. `fase_actual` is one of: SPIKE, SPEC, BUILD, VERIFY — if null: block with "No hay fase activa para aprobar. Ejecutá `forge new` primero."
4. Current phase is `🔄 En progreso` — if already `✅ Aprobado`: output E502 and STOP
5. Artifact file exists for the current phase — if not: output artifact-not-found error and STOP. For BUILD: verify `.forge/features/activo/{slug}/TRACEABILITY.md` exists and code files exist; if missing: output E503 and STOP.

**E001**: "No encontré `.forge/FORGE.md`. Este proyecto no está configurado para Forge."
**E010**: "No hay feature activa. Ejecutá `forge new \"nombre feature\"` para comenzar."
**E502**: "La fase {fase_actual} ya está ✅ Aprobado. Los artefactos aprobados son inmutables."
**E503**: "{PHASE}.md no encontrado. Ejecutá `forge {phase}` para generar el artefacto antes de aprobar."

---

## Forge Runtime

→ Execute `_shared/forge-runtime.md` steps R1–R4 before any skill-specific logic.

---

## Execution Steps

### A1 — Identify current phase and locate artifact(s)

Determine `{PHASE}` from `fase_actual`. Locate the artifact:
- **SPIKE**: `.forge/features/activo/{slug}/SPIKE.md`
- **SPEC**: `.forge/features/activo/{slug}/SPEC.md`
- **BUILD**: `.forge/features/activo/{slug}/TRACEABILITY.md` (+ verify code exists)
- **VERIFY**: `.forge/features/activo/{slug}/VERIFY.md`

Read the full content of each located artifact into memory.

### A1.5 — Phase-specific pre-checks

**If current phase is SPEC:**
- Verify SPEC Quality Score is present and ≥ `spec_score_minimo` (from `.forge/config.yaml`, default 7). If score is missing or below threshold: STOP with error "SPEC Quality Score ({score}) es menor que el mínimo requerido ({spec_score_minimo}). Mejorá el SPEC antes de aprobar."
- Read SPEC content to determine which conditional assertion blocks apply: `when_ui_present`, `when_api_present`, `when_domain_present`, `when_bug`, `when_metrics`. Only activate assertions whose conditions match the SPEC content.

**If current phase is BUILD:**
- Verify auto-gate checkpoint exists in TRACEABILITY.md. If TRACEABILITY.md does not contain an auto-gate checkpoint entry: STOP with error "No se encontró checkpoint de auto-gate en TRACEABILITY.md. Ejecutá `forge build` para completar el auto-gate."

### A2 — Load assertion definitions

Load the assertion file for the current phase:
```
.forge/validation/assertions-{phase}.yaml
```

Where `{phase}` is lowercase: `spike`, `spec`, `build`, `verify`.

**Expected format** of each assertion in the YAML:
```yaml
assertions:
  - id: "SPEC-01"
    description: "Problema del usuario definido"
    severity: blocker          # blocker | warning
    verification: >
      Artifact contains a non-empty "Problema" or "Problem" section
      with actual text (not just a header or placeholder).
    search_hints:
      - "## Problema"
      - "## Problem"
```

If the assertion file does not exist: fall back to the hardcoded checklists in the Built-in Fallback Assertions section below. Output a warning: "⚠️ No se encontró `.forge/validation/assertions-{phase}.yaml` — usando assertions built-in."

### A3 — Execute assertions

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
   - source_file: which artifact file contained the evidence
c. NEVER stop at first failure — run ALL assertions regardless of results
```

### A4 — Cross-phase assertions

Check which prior phases are `✅ Aprobado` in the FORGE.md phase table.

If ANY prior phase is approved:
1. Attempt to load `.forge/validation/assertions-cross.yaml`
2. If found, execute each cross-phase assertion:
   - These verify consistency BETWEEN phase artifacts (e.g., "every AC in SPEC has a domain event", "every domain event has tests in BUILD")
   - Load the relevant prior phase artifacts as needed
   - Record results with the same structure as A3, adding `cross_phase: true`
3. If not found: skip cross-phase assertions silently

### A5 — Calculate summary metrics

Compute:
- `total`: total number of assertions executed (phase + cross-phase)
- `passed`: count of passed assertions
- `failed_blockers`: count of failed assertions with severity=blocker
- `failed_warnings`: count of failed assertions with severity=warning
- `score`: percentage of passed assertions (rounded to nearest integer)
- `blocker_score`: percentage of passed blockers out of total blockers (this is the gate metric)

### A6 — Generate VALIDATION-{PHASE}.md

Write the validation report to:
```
.forge/features/activo/{slug}/VALIDATION-{PHASE}.md
```

Use the format defined in the Output Format section below.

**If a previous VALIDATION-{PHASE}.md exists**: overwrite it entirely. Each run produces a fresh report.

This file is ALWAYS generated — whether approval succeeds or fails.

### A7 — Approval gate

**If `blocker_score` is 100%** (all blocker assertions pass — warnings are allowed):
- Proceed to Write Approval (A8)

**If `blocker_score` is < 100%** (any blocker failed):
- STOP — do NOT modify FORGE.md
- Output all failed blockers with evidence:
```
❌ No se puede aprobar el {PHASE}. {failed_blockers} blocker(s) pendiente(s):

- [ ] {assertion_id}: {description} — Evidencia: {evidence or "No encontrada"}
- [ ] {assertion_id}: {description} — Evidencia: {evidence or "No encontrada"}
...

{failed_warnings} warning(s) adicionales (no bloquean aprobación).

Corregí los blockers y ejecutá `forge approve` de nuevo.
Reporte completo: .forge/features/activo/{slug}/VALIDATION-{PHASE}.md
```

### A8 — Write Approval (only when all blocker assertions pass)

Execute these writes in order:

**Write 1 — Update current phase row in FORGE.md**
In the phase table, find the row for `{fase_actual}` and replace its Estado value with `✅ Aprobado`.

**Write 2 — Update next phase row (if not VERIFY)**
In the phase table, find the row for the NEXT phase (per transition table) and replace its Estado value with `🔄 En progreso`.

**Write 3 — Update `fase_actual`**
In the YAML block under `## Ciclo Activo`, set `fase_actual` to the NEXT phase value (per transition table). If current is VERIFY: set to `null`.

**Write 4 — Update TRACEABILITY.md (if applicable)**
If cross-phase assertions were executed in A4 AND the file `.forge/features/activo/{slug}/TRACEABILITY.md` exists:
- Update it with the latest cross-phase assertion results
- Add/refresh the traceability matrix rows showing which ACs map to domain events, tests, and implementation

If TRACEABILITY.md does not exist: skip this step silently.

**Write 5 — Announce**
Output:
```
✅ {PHASE} aprobado ({passed}/{total} assertions passed, {score}%). {failed_warnings} warning(s).
FORGE.md actualizado: {PHASE}=✅ Aprobado, fase_actual={NEXT_PHASE}.
Reporte: .forge/features/activo/{slug}/VALIDATION-{PHASE}.md
Siguiente fase: {NEXT_PHASE} — ejecutá `forge {next-command}` para continuar.
```

Where `next-command` maps as: SPEC→`forge spec`, BUILD→`forge build`, VERIFY→`forge verify`, null→`forge close`.

---

## Phase Transition Table

| `fase_actual` | FORGE.md write | New `fase_actual` | Next phase row status |
|--------------|----------------|-------------------|-----------------------|
| `SPIKE` | SPIKE row → `✅ Aprobado` | `SPEC` | SPEC row → `🔄 En progreso` |
| `SPEC` | SPEC row → `✅ Aprobado` | `BUILD` | BUILD row → `🔄 En progreso` |
| `BUILD` | BUILD row → `✅ Aprobado` | `VERIFY` | VERIFY row → `🔄 En progreso` |
| `VERIFY` | VERIFY row → `✅ Aprobado` | `null` | feature complete — ready for `forge close` |

---

## Output Format — VALIDATION-{PHASE}.md

```markdown
# Validation Report: {PHASE}

**Feature**: {feature} ({slug})
**Fase**: {fase_actual}
**Fecha**: {YYYY-MM-DD HH:mm}
**Resultado**: {APPROVED | BLOCKED}

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

## Decisión

{If APPROVED: "✅ Todos los blockers pasaron. Fase aprobada."}
{If BLOCKED: "❌ {failed_blockers} blocker(s) pendiente(s). Fase no aprobada."}
```

---

## Built-in Fallback Assertions

These are used ONLY when `.forge/validation/assertions-{phase}.yaml` does not exist. All fallback assertions have severity `blocker`.

### SPIKE Fallback (4 assertions)

| ID | Description | Verification |
|----|-------------|-------------|
| SPIKE-01 | Pregunta técnica formulada | Artifact contains a clear technical question or hypothesis to validate (look for "Pregunta", "Hipótesis", "Question", "Hypothesis" sections with content) |
| SPIKE-02 | Scope del spike delimitado | Artifact defines what the spike will and will NOT investigate (look for "Scope", "Alcance", "Límites", timeboxed constraint) |
| SPIKE-03 | Resultado documentado | Artifact contains findings or conclusions from the investigation (look for "Resultado", "Hallazgos", "Findings", "Conclusión") |
| SPIKE-04 | Recomendación con justificación | Artifact contains a recommendation with reasoning (look for "Recomendación", "Recommendation", "Decisión", supported by evidence) |

### SPEC Fallback (7 assertions)

| ID | Description | Verification |
|----|-------------|-------------|
| SPEC-01 | Problema del usuario definido | Artifact contains a non-empty "Problema" or "Problem" section with actual text (not just a header or placeholder) |
| SPEC-02 | Al menos 3 ACs en formato AC-N | Count occurrences of `**AC-` in the artifact; MUST have >=3. Format: `**AC-1:`, `**AC-2:`, `**AC-3:` etc. |
| SPEC-03 | Eventos de dominio definidos | At least 1 event name present in PascalCase ending in past-tense suffix (-ed, -ado, -ido, -Created, -Failed, etc.) in a "Domain Model" or "Eventos" section |
| SPEC-04 | Arquitectura documentada | At least 1 architecture decision or component diagram documented (look for "Arquitectura", "Architecture", "Componentes", "Layers") |
| SPEC-05 | Decisiones técnicas con justificación | At least 1 ADR-style decision with rationale (look for "Decisión", "Decision", "ADR", "Justificación", "Rationale") |
| SPEC-06 | UI Contract definido | At least 1 UI state or screen contract documented (look for "UI Contract", "Estados UI", "Screens", "Pantallas") |
| SPEC-07 | Scope negativo presente | Artifact contains a section about what the feature does NOT include (look for "fuera de scope", "qué NO incluye", "out of scope", "exclusiones") |

### BUILD Fallback (5 assertions)

| ID | Description | Verification |
|----|-------------|-------------|
| BUILD-01 | Cada AC tiene >=1 test que lo referencia | For each `AC-N` found in SPEC.md, at least one test must reference it by name or docstring |
| BUILD-02 | Eventos del dominio tienen tests | For each domain event found in SPEC.md, at least one test must reference that event |
| BUILD-03 | Tests pasan (GREEN) | All referenced test files exist and tests are passing (not just stubs or RED tests) |
| BUILD-04 | Código de producción implementado | Implementation files exist for the feature (not just test files) |
| BUILD-05 | TRACEABILITY.md actualizado | TRACEABILITY.md exists and contains rows mapping ACs to events, tests, and implementation files |

### VERIFY Fallback (4 assertions)

| ID | Description | Verification |
|----|-------------|-------------|
| VERIFY-01 | Todos los ACs verificados | Each AC from SPEC.md has a verification entry with pass/fail status |
| VERIFY-02 | Tests de integración ejecutados | Integration or E2E test results documented with pass/fail counts |
| VERIFY-03 | UI states verificados | Each UI state from SPEC.md §5 has been manually or automatically verified |
| VERIFY-04 | Criterios de aceptación cumplidos | All ACs marked as passing with evidence (screenshots, logs, test output) |

---

## Rules

- **NEVER write `✅ Aprobado` if ANY blocker assertion fails** — even one failed blocker blocks approval completely. Warnings do NOT block.
- **NEVER modify artifact files** — this skill writes ONLY to FORGE.md and VALIDATION-{PHASE}.md. SPIKE.md, SPEC.md, VERIFY.md are never touched by this skill.
- **ALWAYS run ALL assertions before deciding** — never stop at the first failure. The developer needs to see every gap in a single pass.
- **ALWAYS show evidence for each assertion** — not just pass/fail. Show what text from the artifact satisfied the assertion, or "No se encontró evidencia" if it failed.
- **ALWAYS generate VALIDATION-{PHASE}.md** — regardless of whether approval succeeds or fails.
- **NEVER approve an already-approved phase** — if the phase row already contains `✅ Aprobado`, output E502 and STOP immediately.
- **Prefer YAML assertion files over built-in fallbacks** — built-in assertions exist only as a safety net when YAML files are missing.

---

## Differences from `forge validate`

| Aspecto                        | `forge approve`                                    | `forge validate`                          |
|--------------------------------|----------------------------------------------------|-------------------------------------------|
| Modifica FORGE.md              | ✅ If all blockers pass                            | ❌ Nunca                                  |
| Aprueba la fase                | ✅ If all blockers pass                            | ❌ Nunca                                  |
| Genera VALIDATION-{PHASE}.md  | ✅ Always                                          | ✅ Always                                 |
| Carga assertions desde YAML   | ✅ `.forge/validation/assertions-{phase}.yaml`     | ✅ Same                                   |
| Fallback a built-in           | ✅ If YAML missing                                 | ✅ If YAML missing                        |
| Cross-phase assertions        | ✅ If prior phases approved                        | ✅ Same                                   |
| Severity levels               | ✅ blocker blocks, warning passes                  | ✅ Same                                   |
| Updates TRACEABILITY.md       | ✅ If file exists and cross-phase ran              | ❌ No                                     |
| Meta-evaluación                | ❌ No                                              | ✅ Evaluates assertion quality            |
| Cuándo usar                    | Listo para cerrar la fase                          | Iterando antes de aprobar                 |

---

## Return Envelope

### Success
```
**Estado**: `complete`
**Resumen**: {PHASE} aprobado — {passed}/{total} assertions passed ({score}%). {failed_warnings} warning(s). FORGE.md actualizado: {PHASE}=✅ Aprobado, fase_actual={NEXT_PHASE}.
**Artefactos**: .forge/FORGE.md, .forge/features/activo/{slug}/VALIDATION-{PHASE}.md
**Siguiente comando**: `forge {next-command}`
```

### Blocked
```
**Estado**: `blocked`
**Resumen**: {PHASE} no puede aprobarse — {failed_blockers} blocker(s) pendiente(s). {failed_warnings} warning(s).
**Artefacto**: .forge/features/activo/{slug}/VALIDATION-{PHASE}.md
**Acción requerida**: Corregí los blockers y ejecutá `forge approve` nuevamente.
```
