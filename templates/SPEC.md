# SPEC — {{feature-name}}

> Forge v0.4 | Profundidad: {{LIGERA|MEDIA|PROFUNDA}}
> Feature: {{slug}} | Puntos: {{X}} | Ticket: {{ref}} | Fecha: {{fecha}}

---

## 1. Historia de Usuario
<!-- SIEMPRE — Copiar textual del ticket. Incluir referencia Azure DevOps. [P1, P5] -->

```
COMO    {{tipo de usuario}}
QUIERO  {{acción o capacidad}}
PARA    {{beneficio o valor}}
```

**Azure DevOps:** {{url o ID del ticket}}

---

## 2. Profundidad y Justificación
<!-- SIEMPRE — Profundidad evaluada + ejes de complejidad + ajuste del dev si hubo -->

| Eje | Evaluación | Detalle |
|-----|-----------|---------|
| Lógica de negocio | Baja / Media / Alta | {{descripción}} |
| Superficie de UI | Baja / Media / Alta | {{descripción}} |
| Integración con existente | Baja / Media / Alta | {{descripción}} |
| Riesgo técnico | Bajo / Medio / Alto | {{descripción}} |

**Profundidad resultante:** {{LIGERA | MEDIA | PROFUNDA}}

**Justificación:** {{Por qué se eligió esta profundidad. Si el dev ajustó la evaluación del agente, documentar razón.}}

---

## 3. Criterios de Aceptación
<!-- SIEMPRE — Formato Dado/Cuando/Entonces. "Entonces" = comportamiento observable.
     ACs del grooming: marcar origen. ACs agregados: marcar con aprobación del dev. [P1, P3, P5] -->

| ID | Origen | Dado | Cuando | Entonces |
|----|--------|------|--------|----------|
| AC-1 | Grooming | {{condición inicial}} | {{acción del usuario}} | {{resultado observable}} |
| AC-2 | Grooming | {{condición inicial}} | {{acción del usuario}} | {{resultado observable}} |
| AC-3 | Agregado — aprobado por {{dev}} | {{condición inicial}} | {{acción del usuario}} | {{resultado observable}} |

---

## 4. Casos Borde
<!-- SIEMPRE — Mínimo 2. Cada uno con AC correspondiente o justificación de por qué no tiene AC. [P1] -->

| ID | Caso | AC relacionado | Comportamiento esperado |
|----|------|---------------|------------------------|
| CB-1 | {{descripción del caso borde}} | AC-{{N}} | {{qué debe pasar}} |
| CB-2 | {{descripción del caso borde}} | AC-{{N}} / Sin AC — {{justificación}} | {{qué debe pasar}} |

---

## 5. Archivos y Componentes Afectados

### 5a. Componentes existentes a reutilizar
<!-- SIEMPRE — Clases, utilidades, componentes que YA EXISTEN y que esta feature DEBE usar. [P4]
     Si no hay ninguno, JUSTIFICAR. Incluir: nombre, módulo, para qué se usa. -->

| Nombre | Módulo | Para qué se usa |
|--------|--------|----------------|
| {{NombreClase}} | {{módulo/paquete}} | {{propósito concreto}} |

> Si no hay componentes reutilizables: {{justificación explícita de por qué todo es nuevo}}

### 5b. Archivos nuevos a crear
<!-- SIEMPRE — Archivos nuevos. Para cada uno: por qué no se resuelve reutilizando. [P4, P5]
     Vincular cada archivo a al menos un AC. -->

| Archivo | Capa | AC vinculado | Por qué no se reutiliza existente |
|---------|------|-------------|----------------------------------|
| `{{path/NombreArchivo}}` | {{UI / Domain / Data}} | AC-{{N}} | {{razón}} |

---

## 6. Definición de Done
<!-- SIEMPRE — Concreta. Sin verbos ambiguos. [P3] -->

- [ ] {{Criterio observable y verificable — no "implementar X", sino "X funciona cuando Y"}}
- [ ] {{Criterio de testing: qué tests pasan}}
- [ ] {{Criterio de integración: qué flujo completo funciona}}
- [ ] PR aprobado con cobertura ≥ {{N}}% en capa domain y presentation
- [ ] Sin warnings de lint ni errores de compilación

---

## 7. Modelo de Dominio
<!-- MEDIA + PROFUNDA — Entidades, propiedades, relaciones, invariantes. [P1] -->
<!-- LIGERA: omitir esta sección o dejar vacía con justificación -->

