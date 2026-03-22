# VALIDATION — Reporte de Validación
> **Feature:** {{FEATURE_NAME}}
> **Fase validada:** {{PHASE}}
> **Fecha:** {{DATE}}
> **Resultado:** ✅ APROBADO | ❌ BLOQUEADO

---

## Resumen

| Métrica | Valor |
|---------|-------|
| Assertions totales | {{N}} |
| Passed | {{N}} |
| Failed (blocker) | {{N}} |
| Failed (warning) | {{N}} |
| Score | {{passed / total * 100}}% |

---

## Assertions

| ID | Descripción | Severidad | Resultado | Evidencia |
|----|------------|----------|----------|----------|
| {{ASSERT_ID}} | {{qué verifica}} | blocker / warning | ✅ PASS / ❌ FAIL | {{cita textual o descripción de dónde se encontró/no se encontró}} |

---

## Blockers (deben resolverse antes de aprobar)

<!--
Solo se muestra si hay assertions blocker en FAIL.
Si no hay blockers, esta sección se omite.
-->

| ID | Qué falta | Dónde buscarlo | Cómo resolverlo |
|----|----------|---------------|----------------|
| {{ASSERT_ID}} | {{descripción}} | {{sección del artefacto}} | {{acción concreta}} |

---

## Warnings (recomendaciones, no bloquean)

<!--
Solo se muestra si hay assertions warning en FAIL.
Si no hay warnings, esta sección se omite.
-->

| ID | Qué mejoraría | Sugerencia |
|----|--------------|-----------|
| {{ASSERT_ID}} | {{descripción}} | {{recomendación}} |

---

## Cross-Phase (si aplica)

<!--
Solo se muestra si hay assertions cross-phase ejecutadas.
Requiere al menos 2 fases aprobadas.
-->

| ID | Descripción | Resultado | Evidencia |
|----|------------|----------|----------|
| {{CROSS_ASSERT_ID}} | {{qué verifica entre fases}} | ✅ PASS / ❌ FAIL | {{evidencia de trazabilidad}} |

---

## Meta-evaluación

<!--
Preguntas de calidad sobre las propias assertions.
El agente evalúa si las assertions son realmente útiles.
-->

| Pregunta | Respuesta |
|----------|----------|
| ¿Assertions de baja discriminación? | {{sí/no — cuáles pasarían sin importar el contenido}} |
| ¿Gaps de cobertura detectados? | {{sí/no — outcomes importantes no cubiertos por assertions}} |
| ¿Verificación superficial? | {{sí/no — assertions que verifican formato pero no corrección}} |
