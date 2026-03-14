# Keystone

Stop losing context between planning and building.

---

## The Problem

Claude Code sessions are stateless. You close a tab, and your next session starts from zero. [BMAD](https://github.com/bmad-code-org/BMAD-METHOD) plans well -- it produces PRDs, architecture docs, and user stories. [GSD](https://github.com/gsd-build/get-shit-done) builds well -- it executes tasks in fresh context windows with atomic commits and quality gates. But neither talks to the other. Decisions made during planning don't survive into execution. Architecture drift goes unnoticed. And when a phase finishes, nobody updates the plan.

Keystone fixes the gap.

## What Keystone Does

Keystone is a set of agents, hooks, and scripts for Claude Code that wire BMAD and GSD into one workflow:

- A **wizard** detects your project state (BMAD? GSD? both? neither?) and tells you exactly what to run next
- **Bridge agents** translate BMAD planning documents into GSD execution context, catch architectural drift mid-build, and sync completion status back to BMAD stories
- **Hooks** run automatically -- checking for hardcoded secrets after every file write, showing project state at session start, and surfacing upstream updates
- **Domain agents** add specialised knowledge for IT infrastructure, Godot game dev, open source projects, and administrative documentation

You don't have to use both frameworks. Keystone works with BMAD only, GSD only, or both together.

## Quick Start

**1. Clone:**

```bash
git clone https://github.com/flongstaff/keystone
cd keystone
```

**2. Install for Claude Code:**

```bash
bash scripts/install-runtime-support.sh --claude
```

This installs BMAD + GSD, deploys core agents and hooks to `~/.claude/`, and sets up a weekly version check.

To also install optional domain agents (Godot, open-source, admin-docs):

```bash
bash scripts/install-runtime-support.sh --claude --with-domains
```

**3. Restart Claude Code.**

**4. Open any project and say:**

```
set up this project
```

The wizard takes it from there.

## What's Inside

### Agents

**Core** (installed by default):

| Category | Agent | What it does |
|----------|-------|-------------|
| Entry | `project-setup-wizard` | Interactive project state detection and workflow delivery |
| Bridge | `bmad-gsd-orchestrator` | Translates BMAD docs into GSD `.planning/` structure |
| Bridge | `context-health-monitor` | Detects architectural drift after phase execution |
| Bridge | `doc-shard-bridge` | Splits large docs into per-phase context shards |
| Bridge | `phase-gate-validator` | Formal quality gate between GSD phases |
| Domain | `it-infra-agent` | IT infrastructure with dry-run, rollback, secret hygiene |
| Maintenance | `stack-update-watcher` | Monitors BMAD/GSD for upstream changes |

**Optional** (install with `--with-domains`):

| Agent | What it does |
|-------|-------------|
| `project-setup-advisor` | Lighter alternative to wizard -- direct recommendation, no menus |
| `godot-dev-agent` | Godot 4 / GDScript conventions and patterns |
| `open-source-agent` | OSS project management, dependency upgrades, releases |
| `admin-docs-agent` | Policy documents, runbooks, internal communications |

### Hooks

| Hook | Event | What it does |
|------|-------|-------------|
| `session-start.sh` | SessionStart | Shows project state banner with BMAD/GSD status |
| `stack-update-banner.sh` | SessionStart | One-line update notice from cached version data |
| `post-write-check.sh` | PostToolUse (Write) | Checks for secrets, missing error handling, Godot anti-patterns |

### Scripts

| Script | What it does |
|--------|-------------|
| `install-runtime-support.sh` | One-command install for Claude Code, OpenCode, or Pi |
| `restore.sh` | Restore agent/hook configs from backup (`--dry-run` supported) |
| `weekly-stack-check.sh` | Cron target that refreshes the version cache |

### Skills

| Skill | What it does |
|-------|-------------|
| `wizard.md` | Smart router that detects project state and delivers workflows |
| `wizard-backing-agent.md` | Backing agent for bridge-to-GSD routes |
| `wizard-detect.sh` | Project state detection logic |
| `toolkit-discovery.sh` | Scans installed agents, skills, hooks, and MCP servers |

## How It Works

```
┌─────────────────────────────────────────────────────┐
│  ENTRY: wizard detects state, routes to workflow    │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│  PLANNING (BMAD): PRD → Architecture → Stories      │
└──────────────────────┬──────────────────────────────┘
                       │
         ┌─────────────▼─────────────┐
         │  bmad-gsd-orchestrator    │  translates plans
         └─────────────┬─────────────┘  into .planning/
                       │
┌──────────────────────▼──────────────────────────────┐
│  EXECUTION (GSD): discuss → plan → execute → verify │
│    context-health-monitor watches for drift         │
└──────────────────────┬──────────────────────────────┘
                       │
         ┌─────────────▼─────────────┐
         │  phase-gate-validator     │  blocks bad advances
         └─────────────┬─────────────┘
                       │
         ┌─────────────▼─────────────┐
         │  doc-shard-bridge         │  syncs back to BMAD
         └───────────────────────────┘
```

BMAD handles the "what" -- turning ideas into structured plans. GSD handles the "how" -- executing each task in a fresh context with atomic commits. Keystone's bridge agents sit between them, translating documents, catching drift, and keeping both sides in sync. The wizard figures out where you are and tells you what to do next.

## Docs

- **[Architecture](docs/architecture.md)** -- how the pieces fit together, agent types, the integration problem
- **[Agents](docs/agents.md)** -- detailed reference for all 11 agents with trigger phrases
- **[Hooks & Scripts](docs/hooks-and-scripts.md)** -- hook lifecycle, script usage, settings.json templates
- **[Workflows](docs/workflows.md)** -- end-to-end workflows for all four project scenarios
- **[GSD vs BMAD](docs/gsd-vs-bmad.md)** -- comparison, coexistence, decision matrix
- **[Orchestration](docs/orchestration.md)** -- cross-runtime workflows for Claude Code, OpenCode, and Pi
- **[Troubleshooting](docs/troubleshooting.md)** -- common issues and fixes

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, how agents and hooks work, and how to add your own.

## License

[MIT](LICENSE) -- Copyright (c) 2026 flongstaff
