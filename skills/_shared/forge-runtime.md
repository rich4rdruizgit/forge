# Forge Runtime Protocol (Shared)

> This protocol is referenced by all forge skills. Each skill includes
> `→ See _shared/forge-runtime.md` instead of duplicating these steps.

---

## R0 — forge-memory Session

**Purpose**: Load feature context from forge-memory at session start. Replaces loading `KNOWLEDGE.md` entirely — knowledge is retrieved on-demand, only what's relevant.

1. Attempt `forge_mem_context` call (project: `{slug}` if active feature, otherwise `"forge-global"`)
   - If the tool is unavailable or errors → set `forge_memory_available: false`, skip to R1 silently
   - If available → set `forge_memory_available: true`
2. Call `forge_mem_session_start(project: {slug or "forge-global"})`
3. If active feature exists (slug non-null in FORGE.md):
   - Call `forge_mem_feature_context(slug)` to load relevant context for this feature
   - If results found: output a concise 2-3 line summary — do NOT dump everything
4. Proceed to R1

**Fallback rule**: If `forge_memory_available: false`, every skill that would call forge-memory MUST fall back to reading `.forge/KNOWLEDGE.md` file instead. Never error. Never warn the dev about MCP unavailability unless the command is explicitly `forge ref` or `forge new`.

---

## R1 — Read config

Read `.forge/config.yaml` from the project root. Handle BOTH formats:

| Format | stack | modelo_agente | modelo_arch | lenguaje |
|--------|-------|---------------|-------------|----------|
| **Flat** | `stack` | `modelo_agente` | `modelo_arch` | `lenguaje` |
| **Nested** | `stack.plataforma` | `modelos.default` | `modelos.architect` | `ciclo.idioma` |

**Defaults** (if field absent or file missing):

| Field | Default |
|-------|---------|
| `stack` | `android` |
| `modelo_agente` | `claude-sonnet-4-6` |
| `modelo_arch` | `claude-opus-4-6` |
| `lenguaje` | `es` |

Never fail due to missing config — always fall back to defaults.

---

## R2 — Read FORGE.md

Read `FORGE.md` (or `.forge/FORGE.md`) from the project root.

**Extract from YAML block** (under `## Ciclo Activo`):
- `feature` — name of the active feature (null if none)
- `slug` — folder name under `.forge/features/activo/`
- `azure_story` — ticket ID (may be null)
- `fase_actual` — current phase (`SPIKE` | `SPEC` | `BUILD` | `VERIFY`)

**Extract from phase table** — read the Estado column for each row:

| Status string | Meaning |
|---------------|---------|
| `✅ Aprobado` | Approved (phase complete) |
| `🔄 En progreso` | In progress (phase active) |
| `⏳ Sin iniciar` | Not started |

**Canonical vocabulary** — NEVER use alternatives:
- ~~`✅ Completado`~~ → use `✅ Aprobado`
- ~~`🔄 En construcción`~~ → use `🔄 En progreso`

---

## R3 — Verify preconditions

Check the preconditions defined in the calling skill's `## Preconditions` section.

If ANY precondition fails:
1. **STOP immediately**
2. Output: `🚫 {error_code} — {message}`
3. Do NOT proceed to Execution Steps
4. Do NOT modify any file

---

## R4 — Announce active feature

Output one line at the top of your response:

```
🔥 Forge | Feature: {feature} ({slug}) | Fase actual: {fase_actual}
```

Then proceed to Execution Steps.

---

## Shared Error Codes

Cross-cutting errors reusable by any skill. Phase-specific errors (E050+, E100+, E200+, etc.) remain in each skill file.

| Code | Condition | Message |
|------|-----------|---------|
| **E001** | `FORGE.md` not found | No encontré `.forge/FORGE.md`. Este proyecto no está configurado para Forge. |
| **E002** | Active feature already exists (when creating new) | Ya hay una feature activa: {feature}. Ejecutá `forge close` antes de crear una nueva. |
| **E003** | Templates directory missing | Falta `.forge/templates/`. Copiá los templates de FORGE antes de continuar. |
| **E004** | Feature slug directory already exists | Ya existe `.forge/features/activo/{slug}/`. Elegí un nombre diferente o cerrá la feature existente. |
| **E005** | Empty feature name | El nombre de la feature no puede estar vacío. Especificá un nombre: `forge new "nombre feature"`. |
| **E010** | No active feature (generic) | No hay feature activa. Ejecutá `forge new "nombre feature"` primero. |
| **E011** | Phase already approved (generic) | La fase {fase_actual} ya está ✅ Aprobado. Los artefactos aprobados son inmutables. |
| **E012** | Required artifact not found (generic) | {PHASE}.md no encontrado. Ejecutá `forge {phase}` para generar el artefacto primero. |

### Error Code Ranges (by skill)

| Range | Skill |
|-------|-------|
| E001–E005 | `forge-new` |
| E010–E019 | Shared / generic |
| E050–E059 | `forge-spike` |
| E100–E109 | `forge-spec` |
| E200–E209 | `forge-build` |
| E300–E309 | `forge-verify` |
| E500–E509 | `forge-approve` / `forge-validate` |
| E600–E609 | `forge-close` |
| E700–E709 | `forge-status` |
| E800–E809 | `forge-trace` / `forge-ref` |
