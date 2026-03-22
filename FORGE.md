# 🔥 FORGE — Contexto del Proyecto

> Este archivo es leído automáticamente por cualquier agente de IA (Claude, Gemini, Copilot).
> Contiene el estado actual del ciclo de desarrollo y las instrucciones para el agente.
> **No borrar. Mantener actualizado con `forge approve` y `forge close`.**

---

<!-- ========== CAPA 1: METADATA (siempre cargada, ~30 líneas) ========== -->

## 📦 Stack del Proyecto

```yaml
plataforma:       Android / KMP
lenguaje:         Kotlin
arquitectura:     Clean Architecture + MVVM
di:               Hilt / Koin
async:            Coroutines + Flow / RxJava
tests_unit:       JUnit5 + MockK
tests_ui:         Compose Testing / Espresso
modelo_agente:    claude-sonnet-4-6
modelo_arch:      claude-opus-4-6
forge_version:    v0.4
```

---

## 🎯 Ciclo Activo

```yaml
feature:          null
slug:             null
azure_story:      null
fase_actual:      null
profundidad:      null
hu_original:      null
knowledge_refs:   []
spec_quality_score: null
```

| Fase | Archivo | Estado | Validation Score |
|------|---------|--------|-----------------|
| SPIKE | — | ⏳ Sin iniciar | — |
| SPEC | — | ⏳ Sin iniciar | — |
| BUILD | — | ⏳ Sin iniciar | — |
| VERIFY | — | ⏳ Sin iniciar | — |

---

<!-- ========== CAPA 2: INSTRUCCIONES POR FASE (cargada según fase_actual) ========== -->

## 🤖 Instrucciones para el Agente

### 1. Leer contexto primero
Antes de cualquier acción, leer:
- Este archivo (`FORGE.md`) — Capa 1 siempre, Capa 2 según el comando
- El artefacto de la fase actual si existe
- Los skills en `skills/` relevantes al comando

### 2. Comportamiento por comando

| El dev dice | Tú haces |
|-------------|----------|
| `forge new "nombre feature"` | Skill: forge-new.md — Carga HU, evalúa profundidad, consulta KNOWLEDGE.md, crea ciclo |
| `forge spike` o "trabajemos el spike" | Skill: forge-spike.md — Guía investigación técnica estructurada |
| `forge spec` o "trabajemos la spec" | Skill: forge-spec.md — Protocolo de 7 pasos, conversación guiada, Quality Score por pilares |
| `forge build` o "trabajemos el build" | Skill: forge-build.md — RED → auto-gate → GREEN. Tests primero, implementación después. Tests inmutables |
| `forge validate` | Skill: forge-validate.md — Dry-run de validación con assertions |
| `forge approve` | Skill: forge-approve.md — Validación con assertions + aprobación si pasan blockers |
| `forge verify` o "verificá la feature" | Skill: forge-verify.md — Validación post-implementación SPEC vs código |
| `forge trace` | Skill: forge-trace.md — Genera traceability matrix AC→Evento→UI State→Test→Impl |
| `forge ref <query>` | Skill: forge-ref.md — Consulta as-built references de features cerradas |
| `forge status` | Skill: forge-status.md — Estado actual del ciclo con validation scores |
| `forge close` | Skill: forge-close.md — Archiva feature + extrae conocimiento a KNOWLEDGE.md |

