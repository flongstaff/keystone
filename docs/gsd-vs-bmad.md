# GSD vs BMAD -- Comparison and Coexistence Guide

## Overview

| Aspect | GSD (Get Shit Done) v1.22.4 | BMAD Method (full install) |
|--------|----------------------------|----------------------------------|
| **Philosophy** | Ship fast. Execution-focused. | Agile methodology. Process-driven. |
| **Scope** | General-purpose project execution | Full SDLC framework with specialized modules |
| **Install** | Global (`~/.claude/get-shit-done/`) | Project-local (`_bmad/` per project) |
| **Modules** | 12 agents, 32 commands, 34 workflows | 6 modules, 108 commands, 27+ agents |
| **Supported Tools** | Claude Code, OpenCode, Gemini CLI, Codex | Claude Code (official); Pi (via prompt templates) |
| **Namespace** | `gsd:` prefix | `bmad-` prefix |
| **Conflicts** | None with BMAD | None with GSD |

## BMAD Modules

| Module | Code | Focus | Agents | Commands |
|--------|------|-------|--------|----------|
| **Core** | core | Shared engine, workflow.xml, tasks, brainstorming | 1 (bmad-master) | 8 |
| **BMM** | bmm | Business/product planning — analyst, architect, PM, PO, QA, UX, dev, SM, tech-writer | 10 | 22 |
| **GDS** | gds | Game development — design, architecture, narrative, gametest | 7 | 25 |
| **BMB** | bmb | BMAD Module Builder — create/edit/validate agents, modules, workflows | 3 | 10 |
| **CIS** | cis | Creative Innovation Suite — brainstorming, design thinking, storytelling | 6 | 4 |
| **TEA** | tea | Test Engineering Architecture — ATDD, CI, test framework, NFR testing | 1 | 9 |

## Architecture

### GSD
- **Global installation** — agents/commands/workflows at `~/.claude/`
- **Phase-based execution** — milestones → phases → plans → tasks
- **Goal-backward verification** — verifies outcomes, not just task completion
- **Atomic commits** — each task = one commit with state tracking
- **Context management** — pause/resume across sessions, deviation handling
- **Key agents**: roadmapper, planner, executor, verifier, debugger, phase-researcher

### BMAD
- **Project-local** — `_bmad/` contains agents, workflows, templates, config
- **Modular** — core + installable modules (BMM, GDS, BMB, CIS, TEA)
- **Agent personas** — each agent has identity, menu system, communication style
- **Workflow engine** — `workflow.xml` core OS processes `workflow.yaml` configs
- **Template-driven** — genre templates, architecture templates, test templates
- **Cross-domain** — BMM for general product dev, GDS for games, CIS for innovation, TEA for testing

## What Each Does Better

### GSD Excels At (The Builder)
- **Execution discipline** — atomic commits, state tracking, progress monitoring
- **Context resilience** — pause/resume work across sessions with full context restoration
- **Verification** — goal-backward analysis ensures you built what was planned
- **Debugging** — scientific method debugging with persistent state across resets
- **Integration checking** — cross-phase integration and E2E flow verification
- **Roadmapping** — milestone/phase breakdown with dependency analysis

### BMAD Excels At (The Architect)
- **Product planning** — PRDs, product briefs, market research, domain research (BMM)
- **Architecture design** — solution design, implementation readiness checks (BMM)
- **UX design** — UX specifications, design patterns (BMM)
- **Game preproduction** — game briefs, brainstorming, GDDs, narrative design (GDS)
- **Technical game architecture** — engine-specific knowledge: Unity/Unreal/Godot/Phaser (GDS)
- **Creative innovation** — design thinking, problem solving, storytelling, presentations (CIS)
- **Test engineering** — ATDD, test framework setup, NFR testing, test traceability (TEA)
- **Sprint management** — sprint planning, status, retrospectives, course correction
- **Agent personas** — dedicated roles with contextual menus and communication styles

