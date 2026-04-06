---
name: test-runner
description: >
  Shared utility. Detects the project's test runner from environment markers,
  executes the test suite, and persists execution evidence to TRACEABILITY.md.
  Any skill can invoke this. Returns a structured result for the calling skill.
license: Apache-2.0
metadata:
  author: doubler
  version: "1.0"
---

## Purpose

Detect the test runner from the project environment, execute the test suite, parse the results, and write evidence to TRACEABILITY.md. The calling skill decides what to do with the result.

---

## Detection Protocol

Execute in strict priority order. Stop at the first match.

### Priority 1 — Explicit override in config.yaml

Read `.forge/config.yaml` → `testing.test_command`.
If the field is present and non-empty: use that command verbatim. Set `runner: custom`. Skip detection entirely.

### Priority 2 — Marker file detection

Check in project root, in this exact order:

| Condition | Command | Runner name |
|-----------|---------|-------------|
| `./gradlew` exists AND (`build.gradle.kts` OR `build.gradle` exists) | `./gradlew test` | Gradle |
| `pom.xml` exists | `mvn test` | Maven |
| `package.json` exists → `scripts.test` field present | `npm test` | npm |
| `package.json` exists → `dependencies` or `devDependencies` contains `jest` | `npx jest` | Jest |
| `package.json` exists → `dependencies` or `devDependencies` contains `vitest` | `npx vitest run` | Vitest |
| `Cargo.toml` exists | `cargo test` | Cargo |
| `go.mod` exists | `go test ./...` | Go |
| `pyproject.toml` OR `pytest.ini` OR `setup.cfg` exists | `pytest` | Pytest |
| `Makefile` exists AND contains a `test:` target | `make test` | Make |

For `package.json`: read the file and inspect `scripts`, `dependencies`, and `devDependencies`. Apply the first matching rule in the order listed above.

If no marker matches: fall through to Priority 3.

### Priority 3 — Manual fallback

Trigger when: nothing detected in Priority 2, OR the detected command fails to execute (command not found, permission denied, or any OS-level execution error).

Present to dev:
```
No pude detectar ni ejecutar el test runner automáticamente.
Ejecutá los tests manualmente y pegá el output completo aquí.
```

Wait for dev to paste output. Parse it using the Output Parsing section below.
Set `execution_mode: manual`.

---

## Execution

1. Run the detected command in the project root
2. Capture: `exit_code`, `stdout`, `stderr`, `duration_ms`
3. If `exit_code == 0` → `result: PASSED`
4. If `exit_code != 0` → `result: FAILED`
5. On execution error (command not found, permission denied, timeout) → fall back to Priority 3

---

## Output Parsing

Extract from stdout/stderr regardless of runner. If a value cannot be parsed, default to 0 or empty list.

```
tests_passed:  N   (integer)
tests_failed:  N   (integer)
tests_skipped: N   (integer)
failed_tests:  []  (list of test names/descriptions that failed)
```

Parsing hints per runner:

| Runner | Look for |
|--------|----------|
| Gradle | `X tests completed, Y failed` or `BUILD SUCCESSFUL` / `BUILD FAILED` |
| Maven | `Tests run: X, Failures: Y, Errors: Z` |
| Jest / Vitest | `Tests: X passed, Y failed` or `PASS` / `FAIL` file prefixes |
| Cargo | `test result: ok. X passed; Y failed` |
| Go | `PASS` / `FAIL` lines and `--- FAIL:` entries |
| Pytest | `X passed, Y failed` in the summary line |
| Make | Apply sub-runner hints based on make output content |
| Manual | Agent extracts summary from the pasted output using best effort |

For `failed_tests`: extract individual test names from lines like `--- FAIL:`, `FAIL `, `✕`, `× `, or equivalent failure markers in the runner's output.

---

## Evidence Persistence

After execution (whether automated or manual), write to:
```
.forge/features/activo/{slug}/TRACEABILITY.md
```

Find or create the `## Test Execution` section. Overwrite it entirely with:

```markdown
## Test Execution

| Campo | Valor |
|-------|-------|
| Runner detectado | {runner name} |
| Comando | `{command}` |
| Modo | automated / manual |
| Resultado | ✅ PASSED / ❌ FAILED |
| Tests passed | {N} |
| Tests failed | {N} |
| Tests skipped | {N} |
| Fecha | {YYYY-MM-DD} |
```

If `failed_tests` is non-empty, append immediately after the table:

```markdown
### Tests fallidos

- {test name}
- {test name}
```

---

## Return Values

Return these fields to the calling skill:

| Field | Values |
|-------|--------|
| `test_execution_result` | `PASSED` \| `FAILED` \| `SKIPPED` |
| `test_execution_mode` | `automated` \| `manual` |
| `test_runner` | detected runner name (e.g., `Gradle`, `Jest`, `custom`) |
| `failed_tests` | list of test names that failed (empty list if none) |

`SKIPPED` means the manual fallback was triggered but the dev has not yet pasted output — the pipeline is waiting for confirmation.
