# Workflows

This document covers the end-to-end workflows supported by the Claude Code Stack. Read this alongside the [README](../README.md) for installation and overview.

---

## Table of Contents

1. [Project Setup Workflow](#1-project-setup-workflow)
2. [BMAD + GSD Integration](#2-bmad--gsd-integration)
3. [Bridge Agent Workflows](#3-bridge-agent-workflows)
4. [Domain Agent Workflows](#4-domain-agent-workflows)
5. [Hook Lifecycle](#5-hook-lifecycle)
6. [Update Workflow](#6-update-workflow)
7. [Backup and Restore](#7-backup-and-restore)
8. [Per-Project Configuration](#8-per-project-configuration)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Project Setup Workflow

### Using the Wizard

The `project-setup-wizard` is the entry point for every project session. It detects the project's current state and delivers the exact workflow to follow.

**Activate it by saying any of:**
- `wizard`
- `set up this project`
- `where do I start`
- `resume`

The wizard runs silently, then displays one of four state dashboards:

| State | Condition | Options presented |
|---|---|---|
| Clean Slate | No BMAD, no GSD | Choose BMAD only, GSD only, or BMAD → GSD |
| GSD Active | `.planning/` present, no BMAD docs | Resume, add BMAD, start new milestone |
| BMAD Active | BMAD docs present, no `.planning/` | Start executing with GSD, continue BMAD planning |
| Full Stack | Both present | Resume current phase, start new phase, start new milestone |

For each state the wizard also computes the recommended next command — for example, if plans exist but no UAT file, it suggests `/gsd:execute-phase N`; if the UAT has failures, it suggests re-running execute; if UAT passes, it suggests moving to the next phase.

### Using the Advisor

The `project-setup-advisor` is a lighter alternative. It scans the project and outputs a complete workflow recommendation without asking questions.

**Activate it by saying:**
- `start a project`
- `project setup`
- `which framework should I use`

The advisor classifies your project into one of five scenarios:

- **Scenario A** — New project (no frameworks): recommends full BMAD → GSD stack for complex projects, GSD only for small projects, or a quick task for one-offs
- **Scenario B** — GSD only: recommends installing BMAD and running `doc-shard-bridge` to retrofit planning
- **Scenario C** — BMAD only: recommends verifying doc completeness, installing GSD, then running `bmad-gsd-orchestrator`
- **Scenario D** — Neither (bare project): recommends a framework based on estimated project size
- **Scenario E** — Both present: runs a health check and shows where you are

The advisor also detects project type (`infra`, `web`, `game`, `docs`, `other`) and appends type-specific rules to the workflow output.

### Which Entry Agent to Use

Use the **wizard** when you want an interactive session start with explicit menu choices. Use the **advisor** when you want a single command that directly outputs the right workflow. Both scan the same signals; the difference is presentation and interactivity.

---

## 2. BMAD + GSD Integration

### Division of Responsibility

BMAD and GSD serve different phases of development:

- **BMAD** answers: what are we building? It produces a Product Requirements Document (PRD), an architecture document, and user stories with acceptance criteria.
- **GSD** answers: how do we build it reliably? It executes each phase in a fresh 200k context window, with atomic git commits and formal quality gates.

The handoff happens when BMAD stories reach "Approved" status.

### Full Stack Workflow (New Project)

```
PART A — PLANNING (BMAD)
─────────────────────────
/workflow-init          Activate BMAD for this session
/analyst                Problem framing, users, goals, constraints
/pm                     PRD → docs/prd-[project].md
/architect              Architecture → docs/architecture-[project].md
/scrum-master           Stories → docs/stories/story-NNN-*.md

Iterate until:
  PRD is complete
  Architecture is locked
  3+ stories are in "Approved" status

HANDOFF — Run the bmad-gsd-orchestrator
─────────────────────────────────────────
Say: "initialise GSD from BMAD docs"
Creates: .planning/config.json, CONTEXT.md, per-phase context files

PART B — EXECUTION (GSD)
─────────────────────────
/gsd:discuss-phase N    Lock implementation decisions
/gsd:plan-phase N       Atomic task plans in .planning/
/gsd:execute-phase N    Subagent execution, fresh context per task
/gsd:verify-work N      UAT against BMAD acceptance criteria
[phase-gate-validator]  Formal gate before advancing
[doc-shard-bridge]      Sync completed phase back to BMAD stories

Repeat per phase. When all phases complete:
/gsd:complete-milestone
/gsd:new-milestone       (for the next version)
```

### Adding GSD to an Existing BMAD Project

1. Verify prerequisites: `docs/prd-[project].md`, `docs/architecture-[project].md`, at least one story in "Approved" status.
2. Install GSD: `npx get-shit-done-cc@latest --claude --global`
3. Run `/gsd:new-project` and when GSD prompts for project info, tell it to read the BMAD docs first and map story groups to phases. Do not answer GSD's standard questions — the answers are in the BMAD docs.
4. GSD creates `.planning/ROADMAP.md`, `.planning/CONTEXT.md`, and `.planning/config.json`.
5. Proceed with the GSD execution loop from `/gsd:discuss-phase 1`.

### Adding BMAD to an Existing GSD Project

1. Run `/gsd:map-codebase` to analyse what exists.
2. Install BMAD: `npx bmad-method install`
3. Run `/product-brief` and `/architecture` to document what was already built.
4. Say `run doc-shard-bridge on existing docs` to shard the new BMAD docs into GSD phase context files.
5. Continue with `/gsd:new-milestone` — GSD subagents will now load architecture context automatically at spawn.

### GSD `config.json` Settings

The `bmad-gsd-orchestrator` always sets `auto_advance: false` in `.planning/config.json`. This is non-negotiable — no phase advances without explicit human review. Do not override this setting.

For infrastructure projects, also set `granularity: "fine"` to ensure smaller, more reviewable task units.

---

## 3. Bridge Agent Workflows

### bmad-gsd-orchestrator

**When to run:** After BMAD planning is complete (PRD + architecture minimum).

**Two operations:**

**Operation A — BMAD to GSD initialisation:**
1. Scans for BMAD docs. Blocks and explains if PRD or architecture is missing.
2. Reads PRD (extracts epics, acceptance criteria, tech stack, out-of-scope items) and architecture (directory structure, components, naming conventions, dependencies).
3. Creates `.planning/config.json` mapping each BMAD epic to a GSD phase.
4. Creates `.planning/CONTEXT.md` with a project summary and phase map.
5. Creates `.planning/context/phase-N-context.md` for each phase.
6. Creates `bmad-outputs/STATUS.md` for progress tracking.
7. Prints the exact next command: `/gsd:discuss-phase 1`.

**Operation B — GSD phase complete, update BMAD:**
Triggered after a phase passes the gate. Reads the UAT file, updates the corresponding BMAD story status from "In Progress" to "Done", adds a completion summary block, and updates the `bmad-outputs/STATUS.md` table.

**Trigger phrases:** `initialise GSD from BMAD docs`, `hand off to GSD`, `BMAD to GSD`, `ready to implement`

---

### context-health-monitor

**When to run:** After `/gsd:execute-phase`, before running `phase-gate-validator`.

**Five checks:**

1. **Directory structure drift** — compares the planned structure from the architecture doc against what was actually created
2. **Naming convention drift** — checks recently modified files against naming rules in the architecture doc (camelCase, kebab-case, snake_case, PascalCase)
3. **Tech stack drift** — compares approved dependencies against what is actually in `package.json`, `requirements.txt`, `Cargo.toml`, or `go.mod`
4. **Acceptance criteria coverage** — checks that each criterion from the phase context has corresponding UAT evidence
5. **Cross-phase interface drift** — checks that the interfaces the next phase depends on actually exist

**Output:** A structured report using `✅` (no issues), `⚠` (non-blocking warnings), and `❌` (blockers). Every `❌` includes a specific `/gsd:quick` fix command.

**Advisory role:** The monitor flags issues but does not block. Fix all `❌` items before running `phase-gate-validator`.

**Trigger phrases:** `health check`, `check drift`, `validate output`, `are we on track`

---

### doc-shard-bridge

**When to run:** After `bmad-gsd-orchestrator` initialises `.planning/`, and after each phase completes.

**Operation A — Shard BMAD docs into phase context files:**

For each GSD phase, creates `.planning/context/phase-N-context.md` containing only what that phase's subagents need:

- Project name and one-line description (always included)
- This phase's objective and acceptance criteria
- Relevant sections of the architecture doc for what this phase builds
- Naming conventions and code style
- Dependencies from previous phases
- Explicit out-of-scope items for this phase

Each shard targets under 800 lines (~30% of a 200k context window). For projects with five or more phases, also creates `.planning/MASTER-CONTEXT.md` with cross-phase interface contracts.

**Operation B — Sync phase completion to BMAD stories:**

After a phase passes its gate, updates the BMAD story file:
- Changes status from "In Progress" to "Done"
- Adds a completion block with date, GSD phase number, summary, and UAT result
- Updates `bmad-outputs/STATUS.md`

**Trigger phrases:** `shard documents`, `create phase context`, `update stories`, `sync phase N`

---

### phase-gate-validator

**When to run:** After `context-health-monitor` issues a clean or warning-only report, before advancing to the next phase.

**Five gates:**

| Gate | What it checks | Blocks on FAIL? |
|---|---|---|
| Gate 1 — Acceptance Criteria | Every criterion from the phase context has UAT file evidence | Yes |
| Gate 2 — Git Hygiene | Clean working tree, conventional commit format, no WIP commits, no mega-commits | Yes (dirty tree), Warn (commit style) |
| Gate 3 — Architectural Drift | Naming conventions, directory structure, approved dependencies | Yes (critical violations), Warn (style drift) |
| Gate 4 — Dependency Readiness | Everything the next phase depends on actually exists | Yes |
| Gate 5 — Safety Check | Scripts have dry-run flags, no hardcoded credentials, rollback docs exist | Yes (infra only) |

Gate 5 is not applicable for web, game, or docs projects.

**Verdict: ADVANCE or FIX REQUIRED.** A single FAIL verdict blocks advancement. Multiple warnings alone do not block but must be addressed.

After an ADVANCE verdict, the validator reminds you to run `doc-shard-bridge` to sync the phase to BMAD stories.

**Trigger phrases:** `validate phase`, `is phase N done`, `can we move on`, `gate check`

---

## 4. Domain Agent Workflows

### it-infra-agent

**When it activates:** Automatically on infra trigger phrases such as `deploy`, `PowerShell`, `Bash script`, `Active Directory`, `Ansible`, `Terraform`, `Intune`, `onboarding`, `server`, or `infra`.

**What it enforces on every script it writes:**

1. **Dry-run mode** — `--dry-run` / `-WhatIf` flag required. Always test with dry-run first.
2. **Rollback documentation** — either inline comments or a companion `rollback-[script].sh` for scripts affecting more than 5 objects, security settings, or accounts.
3. **Structured logging** — timestamped log files in a `logs/` directory, using `Start-Transcript` (PowerShell) or `tee` (Bash).
4. **Secret hygiene** — no hardcoded passwords, tokens, or API keys. Uses `Get-Credential`, `$env:`, or vault references.
5. **Idempotency** — scripts are safe to run multiple times. Check-before-create patterns throughout.
6. **Error handling** — `Set-StrictMode -Version Latest` and `$ErrorActionPreference = "Stop"` in PowerShell; `set -euo pipefail` and `trap` in Bash.

**GSD integration:** Always set `auto_advance: false` and `granularity: "fine"` in `.planning/config.json`. Each phase context file must include the target environment description, prerequisites, dry-run instructions, and rollback procedure. Gate 5 of `phase-gate-validator` applies to all infra phases.

**What it does not do:** SAP role management, country-specific compliance rules, billing or procurement, network topology decisions without an architecture doc. Add project-specific environment names, tool versions, and approval processes to the project's `CLAUDE.md`.

---

### godot-dev-agent

**When it activates:** On `Godot`, `GDScript`, `scene`, `node`, `signal`, `game`, `player`, `inventory`, or `state machine`.

**Architecture conventions it enforces:**

- Scene organisation: `scenes/autoloads/`, `scenes/ui/`, `scenes/entities/`, `scenes/world/`, `scenes/shared/`, with `scripts/` mirroring the scene structure
- Signal pattern: entities emit signals; parents connect to them. Never connect from child to grandparent.
- State machines: `enum State` with `match current_state` in `_physics_process`
- Autoloads registered in Project Settings, never created in code
- `await` not `yield` (Godot 4 syntax)
- `@onready` and relative paths instead of `get_node()` with absolute paths
- No game logic in UI nodes

**GSD integration:** Each GSD phase maps to one game system (controller, inventory, combat, save system, etc.). Exclude `assets/`, `*.import`, `export_presets.cfg`, and `.godot/` from GSD analysis. Signals define the interface between systems and should be documented in each phase's context file.

---

### open-source-agent

**When it activates:** On `open source`, `Dependabot`, `dependency`, `ESLint`, `GitHub Actions`, `release`, `semver`, `changelog`, `Next.js`, `TypeScript`, or `PR`.

**Dependency upgrade protocol for major version bumps:**
1. Fetch and read the official migration guide
2. Check current usage against breaking changes
3. Create an upgrade plan as a GSD quick task: `/gsd:quick "Upgrade [package] from vX to vY: [specific changes]"`
4. Run lint, type-check, and build after upgrade

**Release workflow:** Uses `git log` since the last tag to review changes, conventional commits to determine version bump type (`feat:` → minor, `fix:` → patch, `BREAKING CHANGE:` → major), generates a changelog entry from commit history, and tags the release.

**CI template:** Provides a GitHub Actions workflow using `actions/checkout@v4` and `actions/setup-node@v4` running lint, type-check, and build.

---

### admin-docs-agent

**When it activates:** On `document`, `policy`, `runbook`, `SOP`, `communication`, `template`, `admin`, `announcement`, `procedure`, or `guide for staff`.

**Audience adaptation:** The agent always identifies the audience before writing:
- Technical (IT admins) — full detail, exact commands, paths
- Semi-technical (IT coordinators) — process steps, no raw commands
- Non-technical (staff/managers) — what changes, what to do, who to call

**Templates provided:**
- **Communications** — effective date, audience, owner, summary, impact (what changes, what stays, when), numbered actions, support contact
- **Policy documents** — policy ID, version, effective date, review date, owner, approval, scope, with sections for purpose, scope, policy statement, responsibilities, procedures, compliance, related documents, and revision history
- **Runbooks** — frequency, time estimate, skill level, last tested date, prerequisites, per-step actions with expected results and failure steps, rollback, and escalation path

**Note for small doc tasks:** For documentation that does not require policy structure, the `project-setup-advisor` will suggest skipping BMAD and using `/gsd:quick` directly.

---

## 5. Hook Lifecycle

### Session Start Sequence

When a Claude Code session opens, two hooks run in sequence:

**1. stack-update-banner.sh**

Reads `~/.claude/stack-update-cache.json`. If the cache shows that BMAD or GSD has a newer version available, or that required agent fixes are pending from the last watcher run, displays an update notice:

```
┌─────────────────────────────────────────────────┐
│  STACK UPDATE AVAILABLE                          │
├─────────────────────────────────────────────────┤
│  BMAD: 5.1.0    → 5.2.0                         │
│  1 required agent fix(es) pending               │
│  Say: 'check for updates' for details           │
└─────────────────────────────────────────────────┘
```

If the cache is older than 7 days, triggers a background refresh that fetches current npm versions and updates the cache. This runs detached (`disown`) and does not block the session.

If no cache exists, displays a prompt and creates an empty cache file.

**2. session-start.sh**

Scans the current directory for BMAD markers (`_bmad/`, `.bmad/`, `docs/prd*.md`), GSD markers (`.planning/config.json`), and context files (`CLAUDE.md`, `AGENTS.md`). Displays a state banner:

```
┌──────────────────────────────────────────────┐
│  Project: my-project                         │
│  BMAD:    ✓ present                          │
│  GSD:     ✓ Phase 3 active                   │
└──────────────────────────────────────────────┘
```

Additional notices appear when appropriate:
- Missing `CLAUDE.md` and `AGENTS.md` — warning
- Infrastructure project detected (from `CLAUDE.md` keywords) — dry-run reminder
- No framework present — suggestion to say `set up this project`

If a GSD phase is active, also prints: `Current phase: 3 — resume with /gsd:discuss-phase 3`

Logs session context (project directory, BMAD/GSD state, phase, project type) to `~/.claude/logs/session-start.log`.

### Post-Write Checks

After every file write, `post-write-check.sh` runs against the written file. The checks that run depend on the file type:

| File type | Checks run |
|---|---|
| `.sh`, `.bash` | Hardcoded secrets, `set -euo pipefail` presence, dry-run flag if destructive commands present |
| `.ps1` | Hardcoded secrets, `ErrorActionPreference` / `SupportsShouldProcess`, hardcoded Windows user paths |
| `.py`, `.js`, `.ts`, `.json`, `.yaml`, `.yml`, `.env` | Hardcoded secrets |
| `.gd` (GDScript) | Absolute node paths, `yield()` syntax (Godot 3), game logic in UI scripts |

Issues are reported to stderr as `❌ ERROR` (more serious) or `⚠ WARN` (advisory). The hook always exits with code 0 — it warns but never blocks.

All detected issues are appended to `~/.claude/logs/post-write-check.log` with timestamps.

---

## 6. Update Workflow

### Three-Tier System

**Tier 1 — Cached banner** (every session start): The `stack-update-banner.sh` hook reads `~/.claude/stack-update-cache.json` at session open. Zero latency — no network calls. Displays a notice when updates are available.

**Tier 2 — Weekly cron** (background): Installed by `install-runtime-support.sh` to run every Monday at 09:00:

```
0 9 * * 1 /bin/bash ~/.claude/scripts/weekly-stack-check.sh
```

Fetches npm versions for BMAD, GSD, and Pi. Writes results to the cache. Does not apply changes. Logs to `~/.claude/logs/update-checks.log`.

**Tier 3 — On-demand watcher** (when the banner prompts): Run `stack-update-watcher` for full changelog analysis and agent compatibility check.

### Running the Stack Update Watcher

Say `check for updates` or `is my stack up to date` in any Claude Code session.

The watcher will:

1. Detect installed versions of BMAD, GSD, and Pi from local files
2. Fetch current versions from npm
3. Fetch and parse changelogs since your installed version
4. Classify each change:
   - **HIGH IMPACT** — requires updating one or more of your agents (renamed commands, new config fields, changed file paths, new hook events, breaking changes)
   - **RECOMMENDED** — worth adopting (new features, better workflows, token efficiency improvements)
   - **LOW PRIORITY** — monitor only (bug fixes you haven't hit, documentation updates)
5. Scan all 11 agent files, hooks, and scripts for references to commands, paths, and config fields affected by HIGH IMPACT changes
6. Produce a report with exact file paths, line numbers, before/after text, and `/gsd:quick` fix commands
7. Write updated version data to `~/.claude/stack-update-cache.json`

### Applying Updates

The watcher never auto-applies changes. After reviewing the report:

```bash
# Step 1: Update GSD (no module selection required)
npx get-shit-done-cc@latest --claude --global

# Step 2: Update BMAD (interactive — review module choices)
npx bmad-method install

# Step 3: Apply required agent fixes (use the /gsd:quick commands from the report)

# Step 4: Verify the stack loads
# Restart Claude Code, then run /workflow-status and /gsd:help
```

Always update GSD before BMAD when both have updates — GSD's installer is non-interactive.

---

## 7. Backup and Restore

### What to Back Up

The stack lives in three locations:
- `~/.claude/agents/` — all 11 agent files
- `~/.claude/hooks/` — the three hook scripts
- `~/.claude/settings.json` — hook registrations

For Pi and OpenCode support, also back up `~/.pi/agent/` and `~/.config/opencode/agents/`.

### Creating a Backup

Use `rsync` or copy the directories to a backup location before any update:

```bash
BACKUP="$HOME/backups/claude-stack-$(date +%Y%m%d)"
mkdir -p "$BACKUP/claude-agents" "$BACKUP/claude-hooks"
rsync -a ~/.claude/agents/ "$BACKUP/claude-agents/"
rsync -a ~/.claude/hooks/  "$BACKUP/claude-hooks/"
cp ~/.claude/settings.json "$BACKUP/claude-settings.json"
```

The `restore.sh` script expects a backup directory with this structure.

### Restoring with restore.sh

```bash
# Preview what will change (dry run)
bash scripts/restore.sh --dry-run --target claude

# Restore Claude Code configuration
bash scripts/restore.sh --target claude

# Restore Pi configuration
bash scripts/restore.sh --target pi

# Restore OpenCode configuration
bash scripts/restore.sh --target opencode

# Restore everything
bash scripts/restore.sh --target all
```

The script uses `rsync --delete`, which means any files in the destination that are not in the backup will be removed. The `--dry-run` flag is a safe way to preview this before committing.

Since `restore.sh` is idempotent, re-running it restores the state again. There is no separate undo step.

---

## 8. Per-Project Configuration

### CLAUDE.md Patterns by Project Type

Every project should have a `CLAUDE.md` (at `.claude/CLAUDE.md` or the project root). The `session-start.sh` hook reads this to detect project type. The entry agents read it to understand project context before producing workflows.

#### Web Application

```markdown
# Project: [Name]

## Type
web

## Stack
Next.js 14, TypeScript, Tailwind CSS, Prisma, PostgreSQL

## Key Conventions
- Component files: PascalCase
- Utility files: kebab-case
- API routes: REST, JSON responses
- Use GSD --local per repo (not --global)

## GSD Settings
Run /gsd:map-codebase before starting any new milestone on this existing codebase.
```

#### IT Infrastructure

```markdown
# Project: [Name]

## Type
infra

## Stack
PowerShell 7, Active Directory, Microsoft Graph API, Intune

## Environment
- Dev: [environment name]
- Staging: [environment name]
- Production: [environment name — gated, requires approval from X]

## Rules
- auto_advance must be false
- All scripts require -WhatIf and a companion rollback script
- Test on Dev first, then Staging, then Production
- No hardcoded credentials — use Key Vault references

## Approval Process
Production changes require sign-off from [role].
Raise a change ticket in [system] before /gsd:execute-phase on any prod phase.
```

#### Godot Game

```markdown
# Project: [Name]

## Type
game

## Stack
Godot 4.3, GDScript

## Conventions
- Signals over direct calls
- No game logic in UI nodes
- Autoloads: GameManager, AudioManager, SaveSystem
- Each GSD phase = one game system

## GSD Exclusions
assets/, *.import, export_presets.cfg, .godot/
```

#### Documentation / Admin

```markdown
# Project: [Name]

## Type
docs

## Audience
IT staff (technical) and general staff (non-technical)

## Standards
- Policy ID format: IT-[3 digits]
- Review cycle: annual
- Owner: [Role/Team]

## Note
For small doc tasks, skip BMAD and use /gsd:quick directly.
Use admin-docs-agent for policy and runbook work.
```

#### Open Source Project

```markdown
# Project: [Name]

## Type
web (open source)

## Stack
Next.js, TypeScript, ESLint flat config

## Conventions
- Conventional Commits (feat/fix/chore/refactor/docs)
- Semver versioning
- Changelog maintained in CHANGELOG.md

## CI
GitHub Actions — lint, type-check, build required before merge
```

---

## 9. Troubleshooting

### The wizard does not activate when I say "wizard"

Verify the agent is installed in the correct location:

```bash
ls ~/.claude/agents/project-setup-wizard.md
```

If missing, copy it from the repository:

```bash
cp agents/entry/project-setup-wizard.md ~/.claude/agents/
```

Then restart Claude Code.

---

### The session-start banner does not appear

Check that the hooks are registered in `settings.json`:

```bash
cat ~/.claude/settings.json | python3 -m json.tool | grep -A 5 "SessionStart"
```

If the hooks section is missing, re-run the installer:

```bash
bash scripts/install-runtime-support.sh --claude
```

Or manually add the hook entries to `settings.json` as shown in the [Configuration section of the README](../README.md#configuration).

---

### The update banner says "No update cache yet" every session

The cache has not been written. Run the weekly check manually to initialise it:

```bash
bash ~/.claude/scripts/weekly-stack-check.sh
```

Or say `check for updates` to run the `stack-update-watcher` agent, which also writes the cache.

---

### bmad-gsd-orchestrator is blocked (PRD or architecture missing)

The orchestrator requires both `docs/prd-[project].md` and `docs/architecture-[project].md` before it will proceed. Run the missing BMAD agents:

```bash
# If PRD is missing
/prd

# If architecture is missing
/architect
```

Then re-say `initialise GSD from BMAD docs`.

---

### phase-gate-validator fails Gate 2 (dirty working tree)

Gate 2 requires a clean git working tree. Commit or stash any uncommitted changes before running the validator:

```bash
git status            # see what's uncommitted
git add -p            # stage selectively
git commit -m "fix: resolve remaining issues from phase N"
# then re-run gate check
```

---

### phase-gate-validator fails Gate 1 (missing UAT evidence)

The UAT file at `.planning/phases/[N]-UAT.md` does not cover one or more acceptance criteria from the phase context. Options:

1. Re-run `/gsd:verify-work N` to regenerate UAT coverage.
2. If the criterion was actually met but not documented in the UAT, manually add a verification note to the UAT file, then re-run the validator.
3. If the criterion was not met, run `/gsd:execute-phase N` again with the gap addressed.

---

### post-write-check.sh warns about a false positive secret detection

The hook uses heuristics and occasionally flags test fixtures, example values, or template placeholders. The hook is advisory — it never blocks. If you are confident the value is not a real secret (for example, it uses placeholder text or is inside a test file), you can safely ignore the warning.

If the false positives are frequent for a specific file, check whether the file contains obvious non-secret markers the hook already knows to skip: `example`, `placeholder`, `changeme`, `your-`, or environment variable references.

---

### Pi agents are installed but not loading

Pi agents are stored in `~/.pi/agent/` as `.md` files with the YAML frontmatter stripped. Verify:

```bash
ls ~/.pi/agent/*.md
```

Pi loads agents from this directory automatically at startup. If the files are present but agents are not available, check the Pi version and consult Pi documentation for the correct agent directory path for your version.

---

### GSD context rot during a long phase

If a long-running phase shows quality degradation mid-phase (the model loses context of earlier decisions), use `/gsd:quick` for the remaining tasks rather than continuing the current execute-phase session. Each `/gsd:quick` call spawns a fresh context.

After the phase completes, run `context-health-monitor` to catch any drift introduced during the long session, then run `phase-gate-validator` as usual.

---

### Weekly cron is not running

Check whether the cron entry was installed:

```bash
crontab -l | grep weekly-stack-check
```

If missing, add it manually:

```bash
(crontab -l 2>/dev/null; echo "0 9 * * 1 /bin/bash $HOME/.claude/scripts/weekly-stack-check.sh >> $HOME/.claude/logs/update-checks.log 2>&1") | crontab -
```

You can also run the check on demand at any time:

```bash
bash ~/.claude/scripts/weekly-stack-check.sh
```
