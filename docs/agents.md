# Agents

Keystone ships 11 agents across four categories. Each agent is a Markdown file with YAML frontmatter that tells Claude Code when to activate it.

## Quick Reference

| Agent | Category | Trigger phrases |
|-------|----------|----------------|
| `project-setup-wizard` | Entry | "wizard", "set up this project", "where do I start", "resume" |
| `project-setup-advisor` | Entry | "start a project", "project setup", "which framework should I use" |
| `bmad-gsd-orchestrator` | Bridge | "initialise GSD from BMAD docs", "hand off to GSD", "BMAD to GSD" |
| `context-health-monitor` | Bridge | "check drift", "health check", "are we on track" |
| `doc-shard-bridge` | Bridge | "shard documents", "create phase context", "sync phase N" |
| `phase-gate-validator` | Bridge | "is phase N done", "validate phase", "gate check" |
| `it-infra-agent` | Domain | "deploy", "PowerShell", "Bash script", "Active Directory", "infra" |
| `godot-dev-agent` | Domain | "Godot", "GDScript", "scene", "signal", "state machine" |
| `open-source-agent` | Domain | "open source", "Dependabot", "ESLint", "release", "semver" |
| `admin-docs-agent` | Domain | "policy", "runbook", "SOP", "communication", "admin" |
| `stack-update-watcher` | Maintenance | "check for updates", "is my stack up to date", "maintenance" |

---

## Entry Agents

### project-setup-wizard

**File:** `agents/entry/project-setup-wizard.md`

The interactive front door. Detects what's installed in the current project, presents a state-specific menu, and delivers the exact workflow to follow.

**Detects four states:**

| State | Condition | What it offers |
|-------|-----------|---------------|
| Clean Slate | No BMAD, no GSD | BMAD only, GSD only, or BMAD + GSD |
| GSD Active | `.planning/` present | Resume, add BMAD, start new milestone |
| BMAD Active | BMAD docs present | Start executing with GSD, continue planning |
| Full Stack | Both present | Resume phase, new phase, new milestone |

For each state, it computes the recommended next command. If plans exist but no UAT, it suggests `/gsd:execute-phase N`. If UAT has failures, it suggests re-running execute. If UAT passes, it suggests advancing.

**IT infrastructure override:** Auto-appends safety rules when `.ps1` files or infra keywords are detected.

### project-setup-advisor

**File:** `agents/entry/project-setup-advisor.md`

Lighter alternative. Same detection logic, but outputs a compact recommendation instead of an interactive menu. Use it when you already know the tooling and just want the next command.

---

## Bridge Agents

### bmad-gsd-orchestrator

**File:** `agents/bridge/bmad-gsd-orchestrator.md`

Translates completed BMAD planning documents into the GSD `.planning/` structure.

**Two operations:**

**BMAD to GSD (initialisation):**
1. Scans for BMAD docs. Blocks if PRD or architecture is missing.
2. Reads PRD (extracts epics, acceptance criteria, tech stack) and architecture (directory structure, naming conventions, dependencies).
3. Creates `.planning/config.json`, `.planning/CONTEXT.md`, and per-phase context files.
4. Prints the exact next command: `/gsd:discuss-phase 1`.

**GSD to BMAD (phase complete):**
After a phase passes its gate, reads the UAT file, updates the BMAD story status to "Done", and adds a completion summary.

### context-health-monitor

**File:** `agents/bridge/context-health-monitor.md`

Runs after `/gsd:execute-phase` to catch drift before it compounds.

**Five checks:**
1. **Directory structure drift** -- planned vs actual
2. **Naming convention drift** -- files against architecture rules
3. **Tech stack drift** -- approved dependencies vs actual
4. **Acceptance criteria coverage** -- each criterion has UAT evidence
5. **Cross-phase interface drift** -- interfaces the next phase needs actually exist

Output uses checkmarks/warnings/errors for scannability. Every blocker includes a specific `/gsd:quick` fix command.

**Advisory only** -- it flags issues but doesn't block. Fix blockers before running `phase-gate-validator`.

### doc-shard-bridge

**File:** `agents/bridge/doc-shard-bridge.md`

Handles two-way translation between BMAD and GSD document formats.