---

## Can BMAD Run in Claude Code Alongside GSD?

**YES — zero conflicts confirmed.**

### Conflict Analysis

| Check | Result |
|-------|--------|
| **Command namespace** | GSD: `gsd:*` (32 cmds) / BMAD: `bmad-*` (108 cmds) — no collisions |
| **Agent files** | GSD: `~/.claude/agents/gsd-*.md` / BMAD: none in agents/ (uses commands) |
| **Settings** | BMAD does NOT modify `~/.claude/settings.json` — GSD owns it |
| **Hooks** | BMAD creates no hooks — GSD's hooks remain untouched |
| **File locations** | GSD: global `~/.claude/` / BMAD: project-local `.claude/commands/` + `_bmad/` |
| **Total commands** | 140 combined (32 + 108) — manageable, clearly separated by prefix |
| **Global pollution** | BMAD installs NOTHING globally — fully project-scoped |

### How It Works in Claude Code

When you run `npx bmad-method install` in a project:
- Creates `_bmad/` with all modules, workflows, agents, templates
- Creates `.claude/commands/bmad-*.md` (108 project-local commands)
- These appear as `/bmad-*` slash commands only in that project
- GSD's `/gsd:*` commands remain available globally
- Both command sets show in the palette — clearly separated by prefix

---

## Unified Workflow: BMAD as Architect + GSD as Builder

### The Core Principle

```
BMAD = WHAT to build (design, architecture, knowledge, planning)
GSD  = HOW to build (execution, tracking, verification, shipping)
```

### Key Separation Rules

| Domain | Owner | Rule |
|--------|-------|------|
| Design docs (`docs/`, `_bmad-output/`) | BMAD | BMAD creates and maintains all design artifacts |
| Git history | GSD | GSD owns commits, branches, milestone tracking |
| `.planning/` | GSD | GSD's execution plans, state, verification |
| `_bmad/` | BMAD | BMAD's workflows, agents, templates |
| Mid-stream pivots | BMAD first | Return to BMAD to re-architect, then GSD re-plans |

### Decision Matrix

| Task | Use GSD | Use BMAD | Why |
|------|---------|----------|-----|
| **"I have a product idea"** | | `/bmad-bmm-create-product-brief` | BMM product brief workflow |
| **"Create requirements"** | | `/bmad-bmm-create-prd` | BMM PRD creation with validation |
| **"Design the UX"** | | `/bmad-bmm-create-ux-design` | BMM UX specification workflow |
| **"Plan the architecture"** | | `/bmad-bmm-create-architecture` | BMM solution design |
| **"I have a game idea"** | | `/bmad-gds-create-game-brief` | GDS game vision template |
| **"Design the gameplay"** | | `/bmad-gds-create-gdd` | GDS genre-specific GDD templates |
| **"Write the story"** | | `/bmad-gds-narrative` | GDS narrative design workflow |
| **"Game architecture"** | | `/bmad-gds-game-architecture` | Engine-specific tech knowledge |
| **"Research the domain"** | | `/bmad-bmm-domain-research` | BMM domain research workflow |
| **"Market analysis"** | | `/bmad-bmm-market-research` | BMM market research workflow |
| **"Brainstorm ideas"** | | `/bmad-brainstorming` | Core brainstorming workflow |
| **"Design thinking"** | | `/bmad-cis-design-thinking` | CIS design thinking coach |
| **"Set up tests"** | | `/bmad-tea-testarch-framework` | TEA test framework setup |
| **"Break into milestones"** | `/gsd:new-project` | | GSD's roadmapper + phase system |
| **"Plan this phase"** | `/gsd:plan-phase` | | Executable plans with dependency analysis |
| **"Code this feature"** | `/gsd:execute-phase` | | Atomic commits, state tracking |
| **"Debug this bug"** | `/gsd:debug` | | Scientific debugging with checkpoints |
| **"Verify it works"** | `/gsd:verify-work` | | Goal-backward UAT validation |
| **"Quick task"** | `/gsd:quick` | | GSD guarantees without full ceremony |
| **"Prototype fast"** | | `/bmad-gds-quick-dev` | GDS quick flow dev |
| **"Sprint planning"** | Either | Either | GSD: `/gsd:progress` / BMAD: `/bmad-bmm-sprint-planning` |
| **"Code review"** | Either | Either | GSD: general / BMAD: adversarial |
| **"Resume tomorrow"** | `/gsd:pause-work` | | GSD context persistence |
| **"Ship a release"** | `/gsd:complete-milestone` | | GSD milestone archival |

