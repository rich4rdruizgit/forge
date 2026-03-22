# FORGE — Project Status
> Generated: 2026-03-26

---

## Overview

**FORGE** is an AI-assisted development methodology that enforces a gated pipeline:

```
SPIKE (optional) → SPEC → BUILD (RED → auto-gate → GREEN) → VERIFY → CLOSE
```

Each phase produces an **approved artifact** that unlocks the next. No phase skipping. No implementation without approved specs. Philosophy: *think before you code*.

- **Version:** v0.4 (implemented 2026-03-26)
- **Author:** doubler
- **Primary Stack:** Android / KMP (Kotlin)
- **Repository:** Clean — no uncommitted changes

---

## Active Feature Cycle

**No active feature.** Ready to start with `forge new "feature name"`.

| SPIKE | SPEC | BUILD | VERIFY |
|:-----:|:----:|:-----:|:------:|
|  ⏳   |  ⏳  |  ⏳   |   ⏳   |

---

## Repository Structure

```
FORGE/
├── FORGE.md                    ← Agent context (3-layer: metadata, phase, reference)
├── KNOWLEDGE.md                ← Progressive project memory (v0.4)
├── README.md
├── config.yaml                 ← Team configuration template
├── setup-project.sh            ← Bootstrap script
│
├── skills/                     ← 11 agent skills (Forge commands) + 1 shared runtime
│   ├── forge-new.md            ← MODIFIED v0.4
│   ├── forge-spike.md
│   ├── forge-spec.md           ← MODIFIED v0.4
│   ├── forge-build.md          ← MODIFIED v0.4
│   ├── forge-verify.md         ← MODIFIED v0.4
│   ├── forge-approve.md
│   ├── forge-validate.md
│   ├── forge-trace.md
│   ├── forge-ref.md
│   ├── forge-status.md         ← MODIFIED v0.4
│   ├── forge-close.md          ← MODIFIED v0.4
│   └── _shared/
│       └── forge-runtime.md    ← NEW v0.4 (shared runtime protocol)
│
├── templates/                  ← 7 artifact templates
│   ├── SPIKE.md
│   ├── SPEC.md
│   ├── VERIFY.md
│   ├── TRACEABILITY.md
│   ├── VALIDATION.md
│   ├── INDEX.md
│   └── KNOWLEDGE.md            ← NEW v0.4 (progressive team memory)
│
├── validation/                 ← 5 assertion YAML files (reorganized by pillars)
│   ├── assertions-spike.yaml
│   ├── assertions-spec.yaml    ← MODIFIED v0.4
│   ├── assertions-build.yaml   ← MODIFIED v0.4
│   ├── assertions-verify.yaml  ← MODIFIED v0.4
│   └── assertions-cross.yaml
│
└── stacks/
    ├── android.md
    ├── kmp.md
    └── TEMPLATE.md
```

---

## Commands

| Command | Skill | Purpose | v0.4 |
|---------|-------|---------|------|
| `forge new "name"` | forge-new | Bootstrap feature cycle | Loads HU, evaluates adaptive depth, consults KNOWLEDGE.md |
| `forge spike` | forge-spike | Optional exploration/research phase | — |
| `forge spec` | forge-spec | Generate unified SPEC document | 7-step conversation protocol |
| `forge build` | forge-build | RED → auto-gate → GREEN implementation | Auto-gate replaces manual TDD/SDD commands |
| `forge verify` | forge-verify | Explicit verification phase | Quality Score (0-10) with 5-pillar rubric |
| `forge approve` | forge-approve | Validate & approve phase | Assertions organized by pillars |
| `forge validate` | forge-validate | Dry-run validation (no approval) | — |
| `forge trace` | forge-trace | Generate traceability matrix | — |
| `forge ref <query>` | forge-ref | Query closed features as reference | — |
| `forge status` | forge-status | Cycle state report | Shows Quality Score and pillar breakdown |
| `forge close` | forge-close | Archive completed feature | Updates KNOWLEDGE.md with learnings |

---

## v0.4 Key Features

### 1. Five Pillars (P1–P5)
All validation, assertions, and the Quality Score are organized around five semantic pillars:
- **P1 — Requirements**: Acceptance criteria, user stories, scope
- **P2 — Domain**: Domain model, events, commands, aggregates, invariants
- **P3 — Architecture**: File structure, contracts, decisions, layers
- **P4 — Testing**: Coverage, RED/GREEN state, immutability rule
- **P5 — Quality**: Code quality, patterns, documentation

Replacing arbitrary checklists with pillar-based assertions gives semantic meaning to validation failures.

