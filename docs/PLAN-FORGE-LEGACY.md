# FORGE Enterprise: Plan Tecnico para Proyectos Android Legacy (Brownfield)

> v0.1 — Design Document | FORGE v0.6 → v0.7
> Fecha: 2026-03-30

---

## 1. Arquitectura del Analizador ("El Arqueologo")

### 1.1 Objetivo

A script (`forge-scan`) that analyzes a legacy Android project in < 60 seconds without compiling, without Gradle sync, without touching anything. Output: `.forge/project-dna.yaml` — a genetic map of the project that feeds SPEC, BUILD, and assertions dynamically.

### 1.2 Herramientas y Estrategia de Escaneo

2 niveles de escaneo: project-wide (siempre) + per-module (selectivo).

#### Nivel 1 — Project-wide scan (obligatorio, < 10s)

Informacion global que no se puede partir por modulo. Corre SIEMPRE.

Tool: `fd` + `rg` (already required by FORGE)

| Signal | Command | Output |
|--------|---------|--------|
| Module catalog | `fd -t d "src/main" --max-depth 3` | Module list, monolith vs multi-module |
| Version catalog | `fd "libs.versions.toml" gradle/` + parse `[versions]` section | All library versions centralized (Kotlin, AGP, Compose BOM, Retrofit, Room, etc.) |
| DI framework | `rg -l "(@Module\|@InstallIn)" --type kotlin` vs `rg -l "(single\|factory\|module {)" --type kotlin` | Hilt / Koin / Dagger / Manual |
| Build flavors | `rg "productFlavors" build.gradle*` | Flavor names and dimensions |
| Min/Target SDK | `rg "(minSdk\|targetSdk\|compileSdk)" build.gradle*` | SDK versions (root level) |
| Kotlin/AGP version | `rg "(kotlin|agp)" gradle/libs.versions.toml` or `rg "ext.kotlin_version" build.gradle` | Language and toolchain versions |
| Gradle wrapper | `rg "distributionUrl" gradle/wrapper/gradle-wrapper.properties` | Gradle version |
| KSP vs KAPT | `rg "(kapt\|ksp)" build.gradle*` | Annotation processor type |

**Version catalog parsing**: Si existe `gradle/libs.versions.toml` (estandar moderno), se parsea la seccion `[versions]` para extraer TODAS las versiones centralizadas. Fallback: extraer versiones de `build.gradle(.kts)` via `rg` en `ext {}` blocks o `buildscript` declarations.

```bash
# Modern projects (libs.versions.toml)
fd "libs.versions.toml" gradle/ | xargs rg "^\w+\s*=" | head -50

# Legacy projects (build.gradle ext blocks)
rg -U "ext\s*\{[^}]+\}" build.gradle --multiline
```

#### Nivel 2 — Per-module scan (selectivo)

Solo corre para los modulos que el usuario elija. Se puede ejecutar incrementalmente.

##### Capa 2a — Module file-system heuristics (< 5s per module)

| Signal | Command | Output |
|--------|---------|--------|
| XML vs Compose ratio | `fd -e xml -p "layout/" {module}` vs `rg -l "@Composable" --type kotlin {module}` | Percentage per paradigm |
| Async patterns | `rg -c "(Observable\|Single\|Completable\|Flowable)" --type kotlin {module}` vs `rg -c "(suspend fun\|\.collect\|\.flow)" --type kotlin {module}` | RxJava count vs Coroutines count |
| Architecture pattern | `rg -l "class.*Presenter" {module}`, `rg -l "class.*ViewModel" {module}` | MVP / MVVM / MVI detection |
| Test frameworks | `rg -l "(import org\.junit\|import io\.mockk\|import org\.mockito\|import io\.kotest)" {module}/src/test` | JUnit4 vs JUnit5, MockK vs Mockito |
| Module dependencies | `rg "implementation|api|kapt|ksp" {module}/build.gradle*` | Per-module dependency list |

##### Capa 2b — Module pattern recognition (< 10s per module)

Tool: `rg` with multiline patterns (`-U`), scoped to selected module

