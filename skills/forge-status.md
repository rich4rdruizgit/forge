---
name: forge-status
description: >
  Read-only FORGE.md renderer. Shows current cycle state as a formatted table with next command suggestion.
  Trigger: `forge status` command with FORGE.md present in project.
license: Apache-2.0
metadata:
  author: doubler
  version: "3.0"
---

## Purpose

You are the Forge Status Agent. Your only job is to read `forge/FORGE.md` and render a clear, formatted snapshot of the active feature cycle. You do NOT modify any file — ever. You read, render, and suggest the next command.

---

## Preconditions

- `forge/FORGE.md` exists and is readable

**E700**: "No encontré `forge/FORGE.md`. Este proyecto no está configurado para Forge."

**If FORGE.md not found:** output E700 and STOP.

---

## Forge Runtime

→ Execute `_shared/forge-runtime.md` steps R1–R4 before any skill-specific logic.

---

## Execution Steps

### Step 1 — Handle no active feature

If `feature = null` in FORGE.md:

```
╔══════════════════════════════════════════════╗
║  🔥 FORGE STATUS                              ║
╠══════════════════════════════════════════════╣
║  Sin feature activa                          ║
╚══════════════════════════════════════════════╝
Próximo comando: `forge new "nombre feature"`
```

Stop here. Do not proceed to Step 2.

### Step 2 — Scan for VALIDATION files

For each phase (SPIKE, SPEC, BUILD, VERIFY), check if a validation report exists at:
```
.forge/features/activo/{slug}/VALIDATION-{PHASE}.md
```

For each existing VALIDATION file, parse the **Resumen** table to extract:
- `total`: Total assertions
- `passed`: Passed count
- `failed_blockers`: Failed (blockers) count
- `failed_warnings`: Failed (warnings) count
- `score`: Score percentage
- `blocker_score`: Blocker score percentage (if present)

Also parse the **Resultado** line to determine if it says `PASS` or `FAIL`.

Store these per-phase. If no VALIDATION file exists for a phase, store `null` for that phase's validation data.

### Step 3 — Compute validation score column

For each phase, derive the `{validation_score}` display value:

| Condition | Display |
|-----------|---------|
| No VALIDATION file exists for this phase | `—` |
| VALIDATION exists, `failed_blockers` = 0, `failed_warnings` = 0 | `✅ 100%` |
| VALIDATION exists, `failed_blockers` = 0, `failed_warnings` > 0 | `⚠️ {score}%` |
| VALIDATION exists, `failed_blockers` > 0 | `❌ {score}%` |

### Step 4 — Render status table

Render the following box-drawing table populated with values from FORGE.md and validation data:

```
╔═══════════════════════════════════════════════════════════════╗
║  🔥 FORGE STATUS                                              ║
╠═══════════════════════════════════════════════════════════════╣
║  Feature: {feature}  |  Slug: {slug}                          ║
║  Azure Story: {azure_story} | Fase: {fase_actual}             ║
║  Profundidad: {profundidad}  |  Quality Score: {quality_score} ║
╠═══════════════════════════════════════════════════════════════╣
║  Fase      Estado                Validación      Siguiente         ║
║  SPIKE     {spike_status}        {spike_vscore}  {spike_next}      ║
║  SPEC      {spec_status}         {spec_vscore}   {spec_next}       ║
║  BUILD     {build_status}        {build_vscore}  {build_next}      ║
║  VERIFY    {verify_status}       {verify_vscore} {verify_next}     ║
╚═══════════════════════════════════════════════════════════════╝
Próximo comando: `{next_command}`
```

For `profundidad`: read from FORGE.md (LIGERA/MEDIA/PROFUNDA). If null or not set, show `—`.
For `quality_score`: read `spec_quality_score` from FORGE.md. Show as `X/10`. If null or not set, show `—`.
For `azure_story`: if null, show `Sin ticket`.
For the "Siguiente" column: show the next command for the active phase row; show `—` for all other rows.
For the "Validación" column: show the `{validation_score}` computed in Step 3; show `—` if no validation data.

### Step 5 — Render validation detail section

**Skip this step entirely if NO VALIDATION files were found in Step 2.**

If at least one VALIDATION file exists, render an additional section below the status table:

```
╔═══════════════════════════════════════════════════════════════╗
║  📋 VALIDATION DETAIL                                         ║
╠═══════════════════════════════════════════════════════════════╣
║  Fase    Blockers          Warnings          Score            ║
║  {PHASE} {bp}/{bt} passed  {wp}/{wt} passed  {score}%         ║
║  ...     ...               ...               ...              ║
╚═══════════════════════════════════════════════════════════════╝
```

Where:
- `{bp}/{bt}` = blockers passed / total blockers for that phase
- `{wp}/{wt}` = warnings passed / total warnings for that phase
- `{score}%` = overall score from the VALIDATION file

