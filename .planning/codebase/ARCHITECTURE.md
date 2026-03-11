# Architecture

**Analysis Date:** 2026-03-11

## Pattern Overview

**Overall:** Multi-tier agent ecosystem with orchestration, domain specialization, and lifecycle hooks.

**Key Characteristics:**
- **Modular agent framework** — 11 independent agents in 4 categories (entry, bridge, domain, maintenance)
- **Layered deployment** — Global runtime installation + per-project overrides
- **Integration-first design** — Bridges BMAD planning and GSD execution frameworks
- **Hook-based automation** — SessionStart and PostToolUse hooks for background validation
- **Domain-specific intelligence** — Domain agents auto-activate based on project type detection

## Layers

**Entry Layer:**
- Purpose: First-contact agents that detect project state and recommend workflows
- Location: `agents/entry/`
- Contains: `project-setup-wizard.md`, `project-setup-advisor.md`
- Depends on: Bash utilities for project detection (git state, .planning/, _bmad/ directories)
- Used by: Every new project session; triggered by user phrases like "set up this project"

**Bridge Layer:**
- Purpose: Connect BMAD planning output to GSD execution input; validate phase boundaries; monitor drift
- Location: `agents/bridge/`
- Contains: `bmad-gsd-orchestrator.md`, `context-health-monitor.md`, `doc-shard-bridge.md`, `phase-gate-validator.md`
- Depends on: BMAD document structure, GSD config.json format, git repository state
- Used by: Between planning completion (BMAD) and execution start (GSD), and between phases

**Domain Layer:**
- Purpose: Enforce domain-specific patterns for infrastructure, game development, open source, and documentation work
- Location: `agents/domain/`
- Contains: `it-infra-agent.md`, `godot-dev-agent.md`, `open-source-agent.md`, `admin-docs-agent.md`
- Depends on: Project type detection via CLAUDE.md pattern matching, trigger phrase recognition
- Used by: Automatically when project type matches; can be manually invoked

**Maintenance Layer:**
- Purpose: Monitor framework versions and track required updates
- Location: `agents/maintenance/`
- Contains: `stack-update-watcher.md`
- Depends on: npm registry, cached version data at `~/.claude/stack-update-cache.json`
- Used by: Periodically (cron), or when user asks about updates

**Hook Layer:**
- Purpose: Automation triggered at specific lifecycle events without explicit user invocation
- Location: `hooks/`
- Triggers: SessionStart (project state banner), PostToolUse-Write (safety checks)
- Used by: Claude Code lifecycle events, non-blocking (warnings only, never blocks execution)

**Script Layer:**
- Purpose: Installation, restoration, and scheduled maintenance
- Location: `scripts/`
- Contains: One-command installer for runtimes, restore/rollback script, weekly version check
- Used by: Initial setup, recovery scenarios, cron jobs

## Data Flow

**Initialization Flow (New Project):**

1. User opens project in Claude Code
2. `session-start.sh` hook detects project state (looks for `.planning/config.json`, `_bmad/` directory, `CLAUDE.md`)
3. Banner displays BMAD presence, GSD phase status, and next recommended action
4. User says "set up this project"
5. `project-setup-wizard` detects installed frameworks, asks user preference, outputs exact workflow

**BMAD → GSD Handoff Flow:**

1. User completes BMAD planning (documents in `docs/prd-*.md`, `docs/architecture-*.md`, `docs/stories/`)
2. User says "initialise GSD from BMAD docs"
3. `bmad-gsd-orchestrator` reads BMAD docs, validates completeness, creates `.planning/config.json` and per-phase context files
4. GSD is now initialised with phases extracted from BMAD epics
5. User begins `/gsd:execute-phase` workflow

**Phase Execution Flow:**

1. User runs `/gsd:execute-phase N`
2. Context-sharded version of phase context is presented
3. User and subagents implement phase
4. User runs `/gsd:discuss-phase N` for UAT
5. `phase-gate-validator` checks acceptance criteria, git hygiene, architectural drift
6. If all gates pass, user advances to next phase
7. `doc-shard-bridge` updates BMAD story status files with completion evidence
8. If phase fails validation, `context-health-monitor` flags specific drift issues and suggests fixes

**State Management:**

- **Persistent state:** `.planning/config.json` (GSD config), `.planning/STATE.md` (current phase), `_bmad/` or `.bmad/` (BMAD documents)
- **Session state:** Cached in `~/.claude/stack-update-cache.json` (version information), `~/.claude/logs/` (session history)
- **Git state:** Entry point agents check `git branch`, `git status --porcelain` to understand uncommitted changes and project history
- **Project type detection:** Read from `.claude/CLAUDE.md` for project-specific rules (infra, game, web)

## Key Abstractions

**Agent Descriptor (YAML frontmatter):**
- Purpose: Defines agent identity, activation triggers, and capability constraints
- Examples: All `.md` files in `agents/` directory
- Pattern: Starts with `---` YAML block containing `name`, `description`, `model`, `tools`, `maxTurns`

