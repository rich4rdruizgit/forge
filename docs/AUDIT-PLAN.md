# FORGE — Plan de Auditoría File-by-File

> Rama: `feature/full-audit-review`
> Objetivo: Revisar cada archivo del proyecto punto a punto — consistencia, calidad, gaps, mejoras.
> Estado: ✅ Completado — 2026-04-05

---

## Metodología

Cada archivo se revisa contra estos ejes:

| Eje | Pregunta |
|-----|---------|
| **Consistencia** | ¿Es coherente con el resto del sistema? ¿Usa las mismas convenciones? |
| **Completitud** | ¿Le falta algo para cumplir su propósito? |
| **Claridad** | ¿Cualquier agente AI lo entiende sin ambigüedad? |
| **Acoplamiento** | ¿Tiene dependencias frágiles con otros archivos? |
| **Deuda** | ¿Hay algo desactualizado, duplicado, o que ya no aplica? |
| **Seguridad** | (scripts bash) ¿Hay vectores de inyección, race conditions, data exposure? |

Resultado por archivo: ✅ OK | ⚠️ Issues menores | 🔴 Issues críticos | ✏️ Mejoras aplicadas

---

## Inventario Total

**39 archivos — ~9,117 líneas**

---

## TIER 1 — Núcleo del sistema (revisar primero)

> Cambios aquí tienen efecto cascada en todo FORGE.

| # | Archivo | Líneas | Estado | Notas |
|---|---------|--------|--------|-------|
| 1 | `config.yaml` | 79 | ✏️ | 4 fixes: fragmentar_en_puntos removida, max_knowledge_entries removida, knowledge_file path corregido, idioma comentado como informativo. |
| 2 | `skills/_shared/forge-runtime.md` | 189 | ✏️ | 4 fixes: R0 KNOWLEDGE.md clarified as thin index; R1 nested-only; E001–E009 ownership; nuevo R5 session close. |
| 3 | `skills/forge-spec.md` | 365 | ✏️ | 4 fixes: R5 added; edge cases table LIGERA/MEDIA/PROFUNDA; KNOWLEDGE.md refs → forge-memory; Rule 11 updated. |
| 4 | `skills/forge-build.md` | 584 | ✏️ | 3 fixes: R5 added; E204 for SPEC-not-approved; B5.5 moved after B6. |
| 5 | `validation/assertions-spec.yaml` | 347 | ✏️ | 4 fixes: v0.7; P2-SPEC-001 step; forge-memory refs; new P3-SPEC-004. |
| 6 | `validation/assertions-build.yaml` | 445 | ✏️ | 4 fixes: v0.7; P1-BUILD-001 cross-ref exclusions; P2 updated; P5-BUILD-002 columns. |

---

## TIER 2 — Pipeline completo

| # | Archivo | Líneas | Estado | Notas |
|---|---------|--------|--------|-------|
| 7  | `skills/forge-new.md` | 260 | ✏️ | 2 fixes: R5 added; Phase 5 summary forge-memory/KNOWLEDGE.md. |
| 8  | `skills/forge-spike.md` | 285 | ✏️ | 6 fixes: v0.7; R5 added; path .forge/; E053 split; forge_mem_search; Step 10.5 persist. |
| 9  | `skills/forge-build-red.md` | 370 | ✏️ | 3 fixes: R5 added; B3 continuation marker; E204 SPEC-not-approved. |
| 10 | `skills/forge-build-green.md` | 257 | ✏️ | 2 fixes: R5 added; E204 SPEC-not-approved. |
| 11 | `skills/forge-verify.md` | 406 | ✏️ | 4 fixes: R5 added; E304 SPEC-not-found; V2 extracts TITULO+EVENTO_IDS; Step V7.5 persist. |
| 12 | `skills/forge-close.md` | 296 | ✏️ | 2 fixes: R5 exception documented; bottom forge-memory section consolidated into K5. |
| 13 | `skills/forge-approve.md` | 391 | ✏️ | 3 fixes: R5 added; TRACEABILITY.md write rule; VERIFY-03 §5→Section 8. |
| 14 | `validation/assertions-verify.yaml` | 224 | ✏️ | 4 fixes: v0.7; P1-VERIFY-001 status; P2-VERIFY-001 description; P5-VERIFY-002 EVENTO_IDS exception. |

---

## TIER 3 — Utilidades y soporte