| Pattern | Detection Logic |
|---------|----------------|
| Base classes | `rg "abstract class Base(Activity\|Fragment\|ViewModel\|Presenter)" {module}` |
| Custom Result/Either types | `rg "sealed (class\|interface) (Result\|Either\|Resource)" {module}` |
| Network error handling | `rg "(HttpException\|NetworkException\|ErrorHandler\|ErrorMapper)" {module}` |
| Navigation pattern | `rg "(findNavController\|NavHost\|Router\|Navigator)" {module}` |
| Event bus / legacy comms | `rg "(EventBus\|Otto\|LocalBroadcastManager\|LiveDataBus)" {module}` |
| Forbidden patterns | `rg "(AsyncTask\|Loader\|IntentService)" {module}` — zombies still alive |

#### Modos de ejecucion

```bash
forge scan                        # Nivel 1 + ALL modules (full scan)
forge scan app feature-login      # Nivel 1 + solo esos modulos
forge scan --interactive          # Nivel 1 + selector interactivo de modulos
forge scan feature-payments       # Nivel 1 (si no existe) + agrega modulo al DNA existente
```

El modo `--interactive` muestra:

```
Proyecto: 12 modulos detectados

  [x] app (45K LOC)
  [ ] core (12K LOC)
  [x] feature-login (3.2K LOC)
  [ ] feature-settings (2.1K LOC)
  ...

Selecciona los modulos a escanear (Space = toggle, Enter = confirmar):
```

Ejecutar `forge scan {modulo}` sobre un proyecto con DNA existente AGREGA el modulo al array `estructura.modulos` sin reemplazar los demas. Re-escanear un modulo ya existente lo ACTUALIZA.

#### Por que NO AST parsing

AST parsing (KtLint PSI, detekt custom rules, kotlin-compiler-embeddable) gives more precision but adds:

