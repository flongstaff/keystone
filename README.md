# Claude Code Stack

A curated set of custom agents, hooks, and scripts for [Claude Code](https://claude.ai/claude-code) that integrate the [BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD) and [GSD (Get Shit Done)](https://github.com/gsd-build/get-shit-done) frameworks into a cohesive, opinionated development workflow.

BMAD handles structured planning — turning vague ideas into PRDs, architecture documents, and user stories. GSD handles reliable execution — running each implementation task in a fresh context window with atomic git commits and formal quality gates. This stack wires the two frameworks together and adds domain-specific agents for infrastructure, game development, open source, and documentation work.

---

## Directory Structure

```
claude-code-stack/
├── agents/
│   ├── entry/
│   │   ├── project-setup-advisor.md    # Framework detection + workflow output
│   │   └── project-setup-wizard.md     # Interactive setup with state display
│   ├── bridge/
│   │   ├── bmad-gsd-orchestrator.md    # BMAD → GSD handoff + story sync
│   │   ├── context-health-monitor.md   # Drift detection between plan and build
│   │   ├── doc-shard-bridge.md         # Per-phase context file generation
│   │   └── phase-gate-validator.md     # Formal quality gate between phases
│   ├── domain/
│   │   ├── admin-docs-agent.md         # IT policy, runbooks, communications
│   │   ├── godot-dev-agent.md          # Godot 4 / GDScript specialist
│   │   ├── it-infra-agent.md           # Infrastructure scripts and automation
│   │   └── open-source-agent.md        # OSS project management and web apps
│   └── maintenance/
│       └── stack-update-watcher.md     # BMAD + GSD version tracking
├── hooks/
│   ├── post-write-check.sh             # Safety checks after every file write
│   ├── session-start.sh                # Project state banner at session open
│   └── stack-update-banner.sh          # Update notification from cache
├── scripts/
│   ├── install-runtime-support.sh      # One-command install across all runtimes
│   ├── restore.sh                      # Restore configurations from backup
│   └── weekly-stack-check.sh           # Version cache refresh (cron target)
└── docs/
    └── workflows.md                    # Detailed workflow documentation
```

---

## Agents

### Entry Agents

These are the front door. Every project session starts here.

| Agent | Description |
|---|---|
| **project-setup-wizard** | Interactive setup agent. Detects whether BMAD, GSD, both, or neither is installed in the current project. Presents a state dashboard and numbered menu, then delivers the complete workflow — install commands, phase loop, and the exact next command to run. Say `wizard`, `set up this project`, or `where do I start`. |
| **project-setup-advisor** | Lighter alternative. Scans the project silently and outputs the correct workflow for the detected scenario (new project, GSD only, BMAD only, neither, or both). Best when you want a direct recommendation rather than interactive choice. Say `start a project`, `project setup`, or `which framework should I use`. |

### Bridge Agents

Bridge agents connect BMAD and GSD, and enforce quality gates between phases.

| Agent | Description |
|---|---|
| **bmad-gsd-orchestrator** | Translates completed BMAD planning documents into the GSD `.planning/` structure. Creates `config.json`, `CONTEXT.md`, and per-phase context files. Also handles the return path: after a phase completes, it updates BMAD story status files. Say `initialise GSD from BMAD docs` or `bridge docs`. |
| **context-health-monitor** | Checks five dimensions of drift after `execute-phase`: directory structure, naming conventions, tech stack, acceptance criteria coverage, and cross-phase interface readiness. Advisory — it flags issues and provides `/gsd:quick` fix commands, but does not block execution. Say `health check`, `check drift`, or `are we on track`. |
| **doc-shard-bridge** | Splits large BMAD planning documents into per-phase context shards under 800 lines (~30% of a 200k context window). Each shard contains only what a phase's subagents need to see. Also syncs completed phase results back to BMAD story files. Say `shard documents` or `create phase context`. |
| **phase-gate-validator** | Formal quality gate that must pass before any phase advance. Checks five gates: acceptance criteria coverage, git hygiene, architectural drift, dependency readiness for the next phase, and (for infra projects) safety checks for dry-run flags and credential hygiene. Say `validate phase`, `is phase N done`, or `gate check`. |

### Domain Agents

Domain agents activate based on the type of work being done.

| Agent | Description |
|---|---|
| **it-infra-agent** | Writes production-quality infrastructure scripts with non-negotiable safety patterns: `--dry-run` / `-WhatIf` flags on every change script, rollback documentation, structured logging, secret hygiene (no hardcoded credentials), idempotent operations, and strict error handling. Covers PowerShell and Bash. Activates on infrastructure trigger phrases such as `deploy`, `PowerShell`, `Ansible`, `Active Directory`, `Intune`, or `onboarding`. |
| **godot-dev-agent** | Godot 4.x GDScript specialist. Enforces scene organisation conventions, the signal-over-direct-calls pattern, state machine structures, and Godot 4 syntax (`await` not `yield`). Integrates with GSD by mapping each phase to a game system. Activates on `Godot`, `GDScript`, `scene`, `signal`, or related phrases. |
| **open-source-agent** | Handles open source project management and web application development. Covers Dependabot PR triage, major dependency upgrade protocols, ESLint flat config migration, release workflows with conventional commits, and GitHub Actions CI templates. Activates on `open source`, `Dependabot`, `release`, `semver`, `Next.js`, or `GitHub Actions`. |
| **admin-docs-agent** | Produces administrative documentation for IT environments. Provides structured templates for communications (effective date, audience, impact, actions), policy documents (with policy ID, version, scope, revision history), and runbooks (prerequisites, step-by-step with expected results, rollback, escalation). Adapts language to technical, semi-technical, or non-technical audiences. Activates on `policy`, `runbook`, `SOP`, `communication`, or `admin`. |

### Maintenance Agent

| Agent | Description |
|---|---|
| **stack-update-watcher** | Monitors BMAD and GSD for new releases, fetches changelogs, classifies changes by impact (required/recommended/monitor), cross-references changes against all 11 installed agents, and produces a concrete update action plan with exact fix commands. Never auto-applies changes. Say `check for updates`, `is my stack up to date`, or `maintenance`. |

---

## Hooks

Hooks run automatically within Claude Code at defined lifecycle events.

| Hook | Event | Description |
|---|---|---|
| **session-start.sh** | `SessionStart` | Displays a project state banner showing BMAD presence, GSD active phase, and the next recommended command. Logs session context to `~/.claude/logs/`. Shows a warning if no `CLAUDE.md` or `AGENTS.md` is found. Shows an infra safety reminder for infrastructure projects. |
| **stack-update-banner.sh** | `SessionStart` | Reads `~/.claude/stack-update-cache.json` and displays a one-line update notice if BMAD or GSD has a newer version available. Triggers a background async refresh if the cache is older than 7 days. Non-blocking — reads cache only, never makes network calls inline. |
| **post-write-check.sh** | `PostToolUse` (Write) | Runs after every file write. Checks for hardcoded secrets, missing `set -euo pipefail` in shell scripts, missing dry-run flags in scripts with destructive commands, missing PowerShell error handling, hardcoded Windows user paths, and Godot 3 syntax in GDScript files. Outputs warnings and errors to stderr. Never blocks execution. |

---

## Scripts

| Script | Description |
|---|---|
| **install-runtime-support.sh** | One-command installer for Claude Code, OpenCode, and Pi. Installs BMAD via `npx bmad-method install`, installs GSD for each selected runtime, deploys all agents to runtime agent directories, deploys and registers hooks in `settings.json`, and sets up the weekly cron job. Accepts `--claude`, `--opencode`, `--pi`, or `--all`. |
| **restore.sh** | Restores agent configurations, hooks, and settings from a backup directory to the target runtime(s). Supports `--dry-run` to preview changes before applying. Accepts `--target claude|pi|opencode|all`. This script is its own rollback: re-run it to restore again after any accidental change. |
| **weekly-stack-check.sh** | Fetches current npm versions for BMAD, GSD, and Pi, compares against installed versions, and writes the result to `~/.claude/stack-update-cache.json`. Designed to run as a cron job (Monday 09:00). Does not apply any changes. Run manually with `bash weekly-stack-check.sh`. |

---

## Quick Start

### Prerequisites

Before installing this stack, you need:

- **Claude Code** — `npm install -g @anthropic-ai/claude-code`
- **Node.js** with npx (for BMAD and GSD installers)
- **BMAD Method** — installed during stack install, or manually with `npx bmad-method install`
- **GSD** — installed during stack install, or manually with `npx get-shit-done-cc --claude --global`
- **Pi** (optional) — `npm install -g @mariozechner/pi-coding-agent`
- **OpenCode** (optional) — `npm install -g opencode-ai`

### Installation

**1. Clone this repository:**

```bash
git clone https://github.com/flongstaff/claude-code-stack claude-code-stack
cd claude-code-stack
```

**2. Run the installer for your runtime(s):**

```bash
# Claude Code only (most common)
bash scripts/install-runtime-support.sh --claude

# All runtimes
bash scripts/install-runtime-support.sh --all

# Specific combination
bash scripts/install-runtime-support.sh --claude --pi
```

The installer will:
- Install BMAD and GSD
- Copy all 11 agents to `~/.claude/agents/`
- Deploy and register hooks in `~/.claude/hooks/`
- Patch `~/.claude/settings.json` with hook registrations
- Set up the weekly version check cron job

**3. Restart Claude Code.**

**4. Open any project directory and say:**

```
set up this project
```

The `project-setup-wizard` will detect your project's state and provide the exact workflow to follow.

---

## Configuration

### settings.json

The installer patches `~/.claude/settings.json` to register hooks. The resulting hooks section looks like this:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "bash $HOME/.claude/hooks/stack-update-banner.sh"
      },
      {
        "type": "command",
        "command": "bash $HOME/.claude/hooks/session-start.sh"
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash $HOME/.claude/hooks/post-write-check.sh"
          }
        ]
      }
    ]
  }
}
```

If you manage `settings.json` manually, add these entries to your existing hooks configuration.

### Per-Project CLAUDE.md

Each project should have a `.claude/CLAUDE.md` (or root-level `CLAUDE.md`) that describes the project type and any project-specific rules. The `session-start.sh` hook reads this file to detect project type and show appropriate reminders.

Recommended minimum for any project:

```markdown
# Project: [Name]

