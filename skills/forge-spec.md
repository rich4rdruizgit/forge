---
name: forge-spec
description: >
  7-step conversation protocol for building a validated SPEC.
  Anchors to business problem, validates architecture against project,
  computes Quality Score by 5 pillars.
license: Apache-2.0
metadata:
  author: doubler
  version: "3.0"
---

## Purpose

Build SPEC.md through guided conversation. Each step validates one or more of the 5 Pillars. The conversation IS the validation — by the time the SPEC is complete, it's already validated.

The 5 Pillars:
- **P1** Problema de Negocio — ¿resuelve lo que pide el ticket?
- **P2** Consistencia Arquitectónica — ¿sigue los patrones del proyecto?
- **P3** Tests de Comportamiento Real — ¿los ACs describen comportamiento, no implementación?
- **P4** Integración con lo Existente — ¿reutiliza lo que ya hay?
- **P5** Trazabilidad — ¿cada AC tiene ID, traza a HU, archivos vinculados?

---

## Forge Runtime

→ Execute `_shared/forge-runtime.md` steps R1–R4 before any skill-specific logic.

---

## Preconditions

1. Active feature exists (`feature` non-null in FORGE.md)
2. `fase_actual` is `SPEC`
3. SPEC phase is `🔄 En progreso` or `⏳ Sin iniciar` (NOT `✅ Aprobado`)

**If no active feature — E010:**
> 🚫 E010: No hay feature activa. Ejecutá `forge new "nombre feature"` primero.

**If SPEC already approved — E011:**
> 🚫 E011: La fase SPEC ya está ✅ Aprobado. Los artefactos aprobados son inmutables.

---

## Step 0 — Load Stack Skill

1. Read `.forge/config.yaml` → get `stack` value
2. Look for `.forge/stack-skills/{stack}.md`
3. If file does not exist → STOP:
   > 🚫 E102: No existe skill para el stack '{stack}'.
   > Creá `.forge/stack-skills/{stack}.md` usando la plantilla en `.forge/stack-skills/TEMPLATE.md`.
4. Load the file. Apply ALL naming conventions and patterns throughout the SPEC.

---

## Step 1 — Load Context [P2, P4]

1. Read `KNOWLEDGE.md` from project root
2. Find: applicable patterns, contracts, reusable components, modules touched
3. **Present findings to dev** — this is a GATE, not informational
4. If KNOWLEDGE.md is empty → declare explicitly: "KNOWLEDGE.md está vacío — no hay patrones previos."
5. Read `profundidad` from FORGE.md (set by `forge new`)

Agent MUST present context findings BEFORE asking any SPEC questions. The dev must see what the project already knows before the conversation starts.

If SPIKE.md exists in the feature folder and is `✅ Aprobado`:
- Extract decisions, reasoning, and SPEC impact
- Present as additional context

---

## Step 2 — Anchor to Business Problem [P1]

Confirm the PROBLEM the HU solves, not the SOLUTION it describes.

> "La HU dice [X]. ¿El problema real es [Y]? ¿O hay contexto que no está en la HU?"

Wait for dev response. Record confirmed problem in SPEC section 1 (User Story).

**CRITICAL**: Do NOT proceed to ACs until the business problem is confirmed. If the dev corrects the problem statement, update before continuing.

---

## Step 3 — Work ACs [P1, P3, P5]

For each AC, verify:
- **Origen**: ¿viene del grooming o es nuevo?
- **Formato**: Given/When/Then con "Then" observable
- **Completitud**: ¿faltan escenarios?

### AC Elicitation Loop

```
Para cada AC:
  a. Preguntá: "¿Cuál es el siguiente criterio de aceptación?"
  b. Esperá la respuesta del dev
  c. Formateá como Dado/Cuando/Entonces, mostrá el resultado
  d. Preguntá: "¿Es correcto? (sí / modificar)"
  e. Esperá confirmación
  f. Escribí el AC confirmado en SPEC.md
  g. Preguntá: "¿Hay otro criterio de aceptación? (s/n)"
  h. Repetí o continuá
```

### AC Format

```markdown
| AC-{N} | {título} | Dado {condición} | Cuando {acción} | Entonces {resultado} |
```

### Rules

- **NEVER** add AC without dev approval
- **NEVER** accept AC that describes implementation:
  - ❌ "ViewModel emits Loading state" → REJECT
  - ✅ "user sees loading indicator" → ACCEPT
- **NEVER** continue with vague AC → reject with explanation of what's vague
- **NEVER** suggest "ACs típicos" from similar features — asking is mandatory, suggesting is forbidden
- Mark added ACs as "AC agregado en SPEC — aprobado por dev"

---

## Step 4 — Validate Architecture [P2, P4]

**MEDIA + PROFUNDA only.** Skip for LIGERA (document skip reason).