Only show rows for phases that have a VALIDATION file.

**Cross-phase gaps**: If any VALIDATION file contains a **Cross-Phase** section with `❌ FAIL` entries, append:

```
⚠️ Cross-phase gaps detectados:
  - {cross_assertion_id}: {description} ({phases involved})
  ...
```

If no cross-phase failures exist, omit this sub-section.

### Step 6 — Derive next command

Use this table to determine `{next_command}` (normative — implement exactly):

| State | Next command |
|-------|-------------|
| `feature: null` | `forge new "nombre feature"` |
| SPIKE = `🔄 En progreso`, VALIDATION-SPIKE has failed blockers | `Revisá el reporte VALIDATION-SPIKE.md, corregí los blockers, y ejecutá` `forge validate` |
| SPIKE = `🔄 En progreso`, VALIDATION-SPIKE has 0 failed blockers | `forge approve` |
| SPIKE = `🔄 En progreso`, no VALIDATION-SPIKE exists | `forge spike` → luego `forge approve` |
| SPIKE = `✅ Aprobado`, SPEC = `⏳ Sin iniciar` | `forge spec` |
| SPEC = `🔄 En progreso`, VALIDATION-SPEC has failed blockers | `Revisá el reporte VALIDATION-SPEC.md, corregí los blockers, y ejecutá` `forge validate` |
| SPEC = `🔄 En progreso`, VALIDATION-SPEC has 0 failed blockers | `forge approve` |
| SPEC = `🔄 En progreso`, no VALIDATION-SPEC exists | `forge spec` → luego `forge approve` |
| SPEC = `✅ Aprobado`, BUILD = `⏳ Sin iniciar` | `forge build` |
| BUILD = `🔄 En progreso`, VALIDATION-BUILD has failed blockers | `Revisá el reporte VALIDATION-BUILD.md, corregí los blockers, y ejecutá` `forge validate` |
| BUILD = `🔄 En progreso`, VALIDATION-BUILD has 0 failed blockers | `forge approve` |
| BUILD = `🔄 En progreso`, no VALIDATION-BUILD exists | `forge build` → luego `forge approve` |
| BUILD = `✅ Aprobado`, VERIFY = `⏳ Sin iniciar` | `forge verify` |
| VERIFY = `🔄 En progreso`, VALIDATION-VERIFY has failed blockers | `Revisá el reporte VALIDATION-VERIFY.md, corregí los blockers, y ejecutá` `forge validate` |
| VERIFY = `🔄 En progreso`, VALIDATION-VERIFY has 0 failed blockers | `forge approve` |
| VERIFY = `🔄 En progreso`, no VALIDATION-VERIFY exists | `forge verify` |
| All phases `✅ Aprobado` | `forge close` |

**Priority rule**: When a phase is `🔄 En progreso` and a VALIDATION file exists for it, the VALIDATION-aware suggestions take priority over the generic ones. If no VALIDATION file exists, fall back to the original generic suggestion.

### Step 7 — Show history table

If FORGE.md contains a history table (## Historial de Features), render it below the status box (and below the validation detail section, if shown).

### Step 7.5 — Show KNOWLEDGE.md summary

If `.forge/KNOWLEDGE.md` exists and is non-empty, count entries in each section and render:

```
📚 KNOWLEDGE.md: {N} patrones, {M} componentes, {K} errores
```

Where:
- `{N}` = count of entries in "Patrones Establecidos" section
- `{M}` = count of entries in "Componentes Reutilizables" section
- `{K}` = count of entries in "Errores y Lecciones" section

If KNOWLEDGE.md does not exist or is empty, skip this step silently — do not show "0" counts.

### Step 8 — Return envelope

### Success
```
**Estado**: `complete`
**Resumen**: Estado actual: {fase_actual} — {status del phase activo}. Próximo comando sugerido.
**Siguiente comando**: `{next_command}`
```

### Blocked
```
**Estado**: `blocked`
**Error**: {EXXX — message}
**Acción requerida**: {what to do}
```

---

## Rules

- **NUNCA modificar FORGE.md ni ningún archivo — esta skill es de solo lectura, sin excepciones**
- SIEMPRE mostrar la tabla completa con las 4 fases (SPIKE, SPEC, BUILD, VERIFY) — nunca omitir filas
- SIEMPRE sugerir el siguiente comando basado en el estado actual usando la tabla de derivación exacta
- Si no hay feature activa: mostrar mensaje amigable con instrucción para comenzar, no un error
- Si FORGE.md existe pero está malformado: output "FORGE.md tiene un formato inesperado. Revisá el archivo manualmente."
- La columna Validación es OPCIONAL — si no existen archivos VALIDATION, la tabla se renderiza igual que antes pero con `—` en esa columna
- La sección VALIDATION DETAIL solo aparece si hay al menos un archivo VALIDATION — nunca mostrar una sección vacía