---

## Complementary Workflow (Full Project Lifecycle)

```
PROJECT LIFECYCLE — BMAD + GSD
================================

PHASE 1: Discovery & Design (BMAD — Pi or Claude Code)
├── /bmad-bmm-create-product-brief  → Define product vision
├── /bmad-bmm-domain-research       → Research the domain
├── /bmad-bmm-market-research       → Analyze competition
├── /bmad-bmm-create-prd            → Product Requirements Document
├── /bmad-bmm-create-ux-design      → UX specifications
├── /bmad-bmm-create-architecture   → Solution design
├── /bmad-bmm-create-epics-and-stories → Break into epics
└── /bmad-bmm-check-implementation-readiness → Validate completeness
    Output: _bmad-output/planning-artifacts/

PHASE 1b: Game-Specific Design (BMAD GDS — if game project)
├── /bmad-gds-create-game-brief     → Game vision
├── /bmad-gds-brainstorm-game       → Mechanic ideation
├── /bmad-gds-create-gdd            → Game Design Document
├── /bmad-gds-narrative             → Story & world design
└── /bmad-gds-game-architecture     → Engine-specific architecture
    Output: _bmad-output/planning-artifacts/

PHASE 2: Planning & Roadmap (GSD — Claude Code)
├── /gsd:new-project    → Initialize with BMAD's output as context
├── /gsd:plan-phase     → Break architecture into executable phases
└── /gsd:discuss-phase  → Refine each phase before planning
    Input:  _bmad-output/ (reads BMAD's design docs)
    Output: .planning/ (GSD's phase plans)

PHASE 3: Implementation (GSD — Claude Code)
├── /gsd:execute-phase  → Code with atomic commits
├── /gsd:verify-work    → UAT validation
├── /gsd:debug          → Scientific debugging
└── /gsd:quick          → Small tasks with GSD guarantees
    Output: Working code with tracked commits

PHASE 4: QA & Testing (BMAD TEA + GDS — Pi or Claude Code)
├── /bmad-tea-testarch-framework    → Set up test framework
├── /bmad-tea-testarch-test-design  → Design test scenarios
├── /bmad-tea-testarch-automate     → Automate tests
├── /bmad-tea-testarch-nfr          → Non-functional requirements
├── /bmad-gds-gametest-playtest-plan → Playtest plans (games)
├── /bmad-gds-gametest-test-review  → Review test coverage (games)
└── /bmad-gds-gametest-performance  → Performance profiling (games)
    Output: _bmad-output/implementation-artifacts/

PHASE 5: Sprint Ops (Either tool)
├── BMAD: /bmad-bmm-sprint-planning, /bmad-bmm-sprint-status, /bmad-bmm-retrospective
├── GSD:  /gsd:progress, /gsd:check-todos, /gsd:pause-work
└── Pivot: /bmad-bmm-correct-course (return to BMAD to re-architect)
```

### Handoff Between Systems

The key integration point is `_bmad-output/`:
1. BMAD writes design docs (PRDs, architecture, briefs) to `_bmad-output/planning-artifacts/`
2. GSD reads them as project context when initializing with `/gsd:new-project`
3. GSD creates its own `.planning/` directory for execution tracking
4. Both systems stay in their lane — no cross-referencing of internal state

