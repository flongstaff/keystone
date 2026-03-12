# Codebase Structure

**Analysis Date:** 2026-03-11

## Directory Layout

```
claude-code-stack/
├── agents/                      # 11 custom Claude Code subagents (.md YAML+Markdown)
│   ├── entry/                   # First-contact agents (project detection)
│   │   ├── project-setup-wizard.md
│   │   └── project-setup-advisor.md
│   ├── bridge/                  # BMAD↔GSD integration agents
│   │   ├── bmad-gsd-orchestrator.md
│   │   ├── context-health-monitor.md
│   │   ├── doc-shard-bridge.md
│   │   └── phase-gate-validator.md
│   ├── domain/                  # Project-type-specific agents
│   │   ├── it-infra-agent.md
│   │   ├── godot-dev-agent.md
│   │   ├── open-source-agent.md
│   │   └── admin-docs-agent.md
│   └── maintenance/             # Framework maintenance
│       └── stack-update-watcher.md
├── hooks/                       # Claude Code lifecycle hooks (.sh)
│   ├── session-start.sh         # SessionStart: project state banner
│   ├── post-write-check.sh      # PostToolUse(Write): safety checks
│   └── stack-update-banner.sh   # SessionStart: version update notice
├── scripts/                     # Standalone installation & maintenance (.sh)
│   ├── install-runtime-support.sh  # One-command installer for Claude/OpenCode/Pi
│   ├── restore.sh              # Restore agents/hooks/config from backup
│   └── weekly-stack-check.sh   # Fetch npm versions, update cache (cron target)
├── docs/                        # Developer documentation (architecture, workflows)
│   ├── architecture.md          # Detailed agent architecture guide
│   ├── orchestration.md         # BMAD-GSD integration patterns
│   ├── workflows.md             # Step-by-step workflow procedures
│   └── gsd-vs-bmad.md          # Comparison and decision framework
├── .planning/                   # Phase planning output (generated)
│   └── codebase/               # Codebase analysis documents (this directory)
│       ├── ARCHITECTURE.md
│       ├── STRUCTURE.md
│       ├── STACK.md (if tech focus)
│       └── ...
├── plans/                       # BMAD output from planning phases
├── _bmad-output/               # Legacy BMAD artifacts
├── README.md                    # Project overview, quick start, configuration
├── LICENSE                      # MIT license
└── .github/
    └── instructions/           # GitHub-specific documentation
```

## Directory Purposes