## Type
[web / infra / game / docs / other]

## Stack
[language, framework, key libraries]

## Key Conventions
[naming, structure, any rules the team follows]
```

For infra projects specifically, add:

```markdown
## Environment
[environment names, target systems, tool versions]

## Approval Process
[who must approve before deploying to production]
```

See [docs/workflows.md](docs/workflows.md) for per-project CLAUDE.md patterns for each project type.

---

## Three-Tier Update System

The stack uses three tiers to keep BMAD and GSD version information available without slowing down Claude Code sessions:

**Tier 1 — Cached banner** (`stack-update-banner.sh`): Runs at every session start. Reads `~/.claude/stack-update-cache.json` synchronously. If an update is available or required agent fixes are pending, displays a notice. If the cache is older than 7 days, triggers a background async refresh. Zero latency — never makes network calls inline.

**Tier 2 — Weekly cron** (`weekly-stack-check.sh`): Runs automatically every Monday at 09:00 (installed by the setup script). Fetches current npm versions for BMAD, GSD, and Pi, compares against installed versions, and writes the result to the cache file. Does not apply changes.

**Tier 3 — On-demand analysis** (`stack-update-watcher` agent): Run when the banner indicates an update is available, or on a schedule. Fetches full changelogs, classifies every change by impact level, cross-references changes against all 11 agent files (checking command names, file paths, config fields, and model IDs), and produces a prioritised action plan with exact fix commands. Always presents commands for review — never auto-applies.

The cache file at `~/.claude/stack-update-cache.json` contains installed versions, latest versions, and a count of required agent fixes pending from the last watcher run.

---

## Runtime Support

| Runtime | Support Level | Notes |
|---|---|---|
| **Claude Code** | Primary | Full support: agents, hooks, scripts, settings.json integration |
| **Pi** | Secondary | Agents deployed to `~/.pi/agent/` with frontmatter stripped. GSD does not have a native Pi installer; the stack installs a Claude Code base and creates Pi-compatible wrappers. |
| **OpenCode** | Secondary | Agents deployed to the OpenCode agent directory. Hook registration is Claude Code-specific; OpenCode users configure hooks separately per OpenCode documentation. |

---

## License

MIT
