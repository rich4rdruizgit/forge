# Stack: android

> Forge Stack Skill | Cargado automáticamente para proyectos Android/Kotlin

## Test Framework
JUnit5 + MockK + Turbine (para Flows)

## Dependencias de test
- junit5
- mockk
- turbine
- kotlinx-coroutines-test

## Ubicación de tests
- Unit tests: `{module}/src/test/java/{package}/`
- UI / Integration tests: `{module}/src/androidTest/java/{package}/`

## Naming convention — archivos
`{Módulo}Test.kt` — ej: `GetUserUseCaseTest.kt`, `UserRepositoryTest.kt`

## Naming convention — funciones/métodos
Backtick names en español: `` `dado_{condición}_cuando_{acción}_entonces_{resultado}` ``

Ejemplo: `` `dado repositorio exitoso, cuando se invoca, entonces retorna entidad` ``

## Anatomía de un test (RED state)

```kotlin
@ExtendWith(MockKExtension::class)
class GetFeatureUseCaseTest {

    @MockK
    lateinit var repository: FeatureRepository

    private lateinit var useCase: GetFeatureUseCase

    @BeforeEach
    fun setUp() {
        useCase = GetFeatureUseCase(repository)
    }

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
{module}/src/test/java/{package}/
├── domain/
│   └── GetFeatureUseCaseTest.kt
└── data/
    └── FeatureRepositoryImplTest.kt
{module}/src/androidTest/java/{package}/
└── FeatureIntegrationTest.kt
```

## Anti-patterns
- ❌ Lógica de negocio en el ViewModel
- ❌ Llamadas de red directas en el ViewModel
- ❌ Entidades de dominio con anotaciones de Retrofit o Room
- ❌ `LiveData` en código nuevo (usamos `StateFlow`)
- ❌ `var` en `UiState` (siempre `val` + `copy()`)
- ❌ Compartir estado mutable entre tests
- ❌ Usar `Thread.sleep()` en tests (usar `runTest` y coroutines)

## Convenciones adicionales

### Arquitectura base
- **Patrón:** Clean Architecture + MVVM
- **Capas:** UI → Presentation → Domain → Data
- **Regla:** Las capas internas no conocen las externas. Domain no depende de Data ni de UI.

### Estructura de carpetas por feature
```
feature-name/
├── presentation/
│   ├── FeatureScreen.kt          # Composable o Fragment
│   ├── FeatureViewModel.kt
│   └── FeatureUiState.kt         # data class sellada, inmutable
├── domain/
│   ├── FeatureEntity.kt          # modelo de dominio puro
│   ├── FeatureRepository.kt      # interfaz
│   └── GetFeatureUseCase.kt
└── data/
    ├── FeatureRepositoryImpl.kt
    ├── remote/
    │   ├── FeatureApiService.kt
    │   └── FeatureDto.kt
    ├── local/
    │   └── FeatureDao.kt         # solo si hay caché
    └── FeatureMapper.kt
```

### Naming conventions
- ViewModels: `NombreViewModel` → expone `StateFlow<NombreUiState>`
- UseCases: verbo + sustantivo → `GetUserUseCase`, `SaveOrderUseCase`
- Repositorios: interfaz en domain, impl en data → `UserRepository` / `UserRepositoryImpl`
- DTOs: sufijo `Dto` → `UserDto`
- Mappers: extensión en el DTO → `fun UserDto.toEntity(): UserEntity`

### DI con Hilt
```kotlin
@Module
@InstallIn(SingletonComponent::class)
abstract class FeatureModule {
    @Binds
    abstract fun bindRepository(impl: FeatureRepositoryImpl): FeatureRepository
}
```
