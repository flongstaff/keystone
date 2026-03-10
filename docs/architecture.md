# Architecture

How the pieces fit together, why they exist, and what problems they solve.

## The Integration Problem

BMAD and GSD are independent systems that don't talk to each other:

```
BMAD produces:              GSD expects:
docs/prd-*.md        ----?  .planning/ folder
docs/architecture-*  ----?  .planning/config.json
bmad-outputs/        ----?  Context in each fresh subagent
```

Without bridge agents, you hit these problems:

- GSD spawns a fresh executor that knows nothing about your BMAD PRD
- BMAD creates story files that GSD ignores
- Context rot causes GSD executors to drift from the BMAD architecture
- No agent checks whether GSD output matches the BMAD plan
- After a GSD phase finishes, BMAD doesn't know the status changed

Keystone's bridge agents fix each of these.

## Agent Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  ENTRY LAYER                                                │
│  project-setup-wizard / project-setup-advisor               │
│  Detects state, routes to workflow                          │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  PLANNING LAYER (BMAD)                                      │
│  Analyst -> PM -> Architect -> Stories                       │
│  Output: PRD, Architecture, Stories in docs/                │
└──────────────────────┬──────────────────────────────────────┘
                       │
         ┌─────────────▼─────────────┐
         │  bmad-gsd-orchestrator    │  Bridge 1
         │  Translates docs -> GSD   │
         └─────────────┬─────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  EXECUTION LAYER (GSD)                                      │
│  discuss -> plan -> execute -> verify                       │
│  context-health-monitor watches for drift (Bridge 2)        │
└──────────────────────┬──────────────────────────────────────┘
                       │
         ┌─────────────▼─────────────┐
         │  phase-gate-validator     │  Bridge 3
         │  Blocks bad advances      │
         └─────────────┬─────────────┘
                       │
         ┌─────────────▼─────────────┐
         │  doc-shard-bridge         │  Bridge 4
         │  Syncs state back         │
         └───────────────────────────┘
```

## Agent Types

Claude Code supports three kinds of agents, and Keystone uses all three:

| Type | Location | Triggered by | Best for |
|------|----------|-------------|----------|
| Claude Code subagent | `~/.claude/agents/*.md` | Auto-detection from `description` field, or `use agent:name` | Specialised execution |
| BMAD skill | `~/.claude/skills/bmad/custom/*/SKILL.md` | `/skill-name` or natural language | Strategic planning |
| GSD command | `~/.claude/commands/gsd/*.md` | `/gsd:command` | Execution + context management |

### Subagent Frontmatter

Every agent file starts with YAML frontmatter that tells Claude Code what the agent does and when to use it:

```yaml
---
name: agent-name
description: >
  What this agent does and WHEN to activate it.
  Be explicit -- Claude uses this to auto-route.
model: sonnet
tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
maxTurns: 20
---

System prompt goes here in Markdown...
```

The `description` field is critical. Claude reads it to decide whether to activate the agent for a given task. Vague descriptions lead to missed activations. Include explicit trigger phrases.

## Four Agent Categories

### Entry Agents

The front door. Every project session starts here. The wizard detects whether BMAD, GSD, both, or neither is installed, then delivers the right workflow with exact commands.

**Why two entry agents?** The wizard is interactive (menus, choices). The advisor is direct (one recommendation, no questions). Use the wizard when you want to explore options, the advisor when you already know the tooling.

### Bridge Agents

These sit between BMAD and GSD. They handle translation (docs to context), validation (drift detection, quality gates), and synchronisation (completion status back to BMAD).

**Why four bridge agents instead of one?** Each has a distinct trigger point in the workflow. The orchestrator runs once at handoff. The health monitor runs after every phase execution. The gate validator runs before every phase advance. The shard bridge runs at both handoff and completion. Combining them would create a monolithic agent that's hard to trigger correctly.

### Domain Agents

Project-type specialists. They activate automatically based on keywords in their `description` field. You don't call them directly -- Claude routes to them when it detects matching work.

Each domain agent brings its own non-negotiable patterns. The infra agent enforces dry-run flags and rollback scripts. The Godot agent enforces signal patterns and scene organisation. These patterns are baked into the agent's system prompt so they apply every time, without relying on the user to remember.

### Maintenance Agent

The stack-update-watcher monitors BMAD and GSD for upstream changes, classifies them by impact, and produces fix commands. It never auto-applies changes.

## Hooks and Scripts

Hooks fire automatically on Claude Code lifecycle events. Scripts are run manually or by cron.

The three hooks handle session startup (project state banner + update notice) and post-write safety checks (secrets, missing error handling, Godot anti-patterns). They warn but never block.

See [docs/hooks-and-scripts.md](hooks-and-scripts.md) for the full lifecycle and registration details.

## File Structure

```
keystone/
├── agents/
│   ├── entry/           # Wizard and advisor
│   ├── bridge/          # BMAD-GSD integration
│   ├── domain/          # IT infra, Godot, OSS, admin docs
│   └── maintenance/     # Stack update watcher
├── hooks/               # Session-start, post-write, update banner
├── scripts/             # Installer, restore, weekly cron
├── skills/              # Wizard router and detection logic
├── tests/               # Shell-based test suites
└── docs/                # This documentation
```

When installed, agents go to `~/.claude/agents/`, hooks to `~/.claude/hooks/`, and scripts to `~/.claude/scripts/`. The install script handles all of this.

## Per-Project Configuration

Each project should have a `.claude/CLAUDE.md` (or root-level `CLAUDE.md`) describing the project type and conventions. The session-start hook reads this to detect project type and show appropriate reminders.

See [docs/workflows.md](workflows.md) for CLAUDE.md templates by project type (web, infra, game, docs).