1. Check KNOWLEDGE.md patterns against proposed approach
   - If dev wants to deviate → must document reason in Decisiones Técnicas (section 10)
2. Check existing code to reuse
   - Section 5a (Componentes a Reutilizar) CANNOT be empty without justification
3. Ask explicitly:
   > "¿Este módulo ya tiene [X]? ¿Hay algo en core/common que podamos reutilizar?"

Wait for dev response. Document findings in sections 5a and 5b.

---

## Step 5 — Complete Sections by Depth [P1-P5]

Ask SPECIFIC questions, never generic:
- ✅ "¿Qué pasa si el usuario pierde conexión a mitad del envío?"
- ❌ "¿Cuáles son los edge cases?"

Fill sections according to `profundidad`:

| # | Sección | LIGERA | MEDIA | PROFUNDA |
|---|---------|--------|-------|----------|
| 1 | User Story (verbatim del ticket) | ✅ | ✅ | ✅ |
| 2 | Profundidad y Justificación | ✅ | ✅ | ✅ |
| 3 | Criterios de Aceptación (GWT) | ✅ | ✅ | ✅ |
| 4 | Casos Borde (mín 2) | ✅ | ✅ | ✅ |
| 5a | Componentes a Reutilizar | ✅ | ✅ | ✅ |
| 5b | Componentes Nuevos | ✅ | ✅ | ✅ |
| 6 | Definition of Done | ✅ | ✅ | ✅ |
| 7 | Modelo de Dominio | — | ✅ | ✅ |
| 8 | Estados de UI | — | ✅ | ✅ |
| 9 | Contrato de Componente | — | ✅ | ✅ |
| 10 | Decisiones Técnicas (ref KNOWLEDGE.md) | — | ✅ | ✅ |
| 11 | Arquitectura por Capa | — | — | ✅ |
| 12 | Contrato de API | — | — | ✅ |
| 13 | Flujo de Datos | — | — | ✅ |
| 14 | Estrategia de Testing por Capa | — | — | ✅ |
| 15 | Dependencias Externas | — | — | ✅ |

For each applicable section, ask targeted questions. Build incrementally — NEVER generate the complete SPEC at once.

---

## Step 6 — Technical Challenge Questions [P1-P4]

The agent asks challenge questions and WAITS. Never invents answers.

| Profundidad | Mínimo preguntas | Pilares a cubrir |
|-------------|-------------------|------------------|
| LIGERA | 1 | ≥ 1 pilar |
| MEDIA | 3 | ≥ 2 pilares |
| PROFUNDA | 5 | ≥ 3 pilares |

### Challenge Types

- **Business challenge (P1)**: "Si el usuario hace [X] y luego [Y], ¿qué debería pasar? La HU no lo dice."
- **Consistency challenge (P2)**: "En KNOWLEDGE.md el patrón es [X]. ¿Aplicamos lo mismo o hay razón para desviarnos?"
- **Testing challenge (P3)**: "¿Cómo verificamos este AC sin depender de [implementación específica]?"
- **Integration challenge (P4)**: "El módulo [X] ya tiene [Y]. ¿Lo reutilizamos o hay razón para duplicar?"

Each question must reference a specific pillar. Record answers in the relevant SPEC section.

---

## Step 7 — Estimation Coherence [P1]

Check coherence between profundidad and story points:

| Condición | Acción |
|-----------|--------|
| PROFUNDA con ≤ 2 puntos | ⚠️ WARN: "La profundidad no cuadra con los puntos. ¿Revisamos?" |
| LIGERA con ≥ 8 puntos | ⚠️ WARN: "La profundidad no cuadra con los puntos. ¿Revisamos?" |
| Puntos ≥ umbral de fragmentación | 🚫 BLOCK: proponer fragmentación |

### Fragmentation Rule

Read `umbral_fragmentacion` from config.yaml (default: 8).

When points ≥ umbral:
> Esta feature supera el umbral de fragmentación ({umbral} puntos). Te propongo dividirla en:
> - {slug}-parte-1: {descripción}
> - {slug}-parte-2: {descripción}
> ¿Confirmás esta división, o preferís continuar con la feature completa?

**MUST wait for dev decision.** The agent proposes, the dev decides.

---

## Step 8 — Generate SPEC + Quality Score [P1-P5]

Write SPEC.md with all applicable sections for the determined profundidad.
Compute and append Quality Score.

### Quality Score Rubric

Total: X/10. Minimum threshold: **7/10** (configurable via `spec_score_minimo` in config.yaml).

#### P1 — Problema de Negocio (0-3)

