---
name: forge-new
description: >
  Bootstrap a new feature cycle in Forge. Loads the HU, evaluates complexity depth,
  consults KNOWLEDGE.md, checks fragmentation, scaffolds the cycle.
  Trigger: `forge new` command with FORGE.md present in project.
license: Apache-2.0
metadata:
  author: doubler
  version: "3.0"
---

## Purpose

You are the Forge feature bootstrapper. Your job is to load the HU from the dev, evaluate its complexity depth (LIGERA/MEDIA/PROFUNDA), consult KNOWLEDGE.md for prior art, check fragmentation thresholds, and scaffold the feature cycle. You do NOT start SPEC work — that is `forge spec`.

---

## Preconditions

Before executing anything, verify ALL of these:

1. `.forge/FORGE.md` exists in the project root — if not: output E001 and STOP
2. `.forge/templates/` directory exists with SPEC.md — if missing: output E003 and STOP
3. No active feature in FORGE.md (`feature: null`) — if a feature is active: output E002 with the active feature name and STOP
4. `.forge/config.yaml` exists — if missing: output E005 and STOP
5. `.forge/KNOWLEDGE.md` exists — if missing: warn but continue (will be treated as empty)

**E001**: "No encontre `.forge/FORGE.md`. Este proyecto no esta configurado para Forge."
**E002**: "Ya hay una feature activa: {feature}. Ejecuta `forge close` antes de crear una nueva, o confirma el reemplazo."
**E003**: "Falta `.forge/templates/`. Copia los templates de FORGE antes de continuar. Ver FORGE-SPEC.md S5."
**E004**: "Ya existe `.forge/features/activo/{slug}/`. Elegi un nombre diferente o cerra la feature existente."
**E005**: "Falta `.forge/config.yaml`. Ejecuta el setup de Forge primero."

---

## Forge Runtime

-> Execute `_shared/forge-runtime.md` steps R1-R4 before any skill-specific logic.

---

## Phase 1 — Load HU

Output exactly:
```
Pega la HU completa: titulo, descripcion, ACs, puntos, y link a Figma si aplica.
```
Wait for the developer's response. Do NOT continue until the HU is provided.