### Entidades

| Entidad | Propiedades clave | Invariantes |
|---------|------------------|------------|
| {{NombreEntidad}} | {{prop: tipo, prop: tipo}} | {{regla que nunca puede violarse}} |

### Relaciones

```
{{EntidadA}} 1 ──── N {{EntidadB}}
{{EntidadB}} 1 ──── 1 {{EntidadC}}
```

### Glosario de dominio

| Término | Definición |
|---------|-----------|
| {{término}} | {{definición en lenguaje del negocio}} |

---

## 8. Estados de UI
<!-- MEDIA + PROFUNDA (si hay UI) — Todos los estados. Mínimo: loading, empty, error, success. [P1, P3] -->
<!-- LIGERA: omitir si no hay UI compleja -->

### {{NombrePantalla}}

| Estado | Condición | Elementos visibles | TestTag |
|--------|-----------|-------------------|---------|
| Loading | Petición en curso | Skeleton / ProgressBar | `tag_{{screen}}_loading` |
| Success | Datos disponibles | {{contenido principal}} | `tag_{{screen}}_content` |
| Empty | Sin datos | EmptyState + CTA | `tag_{{screen}}_empty` |
| Error | Fallo de red o servidor | ErrorMessage + Retry | `tag_{{screen}}_error` |
| {{EstadoExtra}} | {{condición}} | {{qué se muestra}} | `tag_{{screen}}_{{estado}}` |

---

## 9. Contrato de Componente
<!-- MEDIA + PROFUNDA (si aplica) — Props, callbacks, variantes. -->
<!-- LIGERA: omitir si no hay componentes nuevos con interfaz pública -->

### {{NombreComponente}}

```kotlin
@Composable
fun {{NombreComponente}}(
    {{prop}}: {{Tipo}},                    // {{descripción}}
    {{prop}}: {{Tipo}} = {{default}},      // {{descripción}}
    on{{Accion}}: ({{Param}}) -> Unit,     // {{cuándo se dispara}}
)
```

| Variante | Condición | Diferencia visual |
|----------|-----------|------------------|
| {{variante}} | {{cuándo}} | {{qué cambia}} |

---

## 10. Decisiones Técnicas
<!-- MEDIA + PROFUNDA — Decisión + alternativas descartadas + razón. Referencia a KNOWLEDGE.md. [P2] -->
<!-- LIGERA: omitir si no hubo decisiones no triviales -->

### DEC-1: {{pregunta o dilema técnico}}

| Campo | Valor |
|-------|-------|
| **Contexto** | {{por qué surgió la decisión}} |
| **Decisión** | {{qué se eligió}} |
| **Referencia** | KNOWLEDGE.md#{{sección}} |

| Opción | Pros | Contras |
|--------|------|---------|
| A: {{opción elegida}} | {{pros}} | {{contras}} |
| B: {{opción descartada}} | {{pros}} | {{por qué se descartó}} |

**Razonamiento:** {{explicación del tradeoff y condiciones que cambiarían la decisión}}

---

## 11. Arquitectura por Capa
<!-- PROFUNDA — Presentation / Domain / Data + responsabilidades concretas. [P2] -->
<!-- LIGERA y MEDIA: omitir -->

```
Presentation
  └── {{ScreenName}}           → Observa UiState, delega eventos al ViewModel
  └── {{ViewModelName}}        → Expone StateFlow<UiState>, invoca UseCases

Domain
  └── {{UseCaseName}}          → Orquesta lógica, retorna Result<T>
  └── {{EntityName}}           → Entidad con invariantes
  └── {{RepositoryInterface}}  → Contrato (solo interfaz)

Data
  └── {{RepositoryImpl}}       → Implementa contrato, coordina fuentes
  └── {{RemoteDataSource}}     → Llamadas HTTP, mapea DTOs
  └── {{LocalDataSource}}      → Room / DataStore
```

**Reglas de dependencia:**
- Presentation → Domain (nunca al revés)
- Domain → cero dependencias externas
- Data → implementa interfaces de Domain

---

## 12. Contrato de API
<!-- PROFUNDA (si hay API) — Endpoint, método, request, response, códigos de error. [P1] -->
<!-- LIGERA y MEDIA: omitir si no hay API nueva -->