| Score | Criterio |
|-------|----------|
| 3 | Todos los ACs trazan a la HU + ACs agregados tienen aprobación documentada + problema de negocio confirmado + no hay requisitos implícitos sin AC |
| 2 | ACs trazan pero 1 AC agregado sin aprobación, O 1 requisito implícito faltante |
| 1 | 2+ ACs no trazan a la HU |
| 0 | Los ACs resuelven un problema diferente al confirmado en Step 2 |

#### P2 — Consistencia Arquitectónica (0-2)

| Score | Criterio |
|-------|----------|
| 2 | Patrones de KNOWLEDGE.md referenciados y seguidos (o desviación justificada). **Si KNOWLEDGE.md vacío → 2/2 automático** |
| 1 | Ignora patrones existentes sin justificación |
| 0 | Contradice patrones establecidos |

#### P3 — Testabilidad Real (0-2)

| Score | Criterio |
|-------|----------|
| 2 | Todos los ACs describen comportamiento (no implementación) + input/output identificable sin mencionar mocks |
| 1 | 1-2 ACs describen implementación |
| 0 | Múltiples ACs describen implementación |

#### P4 — Integración (0-2)

| Score | Criterio |
|-------|----------|
| 2 | Sección 5a identifica componentes concretos a reutilizar + no hay duplicación obvia. **Si es la primera feature de un módulo → 2/2 automático** |
| 1 | Sección 5a vacía sin justificación |
| 0 | Ignora código existente completamente |

#### P5 — Trazabilidad (0-1)

| Score | Criterio |
|-------|----------|
| 1 | Cada AC tiene ID único + traza a HU + referencia de ticket + archivos vinculados a ACs |
| 0 | ACs sin ID o archivos sin AC |

### Critical Adaptation Rule

The score adapts to what EXISTS:
- KNOWLEDGE.md empty → P2 automatic 2/2
- First feature in module → P4 automatic 2/2
- Score penalizes IGNORING what exists, NOT absence of prior knowledge

### Score Evaluation

- Score ≥ 7 → "SPEC listo para `forge approve`"
- Score < 7 → list corrections needed by pillar, offer to fix

### Quality Score Block (appended to SPEC.md)

```markdown
## Quality Score

| Pilar | Score | Notas |
|-------|-------|-------|
| P1 — Negocio | {0-3} | {justificación} |
| P2 — Arquitectura | {0-2} | {justificación} |
| P3 — Testabilidad | {0-2} | {justificación} |
| P4 — Integración | {0-2} | {justificación} |
| P5 — Trazabilidad | {0-1} | {justificación} |
| **Total** | **{X}/10** | |
```

---

## Finalization

### Update FORGE.md

After generating SPEC.md:
1. If SPEC row is `⏳ Sin iniciar` → update to `🔄 En progreso`
2. Write `spec_quality_score` to FORGE.md YAML block

---

## Rules

1. **NEVER** invent ACs — ask the dev, always
2. **NEVER** invent technical decisions — present options, dev decides
3. **NEVER** ignore established patterns from KNOWLEDGE.md
4. **NEVER** accept AC describing implementation (reject with explanation)
5. **NEVER** continue with vague AC — reject and explain what's vague
6. **NEVER** generate complete SPEC at once — build incrementally in conversation
7. **ALWAYS** anchor to business problem first (Step 2 before Step 3)
8. **ALWAYS** verify integration: what exists to reuse (Step 4)
9. **ALWAYS** ask challenge questions (min 1/3/5 by depth)
10. **ALWAYS** compute Quality Score with the exact rubric above
11. **ALWAYS** present context from KNOWLEDGE.md BEFORE any questions (Step 1 is a gate)
12. **ALWAYS** load stack skill before generating architecture sections
13. **ALWAYS** one question at a time — wait for response before continuing
14. **ALWAYS** format ACs as Dado/Cuando/Entonces (Given/When/Then if `lenguaje=en`)
15. If SPIKE.md exists → reference its decisions in Decisiones Técnicas
16. If story points ≥ umbral → BLOCK and propose fragmentation before any AC

---

## Error Codes

| Code | Condition | Response |
|------|-----------|----------|
| E010 | No active feature | Block. Instruct `forge new`. |
| E011 | SPEC already `✅ Aprobado` | Block. Artifacts are immutable. |
| E102 | Stack skill file not found | Block. Instruct to create stack skill. |
| E103 | SPEC.md not found on disk | Warn. Recreate from template and continue. |
| E104 | Quality Score < 7 | Warn. List corrections by pillar. |

---

## Return Envelope

### Success
```
Estado: complete
Resumen: SPEC generada — {N} ACs, profundidad {PROF}, Quality Score {X}/10.
Artefacto: .forge/features/activo/{slug}/SPEC.md
Siguiente comando: forge approve
```

### Blocked
```
Estado: blocked
Error: {EXXX} — {message}
Acción requerida: {what to do}
```