**Sharding (BMAD to GSD):** For each GSD phase, creates a context file containing only what that phase's subagents need -- objective, acceptance criteria, relevant architecture decisions, naming conventions, and dependencies from previous phases. Targets under 800 lines per shard (~30% of a 200k context window).

**Syncing (GSD to BMAD):** After a phase passes its gate, updates the BMAD story file with completion status, date, phase number, and UAT results.

For projects with 5+ phases, also creates a `MASTER-CONTEXT.md` with cross-phase interface contracts.

### phase-gate-validator

**File:** `agents/bridge/phase-gate-validator.md`

Formal quality gate between GSD phases. Nothing advances without its sign-off.

**Five gates:**

| Gate | What it checks | Blocks? |
|------|---------------|---------|
| 1. Acceptance Criteria | Every criterion has UAT evidence | Yes |
| 2. Git Hygiene | Clean tree, conventional commits, no mega-commits | Yes (dirty tree) |
| 3. Architectural Drift | Naming, structure, approved dependencies | Yes (critical) |
| 4. Dependency Readiness | Next phase's dependencies exist | Yes |
| 5. Safety Check | Dry-run flags, no hardcoded credentials, rollback docs | Yes (infra only) |

A single FAIL blocks advancement. Warnings alone don't block but must be acknowledged.

---

## Domain Agents

### it-infra-agent

**File:** `agents/domain/it-infra-agent.md`

IT infrastructure specialist. Enforces six non-negotiable patterns on every script it writes:

1. **Dry-run mode** -- `--dry-run` (Bash) or `-WhatIf` (PowerShell)
2. **Rollback docs** -- companion rollback script for changes affecting 5+ objects
3. **Structured logging** -- timestamped, levelled, contextual
4. **Secret hygiene** -- no hardcoded credentials, use vaults or env vars
5. **Idempotency** -- safe to run multiple times
6. **Error handling** -- `set -euo pipefail` (Bash) or `Set-StrictMode` (PowerShell)

For GSD integration, always sets `auto_advance: false` and `granularity: "fine"`.

**Does not handle:** SAP roles, country-specific compliance, billing, or network topology decisions. Add those to the project's CLAUDE.md.

### godot-dev-agent

**File:** `agents/domain/godot-dev-agent.md`

Godot 4.x GDScript specialist. Enforces:

- Scene organisation: `scenes/autoloads/`, `scenes/ui/`, `scenes/entities/`, `scenes/world/`, `scenes/shared/`
- Signal pattern: entities emit signals, parents connect. Never child-to-grandparent.
- State machines: `enum State` with `match current_state` in `_physics_process`
- `await` not `yield` (Godot 4 syntax)
- `@onready` and relative paths, not `get_node()` with absolute paths
- No game logic in UI nodes

For GSD integration, each phase maps to one game system. Excludes `assets/`, `*.import`, `export_presets.cfg`, and `.godot/` from analysis.

### open-source-agent

**File:** `agents/domain/open-source-agent.md`

OSS project management and web app development. Handles:

- **Dependency upgrades:** Fetch migration guide, check breaking changes, create GSD quick task, run lint/typecheck/build
- **Release workflow:** Conventional commits to determine version bump, generate changelog, tag release
- **CI templates:** GitHub Actions with checkout, setup-node, lint, typecheck, build

### admin-docs-agent

**File:** `agents/domain/admin-docs-agent.md`

Administrative documentation for IT environments. Adapts language to audience:

- **Technical** (IT admins): full detail, exact commands
- **Semi-technical** (IT coordinators): process steps, no raw commands
- **Non-technical** (staff/managers): what changes, what to do, who to call

Provides templates for communications (effective date, audience, impact), policy documents (with policy ID, version, scope), and runbooks (prerequisites, per-step actions with expected results, rollback).

---

## Maintenance Agent

### stack-update-watcher

**File:** `agents/maintenance/stack-update-watcher.md`

Monitors BMAD and GSD for upstream changes. Fetches changelogs, classifies changes by impact (required/recommended/monitor), cross-references against all 11 agent files, and produces a fix plan with exact commands.

Never auto-applies changes. Always presents commands for review.

Part of the three-tier update system:
1. **Session banner** -- cached, zero-latency notification
2. **Weekly cron** -- background version check
3. **This agent** -- full analysis on demand
