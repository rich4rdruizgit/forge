# Stack: kmp

> Forge Stack Skill | Cargado automáticamente para proyectos Kotlin Multiplatform

## Test Framework
JUnit5 + MockK + Turbine (para Flows)

## Dependencias de test
- kotlin.test (commonTest)
- mockk
- turbine
- kotlinx-coroutines-test

## Ubicación de tests
- Shared logic: `{module}/src/commonTest/kotlin/{package}/`
- Android-specific: `{module}/src/androidTest/kotlin/{package}/`
- iOS-specific: `{module}/src/iosTest/kotlin/{package}/`

> **Regla KMP**: Toda lógica compartida se testea en `commonTest`. Solo los comportamientos
> específicos de plataforma van en `androidTest` o `iosTest`.

## Naming convention — archivos
`{Módulo}Test.kt` — ej: `GetUserUseCaseTest.kt`, `UserRepositoryTest.kt`

## Naming convention — funciones/métodos
Backtick names en español: `` `dado_{condición}_cuando_{acción}_entonces_{resultado}` ``

Ejemplo: `` `dado repositorio exitoso, cuando se invoca, entonces retorna entidad` ``

## Anatomía de un test (RED state)

```kotlin
// En commonTest — usa kotlin.test, NO junit directamente
class GetFeatureUseCaseTest {

    private val repository = mockk<FeatureRepository>()
    private val useCase = GetFeatureUseCase(repository)

    @Test
    fun `dado repositorio exitoso, cuando se invoca, entonces retorna entidad`() = runTest {
        // GIVEN
        coEvery { repository.getData(any()) } returns Result.success(fakeEntity)
        // WHEN
        val result = useCase("param-valido")
        // THEN
        assertTrue(result.isSuccess)
        assertEquals(fakeEntity, result.getOrNull())
    }
}
```

## Estructura de archivos de ejemplo

```
{module}/src/
├── commonMain/kotlin/{package}/
│   └── domain/
│       └── GetFeatureUseCase.kt
├── commonTest/kotlin/{package}/
│   └── domain/
│       └── GetFeatureUseCaseTest.kt     ← lógica compartida aquí
├── androidMain/kotlin/{package}/
├── androidTest/kotlin/{package}/
│   └── FeatureAndroidIntegrationTest.kt ← solo comportamiento Android
└── iosTest/kotlin/{package}/
    └── FeatureIosIntegrationTest.kt     ← solo comportamiento iOS
```

## Anti-patterns
- ❌ Tests de lógica compartida en `androidTest` o `iosTest` — van en `commonTest`
- ❌ Importar clases específicas de plataforma (android.*, UIKit) en `commonMain`
- ❌ Compartir estado mutable entre tests
- ❌ Usar `Thread.sleep()` en tests (usar `runTest` y coroutines)
- ❌ `LiveData` en código nuevo (usamos `StateFlow`)
- ❌ `var` en `UiState` (siempre `val` + `copy()`)

## Convenciones adicionales

### Arquitectura base
- **Patrón:** Clean Architecture + MVVM (shared ViewModel via KMP)
- **Capas:** UI (platform) → ViewModel (shared) → Domain (shared) → Data (shared + platform adapters)
- **Regla:** Domain y Data son 100% compartidos. UI es específica por plataforma.

### Estructura de carpetas por feature
```
feature-name/
├── commonMain/kotlin/{package}/
│   ├── presentation/
│   │   ├── FeatureViewModel.kt       # ViewModel compartido
│   │   └── FeatureUiState.kt         # data class sellada, inmutable
│   ├── domain/
│   │   ├── FeatureEntity.kt
│   │   ├── FeatureRepository.kt      # interfaz
│   │   └── GetFeatureUseCase.kt
│   └── data/
│       ├── FeatureRepositoryImpl.kt
│       └── FeatureMapper.kt
├── androidMain/kotlin/{package}/
│   └── data/remote/FeatureApiService.kt
└── iosMain/kotlin/{package}/
    └── data/remote/FeatureApiServiceIos.kt
```

### Naming conventions
- ViewModels: `NombreViewModel` → expone `StateFlow<NombreUiState>`
- UseCases: verbo + sustantivo → `GetUserUseCase`, `SaveOrderUseCase`
- Repositorios: interfaz en domain, impl en data → `UserRepository` / `UserRepositoryImpl`
- DTOs: sufijo `Dto` → `UserDto`
- Mappers: extensión en el DTO → `fun UserDto.toEntity(): UserEntity`
