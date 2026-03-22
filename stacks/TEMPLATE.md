# Stack: {nombre}

> Completá cada sección. Este archivo es cargado por forge-spec y forge-build
> para generar código y tests coherentes con tu stack.
> Eliminá los comentarios HTML una vez completado.

## Test Framework
<!-- Nombre y versión del framework de testing principal. -->
<!-- Ej: pytest 8.x | JUnit5 + MockK | Jest 29.x | RSpec 3.x -->

## Dependencias de test
<!-- Lista de librerías necesarias para correr los tests. -->
<!-- Ej: pytest, pytest-asyncio, pytest-cov -->

## Ubicación de tests
<!-- Dónde viven los archivos de test relativo al root del proyecto. -->
<!-- Ej: tests/ | src/__tests__/ | spec/ -->

## Naming convention — archivos
<!-- Cómo se nombran los archivos de test. -->
<!-- Ej: test_{módulo}.py | {módulo}.test.ts | {módulo}_spec.rb -->

## Naming convention — funciones/métodos
<!-- Cómo se nombran los tests individuales. -->
<!-- Ej: test_{behavior}_{condition} | should_{behavior}_when_{condition} -->

## Anatomía de un test (RED state)
<!-- Ejemplo mínimo de un test que compila pero falla. -->
<!-- Debe mostrar: imports, estructura de la clase/función, aserción que falla. -->

```
<!-- reemplazá con el ejemplo real de tu stack -->
```

## Estructura de archivos de ejemplo
<!-- Cómo quedaría la carpeta de tests para un módulo típico. -->
<!-- Ej:
tests/
├── unit/
│   └── test_payment.py
└── integration/
    └── test_payment_flow.py
-->

## Anti-patterns
<!-- Qué NO hacer cuando se escriben tests en este stack. -->
<!-- Ej: no usar time.sleep(), no compartir estado entre tests, no mockear lo que no controlás -->

## Convenciones adicionales
<!-- Cualquier patrón, herramienta, o regla específica de este stack que el LLM debe conocer. -->
<!-- Ej: fixtures en conftest.py, factories con factory_boy, coverage mínimo 80% -->