### 3. Reglas que nunca rompes
- ❌ No generas código de implementación si la SPEC no está aprobada
- ❌ No avanzas de fase sin que las assertions blocker pasen
- ❌ No inventas criterios de aceptación — los preguntas al dev
- ❌ No modificas artefactos de fases anteriores ya aprobados
- ❌ No generás SPEC sin consultar KNOWLEDGE.md primero
- ❌ No aprobás SPEC con Quality Score < umbral (default 7/10)
- ❌ No aceptás AC cuyo "Entonces" describe implementación en vez de comportamiento
- ❌ No ignorás patrones establecidos en KNOWLEDGE.md sin justificación documentada
- ❌ No modificás tests durante la fase GREEN del BUILD — solo el dev puede hacerlo
- ❌ No cerrás feature sin ofrecer extracción de conocimiento a KNOWLEDGE.md
- ❌ No escribís en KNOWLEDGE.md sin aprobación del dev
- ✅ Siempre muestras qué fase está activa al inicio de cada respuesta
- ✅ Siempre referencias el AC de la SPEC cuando escribes un test
- ✅ Usas el lenguaje/framework del stack configurado en este archivo

### 4. Fragmentación automática
Si al generar la SPEC detectas que la feature supera el `umbral_fragmentacion` configurado en config.yaml (default: 8 puntos de historia):
- Propones fragmentación en sub-features
- Cada sub-feature tiene su propio ciclo SPIKE→SPEC→BUILD→VERIFY
- El dev aprueba la fragmentación antes de continuar

---

<!-- ========== CAPA 3: REFERENCIA (cargada on-demand) ========== -->

## 📁 Estructura de Forge

```
FORGE.md                              ← estás aquí
KNOWLEDGE.md                          ← memoria progresiva del proyecto (v0.4)
config.yaml                           ← configuración del equipo
setup-project.sh                      ← bootstrap del proyecto

templates/
├── SPIKE.md                          ← investigación técnica
├── SPEC.md                           ← 15 secciones, profundidad adaptativa (v0.4)
├── KNOWLEDGE.md                      ← template vacío para setup
├── VERIFY.md                         ← verificación post-implementación
├── TRACEABILITY.md                   ← matriz de trazabilidad
├── VALIDATION.md                     ← reporte de validación
└── INDEX.md                          ← as-built reference metadata

validation/
├── assertions-spike.yaml
├── assertions-spec.yaml              ← por pilares P1-P5 + condicionales (v0.4)
├── assertions-build.yaml             ← por pilares + auto-gate (v0.4)
├── assertions-verify.yaml            ← por pilares + condicionales (v0.4)
└── assertions-cross.yaml             ← IDs formato P{n} (v0.4)

stacks/
├── android.md
├── kmp.md
└── TEMPLATE.md

skills/
├── _shared/
│   └── forge-runtime.md              ← runtime compartido R1-R4 (v0.3.1)
├── forge-new.md                      ← carga HU, profundidad, KNOWLEDGE.md (v0.4)
├── forge-spike.md
├── forge-spec.md                     ← protocolo 7 pasos, Quality Score (v0.4)
├── forge-build.md                    ← RED → auto-gate → GREEN (v0.4)
├── forge-verify.md
├── forge-validate.md
├── forge-approve.md                  ← Quality Score check + condicionales (v0.4)
├── forge-trace.md
├── forge-ref.md                      ← busca en KNOWLEDGE.md (v0.4)
├── forge-status.md                   ← muestra profundidad, score, memoria (v0.4)
└── forge-close.md                    ← extracción de conocimiento (v0.4)

features/
├── activo/
│   └── {{feature-slug}}/
│       ├── SPIKE.md                  ← opcional
│       ├── SPEC.md
│       ├── VERIFY.md
│       ├── TRACEABILITY.md
│       ├── VALIDATION-SPIKE.md       ← si hubo SPIKE
│       ├── VALIDATION-SPEC.md
│       ├── VALIDATION-BUILD.md
│       └── VALIDATION-VERIFY.md
└── closed/
    └── {{feature-slug-completada}}/
        ├── (todos los artefactos)
        └── INDEX.md                  ← generado por forge close
```

---

## 📜 Historial de Features

| Feature | Slug | Azure Story | Fecha cierre | Estado | Validation Score |
|---------|------|-------------|-------------|--------|-----------------|
| — | — | — | — | — | — |

---

*Generado por Forge v0.4 — github.com/tu-usuario/forge*