- 30-60s compilation overhead
- JVM dependency (not all devs have the right JDK in PATH)
- Fragile against incomplete code (legacy projects often don't compile cleanly)

`rg`-based heuristics give 90% accuracy at 5% of the cost. False positives handled by the interactive questionnaire (Phase 2).

### 1.3 Estructura de `project-dna.yaml`

Full example YAML schema:

```yaml
# .forge/project-dna.yaml — Generated by forge-scan, editable by dev
# Last scan: 2026-03-30T14:22:00

scan_version: "1.0"
scan_date: "2026-03-30"
scan_mode: incremental  # full | incremental
modulos_escaneados: ["app", "feature-login"]
modulos_pendientes: ["core", "feature-settings", "feature-payments"]
confidence: high  # high | medium | low

# --- Nivel 1: Project-wide (siempre presente) ---

proyecto:
  tipo: brownfield
  edad_estimada: "5+ years"
  gradle_version: "8.5"
  compile_sdk: 34
  min_sdk: 24
  target_sdk: 34

version_catalog:
  source: "gradle/libs.versions.toml"  # toml | build.gradle ext | mixed
  versions:
    kotlin: "1.9.22"
    agp: "8.2.1"
    compose-bom: "2024.02.00"
    compose-compiler: "1.5.8"
    coroutines: "1.7.3"
    retrofit: "2.9.0"
    okhttp: "4.12.0"
    room: "2.6.1"
    hilt: "2.50"
    navigation: "2.7.6"
    rxjava: "3.1.6"
    coil: "2.5.0"
    junit: "5.10.1"
    mockk: "1.13.9"
    turbine: "1.0.0"
  # Nota: solo se listan las versiones detectadas. El catalogo completo
  # esta en gradle/libs.versions.toml para consulta directa.

# --- Nivel 2: Per-module (solo modulos escaneados) ---

estructura:
  tipo: multi-module
  modulos:
    - nombre: app
      tipo: application
      escaneado: true
      loc_kotlin: 45000
      loc_xml_layouts: 120
      composables: 15
    - nombre: core
      tipo: library
      escaneado: false  # detectado pero no escaneado
    - nombre: feature-login
      tipo: library
      escaneado: true
      loc_kotlin: 3200
      composables: 0
      xml_layouts: 8
  ui_paradigma:  # calculado solo sobre modulos escaneados
    xml_pct: 85
    compose_pct: 15
    estado_migracion: parcial

arquitectura:
  patron_dominante: mvvm
  patrones_detectados:
    mvp: ["feature-login", "feature-settings"]
    mvvm: ["feature-home", "feature-profile"]
    mvi: []
  capas: clean
  base_classes:
    - "BaseFragment"
    - "BaseViewModel"
    - "BaseActivity"

dependencias:
  # Versiones centralizadas en version_catalog.versions (Nivel 1)
  # Aqui solo se registra QUE se usa y detalles no versionables
  di:
    framework: hilt
    procesador: ksp
  async:
    coroutines: true
    rxjava: true
    migracion_rx_coroutines: parcial
  networking:
    http_client: okhttp
    api_layer: retrofit
    interceptors: ["AuthInterceptor", "LoggingInterceptor"]
  local_db:
    framework: room
  navigation:
    tipo: navigation-component
    version: "2.7.6"
  image_loading: coil

testing:
  frameworks:
    unit: junit5
    mocking: mockk
    ui: compose-test
    coroutines: kotlinx-coroutines-test
    flows: turbine
  cobertura_estimada:
    con_tests: 45
    ratio_test_src: 0.3
  infra_existente:
    base_test_classes: ["BaseViewModelTest", "BaseRepositoryTest"]
    test_fixtures: ["FakeUserRepository", "TestDispatcherRule"]
    custom_matchers: []

patrones_legacy:
  activos:
    - pattern: "EventBus"
      ubicacion: ["feature-login", "core"]
      nota: "Usado para comunicacion inter-feature"
    - pattern: "AsyncTask"
      ubicacion: ["feature-settings"]
      nota: "Zombie — should be dead but isn't"
  resultado_custom:
    tipo: "sealed class Resource<T>"
    ubicacion: "core/domain/Resource.kt"
  error_handling:
    tipo: "ErrorMapper + sealed NetworkError"
    ubicacion: "core/data/error/"
```

### 1.4 Script Implementation

Bash script (~300 lines), outputs YAML via printf/heredoc. No Python dependency. Entry point: `forge scan` (new command).

Output:

1. `.forge/project-dna.yaml` — machine-readable
2. Terminal summary — human-readable
3. Confidence warnings for ambiguous signals

---

## 2. Diseno del "Skill-Creator" Interactivo

### 2.1 Problema

`forge-scan` detects what IS. But enterprise projects have tribal knowledge about what SHOULD and SHOULD NOT be:

- "We're migrating from RxJava but feature-payments MUST stay on Rx until Q3"
- "Never touch LegacyAuthManager — it's being replaced by AuthService"
- "We use MVP in old features but new features MUST use MVVM"
- "BaseFragment is deprecated — use ComposeFragment for new screens"

### 2.2 Terminal Flow: The "5-Minute Interview"

Not a 50-question form. A SMART questionnaire that uses `project-dna.yaml` to ask ONLY relevant questions.

Command: `forge interview`

#### Phase A — Confirm/Correct Scan Results (30 seconds)

```
El Arqueologo detecto esto. Corregi lo que este mal:

  DI: Hilt (ksp)          <- [Enter = OK, o escribi la correccion]
  Async: Coroutines + RxJava 3  <-
  Arquitectura: MVVM + MVP (mixed) <-
  UI: 85% XML / 15% Compose <-
  Testing: JUnit5 + MockK <-

Algo mas que no haya detectado? (Enter para continuar)
```

#### Phase B — Migration Status (1 minute)

Only triggered for mixed-signal findings.

```
Detecte RxJava Y Coroutines. Cual es la situacion?
  1. Migrando a Coroutines — nuevo codigo DEBE usar Coroutines
  2. Coexisten — cada modulo usa lo que tiene, sin migracion activa
  3. RxJava es el estandar — Coroutines solo en tests

Detecte XML Y Compose. Cual es la situacion?
  1. Migrando a Compose — nuevas pantallas DEBEN ser Compose
  2. Coexisten — depende del modulo
  3. Compose solo para Design System components
```

#### Phase C — Forbidden Zones (1 minute)

```
Hay clases o paquetes que el AI NO DEBE tocar ni usar?
(Una por linea, Enter vacio para terminar)

  > LegacyAuthManager
  > com.app.legacy.payments
  > BaseActivity (deprecated, usar ComposeActivity)

Hay clases que el AI DEBE usar en vez de crear nuevas?
  > ErrorMapper (core/data/error/) — para mapear errores de red
  > Resource<T> (core/domain/) — NO crear sealed classes de resultado nuevas
```

#### Phase D — Team Conventions (1 minute)

```
Convenciones del equipo (Enter vacio para skip):

  Prefijo de branches? (ej: feature/, feat/): feature/
  Idioma de commits? (es/en): es
  Modulo para features nuevas? (ej: feature-{name}): feature-{name}
  Paquete base?: com.empresa.app

Algo mas que el AI deba saber? (texto libre, Enter para skip)
  > Usamos Detekt con reglas custom en config/detekt.yml
```

#### Phase E — Severity Classification

```
Para las clases prohibidas, que nivel de bloqueo?
  1. BLOCKER — forge approve rechaza si el AI las usa
  2. WARNING — forge approve avisa pero deja pasar

  LegacyAuthManager: [1]
  com.app.legacy.payments: [1]
  BaseActivity: [2]
```

### 2.3 Output: `tribal_knowledge` section appended to `project-dna.yaml`

```yaml
tribal_knowledge:
  interview_date: "2026-03-30"
  interviewer: "Tech Lead"

  migraciones:
    rx_to_coroutines:
      estado: activa
      regla: "Codigo nuevo DEBE usar Coroutines"
      excepciones: ["feature-payments — hasta Q3 2026"]
    xml_to_compose:
      estado: activa
      regla: "Pantallas nuevas DEBEN ser Compose"
      excepciones: []

  prohibiciones:
    - clase: "LegacyAuthManager"
      razon: "Siendo reemplazada por AuthService"
      severidad: blocker
      alternativa: "AuthService (core/auth/)"
    - paquete: "com.app.legacy.payments"
      razon: "Modulo legacy en proceso de reescritura"
      severidad: blocker
    - clase: "BaseActivity"
      razon: "Deprecated"
      severidad: warning
      alternativa: "ComposeActivity"

  obligatorios:
    - clase: "ErrorMapper"
      ubicacion: "core/data/error/ErrorMapper.kt"
      proposito: "Mapeo de errores de red — NO crear alternativas"
    - clase: "Resource<T>"
      ubicacion: "core/domain/Resource.kt"
      proposito: "Result wrapper — NO crear sealed classes de resultado nuevas"

  convenciones:
    branch_prefix: "feature/"
    commit_language: "es"
    new_module_pattern: "feature-{name}"
    base_package: "com.empresa.app"
    detekt: "config/detekt.yml"
    notas_libres: "Usamos Detekt con reglas custom"
```

### 2.4 Integracion con `config.yaml`

| File | Read by | Purpose |
|------|---------|---------|
| `config.yaml` | All phases | FORGE pipeline settings |
| `project-dna.yaml` | SPEC, BUILD, assertions | Project constraints |
| `stack-skills/{stack}.md` | SPEC, BUILD | Code generation patterns |

---

## 3. Mapeo de Descubrimientos a los Gates de Forge

### 3.1 Ejemplo 1: BUILD forzado a usar version detectada de libreria

**Scenario**: `project-dna.yaml` version catalog shows `retrofit: "2.9.0"`. The AI generates code using Retrofit 2.11 API features.

**Solution**: `forge-build` Step B1 loads DNA and injects constraints from `version_catalog.versions`:

```
CONSTRAINTS (from project-dna.yaml version_catalog):
- Retrofit: 2.9.0 — do NOT use APIs introduced after this version
- Room: 2.6.1 — do NOT use APIs introduced after this version
- Kotlin: 1.9.22 — do NOT use language features from 2.0+
- Compose BOM: 2024.02.00 — use compatible Compose APIs only
- Min SDK: 24 — all APIs must be available at this level
- DI: Hilt with KSP — use @HiltViewModel, @Inject, NOT Koin modules
- Async: Coroutines for new code (migration active from RxJava)

FORBIDDEN:
- LegacyAuthManager -> use AuthService
- com.app.legacy.payments -> do not import

MANDATORY REUSE:
- ErrorMapper for network errors
- Resource<T> for result wrapping
```

### 3.2 Ejemplo 2: SPEC detecta toque de XML view y sugiere migracion

**Scenario**: Dev modifies `LoginFragment.xml`. DNA says `xml_to_compose.estado: activa`.

**Solution**: Inject into `forge-spec` Step 4:

```
DNA Check: Esta feature toca {LoginFragment.xml} (XML layout).
El proyecto tiene migracion activa a Compose.

Opciones:
a) Migrar esta pantalla a Compose como parte de esta feature
b) Mantener XML con justificacion (documenta en Decisiones Tecnicas)
c) Crear ticket separado para migracion
```

If answer is (b): auto-add Decision entry with justification.

### 3.3 Ejemplo 3: BUILD detecta modulo no escaneado

**Scenario**: Feature toca `feature-payments` pero `modulos_escaneados` no lo incluye.

**Solution**: `forge-build` Step B1 emite warning:

```
⚠ DNA Warning: Esta feature toca {feature-payments} pero no fue escaneado.
No hay constraints de arquitectura ni patrones detectados para este modulo.

Opciones:
a) Ejecutar `forge scan feature-payments` ahora (agrega al DNA existente)
b) Continuar sin DNA para este modulo (riesgo: puede violar patrones no detectados)
```

### 3.4 Ejemplo 4: Assertion Gate que bloquea uso de clase prohibida

New assertion file `.forge/validation/assertions-dna.yaml`, auto-generated from `project-dna.yaml`:

```yaml
# .forge/validation/assertions-dna.yaml
# AUTO-GENERATED from project-dna.yaml — do NOT edit manually

phase: build

pillars:
  - pillar: P2
    name: Project DNA Constraints
    assertions:
      - id: P2-DNA-001
        description: "No usa LegacyAuthManager (prohibido — blocker)"
        severity: blocker
        verification: |
          El codigo nuevo NO importa ni referencia LegacyAuthManager.
          Alternativa obligatoria: AuthService (core/auth/).
        evidence_hint: "rg 'LegacyAuthManager' en archivos implementados"

      - id: P2-DNA-002
        description: "No importa desde com.app.legacy.payments (prohibido — blocker)"
        severity: blocker
        verification: |
          El codigo nuevo NO importa nada del paquete com.app.legacy.payments.
        evidence_hint: "rg 'com.app.legacy.payments' en archivos implementados"

      - id: P2-DNA-003
        description: "No usa BaseActivity (deprecado — warning)"
        severity: warning
        verification: |
          El codigo nuevo NO extiende BaseActivity.
          Alternativa: ComposeActivity.
        evidence_hint: "rg 'BaseActivity' en archivos implementados"

      - id: P4-DNA-001
        description: "Usa ErrorMapper para errores de red (obligatorio)"
        severity: blocker
        condition: "SPEC tiene seccion API"
        verification: |
          Si el codigo maneja errores de red, usa ErrorMapper de core/data/error/.
          NO crea una clase nueva de mapeo de errores.

      - id: P4-DNA-002
        description: "Usa Resource<T> para wrapping de resultados (obligatorio)"
        severity: blocker
        verification: |
          Si el codigo retorna resultados async, usa Resource<T> de core/domain/.
          NO crea sealed class Result/Either/Resource nueva.

      - id: P2-DNA-MIG-001
        description: "Codigo nuevo usa Coroutines, no RxJava"
        severity: blocker
        condition: "migraciones.rx_to_coroutines.estado == activa"
        verification: |
          Archivos NUEVOS usan suspend fun, Flow, StateFlow.
          NO usan Observable, Single, Completable, Flowable.
          Excepciones documentadas en project-dna.yaml.

      - id: P2-DNA-MIG-002
        description: "Pantallas nuevas usan Compose, no XML"
        severity: blocker
        condition: "migraciones.xml_to_compose.estado == activa"
        verification: |
          Pantallas NUEVAS son @Composable functions, no Fragments con XML.
          Modificaciones a XML existente: permitido con justificacion.
```

### 3.5 Estrategia de Integracion de Assertions

**Phase 1 (Static generation)**: `forge scan` + `forge interview` generate `assertions-dna.yaml` from templates. Each prohibition becomes a blocker assertion. Each migration rule becomes a conditional assertion. Leverages existing assertion infrastructure with ZERO changes to `forge-approve`.

**Phase 3 (Runtime interpretation)**: `forge-approve` reads `project-dna.yaml` directly and evaluates constraints programmatically. More flexible but requires approve skill changes.

### 3.6 Personalizacion de Stack Skills

`forge scan` generates a CUSTOMIZED stack skill at `.forge/stack-skills/android.md` that overrides the generic one.

Example generated section for a mixed async project:

```markdown
## Async Model

### New code (MUST use):
- `suspend fun` for all async operations
- `StateFlow<UiState>` in ViewModels
- `kotlinx-coroutines-test` + `runTest` for testing

### Existing code (MAY encounter):
- RxJava 3 (Observable, Single, Completable)
- When modifying existing Rx code: maintain Rx unless full function rewrite
- Bridge: `asFlow()` extension for Rx->Coroutines interop

### Exception modules (keep RxJava):
- `feature-payments` — until Q3 2026
```

---

## 4. Integracion con forge-memory

### 4.1 Objetivo

Sin forge-memory el DNA muere con el archivo — el agente tiene que leer el YAML cada sesion y no puede cruzar conocimiento entre proyectos. Con forge-memory, el DNA se convierte en memoria semantica persistente y buscable.

### 4.2 Topic Keys

| Momento | Topic Key | Operacion |
|---------|-----------|-----------|
| `forge scan` | `project-dna/{project}/scan` | `forge_mem_save` — resultados del analisis estatico |
| `forge interview` | `project-dna/{project}/tribal-knowledge` | `forge_mem_save` — prohibiciones, migraciones, convenciones |
| `forge rescan` | mismos keys | `forge_mem_update` — actualiza sin duplicar |

### 4.3 Persistencia por Fase

#### Al ejecutar `forge scan`:

```
forge_mem_save(
  title: "Project DNA scan: {project}",
  content: <structured summary of project-dna.yaml scan results>,
  observation_type: "architecture",
  topic_key: "project-dna/{project}/scan",
  project: "{project}"
)
```

#### Al ejecutar `forge interview`:

```
forge_mem_save(
  title: "Tribal knowledge: {project}",
  content: <structured summary of prohibitions, migrations, conventions, mandatory classes>,
  observation_type: "decision",
  topic_key: "project-dna/{project}/tribal-knowledge",
  project: "{project}"
)
```

#### Al ejecutar `forge rescan`:

```
forge_mem_update(
  id: <existing observation id>,
  content: <updated scan results>,
  project: "{project}"
)
```

Uses `forge_mem_search` first to find existing observation, then `forge_mem_update` to avoid duplicates.

### 4.4 Puntos de Consumo en el Pipeline

| Fase | Que consulta | Como | Fallback |
|------|-------------|------|----------|
| `forge-runtime` R0 (session start) | DNA del proyecto activo | `forge_mem_knowledge_search("project-dna {project}")` | Read `.forge/project-dna.yaml` |
| `forge new` | Patrones + prohibiciones relevantes | `forge_mem_knowledge_search("prohibiciones migraciones {feature}")` | Read `project-dna.yaml` tribal_knowledge section |
| `forge spec` Step 4 | Constraints de migracion | `forge_mem_search("project-dna/{project}/tribal-knowledge")` | Read `project-dna.yaml` migraciones section |
| `forge build` B1 | Versiones, clases prohibidas/obligatorias | `forge_mem_search("project-dna/{project}/scan")` | Read `project-dna.yaml` dependencias + prohibiciones |
| `forge ref` (cross-project) | Conocimiento de OTROS proyectos | `forge_mem_knowledge_search("xml compose migration")` | Not available without forge-memory |

### 4.5 Cross-Project Knowledge

This is the killer feature that ONLY forge-memory enables. Examples:

- Squad A completed an RxJava to Coroutines migration in `feature-checkout`. Squad B is about to start the same migration in `feature-cart`. `forge ref "rxjava coroutines migration"` surfaces Squad A's experience, gotchas, and patterns.
- Tech Lead interviews across 5 projects reveal that 3 teams prohibit `EventBus`. A new project's `forge new` can surface: "3 projects in your org prohibit EventBus — consider alternatives."
- A team discovers that `Room 2.6.1` has a bug with `@Embedded` entities. They save this as tribal knowledge. Other teams using the same Room version get warned automatically.

### 4.6 Estrategia de Fallback

forge-memory is RECOMMENDED but NOT REQUIRED:

```
IF forge-memory available:
  -> Load DNA from memory (faster, semantic search, cross-project)
  -> Write DNA to memory on scan/interview
ELSE:
  -> Load DNA from .forge/project-dna.yaml (file read, project-scoped only)
  -> No cross-project knowledge available
```

This matches the existing FORGE pattern where forge-memory enhances but never gates the pipeline.

---

## 5. Hoja de Ruta de Implementacion

### 5.1 Principio Fundamental: No Romper v0.6

Every change is ADDITIVE. Without `project-dna.yaml`, FORGE v0.7 behaves exactly like v0.6:

- `forge-spec` and `forge-build` load DNA with `if exists` guards
- `assertions-dna.yaml` only loaded if present
- `config.yaml` gets zero schema changes
- Stack skills overwritten only by explicit `forge scan`

### Phase 1: Static Analyzer Script (Semanas 1-3)

**Deliverables:**

1. `forge-scan` bash script (~350 lines) con soporte Nivel 1 + Nivel 2 selectivo
2. `project-dna.yaml` schema and generator (con version catalog)
3. Documentation in FORGE.md (new command + modes)

| Task | Effort | Details |
|------|--------|---------|
| Write `forge-scan` Nivel 1 (project-wide) | 2 days | Bash, version catalog parser, DI/SDK/Gradle detection |
| Write `forge-scan` Nivel 2 (per-module) | 2 days | Module-scoped heuristics + pattern recognition |
| Incremental scan logic | 1 day | Merge new modules into existing DNA without overwrite |
| Interactive module selector (`--interactive`) | 1 day | Terminal UI for module selection |
| Define `project-dna.yaml` schema | 1 day | YAML schema doc + examples |
| Add `forge scan` to command table | 0.5 day | Update FORGE.md, setup-project.sh |
| Confidence scoring | 1 day | Each signal gets confidence score |
| Terminal summary output | 0.5 day | Pretty-print DNA findings |
| Integration test | 2 days | Test against 3 real legacy projects |
| forge-memory persistence | 1 day | Save scan results to forge-memory |

Entry in `setup-project.sh`:

```bash
echo "Queres escanear el proyecto para detectar patrones? (recomendado para proyectos existentes)"
read -r -p "[S/n]: " scan_confirm
if [[ ! "$scan_confirm" =~ ^[Nn]$ ]]; then
  echo "Modo de escaneo:"
  echo "  1. Completo (todos los modulos)"
  echo "  2. Interactivo (elegir modulos)"
  echo "  3. Solo ficha tecnica (Nivel 1, sin modulos)"
  read -r -p "[1/2/3]: " scan_mode
  case "$scan_mode" in
    2) bash "$FORGE_REPO/forge-scan.sh" --interactive ;;
    3) bash "$FORGE_REPO/forge-scan.sh" --project-only ;;
    *) bash "$FORGE_REPO/forge-scan.sh" ;;
  esac
fi
```

### Phase 2: Interactive Questionnaire + Skill Generation (Semanas 4-6)

**Deliverables:**

1. `forge interview` command (~200 lines)
2. `tribal_knowledge` section in `project-dna.yaml`
3. Auto-generated `assertions-dna.yaml`
4. Auto-customized `stack-skills/android.md`

| Task | Effort | Details |
|------|--------|---------|
| Write `forge interview` script | 3 days | Interactive terminal flow (Phases A-E) |
| Assertion template generator | 2 days | Read prohibitions/migrations, write assertions-dna.yaml |
| Stack skill customizer | 2 days | Read DNA, generate project-specific android.md |
| Merge logic | 1 day | Re-running interview merges, doesn't overwrite |
| `forge rescan` command | 0.5 day | Re-run scan + preserve tribal_knowledge |
| forge-memory persistence | 1 day | Save tribal knowledge to forge-memory |
| Test with real team | 2 days | Interview a real Tech Lead, validate < 5 min |

### Phase 3: Dynamic Assertion Injection (Semanas 7-9)

**Deliverables:**

1. Modified `forge-spec.md` — DNA-aware architecture validation
2. Modified `forge-build.md` — DNA constraint loading
3. Modified `forge-approve.md` — loads `assertions-dna.yaml`
4. Modified `forge-runtime.md` — DNA loading + forge-memory integration

| Task | Effort | Details |
|------|--------|---------|
| Extend `forge-runtime.md` R1 | 0.5 day | Add DNA loading step (R1.5) with `if exists` guard |
| Extend `forge-spec.md` Step 4 | 1 day | Migration check, forbidden class warning |
| Extend `forge-build.md` Step B1 | 1 day | Version constraints, mandatory reuse injection |
| Extend `forge-approve.md` | 1 day | Load `assertions-dna.yaml` in assertion discovery |
| forge-memory integration in pipeline | 1 day | R0 loads from memory, fallback to file |
| Cross-project `forge ref` queries | 1 day | Enable DNA search across projects |
| Regression test v0.6 | 2 days | Full cycle WITHOUT DNA, verify identical behavior |
| Integration test with DNA | 2 days | Full cycle WITH DNA on a legacy project |

### Matriz de Riesgos

| Risk | Mitigation |
|------|------------|
| False positives in scan | Confidence scoring + interview correction |
| Tech Lead skips interview | DNA works with scan-only data |
| DNA file gets stale | `forge rescan` + age warning (> 90 days) |
| Performance on huge monoliths | Timeout per scan step (5s). Skip Capa 3 if > 30s |
| Agent ignores DNA constraints | Assertions catch violations at approve gate |
| Breaking v0.6 | Everything behind `if project-dna.yaml exists` guards |
| forge-memory unavailable | Fallback to file-based DNA reading |

### Metricas de Exito

| Metric | Target |
|--------|--------|
| Nivel 1 scan time | < 10 seconds |
| Full scan time on 100K LOC project | < 60 seconds |
| Interview completion time | < 5 minutes |
| False positive rate | < 15% |
| Forbidden class usage caught | 100% |
| v0.6 regression | 0 breaking changes |
| Cross-project knowledge queries | Available via forge ref |

---

## Resumen Ejecutivo

3 new commands for FORGE v0.7:

| Command | Purpose |
|---------|---------|
| `forge scan [modulos...] [--interactive\|--project-only]` | The Archaeologist — Nivel 1 (project-wide + version catalog) always runs; Nivel 2 (per-module) is selective |
| `forge interview` | Tribal Knowledge Extractor — 5-min questionnaire, generates assertions + custom stack skills |
| `forge rescan` | Re-run scan preserving tribal knowledge |

2 injection points in the existing pipeline:

- **Context injection** — `forge-spec` and `forge-build` load DNA constraints into the agent's context window
- **Gate enforcement** — `assertions-dna.yaml` blocks forbidden patterns at `forge approve`

1 persistence layer:

- **forge-memory** — DNA and tribal knowledge stored as semantic memory, enabling cross-project knowledge sharing and session-persistent constraints. Falls back to file-based reading when forge-memory is unavailable.

The architecture is an exoskeleton: the AI agent reasons freely within explicit boundaries. It doesn't need to "know" about legacy code — it needs to see the constraints before it writes anything. The constraints are VISIBLE (in context window), ENFORCEABLE (through assertions), and PERSISTENT (through forge-memory).