### `{{MÉTODO}} {{/ruta/del/endpoint}}`

**Request:**
```json
{
  "{{campo}}": "{{tipo — descripción}}"
}
```

**Response exitosa (`200`):**
```json
{
  "{{campo}}": "{{tipo — descripción}}"
}
```

**Códigos de error:**

| Código | Significado | Comportamiento en app |
|--------|------------|----------------------|
| 400 | {{descripción}} | {{qué muestra la UI}} |
| 401 | No autorizado | Redirigir a login |
| 404 | {{descripción}} | {{qué muestra la UI}} |
| 500 | Error de servidor | Error genérico + retry |

---

## 13. Flujo de Datos
<!-- PROFUNDA — Acción usuario → ViewModel → UseCase → Repository → API → respuesta → UI. [P1] -->
<!-- LIGERA y MEDIA: omitir -->

```
Usuario: {{acción}}
  │
  ▼
{{ViewModelName}}.{{onAction}}()
  │  emite UiState.Loading
  ▼
{{UseCaseName}}.invoke({{params}})
  │
  ▼
{{RepositoryImpl}}.{{method}}()
  │  verifica caché local → si válido, retorna sin llamar API
  ▼
{{RemoteDataSource}}.{{method}}()
  │  GET/POST {{/endpoint}}
  ▼
Respuesta HTTP
  │  mapea DTO → Entidad de dominio
  ▼
{{RepositoryImpl}} retorna Result<{{Tipo}}>
  │
  ▼
{{UseCaseName}} retorna Result<{{Tipo}}>
  │
  ▼
{{ViewModelName}} emite UiState.Success(data) o UiState.Error(msg)
  │
  ▼
UI re-compone con nuevo estado
```

---

## 14. Estrategia de Testing por Capa
<!-- PROFUNDA — Qué se testea en cada capa, con qué herramientas. [P3] -->
<!-- LIGERA y MEDIA: omitir o simplificar a tabla básica -->

| Capa | Qué se testea | Herramientas | Criterio mínimo |
|------|--------------|-------------|----------------|
| Domain / UseCase | Lógica de negocio, invariantes, flujos de error | JUnit5 + MockK + Turbine | Todos los ACs cubiertos |
| Repository | Coordinación caché/red, mapeo de errores | MockK + coroutines-test | Rutas feliz y error |
| ViewModel | Estados emitidos por acción, side effects | Turbine + MockK | Estado por cada AC |
| UI | Renderizado de estados, interacciones | Compose Testing | Estados loading/success/error/empty |
| API / Data Source | Contrato HTTP, parsing de DTOs | MockWebServer | Request/response por endpoint |

### Casos críticos a testear

| ID | Caso | Capa | AC vinculado |
|----|------|------|-------------|
| T-1 | {{descripción del caso}} | {{capa}} | AC-{{N}} |
| T-2 | {{descripción del caso}} | {{capa}} | AC-{{N}} |

---

## 15. Dependencias Externas
<!-- PROFUNDA (si aplica) — Librerías, SDKs, versiones. -->
<!-- LIGERA y MEDIA: omitir si no hay dependencias nuevas -->

| Librería / SDK | Versión | Para qué se usa | Ya en el proyecto |
|---------------|---------|----------------|------------------|
| {{nombre}} | {{versión}} | {{propósito}} | Sí / No |

---

## Validación del SPEC
<!-- SIEMPRE — Generado por el agente. NO llenar manualmente. -->

**SPEC Quality Score: _/10**

| Pilar | Dimensión | Score | Detalle |
|-------|-----------|-------|---------|
| P1 | Problema de negocio | _/3 | |
| P2 | Consistencia arquitectónica | _/2 | |
| P3 | Testeabilidad real | _/2 | |
| P4 | Integración con existente | _/2 | |
| P5 | Trazabilidad | _/1 | |

### Problema de negocio confirmado
<!-- ¿Los ACs reflejan comportamiento observable por el usuario final? ¿El dominio modela el problema real? -->

### Patrones del proyecto aplicados
<!-- ¿Las decisiones técnicas siguen los patrones establecidos en KNOWLEDGE.md? -->

### Desafíos técnicos realizados
<!-- ¿Se cuestionaron las alternativas? ¿Se documentaron los tradeoffs? -->

### Observaciones
<!-- Gaps, riesgos, preguntas abiertas que bloquean la aprobación -->
