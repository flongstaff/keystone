# Wizard Orchestrator

## What This Is

A unified wizard system for the Claude Code Stack that makes BMAD planning and GSD execution feel like one continuous workflow. Instead of manually running separate commands and bridging frameworks, users interact with a single guided wizard that detects project state, preserves context between stages, and drives from idea to working code with minimal typing.

## Core Value

At any point in a project, one command (`/wizard`) tells the user exactly where they are and does the next right thing — whether that's starting BMAD planning, bridging to GSD, or continuing execution.

## Requirements

### Validated

- ✓ BMAD planning framework installed and functional — existing
- ✓ GSD execution framework installed and functional — existing
- ✓ Bridge agents connect BMAD output to GSD input — existing
- ✓ Entry agents detect project state (BMAD/GSD presence) — existing
- ✓ Session hooks show project status on startup — existing
- ✓ Phase gate validation between GSD phases — existing
- ✓ Context sharding for large BMAD documents — existing

### Active

- [ ] Smart router skill that detects project state and routes to the right action
- [ ] Guided wizard skill with step-by-step choices and smart defaults
- [ ] Backing agent for heavy orchestration work behind the scenes
- [ ] Requirement traceability from BMAD docs through GSD phases (no lost requirements)
- [ ] Context-efficient orchestration (minimize tokens spent on plumbing, maximize for actual work)
- [ ] Flexible entry — start fresh, resume mid-BMAD, bridge to GSD, or continue GSD phases
- [ ] Full lifecycle support — idea → BMAD planning → bridge → GSD execution → completion
- [ ] State persistence across context resets (wizard always knows where you are)

### Out of Scope

- Replacing existing BMAD or GSD agents — wizard wraps them, doesn't replace
- Changing BMAD or GSD internals — work with their existing APIs and outputs
- Domain-specific logic (infra, game dev, etc.) — domain agents handle that separately
- Multi-project orchestration — one project at a time

## Context

This is a brownfield project. The Claude Code Stack already has 11 agents across 4 categories (entry, bridge, domain, maintenance), lifecycle hooks, and install/restore scripts. BMAD and GSD are installed via npm and work independently.

**Current pain points the wizard solves:**
- Requirements get lost between BMAD planning output and GSD phase execution
- Too much context window is spent on orchestration overhead (typing commands, reading agent instructions) instead of actual implementation work
- Users don't know which command to run next — multiple slash commands across two frameworks
- Manual bridging steps between BMAD completion and GSD initialization

**Existing infrastructure to wrap:**
- `agents/bridge/bmad-gsd-orchestrator.md` — translates BMAD docs to GSD structure
- `agents/bridge/doc-shard-bridge.md` — splits docs into phase-sized contexts
- `agents/bridge/phase-gate-validator.md` — validates phase completion
- `agents/bridge/context-health-monitor.md` — detects architectural drift
- `agents/entry/project-setup-wizard.md` — detects project state
- `agents/entry/project-setup-advisor.md` — recommends next action

**Technical form:** Three components working together:
1. **Smart router skill** — detects state, delegates to right BMAD/GSD command
2. **Wizard skill** — guided UI for the full pipeline
3. **Backing agent** — handles orchestration heavy lifting

## Constraints

- **Architecture**: Must wrap existing agents, not replace them — preserves modularity
- **Context budget**: Wizard overhead must be < 10% of context window — the whole point is less overhead
- **Compatibility**: Must work with current BMAD (`bmad-method`) and GSD (`get-shit-done-cc`) npm packages
- **Runtime**: Claude Code primary target (skills + agents system)
- **File conventions**: Skills as `.md` in skills directory, agents as `.md` with YAML frontmatter in `agents/`

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Wrap existing agents, don't replace | Preserves modularity, avoids rewriting working code | — Pending |
| Three-component architecture (router + wizard + agent) | Router handles detection, wizard handles UI, agent handles work — clean separation | — Pending |
| Single `/wizard` entry point | Reduces cognitive load — one command to remember | — Pending |
| State persisted to `.planning/` | Survives context resets, consistent with GSD conventions | — Pending |

---
*Last updated: 2026-03-11 after initialization*