### Pivot Rule

When requirements change mid-implementation:
1. Pause GSD: `/gsd:pause-work`
2. Return to BMAD: update PRD/architecture via `/bmad-bmm-edit-prd` or `/bmad-bmm-correct-course`
3. Resume GSD: `/gsd:resume-work` — GSD reads updated BMAD artifacts

---

## Cross-Tool Setup

### Tool Availability Matrix

| Command Set | Claude Code | OpenCode | Pi |
|-------------|-------------|----------|-----|
| **GSD commands** (32) | Native (global) | Via `.claude/commands/` fallback | Reference prompts (4) |
| **BMAD commands** (108) | Native (project-local) | Via `.claude/commands/` fallback | Full prompts (109) |
| **Combined** | 140 commands | 140 commands | 113 prompts |

### Pi Prompt Inventory

| Category | Count | Prefix |
|----------|-------|--------|
| BMAD Core | 8 | `bmad-` |
| BMAD BMM agents | 10 | `bmad-agent-bmm-` |
| BMAD BMM workflows | 22 | `bmad-bmm-` |
| BMAD GDS agents | 7 | `bmad-agent-gds-` |
| BMAD GDS workflows | 25 | `bmad-gds-` |
| BMAD BMB | 13 | `bmad-bmb-` / `bmad-agent-bmb-` |
| BMAD CIS | 10 | `bmad-cis-` / `bmad-agent-cis-` |
| BMAD TEA | 10 | `bmad-tea-` / `bmad-agent-tea-` |
| Custom | 1 | `bmad-quick-prototype` |
| GSD Reference | 4 | `gsd-` |
| **Total** | **113** | |

---

## Update Strategy

### BMAD Updates
```bash
# Check current version
npx bmad-method status

# Quick update (preserves configs, refreshes workflows)
npx bmad-method install --action quick-update

# Full update (change modules, IDEs)
npx bmad-method install --action update

# Force latest version
npm cache clean --force && npx bmad-method@latest install
```

### GSD Updates
```bash
/gsd:update
```

### Pi Sync (automatic)

Pi prompts auto-sync via PostToolUse hook when GSD or BMAD update commands run in Claude Code.

```bash
# Manual run (or preview)
~/Developer/sync-pi-prompts.sh
~/Developer/sync-pi-prompts.sh --dry-run
```

| What | How | Auto? |
|------|-----|-------|
| BMAD → Claude Code | `npx bmad-method install` | Native |
| BMAD → OpenCode | `npx bmad-method install` | Native |
| GSD → Claude Code | `/gsd:update` | Native |
| GSD → OpenCode | `/gsd:update` | Native |
| BMAD → Pi prompts | `sync-pi-prompts.sh` | Hook (`sync-pi-after-update.sh`) |
| GSD → Pi prompts | Hand-written (4 files) | Only on major structural changes |

Hook: `~/.claude/hooks/sync-pi-after-update.sh` — triggers on Bash commands matching `gsd:update` or `bmad-method install`

---

## Installation Summary

| Component | Location | Tool | Scope |
|-----------|----------|------|-------|
| GSD agents | `~/.claude/agents/gsd-*.md` | Claude Code | Global |
| GSD commands | `~/.claude/commands/gsd/` | Claude Code | Global |
| GSD workflows | `~/.claude/get-shit-done/` | Claude Code | Global |
| BMAD project files | `<project>/_bmad/` | All tools | Project |
| BMAD Claude commands | `<project>/.claude/commands/bmad-*.md` | Claude Code / OpenCode | Project |
| BMAD Pi prompts | `~/.pi/agent/prompts/bmad-*.md` | Pi | Global |
| GSD Pi reference | `~/.pi/agent/prompts/gsd-*.md` | Pi | Global |
| BMAD outputs | `<project>/_bmad-output/` | All tools (read) | Project |
| BMAD cache | `~/.bmad/cache/` | Installer | Global |
