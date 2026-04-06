# FORGE — Plan de Auditoría File-by-File

> Rama: `feature/full-audit-review`
> Objetivo: Revisar cada archivo del proyecto punto a punto — consistencia, calidad, gaps, mejoras.
> Estado: 🔄 En progreso

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
| 1 | `config.yaml` | 80 | ⏳ | Stack, modelos LLM, umbrales. Cambiar aquí afecta TODO. |
| 2 | `skills/_shared/forge-runtime.md` | 189 | ⏳ | Protocolo R0–R4. Todos los skills lo ejecutan primero. |
| 3 | `skills/forge-spec.md` | 365 | ⏳ | 7-pasos, 5 Pillars, quality score. Core del pipeline. |
| 4 | `skills/forge-build.md` | 584 | ⏳ | Orquestador RED→GREEN, auto-gate. El skill más complejo. |
| 5 | `validation/assertions-spec.yaml` | 347 | ⏳ | Gates de SPEC. Define qué es "aprobable". |
| 6 | `validation/assertions-build.yaml` | 445 | ⏳ | Gates de BUILD. Inmutabilidad, coverage, calidad. |

---

## TIER 2 — Pipeline completo

| # | Archivo | Líneas | Estado | Notas |
|---|---------|--------|--------|-------|
| 7  | `skills/forge-new.md` | 260 | ⏳ | Bootstrap. Evaluación de profundidad, fragmentación. |
| 8  | `skills/forge-spike.md` | 285 | ⏳ | Exploración técnica opcional. |
| 9  | `skills/forge-build-red.md` | 370 | ⏳ | Fase RED: genera todos los tests sin implementación. |
| 10 | `skills/forge-build-green.md` | 257 | ⏳ | Fase GREEN: implementa AC por AC. |
| 11 | `skills/forge-verify.md` | 406 | ⏳ | Validación post-build. 100% cobertura requerida. |
| 12 | `skills/forge-close.md` | 296 | ⏳ | Archiving, knowledge extraction, reset de ciclo. |
| 13 | `skills/forge-approve.md` | 391 | ⏳ | Aprobación de fases. Actualiza FORGE.md. |
| 14 | `validation/assertions-verify.yaml` | 224 | ⏳ | Gates de VERIFY. Gap analysis, fidelidad. |

---

## TIER 3 — Utilidades y soporte

| # | Archivo | Líneas | Estado | Notas |
|---|---------|--------|--------|-------|
| 15 | `skills/forge-status.md` | 212 | ⏳ | Consulta de estado activo. |
| 16 | `skills/forge-validate.md` | 263 | ⏳ | Validación de precondiciones. |
| 17 | `skills/forge-trace.md` | 219 | ⏳ | Mantiene TRACEABILITY.md. |
| 18 | `skills/forge-ref.md` | 180 | ⏳ | Búsqueda en features cerradas. |
| 19 | `skills/forge-orchestrator.md` | 258 | ⏳ | Coordinación de transiciones de fase. |
| 20 | `validation/assertions-spike.yaml` | 49 | ⏳ | Gates de SPIKE. |
| 21 | `validation/assertions-cross.yaml` | 75 | ⏳ | Gates genéricos (naming, metadata, no secrets). |

---

## TIER 4 — Templates

| # | Archivo | Líneas | Estado | Notas |
|---|---------|--------|--------|-------|
| 22 | `templates/SPEC.md` | 342 | ⏳ | Template de especificación. Core de cada ciclo. |
| 23 | `templates/VERIFY.md` | 102 | ⏳ | Template de reporte de validación. |
| 24 | `templates/TRACEABILITY.md` | 46 | ⏳ | Matriz AC → Test → Implementación. |
| 25 | `templates/SPIKE.md` | 88 | ⏳ | Template de exploración técnica. |
| 26 | `templates/KNOWLEDGE.md` | 49 | ✅ | Rediseñado (thin index). Revisado en sprint anterior. |
| 27 | `templates/INDEX.md` | 93 | ⏳ | Índice de features cerradas. |
| 28 | `templates/VALIDATION.md` | 79 | ⏳ | Checklist de validación por fase. |

---

## TIER 5 — Stacks

| # | Archivo | Líneas | Estado | Notas |
|---|---------|--------|--------|-------|
| 29 | `stacks/android.md` | 119 | ⏳ | Stack Android: patrones, naming, test conventions. |
| 30 | `stacks/kmp.md` | 109 | ⏳ | Stack KMP: shared/platform, test patterns. |
| 31 | `stacks/TEMPLATE.md` | 51 | ⏳ | Template para nuevos stacks. |

---

## TIER 6 — Scripts bash

| # | Archivo | Líneas | Estado | Notas |
|---|---------|--------|--------|-------|
| 32 | `forge-scan.sh` | 1,599 | ⏳ | Analizador legacy Android. Seguridad ya auditada (v2). |
| 33 | `setup-project.sh` | 596 | ⏳ | Setup de proyecto. Seguridad ya auditada (v2). |

---

## TIER 7 — Documentación raíz

| # | Archivo | Líneas | Estado | Notas |
|---|---------|--------|--------|-------|
| 34 | `FORGE.md` | 194 | ⏳ | Estado vivo del proyecto. Leer como usuario. |
| 35 | `config.yaml` | 80 | ⏳ | (mismo que #1 — revisar como doc de referencia) |
| 36 | `PROJECT-STATUS.md` | 386 | ⏳ | Resumen ejecutivo del proyecto. ¿Está actualizado? |
| 37 | `README.md` | 247 | ⏳ | Documentación pública. ¿Refleja v0.7? |
| 38 | `docs/index.html` | 953 | ✅ | Rediseñado en sprint anterior. |
| 39 | `.gitignore` | 23 | ⏳ | Rápido. ¿Faltan exclusiones? |

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
| T1 — Núcleo | 6 | 0 | — | — |
| T2 — Pipeline | 8 | 0 | — | — |
| T3 — Utilidades | 7 | 0 | — | — |
| T4 — Templates | 7 | 1 ✅ | — | — |
| T5 — Stacks | 3 | 0 | — | — |
| T6 — Scripts | 2 | 0 | — | — |
| T7 — Docs | 6 | 1 ✅ | — | — |
| **TOTAL** | **39** | **2** | — | — |

---

_Plan generado: 2026-04-05 | Rama: feature/full-audit-review_
