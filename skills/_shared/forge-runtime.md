# Forge Runtime Protocol (Shared)

> This protocol is referenced by all forge skills. Each skill includes
> `→ See _shared/forge-runtime.md` instead of duplicating these steps.

---

## R0 — forge-memory Session

**Purpose**: Load feature context from forge-memory at session start. Replaces loading `KNOWLEDGE.md` entirely — knowledge is retrieved on-demand, only what's relevant.

1. Call `forge_mem_session_start(project: {slug or "forge-global"})`
   - If the tool is unavailable or errors → set `forge_memory_available: false`, skip to step 3
   - If available → set `forge_memory_available: true`
2. If active feature exists (slug non-null in FORGE.md):
   - Call `forge_mem_feature_context(slug)` to load relevant context
   - If results found AND non-empty: output a concise 2-3 line summary — do NOT dump everything
   - If results empty → treat as forge_memory_available: false for context recovery (go to step 3)
3. Proceed to R1

### Fallback — Artifact-based context recovery

Trigger this fallback when:
- `forge_memory_available: false` (MCP unavailable), OR
- forge-memory returned empty context for an active feature (context was never saved or was lost)

**Recovery steps** (execute silently, no warnings to dev):

1. Read `FORGE.md` → extract `feature`, `slug`, `fase_actual`, phase table states
2. Based on `fase_actual`, read the relevant artifact:
   - `SPEC` → read `.forge/features/activo/{slug}/SPEC.md` (ACs, depth, tech decisions)
   - `BUILD` → read `.forge/features/activo/{slug}/SPEC.md` + `TRACEABILITY.md` (which ACs are done)
   - `VERIFY` → read `.forge/features/activo/{slug}/SPEC.md` + `TRACEABILITY.md` + `VALIDATION-BUILD.md`
   - `CLOSE` → read all above + `VALIDATION-VERIFY.md`
3. Construct a working context from those files — treat it as the session context going forward
4. Output a recovery briefing:

```
🔥 {feature} ({slug}) — {fase_actual} 🔄

📋 ACs:
  AC-1: {title}  {✅ done / ⏳ pending}
  AC-2: {title}  {✅ done / ⏳ pending}
  ...

▶ Siguiente: {next action based on fase_actual}
```

This ensures the agent always has working context regardless of forge-memory availability.

**Fallback rule for skills**: If `forge_memory_available: false`, every skill that would call forge-memory MUST fall back to reading `.forge/KNOWLEDGE.md` instead. KNOWLEDGE.md is a **thin index** — contains references and forge-memory topic keys, NOT full content. Never error on MCP unavailability.

---

## R1 — Read config

Read `.forge/config.yaml` from the project root. The canonical format is nested:

| Field | Key path |
|-------|----------|
| Platform | `stack.plataforma` |
| Default model | `modelos.default` |
| Architect model | `modelos.architect` |
| Language | `ciclo.idioma` |

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

## R5 — Session Close

Execute this step **after** all skill-specific logic is complete and before returning the final response.

**If `forge_memory_available: true`:**
1. Call `forge_mem_session_end(project: {slug or "forge-global"})`
2. Call `forge_mem_session_summary` with:
   - `goal`: what the skill was asked to do
   - `accomplished`: artifacts written, decisions made, validations run
   - `next_steps`: what the dev should do next (`forge {phase}`)
   - `relevant_files`: paths of files created or modified

**If `forge_memory_available: false`:** skip silently — no error.

> This step ensures that every forge command leaves a recoverable trace in forge-memory. Without R5, sessions accumulate as "started but never closed" and context recovery degrades over time.

**Excepción**: Skills que manejan el cierre de sesión internamente (actualmente: `forge-close.md` vía K5) deben declarar explícitamente `R5_SKIP: true` en su frontmatter o en su sección de Forge Runtime. R5 NO se ejecuta para esos skills.

---

## Shared Error Codes

Cross-cutting errors reusable by any skill. Phase-specific errors (E002+, E050+, E100+, etc.) remain in each skill file.

| Code | Condition | Message |
|------|-----------|---------|
| **E001** | `FORGE.md` not found | No encontré `.forge/FORGE.md`. Este proyecto no está configurado para Forge. |
| **E010** | No active feature (generic) | No hay feature activa. Ejecutá `forge new "nombre feature"` primero. |
| **E011** | Phase already approved (generic) | La fase {fase_actual} ya está ✅ Aprobado. Los artefactos aprobados son inmutables. |
| **E012** | Required artifact not found (generic) | {PHASE}.md no encontrado. Ejecutá `forge {phase}` para generar el artefacto primero. |

### Error Code Ranges (by skill)

| Range | Skill |
|-------|-------|
| E001 | `forge-runtime` (shared — FORGE.md not found) |
| E002–E009 | `forge-new` |
| E010–E019 | Shared / generic |
| E050–E059 | `forge-spike` |
| E100–E109 | `forge-spec` |
| E200–E209 | `forge-build` |
| E300–E309 | `forge-verify` |
| E500–E509 | `forge-approve` / `forge-validate` |
| E600–E609 | `forge-close` |
| E700–E709 | `forge-status` |
| E800–E809 | `forge-trace` / `forge-ref` |

---

## Sub-Agent Mode

When a forge skill runs as a sub-agent (launched by the orchestrator via the Agent tool), the following adjustments apply:

### R4 — Announce (Sub-Agent)

Instead of outputting the announcement to the conversation, include it in the Return Contract output. The orchestrator will present status to the dev.

### Return Contract Protocol

Sub-agents MUST output a structured YAML block at the end of their response. The format is defined in each skill's "Return Contract" section. The orchestrator parses this to determine next actions.

```yaml
status: complete | partial | blocked | needs_input
summary: "1-3 sentence summary"
artifacts_written:
  - path: {file_path}
    action: created | updated
metrics: {phase-specific}
next_recommended: "{next forge command}"
pending_decisions: []  # only for needs_input status
risks: []
```

### Context Recovery in Sub-Agents

Sub-agents start with ZERO conversation history. They recover context by:
1. Reading files from disk (paths provided by orchestrator)
2. Executing R0-R3 normally (forge-memory + config + FORGE.md + preconditions)
3. Loading only their focused skill file (not the full forge-build.md)

This is by design — fresh context means no accumulated token bloat.