### 2. Adaptive Depth (LIGERA / MEDIA / PROFUNDA)
`forge new` evaluates the complexity of the incoming user story and selects a validation depth:
- **LIGERA**: Simple CRUD, no domain logic — faster cycle with fewer required assertions
- **MEDIA**: Standard features with domain events and state — default depth
- **PROFUNDA**: Complex domain, cross-cutting concerns, architectural impact — maximum rigor

Quality Score thresholds and required assertions scale with depth selection.

### 3. Quality Score (0–10)
A numeric score replaces binary pass/fail for the VERIFY phase:
- Score is calculated from pillar weights (each pillar contributes proportionally)
- **Threshold: ≥ 7** to proceed to CLOSE
- Score adapts to existing team knowledge — an empty `KNOWLEDGE.md` does not penalize
- `forge status` shows the score with a per-pillar breakdown

### 4. Auto-Gate in BUILD (RED → GREEN)
The transition from RED to GREEN inside the BUILD phase is automatic — no separate command needed:
- Agent writes failing tests (RED state)
- Auto-gate validates: all tests must compile and fail for the right reason
- If gate passes, agent proceeds to implementation (GREEN)
- If gate fails, RED phase repeats — no skipping forward
- Immutable tests rule: RED tests cannot be modified during GREEN phase

### 5. Immutable Tests Rule
Tests written during RED are locked for the duration of GREEN:
- Prevents retroactive test weakening to make implementation easier
- Violations are flagged by `forge verify` assertions (P4)
- Refactor phase may update tests only if ACs change and with explicit justification

### 6. KNOWLEDGE.md — Progressive Team Memory
A new template and workflow for accumulating team knowledge across features:
- Updated automatically by `forge close` with learnings from the completed cycle
- Versioned in git — shared across the team, not personal/agent memory
- Consulted by `forge new` to inform depth selection and surface relevant patterns
- Starts empty with no penalty; grows more valuable with each closed feature

### 7. forge new — Expanded Behavior
`forge new` now does more than scaffold:
1. Loads the user story (HU) and parses it
2. Consults `KNOWLEDGE.md` for relevant prior patterns
3. Evaluates adaptive depth (LIGERA / MEDIA / PROFUNDA)
4. Surfaces relevant risks or known gotchas from memory
5. Creates the feature workspace with depth-appropriate templates

### 8. forge spec — 7-Step Conversation Protocol
`forge spec` follows a structured 7-step protocol to ensure complete specification:
1. Understand the user story and constraints
2. Identify domain boundaries
3. Define acceptance criteria (AC format enforced)
4. Model domain events and commands
5. Define architecture and file structure
6. Specify UI Contract (states and flows)
7. Review and confirm before writing SPEC.md

### 9. Assertions Reorganized by Pillars
All assertion YAML files now group checks under P1–P5 blocks:
- Conditional blocks per depth level (LIGERA skips some P2/P3 checks)
- Pillar weights used to compute Quality Score
- Consistent pillar keys across spike, spec, build, verify, and cross assertions

### 10. Shared Runtime Protocol
`skills/_shared/forge-runtime.md` centralizes rules shared across all skills:
- Phase transition conditions
- Artifact naming conventions
- Error handling and recovery
- Depth resolution logic

---

## Validation Assertions Summary

| File | Phase | v0.4 Changes |
|------|-------|-------------|
| assertions-spike.yaml | SPIKE | Organized by pillars (P1, P3) |
| assertions-spec.yaml | SPEC | 7-step protocol checks, pillar weights, depth-conditional blocks |
| assertions-build.yaml | BUILD | Auto-gate checks, immutable tests rule, pillar P4 enforcement |
| assertions-verify.yaml | VERIFY | Quality Score rubric, per-pillar scoring, threshold ≥7 |
| assertions-cross.yaml | Cross-phase | AC consistency, event naming, traceability chain |

---

## Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Pipeline | SPIKE → SPEC → BUILD (RED→auto-gate→GREEN) → VERIFY → CLOSE | Auto-gate provides TDD protection without ceremony overhead |
| 5 Pillars | P1 Requirements, P2 Domain, P3 Architecture, P4 Testing, P5 Quality | Semantic organization vs arbitrary checklists; enables weighted scoring |
| Adaptive Depth | LIGERA / MEDIA / PROFUNDA | One-size-fits-all rigor slows simple features; depth scales assertions to complexity |
| Quality Score | 0-10, threshold ≥7, pillar-weighted | Numeric score is more actionable than binary pass/fail; empty KNOWLEDGE.md doesn't penalize |
| Auto-gate | Automatic RED→GREEN transition check | Protection without a separate command; reduces ceremony while maintaining discipline |
| Immutable tests | RED tests locked during GREEN | Prevents retroactive weakening; enforces true TDD discipline |
| KNOWLEDGE.md | Template + git versioned, updated on close | Team-shared memory; grows with usage; survives agent context resets |
| forge new expanded | Loads HU, checks memory, evaluates depth | Front-loads intelligence; better scaffolding from the start |
| forge spec protocol | 7-step conversation | Structured elicitation prevents incomplete specs at the source |
| Shared runtime | `_shared/forge-runtime.md` | Single source of truth for cross-skill rules; no drift between skills |
| SPEC unification | Single SPEC.md replaces PRD + EDD | Requirements and design evolve together; artificial separation caused sync issues |
| Validation | Assertions + evidence | Evidence enables audit trail — no blind checkmarks |
| INDEX.md | Markdown + Engram | File = versionable; Engram = semantic search. Forge works without Engram. |

