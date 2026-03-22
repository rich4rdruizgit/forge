---
name: forge-ref
description: >
  Query as-built references from closed features. Searches INDEX.md files
  and Engram for past implementations matching a query.
trigger: "`forge ref <query>` command with FORGE.md present in project"
license: Apache-2.0
metadata:
  author: doubler
  version: "2.0"
---

## Purpose

Consultar features cerradas como referencia canónica. Buscar por nombre, tag, patrón, o texto libre. Permite reutilizar decisiones, patrones y conocimiento acumulado de features anteriores.

---

## Preconditions

- `forge/FORGE.md` exists and is readable
- `.forge/features/closed/` directory exists (can be empty)

**E800**: "No encontré `forge/FORGE.md`. Este proyecto no está configurado para Forge."
**E801**: "No encontré `.forge/features/closed/`. No hay features cerradas todavía — se va a ir llenando a medida que uses `forge close`."

**If FORGE.md not found:** output E800 and STOP.
**If closed/ not found or empty:** output E801 and STOP.

---

## Forge Runtime

→ Execute `_shared/forge-runtime.md` steps R1–R4 before any skill-specific logic.

---

## Execution Steps

### Step REF1 — Parse query

Parse query from command: `forge ref <query>`

- If query matches a known slug → search directly in `.forge/features/closed/{slug}/INDEX.md`
- If query is a tag or free text → search all INDEX.md files in closed features

### Step REF2 — File search

a. List all folders in `.forge/features/closed/`
b. For each folder, read `INDEX.md`
c. Match query against these fields (case-insensitive):
   - Feature name (header)
   - Tags (## Tags section)
   - Decisiones técnicas clave (table content)
   - Patrones reutilizables (pattern names and context)
   - Eventos del dominio (event names)
   - ACs implementados (AC titles)
   - Resumen ejecutivo (free text)

### Step REF2.5 — KNOWLEDGE.md search

If `.forge/KNOWLEDGE.md` exists and is non-empty:
- Search KNOWLEDGE.md for matches against the query in these sections:
  - **Patrones Establecidos** (pattern names, descriptions)
  - **Contratos Conocidos** (endpoints, components, interfaces)
  - **Componentes Reutilizables** (component names, usage context)
  - **Errores y Lecciones** (error descriptions, lessons learned)
  - **Decisiones Técnicas Globales** (decision titles, rationale)
- Store matching entries separately from INDEX.md results, tagged with source `KNOWLEDGE.md`

If `.forge/KNOWLEDGE.md` does not exist or is empty, skip this step silently.

### Step REF3 — Engram search (if available)

a. Call `mem_search` with the query and project name
b. Filter results matching topic_key patterns: `.forge/features/*`, `forge-close/*`
c. For relevant matches, call `mem_get_observation` to get full content

If Engram is not available → skip this step silently and rely on file search only.

### Step REF4 — Rank results

Rank matching features by relevance:
1. Exact slug match → highest priority
2. Tag match → high priority
3. Pattern name match → high priority
4. Decision or event match → medium priority
5. Free text match in resumen → lower priority

Features with more matches across different fields rank higher.

### Step REF5 — Present results

Render a summary table of matching features:

```
╔═══════════════════════════════════════════════════════════════╗
║  🔍 FORGE REF — Resultados para: "{query}"                    ║
╠═══════════════════════════════════════════════════════════════╣
║  #   Feature                Slug            Relevancia        ║
║  1   {feature_name}         {slug}          {match_reason}    ║
║  2   ...                    ...             ...               ║
╚═══════════════════════════════════════════════════════════════╝
```

For each result, show:
- **Source**: indicate if result comes from `INDEX.md` or `KNOWLEDGE.md`
- **Resumen ejecutivo** (first 2-3 lines) — for INDEX.md results
- **Decisiones técnicas relevantes** (only those matching the query)
- **Patrones reutilizables** (only those matching the query)

If KNOWLEDGE.md returned matches, present them in a separate section AFTER the INDEX.md results:

```
╔═══════════════════════════════════════════════════════════════╗
║  📚 KNOWLEDGE.md — Resultados para: "{query}"                 ║
╠═══════════════════════════════════════════════════════════════╣
║  Sección                    Entrada              Relevancia   ║
║  {section_name}             {entry_title}        {match_reason}║
║  ...                        ...                  ...          ║
╚═══════════════════════════════════════════════════════════════╝
```

If no results found:
```
No encontré features cerradas que matcheen con "{query}".
Tip: probá con otros términos, o revisá los tags en los INDEX.md de features cerradas.
```

### Step REF6 — Detail on request

If the dev asks for more detail on a specific result:
- Load full INDEX.md from `.forge/features/closed/{slug}/INDEX.md`
- Render all sections: ACs, eventos, decisiones, archivos, métricas
- Optionally load related artifacts (PRD, EDD, TDD, SDD) from the same closed feature folder

---

## Output Format

Summary table of matching features (Step REF5), then detail on request (Step REF6).

### Success
```
**Estado**: `complete`
**Resumen**: {N} features encontradas para "{query}".
**Resultados**: {summary table + highlights}
```

### No results
```
**Estado**: `complete`
**Resumen**: Sin resultados para "{query}".
**Sugerencia**: Probá con otros términos o revisá `forge status` para features activas.
```

### Blocked
```
**Estado**: `blocked`
**Error**: {EXXX — message}
**Acción requerida**: {what to do}
```

---

## Rules

- **NUNCA modificar archivos de features cerradas — esta skill es de solo lectura, sin excepciones**
- Si no hay features cerradas → informar amablemente y sugerir que se completará con el uso de `forge close`
- Si Engram no está disponible → buscar solo en archivos, sin error
- Mostrar resultados rankeados por relevancia — los más relevantes primero
- SIEMPRE mostrar el resumen ejecutivo de cada resultado — es el contexto mínimo necesario
- Para búsquedas amplias, limitar a los 5 resultados más relevantes y ofrecer paginación
- Si el dev pide detalle de un resultado, cargar el INDEX.md completo — no resumir de más
