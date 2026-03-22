```
    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
    █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
    ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
```

> **Think before you code.** An AI-assisted development methodology that enforces a gated pipeline from idea to verified implementation.

---

## What is Forge?

Most teams follow the same anti-pattern: receive a ticket → open IDE → start coding. The result is predictable — code nobody understands, tests written as an afterthought, and features that don't solve the real problem. The apparent speed of "straight to code" is an illusion. Time lost to rework, design bugs, and misunderstood requirements is always greater.

Forge enforces a pipeline where you **think, specify, and verify** before writing a single line of production code:

```
SPIKE (optional) → SPEC → BUILD (RED → auto-gate → GREEN) → VERIFY → CLOSE
```

Each phase produces an **approved artifact** that gates the next. No shortcuts. No phase skipping. An AI agent walks with you through each step — generating artifacts, running assertions, and blocking progress if the rules aren't met.

---

## The Pipeline

| Phase | Artifact | Purpose | Gate |
|-------|----------|---------|------|
| **SPIKE** *(optional)* | `SPIKE.md` | Time-boxed investigation — explore unknowns before committing to a spec | `forge approve` |
| **SPEC** | `SPEC.md` | Unified document: requirements, domain model, architecture, UI contract | `forge approve` |
| **BUILD** | Tests + code | Red → auto-gate → Green — tests first, gate validates, then implementation | `forge approve` |
| **VERIFY** | `VERIFY.md` | Explicit post-implementation check — every AC verified with evidence | `forge approve` |
| **CLOSE** | `INDEX.md` | Archive the feature as a searchable as-built reference | — |

Each phase is **immutable once approved** — no silent rewrites, no going back.

---

## Commands

| Command | What it does |
|---------|-------------|
| `forge new "feature name"` | Load HU, evaluate depth, consult knowledge base, bootstrap cycle |
| `forge spike` | Start optional exploration phase |
| `forge spec` | 7-step conversation protocol — AI asks, never invents |
| `forge build` | RED → auto-gate → GREEN — tests first, implementation after, tests immutable |
| `forge verify` | Verify implementation against every AC and UI contract state |
| `forge approve` | Run assertions, generate validation report, approve current phase |
| `forge validate` | Dry-run assertions without approving |
| `forge trace` | Generate traceability matrix: AC → Event → Test → Implementation → UI State |
| `forge ref <query>` | Query closed features as reference |
| `forge status` | Show current cycle state |
| `forge close` | Archive feature, extract knowledge to KNOWLEDGE.md |

---

## Installation

### Requirements

At least one of: [Claude Code](https://claude.ai/code), [Cursor](https://cursor.com), GitHub Copilot, [Windsurf](https://windsurf.com), or [Gemini CLI](https://github.com/google-gemini/gemini-cli).

### Setup

```bash
# Clone Forge
git clone https://github.com/doubler/forge.git

# Run from your project root
cd /your/project
bash /path/to/forge/setup-project.sh
```

The script:
1. Creates `.forge/` in your project with all templates, skills, validation assertions, and `FORGE.md`
2. Detects which AI tools you have installed
3. Generates the appropriate adapters (`.claude/`, `.cursor/rules/`, `.windsurfrules`, `.gemini/`, etc.)

### One-liner alias (optional)

Add to your `.zshrc` or `.bashrc`:

```bash
alias forge-install='bash /path/to/forge/setup-project.sh'
```

Then from any project:

```bash
cd /your/project && forge-install
```

### Configure your stack

Edit `.forge/config.yaml`:

```yaml
stack:
  plataforma: android        # android | kmp

modelos:
  default: claude-sonnet-4-6
  architect: claude-opus-4-6

ciclo:
  idioma: español            # español | english
```

---

## Stack Support

The methodology is stack-agnostic — the pipeline, gates, and AI protocols work regardless of language or framework. Forge currently ships with first-class support for **Android and Kotlin Multiplatform**. Adding support for a new stack means writing a single `stacks/{name}.md` guide.

| Stack | Unit Tests | UI / Integration Tests |
|-------|-----------|----------------------|
| Android (Kotlin) | JUnit5 + MockK + Turbine | Compose Testing / Espresso |
| KMP (Kotlin) | JUnit5 + MockK (`commonTest`) | — |
| *Your stack* | *Add `stacks/{name}.md`* | — |

---

## Rules Forge Never Breaks

1. **No implementation without an approved SPEC** — `forge build` is blocked until SPEC is approved
2. **Acceptance criteria come from the developer, never from the AI** — `forge spec` asks, never invents
3. **No phase advance without passing assertions** — blockers halt progress automatically
4. **Approved artifacts are immutable** — once approved, no silent modifications
5. **Features over 5 story points must be split** — the agent proposes fragmentation before continuing
6. **No `forge close` without an approved VERIFY** — "done coding" ≠ "done"
7. **Tests written in RED cannot be modified during GREEN** — the dev decides, not the AI
8. **No SPEC approval without Quality Score ≥ 7/10**

---

## Project Structure

```
FORGE/
├── FORGE.md                    ← agent context (3-layer: metadata, phase, reference)
├── README.md
├── config.yaml                 ← team configuration template
├── setup-project.sh            ← bootstrap script
│
├── skills/                     ← 11 agent skills (one per forge command)
│   ├── forge-new.md
│   ├── forge-spike.md
│   ├── forge-spec.md
│   ├── forge-build.md
│   ├── forge-verify.md
│   ├── forge-approve.md
│   ├── forge-validate.md
│   ├── forge-trace.md
│   ├── forge-ref.md
│   ├── forge-status.md
│   └── forge-close.md
│
├── KNOWLEDGE.md                ← project memory extracted by forge close
│
├── templates/                  ← artifact templates per phase
│   ├── SPIKE.md
│   ├── SPEC.md
│   ├── VERIFY.md
│   ├── TRACEABILITY.md
│   ├── VALIDATION.md
│   └── INDEX.md
│
├── validation/                 ← assertion YAML files per phase
│   ├── assertions-spike.yaml
│   ├── assertions-spec.yaml
│   ├── assertions-build.yaml
│   ├── assertions-verify.yaml
│   └── assertions-cross.yaml
│
└── stacks/
    ├── android.md
    ├── kmp.md
    └── TEMPLATE.md             ← starting point for new stacks
```

---

## Roadmap

| Phase | Status | Description |
|-------|--------|-------------|
| v0.1 | ✅ Done | Claude Code agent skills — full cycle via chat |
| v0.2 | ✅ Done | Assertion-based validation, traceability matrix, progressive disclosure |
| v0.3 | ✅ Done | Pipeline simplification — unified SPEC, red-green-refactor BUILD, VERIFY phase |
| v0.4 | ✅ Done | 5 Pillars, Quality Score, adaptive depth, project memory (KNOWLEDGE.md), auto-gate in BUILD |
| v0.5 | 🔜 | MCP Server — compatible with Cursor, Zed, VS Code, Claude Desktop |
| v1.0 | 🔜 | Ecosystem — more stacks, web dashboard, Azure DevOps / Jira integration |

---

## Author

**doubler** — [github.com/doubler](https://github.com/doubler)

---

*FORGE v0.4 — March 2026*