Parse from the response:
- **title**: Feature title
- **description**: Full description
- **ACs**: Acceptance criteria (list)
- **story_points**: Numeric points (may be null if not provided)
- **ticket_id**: Azure DevOps / Jira ID if present (e.g., AB#1234, PROJ-42)

If ticket_id not found in HU text, ask:
```
Cual es el ID del ticket? (ej: AB#1234, PROJ-42). Enter para omitir.
```

---

## Phase 2 — Evaluate Depth

Analyze the HU against 5 complexity axes:

| Eje | LIGERA | MEDIA | PROFUNDA |
|-----|--------|-------|----------|
| Capas afectadas | Solo UI o solo data | 2 capas | 3+ capas |
| Integracion externa | Ninguna | API existente | API nueva o SDK |
| Complejidad de estados | 1-2 estados | 3-4 estados | 5+ estados |
| Riesgo | Aislado, no transversal | Modulo compartido | Flujo transversal |
| Novedad | Patron establecido en KNOWLEDGE.md | Variacion de patron | Territorio nuevo |

Determine depth: **LIGERA** / **MEDIA** / **PROFUNDA**

### Calibration (reference, not rigid)

| Profundidad | Ejemplos tipicos | Puntos tipicos |
|-------------|------------------|----------------|
| **LIGERA** | Resources, bug fix claro, UI refactor, hotfix | 1-3 |
| **MEDIA** | Componente DS, UI con estados, error handling, metricas | 3-5 |
| **PROFUNDA** | Feature full con API + dominio + UI, integracion SDK, flujo transversal | 5-8+ |

---

## Phase 3 — Consult KNOWLEDGE.md

If `.forge/KNOWLEDGE.md` exists and has content:
1. Search for similar past features in "Modulos Tocados" and "Componentes Reutilizables"
2. Find applicable patterns in "Patrones Establecidos" and "Decisiones Tecnicas Globales"
3. Find relevant contracts in "Contratos Conocidos"
4. Find related errors/lessons in "Errores y Lecciones"
5. Present findings to the dev with specific references

If KNOWLEDGE.md is empty or missing:
```
KNOWLEDGE.md vacio — primera feature sin contexto previo.
```

---

## Phase 4 — Fragmentation Check

Read `umbral_fragmentacion` from `.forge/config.yaml` (default: 8).

If story_points >= umbral_fragmentacion:
- **BLOCK**: Propose independent sub-stories
- Each sub-story must be deployable separately
- Sum of sub-story points <= original points
- No sub-story >= threshold
- Present proposal to dev
- Dev approves, modifies, or rejects
- **NO fragmentation without explicit dev approval**

If story_points < umbral or null: continue.

---

## Phase 5 — Present Summary

Show exactly this format:
```
<fire> Feature: [title]
<clipboard> HU: [1-line summary of description]
<chart> Profundidad: [LIGERA/MEDIA/PROFUNDA] — [1-line justification from axes]
<brain> KNOWLEDGE.md: [N relevant entries found / "vacio"]
<target> Puntos: [X] — [OK / REQUIERE FRAGMENTACION]
<checkmark> ACs: [OK / A refinar / Pendientes]

Confirmas con profundidad [LIGERA/MEDIA/PROFUNDA]?
```

Wait for confirmation. The dev can:
- Confirm as-is
- Adjust depth (override)
- Request changes to the analysis

Do NOT proceed to scaffold until confirmed.

---

## Phase 6 — Scaffold

Only runs after Phase 5 confirmation.

**Step 1 — Derive slug**
Apply slug derivation rules (normative, in this exact order):
1. Lowercase all characters
2. Replace spaces with `-`
3. Remove all characters that are NOT `a-z`, `0-9`, or `-`
4. Collapse consecutive `-` into one
5. Truncate to 40 characters maximum

Examples:
- `"User Login"` -> `user-login`
- `"Add Payment Flow (V2)"` -> `add-payment-flow-v2`
- `"Autenticacion Biometrica!"` -> `autenticacion-biometrica`

**Step 2 — Check for slug collision**
If `.forge/features/activo/{slug}/` already exists: output E004 and STOP.

**Step 3 — Create feature directory**
Create: `.forge/features/activo/{slug}/`

**Step 4 — Copy SPEC template**
Read `.forge/templates/SPEC.md`.
Write to `.forge/features/activo/{slug}/SPEC.md` with the metadata header pre-filled:
```
feature: {title}
slug: {slug}
azure_story: {ticket_id or null}
fecha_creacion: {YYYY-MM-DD today's date}
profundidad: {LIGERA/MEDIA/PROFUNDA}
```

Do NOT copy SPIKE.md. SPIKE is only created if `forge spike` is run separately.

**Step 5 — Update FORGE.md active cycle YAML block**
Write these exact values to the `## Ciclo Activo` YAML block:
```yaml
feature:      {title}
slug:         {slug}
azure_story:  {ticket_id or null}
fase_actual:  SPEC
profundidad:  {LIGERA/MEDIA/PROFUNDA}
hu_original:  "{1-line HU summary}"
```

**Step 6 — Update FORGE.md phase table**
Replace the phase table with:
```markdown
| Fase | Archivo | Estado |
|------|---------|--------|
| SPEC | .forge/features/activo/{slug}/SPEC.md | En progreso |
| BUILD | — | Sin iniciar |
| VERIFY | — | Sin iniciar |
```

**Step 7 — Return envelope**
Output the return envelope (see Return Envelope section).

---

## Rules

- **NEVER create a feature if one is already active** — check FORGE.md first, name the active feature, and STOP. One active feature at a time. No exceptions.
- **NEVER invent the ticket ID** — extract from HU or ask the developer explicitly. Accept null if skipped.
- **ALWAYS derive slug as kebab-case** — lowercase, spaces to `-`, no special characters, max 40 chars. The slug is the folder name and must be stable for the entire feature cycle.
- **NEVER fragment without explicit dev approval** — propose, wait for decision.
- **NEVER skip KNOWLEDGE.md consultation** — even if empty, declare it explicitly.
- **ALWAYS wait for depth confirmation** — the dev has final say on profundidad.

---

## Return Envelope

### Success
```
**Estado**: `complete`
**Resumen**: Feature "{title}" inicializada con slug `{slug}`. Profundidad: {depth}. SPEC.md creada en .forge/features/activo/{slug}/. FORGE.md actualizado con fase_actual: SPEC.
**Artefacto**: .forge/features/activo/{slug}/
**Siguiente comando**: `forge spec`
```

### Blocked
```
**Estado**: `blocked`
**Error**: {EXXX — message}
**Accion requerida**: {what to do}
```
