# Keystone — Wizard Orchestrator

## What This Is

A unified wizard system for Keystone that makes BMAD planning and GSD execution feel like one continuous workflow. Instead of manually running separate commands and bridging frameworks, users interact with a single guided wizard that detects project state, preserves context between stages, and drives from idea to working code with minimal typing.

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
- ✓ Smart router skill that detects project state and routes to the right action — v1.0
- ✓ Guided wizard skill with step-by-step choices and smart defaults — v1.0
- ✓ Backing agent for heavy orchestration work behind the scenes — v1.0
- ✓ Requirement traceability from BMAD docs through GSD phases — v1.0
- ✓ Context-efficient orchestration (< 10% context budget) — v1.0
- ✓ Flexible entry — start fresh, resume mid-BMAD, bridge to GSD, or continue GSD phases — v1.0
- ✓ Full lifecycle support — idea → BMAD planning → bridge → GSD execution → completion — v1.0
- ✓ State persistence across context resets — v1.0

### Active

- [ ] Dynamic discovery of all user-installed agents, skills, tools, hooks, and MCP servers
- [ ] Capability matching — map discovered tools to workflow stages (research, planning, execution, review)
- [ ] Subagent context injection — GSD/BMAD subagents receive relevant tool references in their prompts
- [ ] MCP-aware recommendations — surface configured MCP servers at appropriate workflow moments
- [ ] User confirmation flow — ask before using discovered tools when intent is ambiguous
- [ ] Token-efficient injection — lightweight capability pointers, not full agent prompts in context

### Out of Scope

- Replacing existing BMAD or GSD agents — wizard wraps them, doesn't replace
- Changing BMAD or GSD internals — work with their existing APIs and outputs
- Domain-specific logic (infra, game dev, etc.) — domain agents handle that separately
- Multi-project orchestration — one project at a time

## Current Milestone: v1.1 Dynamic Toolkit Discovery

**Goal:** Make the wizard and all subagents aware of the user's full toolkit — agents, skills, tools, hooks, and MCP servers — so every workflow stage leverages the best available capabilities with user confirmation when ambiguous.

**Target features:**
- Dynamic scanning of user's installed agents, skills, hooks, and MCP servers
- Capability-to-stage matching (which tools help at which workflow moments)
- Subagent prompt injection (GSD researchers/planners/executors told about relevant tools)
- MCP server awareness and recommendations
- Confirmation UX when tool usage isn't clear-cut
- Token-efficient injection (pointers, not full prompts)

## Context

This is a brownfield project. Keystone already has 11 agents across 4 categories (entry, bridge, domain, maintenance), lifecycle hooks, and install/restore scripts. BMAD and GSD are installed via npm and work independently.

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
*Last updated: 2026-03-13 after v1.1 milestone start*
