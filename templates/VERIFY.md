# VERIFY — Validación Post-Implementación
> **Forge Cycle** | Fase de verificación
> **Estado:** ✅ Verificado | ❌ Gaps encontrados
> **Feature:** {{FEATURE_NAME}}
> **SPEC:** `forge/features/activo/{{slug}}/SPEC.md` ✅
> **BUILD:** ✅ Aprobado
> **Fecha:** {{DATE}}

---

## AC Coverage

| AC | SPEC (§1) | Test | Implementación | Status |
|----|-----------|------|---------------|--------|
| AC-1: {{título}} | ✅ | {{test_ids}} | {{impl_files}} | ✅ Completo |

**Cobertura:** {{N}}/{{N}} ACs ({{100}}%)

---

## Domain Event Coverage

| Evento | SPEC (§2) | Test | Emitido por | Status |
|--------|-----------|------|-----------|--------|
| {{EventName}} | ✅ | {{test_id}} | {{ClassName.method}} | ✅ Completo |

**Cobertura:** {{N}}/{{N}} eventos ({{100}}%)

---

## UI Coverage

### Estados por pantalla

| Pantalla | Estado | Test | TestTag | Status |
|----------|--------|------|---------|--------|
| {{Screen}} | Loading | {{UI-test}} | {{tag}} | ✅ |
| {{Screen}} | Success | {{UI-test}} | {{tag}} | ✅ |
| {{Screen}} | Error | {{UI-test}} | {{tag}} | ✅ |
| {{Screen}} | Empty | {{UI-test}} | {{tag}} | ✅ |

### Interacciones

| ID | Gesto | Test | Status |
|----|-------|------|--------|
| INT-1 | {{gesto}} | {{UI-test}} | ✅ |

### Navegación

| ID | Ruta | Test | Status |
|----|------|------|--------|
| NAV-1 | {{origen → destino}} | {{nav-test}} | ✅ |

**Cobertura UI:** {{N}}/{{N}} estados, {{N}}/{{N}} interacciones, {{N}}/{{N}} rutas

---

## Gaps detectados

### ACs sin cobertura completa

| AC_ID | Falta test | Falta impl | Falta UI |
|-------|-----------|-----------|---------|

### Eventos sin tests

| Evento | Definido en SPEC | Test |
|--------|-----------------|------|

### SPEC Addenda no resueltos

| ADD-N | Descripción | Resuelto |
|-------|------------|----------|

---

## Resumen

| Métrica | Valor |
|---------|-------|
| ACs cubiertos | {{N}}/{{N}} |
| Eventos cubiertos | {{N}}/{{N}} |
| UI estados cubiertos | {{N}}/{{N}} |
| UI interacciones cubiertas | {{N}}/{{N}} |
| Tests totales | {{N}} |
| Tests pasando | {{N}} |
| Gaps totales | {{N}} |

---

## Checklist de verificación

- [ ] Todos los ACs tienen test + implementación
- [ ] Todos los eventos del dominio emitidos y testeados
- [ ] Todos los estados de UI testeados con TestTags
- [ ] Todas las interacciones testeadas
- [ ] Navegación testeada
- [ ] Cero gaps
- [ ] Suite de tests 100% green
- [ ] Coverage Matrix completa en TRACEABILITY.md

> ✅ **Si todo está cubierto, ejecutar:** `forge approve`