| # | Archivo | Líneas | Estado | Notas |
|---|---------|--------|--------|-------|
| 15 | `skills/forge-status.md` | 212 | ✏️ | 4 fixes: path .forge/; R5 added; E700 path; Step 7.5 KNOWLEDGE.md section names updated. |
| 16 | `skills/forge-validate.md` | 263 | ✏️ | 1 fix: R5 added. |
| 17 | `skills/forge-trace.md` | 219 | ✏️ | 8 fixes: path .forge/; R5 added; §1→Section 3; §2→Section 7; §5→Section 8 (3 places + format table). |
| 18 | `skills/forge-ref.md` | 180 | ✏️ | 4 fixes: path .forge/; R5 added; REF3 mem_search→forge_mem_search; mem_get_observation→forge_mem_get. |
| 19 | `skills/forge-orchestrator.md` | 258 | ✅ | Sin issues. Paths y tool names correctos. |
| 20 | `validation/assertions-spike.yaml` | 49 | ✏️ | 2 fixes: v0.7; IDs reformateados P1-SPIKE-/P2-SPIKE- con pillar structure. |
| 21 | `validation/assertions-cross.yaml` | 75 | ✏️ | 2 fixes: v0.7; P1-CROSS-004 status Completo→"✅ Covered". |

---

## TIER 4 — Templates

| # | Archivo | Líneas | Estado | Notas |
|---|---------|--------|--------|-------|
| 22 | `templates/SPEC.md` | 342 | ✏️ | 1 fix: DEC-N Referencia KNOWLEDGE.md# → forge-memory topic_key. |
| 23 | `templates/VERIFY.md` | 102 | ✏️ | 2 fixes: path .forge/; ✅ Completo → ✅ Covered (all occurrences). |
| 24 | `templates/TRACEABILITY.md` | 46 | ✅ | Sin issues. |
| 25 | `templates/SPIKE.md` | 88 | ✅ | Sin issues. |
| 26 | `templates/KNOWLEDGE.md` | 49 | ✅ | Rediseñado (thin index). Revisado en sprint anterior. |
| 27 | `templates/INDEX.md` | 93 | ✏️ | 1 fix: Forge version v0.3 → v0.7. |
| 28 | `templates/VALIDATION.md` | 79 | ✅ | Sin issues. |

---

## TIER 5 — Stacks

| # | Archivo | Líneas | Estado | Notas |
|---|---------|--------|--------|-------|
| 29 | `stacks/android.md` | 119 | ✅ | Sin issues. Sólido. |
| 30 | `stacks/kmp.md` | 109 | ✅ | Sin issues. Sólido. |
| 31 | `stacks/TEMPLATE.md` | 51 | ✅ | Sin issues. |

---

## TIER 6 — Scripts bash

| # | Archivo | Líneas | Estado | Notas |
|---|---------|--------|--------|-------|
| 32 | `forge-scan.sh` | 1,599 | ✅ | Seguridad auditada (commits previos). Contenido sólido. |
| 33 | `setup-project.sh` | 596 | ✅ | Seguridad auditada (commits previos). Contenido sólido. |

---

## TIER 7 — Documentación raíz

| # | Archivo | Líneas | Estado | Notas |
|---|---------|--------|--------|-------|
| 34 | `FORGE.md` | 194 | ✏️ | 5 fixes: forge close description; SPEC.md v0.4→v0.7; assertions v0.4→v0.7 (4); R0-R4→R0-R5; forge-close annotation. |
| 35 | `config.yaml` | 80 | ✅ | (revisado como #1) |
| 36 | `PROJECT-STATUS.md` | 386 | ✏️ | 7 fixes: date; file annotations v0.4→v0.7; KNOWLEDGE.md thin index note; forge close description; v0.4 Feature #6 updated. |
| 37 | `README.md` | 247 | ✏️ | 1 fix: forge close description → forge-memory canonical. |
| 38 | `docs/index.html` | 953 | ✅ | Rediseñado en sprint anterior. |
| 39 | `.gitignore` | 23 | ✅ | Sin issues. |

---

## Protocolo por archivo

Para cada archivo la sesión de revisión sigue este formato:

```
## Revisando: {filename}

### Lectura
[Leer el archivo completo]

### Hallazgos
- ✅ / ⚠️ / 🔴 [hallazgo concreto]

### Cambios aplicados
- [qué se cambió y por qué]

### Veredicto final
✅ OK | ⚠️ Issues menores aplicados | 🔴 Issues críticos — requiere revisión profunda
```

---

## Progreso

| Tier | Archivos | Revisados | Issues encontrados | Issues resueltos |
|------|----------|-----------|-------------------|-----------------|
| T1 — Núcleo | 6 | 6 ✅ | 19 | 19 |
| T2 — Pipeline | 8 | 8 ✅ | 26 | 26 |
| T3 — Utilidades | 7 | 7 ✅ | 21 | 21 |
| T4 — Templates | 7 | 7 ✅ | 4 | 4 |
| T5 — Stacks | 3 | 3 ✅ | 0 | 0 |
| T6 — Scripts | 2 | 2 ✅ | 0 (seguridad ya auditada) | — |
| T7 — Docs | 6 | 6 ✅ | 13 | 13 |
| **TOTAL** | **39** | **39** | **83** | **83** |

---

_Plan generado: 2026-04-05 | Rama: feature/full-audit-review_