**Project State Markers:**
- Purpose: Quick file-based detection without parsing; enables fast branching logic
- Examples:
  - BMAD presence: `_bmad/` directory, `docs/prd-*.md`, `.bmad/` (legacy)
  - GSD presence: `.planning/config.json`, `.planning/STATE.md`
  - Project type: Grep patterns in `.claude/CLAUDE.md` for keywords ("infra", "godot", "next.js")

**Context Sharding:**
- Purpose: Split large BMAD documents into phase-specific, context-window-friendly chunks
- Pattern: `doc-shard-bridge` creates `./planning/context/phase-[N]-context.md` files (~800 lines each)
- Reason: Keeps individual phase contexts under 30% of context window to leave room for implementation code

**Phase Gates:**
- Purpose: Formal validation between phase boundaries; prevents drift propagation
- Pattern: 5-gate validation in `phase-gate-validator.md`:
  1. Acceptance criteria coverage (UAT evidence)
  2. Git hygiene (conventional commits, clean working tree)
  3. Architectural drift (naming conventions, directory structure)
  4. Dependency readiness (next phase's external dependencies are available)
  5. Safety checks (infra projects have dry-run flags, no hardcoded credentials)

## Entry Points

**Project Setup Wizard (Interactive):**
- Location: `agents/entry/project-setup-wizard.md`
- Triggers: User says "set up this project", "where do I start", "wizard", or similar on first project session
- Responsibilities:
  - Silent detection of BMAD, GSD, and git state
  - Interactive menu with numbered choices
  - Output step-by-step workflow (install commands, phase loop, first command to run)

**Project Setup Advisor (Lightweight):**
- Location: `agents/entry/project-setup-advisor.md`
- Triggers: User says "project setup", "start a project", "which framework should I use"
- Responsibilities:
  - Silent scan, no interactive menu
  - Direct recommendation for detected scenario
  - Output recommended workflow without user choice

**Hook-based Entry Points:**

**SessionStart (on every project open):**
- Script: `hooks/session-start.sh`
- Responsibilities:
  - Detect project state (BMAD, GSD phase, project name)
  - Show banner with project info and next action
  - Log session context to `~/.claude/logs/session-start.log`
  - Warn if no CLAUDE.md or AGENTS.md found
  - Show infra safety reminder for infrastructure projects

**PostToolUse-Write (after every file write):**
- Script: `hooks/post-write-check.sh`
- Responsibilities:
  - Check for hardcoded secrets (all script/config types)
  - Enforce shell script safety (`set -euo pipefail`, dry-run flags)
  - Warn on PowerShell missing error handling or hardcoded paths
  - Flag Godot 3 syntax in GDScript files (yield → await)
  - Never blocks execution (warnings to stderr only)

## Error Handling

**Strategy:** Graceful degradation with comprehensive logging; no silent failures.

**Patterns:**

**Agent-level (Python/Bash in agents):**
- Wrap file reads in try/except or `grep... 2>/dev/null || echo ""` patterns
- If critical document missing, output `BLOCKED: [reason] Run [command] first`
- Never exit non-zero from agent scripts (context would fail)

**Hook-level (shell scripts):**
- Validate file existence before processing: `[[ -f "$FILE" ]] || exit 0`
- Log all warnings and errors to `~/.claude/logs/` with timestamp
- Always exit 0 from hooks (PostToolUse hooks block execution on non-zero)
- Use stderr for user-facing messages, stdout only for structured output

**Script-level (install, restore, weekly-check):**
- `set -euo pipefail` enforced in all production scripts
- Dry-run mode for destructive operations (`restore.sh --dry-run`)
- Validate backup/source directories before restore
- Create timestamped backups before overwriting config

## Cross-Cutting Concerns

**Logging:**
- **What:** Project state (project name, phase, BMAD/GSD status) and session context
- **Where:** `~/.claude/logs/session-start.log` (session lifecycle), `~/.claude/logs/post-write-check.log` (file safety checks), `~/.claude/logs/update-checks.log` (version sync)
- **Format:** `[YYYY-MM-DD HH:MM:SS] CONTEXT_INFO` or `[TIMESTAMP] LEVEL: MESSAGE`
- **No sensitive data:** Never log API keys, tokens, or credentials (post-write-check specifically detects and warns)

**Validation:**
- **Project type detection:** Pattern matching in CLAUDE.md (keywords like "infra", "godot", "typescript")
- **Framework detection:** Directory markers (`.planning/`, `_bmad/`), file existence checks
- **Document completeness:** BMAD orchestrator checks for required docs (PRD, Architecture) before proceeding
- **Phase completion:** Gate validator checks acceptance criteria, git hygiene, architectural drift

**Authentication & Secrets:**
- **Approach:** Environment variables and credential managers only
- **Enforcement:** `post-write-check.sh` detects hardcoded secrets in scripts and config files and warns (non-blocking)
- **PowerShell:** Recommend `Get-Credential` for prompts, never hardcode
- **Shell:** Use `read -s` for password prompts
- **Tooling:** `restore.sh` supports dry-run preview before any credential files are touched

---

*Architecture analysis: 2026-03-11*
