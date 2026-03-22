# SPIKE — Investigación Técnica
> **Forge Cycle** | Fase opcional — pre-SPEC
> **Estado:** 🔄 En investigación | ✅ Completado | ❌ Descartado
> **Feature:** {{FEATURE_NAME}}
> **Fecha inicio:** {{DATE}}
> **Time-box:** {{N}} horas (máximo recomendado: 4h)

---

## Pregunta a resolver

<!--
UNA pregunta técnica específica. Si hay más de una, separarlas en SPIKEs independientes.
Ejemplo: "¿Es viable implementar offline-first con Room + WorkManager para sincronización?"
-->

{{pregunta_técnica}}

---

## Contexto

<!--
Por qué surge esta pregunta. Qué alternativas se barajan.
2-3 oraciones máximo.
-->

---

## Hallazgos

### Opción A: {{nombre}}

| Aspecto | Evaluación |
|---------|-----------|
| **Viabilidad** | Alta / Media / Baja |
| **Esfuerzo estimado** | {{horas o SP}} |
| **Riesgos** | {{lista}} |
| **Prototipo** | {{link a branch o snippet}} |

### Opción B: {{nombre}}

| Aspecto | Evaluación |
|---------|-----------|
| **Viabilidad** | Alta / Media / Baja |
| **Esfuerzo estimado** | {{horas o SP}} |
| **Riesgos** | {{lista}} |
| **Prototipo** | {{link a branch o snippet}} |

---

## Decisión

**Opción elegida:** {{A / B / Ninguna — feature no viable}}

**Razonamiento:** {{por qué esta opción sobre las otras}}

**Impacto en SPEC:** {{qué restricciones o decisiones se derivan para la SPEC}}

---

## Riesgos residuales

| Riesgo | Probabilidad | Mitigación |
|--------|-------------|-----------|
| {{riesgo}} | Alta / Media / Baja | {{cómo se mitiga}} |

---

## Artefactos del prototipo

<!--
Branches, snippets, benchmarks, screenshots.
Si no hubo prototipo: "N/A — investigación documental."
-->

- Branch: `spike/{{slug}}`
- Archivos: {{lista}}

---

## Checklist de completitud

- [ ] Pregunta técnica respondida con evidencia
- [ ] Al menos 2 opciones evaluadas (o justificación de por qué solo 1)
- [ ] Decisión documentada con razonamiento
- [ ] Riesgos residuales identificados
- [ ] Impacto en SPEC declarado