**agents/**
- Purpose: Claude Code native subagents that handle specific workflows
- Contains: YAML+Markdown agent definitions
- Key files: All 11 agents listed above
- Note: Installed to `~/.claude/agents/` on target runtime(s)

**agents/entry/**
- Purpose: First-contact agents for project initialization
- Contains: Project state detection and workflow recommendation
- Key files: `project-setup-wizard.md` (interactive), `project-setup-advisor.md` (advisory-only)

**agents/bridge/**
- Purpose: Orchestrate BMAD→GSD handoff and enforce quality gates
- Contains: Document translation, context sharding, drift monitoring, phase validation
- Key files: `bmad-gsd-orchestrator.md` (initializes GSD), `phase-gate-validator.md` (formal gate), `context-health-monitor.md` (advisory drift detection)

**agents/domain/**
- Purpose: Auto-activate specialized patterns for infrastructure, game dev, open source, documentation
- Contains: Domain-specific rules and safety checks
- Key files: Domain agents auto-trigger on keyword detection in CLAUDE.md or user phrases

**agents/maintenance/**
- Purpose: Framework version monitoring and update tracking
- Contains: Stack update watcher
- Key files: `stack-update-watcher.md`

**hooks/**
- Purpose: Automated background validation and state detection
- Contains: Shell scripts that integrate with Claude Code lifecycle
- Generated: No; committed to repo
- Installed: To `~/.claude/hooks/` on target runtime(s)
- Key scripts:
  - `session-start.sh`: Runs SessionStart, shows project banner
  - `post-write-check.sh`: Runs PostToolUse(Write), validates file safety
  - `stack-update-banner.sh`: Runs SessionStart, displays version update notice

**scripts/**
- Purpose: Setup, restoration, and periodic maintenance
- Contains: Bash scripts for installer, rollback, version sync
- Generated: No; committed to repo
- Key scripts:
  - `install-runtime-support.sh`: Install/configure for Claude Code, OpenCode, Pi
  - `restore.sh`: Restore agents, hooks, settings from backup (supports --dry-run)
  - `weekly-stack-check.sh`: Fetch BMAD/GSD versions, update cache (cron job)

**docs/**
- Purpose: Architecture and workflow documentation for developers
- Contains: Markdown guides
- Key files:
  - `architecture.md`: Detailed agent ecosystem explanation
  - `workflows.md`: Step-by-step procedures for common tasks
  - `orchestration.md`: BMAD-GSD integration patterns
  - `gsd-vs-bmad.md`: Framework comparison

**.planning/codebase/**
- Purpose: Generated codebase analysis documents (this is where you are reading from)
- Contains: ARCHITECTURE.md, STRUCTURE.md, STACK.md (tech focus), CONVENTIONS.md, TESTING.md (quality focus), CONCERNS.md (concerns focus)
- Generated: By `/gsd:map-codebase` agent
- Committed: Yes; consumed by `/gsd:plan-phase` and `/gsd:execute-phase`

## Key File Locations

**Entry Points:**

- `agents/entry/project-setup-wizard.md`: Main entry agent; triggered on first project session or explicit invocation
- `agents/entry/project-setup-advisor.md`: Lightweight alternative to wizard; outputs recommendation directly
- `hooks/session-start.sh`: Automatic entry point; runs on every Claude Code session start
- `README.md`: First-read for installation and quick start

**Configuration:**

- `README.md`: Installation commands, hook setup, per-project CLAUDE.md guidance
- `.github/instructions/`: GitHub-specific docs (empty or minimal in this repo)
- `.planning/config.json` (generated): GSD execution config (not in repo, created during orchestrator run)

**Core Logic:**

- `agents/bridge/bmad-gsd-orchestrator.md`: Translation from BMAD docs to GSD structure
- `agents/bridge/phase-gate-validator.md`: 5-gate validation between phases
- `agents/bridge/context-health-monitor.md`: Detects architectural drift
- `agents/bridge/doc-shard-bridge.md`: Splits large docs into phase contexts

**Testing & Validation:**

- `hooks/post-write-check.sh`: Non-blocking file validation after writes
- `scripts/restore.sh`: Restoration with --dry-run preview (acts as its own rollback)

## Naming Conventions

**Files:**

- Agents: Kebab-case + `.md` (e.g., `project-setup-wizard.md`, `bmad-gsd-orchestrator.md`)
- Hooks: Kebab-case + `.sh` (e.g., `session-start.sh`, `post-write-check.sh`)
- Scripts: Kebab-case + `.sh` (e.g., `install-runtime-support.sh`, `restore.sh`)
- Documentation: Kebab-case + `.md` (e.g., `architecture.md`, `workflows.md`)
- Analysis documents: UPPERCASE + `.md` (e.g., `ARCHITECTURE.md`, `STRUCTURE.md`)

**Directories:**

- Agent categories: Lowercase (e.g., `entry`, `bridge`, `domain`, `maintenance`)
- Functional groupings: Lowercase (e.g., `agents`, `hooks`, `scripts`, `docs`)
- Hidden directories: Dot-prefixed (e.g., `.planning`, `.github`)
- Output directories: Underscored prefix (e.g., `_bmad-output`)

**Inside Agent YAML:**

- Agent names (YAML `name:` field): Kebab-case matching filename without `.md`
- Tool lists: Standard Claude Code tools (`Read`, `Write`, `Edit`, `Bash`, `Glob`, `Grep`)
- Model selection: `sonnet` (default for most), `opus` (for complex reasoning), `haiku` (for lightweight tasks)
- MaxTurns: Typical range 20–40 depending on complexity

## Where to Add New Code

**New Agent (specialized workflow):**
- Create: `agents/[category]/[agent-name].md`
- Format: YAML frontmatter + Markdown body
- Required fields: `name`, `description`, `model`, `tools`, `maxTurns`
- Description should include activation trigger phrases so Claude auto-routes
- Category guidelines:
  - `entry/` — Project initialization and setup detection
  - `bridge/` — BMAD↔GSD integration, phase gates, drift detection
  - `domain/` — Project-type-specific patterns (add 5th domain agent here if needed)
  - `maintenance/` — Framework updates and version tracking

**New Hook (automated background task):**
- Create: `hooks/[hook-name].sh`
- Register in: `~/.claude/settings.json` under appropriate hook event
- Hook events in Claude Code:
  - `SessionStart`: Runs at session open (already used by `session-start.sh` and `stack-update-banner.sh`)
  - `PostToolUse` with `matcher: "Write"`: Runs after every file write (used by `post-write-check.sh`)
- Requirements: Must exit 0 (never block), use stderr for messages, log to `~/.claude/logs/`

**New Script (installation, maintenance, or restoration):**
- Create: `scripts/[script-name].sh`
- Requirements: Must use `set -euo pipefail`, support `--dry-run` if destructive, validate inputs
- Integration: Can be called by hooks, installed by `install-runtime-support.sh`, or run manually

**New Domain Agent (project type):**
- If new project type needed, create: `agents/domain/[domain]-agent.md`
- Auto-trigger by extending pattern matching in `hooks/session-start.sh` to detect new type
- Template: Copy from existing domain agent (e.g., `it-infra-agent.md`), adapt patterns

## Special Directories

**.planning/codebase/**
- Purpose: Codebase analysis documents consumed by `/gsd:plan-phase` and `/gsd:execute-phase`
- Generated: Yes (by `/gsd:map-codebase` agent)
- Committed: Yes (updated as codebase evolves)

**.planning/** (parent)
- Purpose: GSD execution structure (config.json, STATE.md, phase context, phase results)
- Generated: Yes (by `bmad-gsd-orchestrator` and `/gsd:` commands)
- Committed: Yes (planning artifacts)

**_bmad/** / **.bmad/**
- Purpose: BMAD v6 and v4 project artifacts (PRD, architecture, stories, status tracking)
- Generated: Yes (by BMAD agents during planning)
- Committed: Yes (planning documents)

**_bmad-output/**
- Purpose: Temporary output from BMAD planning runs
- Generated: Yes
- Committed: Usually (contains artifacts useful for reference)

**~/.claude/logs/**
- Purpose: Session history and audit trail for hooks and background processes
- Generated: Yes (by hooks at runtime)
- Committed: No (local machine only)

**~/.claude/stack-update-cache.json**
- Purpose: Cached version information for BMAD and GSD (updated by `weekly-stack-check.sh`)
- Generated: Yes
- Committed: No (local machine only)

---

*Structure analysis: 2026-03-11*