---

## Stack Configuration

**Android:**
- Unit Tests: JUnit5 + MockK + Turbine
- UI Tests: Compose Testing / Espresso
- DI: Hilt / Koin (configurable)
- Async: Coroutines + Flow / RxJava

**KMP:**
- Unit Tests: JUnit5 + MockK (in `commonTest`)
- Async: Coroutines + Flow

**AI Models:**
- Default: `claude-sonnet-4-6` — SPEC, BUILD, VERIFY, Guardian
- Architect: `claude-opus-4-6` — SPEC (complex domains)
- Fallback: `gemini-2.0-flash`

---

## Git History

| Commit | Date | Message |
|--------|------|---------|
| 9588660 | 2026-03-23 | feat: Forge v0.3 — AI-assisted development methodology for mobile teams |
| f999403 | 2026-03-22 | feat: implement Forge v0.2 — assertion-based validation, EDD separation, traceability, progressive disclosure |
| 65933b7 | 2026-03-22 | feat: add LLM adapter paths to .gitignore based on detected tools |
| 9e0f340 | 2026-03-22 | feat: auto-add .forge/ to project .gitignore on setup |
| 06b96a0 | 2026-03-22 | fix: resolve all audit gaps — paths, error codes, AC format, models, return envelopes |

---

## Roadmap

| Phase | Status | Description |
|-------|--------|-------------|
| Phase 1 | ✅ Done | Claude Code agent skills (v0.1) |
| Phase 1.5 | ✅ Done | Validation and traceability (v0.2) |
| Phase 1.7 | ✅ Done | Pipeline simplification and SPEC unification (v0.3) |
| Phase 1.9 | ✅ Done | Pillars, Adaptive Depth, Quality Score, auto-gate, KNOWLEDGE.md (v0.4) |
| Phase 2 | 🔜 Planned | CLI binary (`forge` as global command with linting) |
| Phase 3 | 🔜 Planned | MCP Server (Cursor, Zed, VS Code, Claude Desktop) |
| Phase 4 | 🔜 Planned | Ecosystem (more stacks, dashboard, Azure/Jira integration) |

---

## File Count (v0.4)

| Category | Files | Notes |
|----------|-------|-------|
| Skills | 11 | forge-new, forge-spike, forge-spec, forge-build, forge-verify, forge-approve, forge-validate, forge-trace, forge-ref, forge-status, forge-close |
| Shared skills | 1 | `_shared/forge-runtime.md` — NEW v0.4 |
| Templates | 7 | SPIKE, SPEC, VERIFY, TRACEABILITY, VALIDATION, INDEX, KNOWLEDGE (NEW v0.4) |
| Validation | 5 | assertions-spike, spec, build, verify, cross (all reorganized by pillars) |
| Core Docs | 2 | FORGE.md, KNOWLEDGE.md |
| Config/Scripts | 2 | config.yaml, setup-project.sh |
| Stack Guides | 3 | android.md, kmp.md, TEMPLATE.md |
| **Total** | **31** | |

---

## v0.4 Changes Summary

### Skills Modified

| Skill | Change |
|-------|--------|
| forge-new | Expanded: loads HU, evaluates depth, consults KNOWLEDGE.md |
| forge-spec | 7-step conversation protocol |
| forge-build | Auto-gate between RED and GREEN; immutable tests rule |
| forge-verify | Quality Score (0-10) with pillar rubric, threshold ≥7 |
| forge-status | Shows Quality Score and per-pillar breakdown |
| forge-close | Updates KNOWLEDGE.md with cycle learnings |

### New Artifacts

| Artifact | Purpose |
|----------|---------|
| `skills/_shared/forge-runtime.md` | Shared runtime protocol (phase transitions, naming, depth logic) |
| `templates/KNOWLEDGE.md` | Progressive team memory template |

### Assertion Changes

| File | Change |
|------|--------|
| All assertion files | Reorganized into P1–P5 pillar blocks |
| assertions-build.yaml | Auto-gate checks, immutable tests rule |
| assertions-verify.yaml | Quality Score rubric with pillar weights |
| assertions-spec.yaml | 7-step protocol checks, depth-conditional blocks |
