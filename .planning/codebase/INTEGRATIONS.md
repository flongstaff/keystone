# External Integrations

**Analysis Date:** 2026-03-11

## APIs & External Services

**Package Registries:**
- npm (npmjs.org) - Fetches and installs BMAD, GSD, and agent packages
  - Calls: `npm view bmad-method version`, `npm view get-shit-done-cc version`, `npm view @mariozechner/pi-coding-agent version`
  - Usage: Version checking in `scripts/weekly-stack-check.sh` and `agents/maintenance/stack-update-watcher.md`
  - Auth: Uses system npm credentials

**GitHub Repositories:**
- BMAD Method (https://github.com/bmad-code-org/BMAD-METHOD)
  - Changelog: https://raw.githubusercontent.com/bmad-code-org/BMAD-METHOD/main/CHANGELOG.md
  - Releases API: https://github.com/bmad-code-org/BMAD-METHOD/releases
  - Used by: `stack-update-watcher` agent for changelog analysis
  - Auth: Public API, no auth required

- GSD (Get Shit Done) (https://github.com/gsd-build/get-shit-done)
  - Changelog: https://raw.githubusercontent.com/gsd-build/get-shit-done/main/CHANGELOG.md
  - Releases API: https://github.com/gsd-build/get-shit-done/releases
  - Used by: `stack-update-watcher` agent for changelog analysis
  - Auth: Public API, no auth required

- Pi Coding Agent (https://github.com/mariozechner/pi-coding-agent)
  - Used by: Optional runtime support
  - Auth: Public repository

## Data Storage

**Databases:**
- None used directly by this stack

**File Storage:**
- Local filesystem only
  - Agent storage: `~/.claude/agents/`, `~/.pi/agent/`, `~/.config/opencode/agents`
  - Hooks storage: `~/.claude/hooks/`
  - Scripts storage: `~/.claude/scripts/`
  - Logs: `~/.claude/logs/`
  - Cache: `~/.claude/stack-update-cache.json`
  - Backups: Can be created via `restore.sh` from user-specified directory

**Caching:**
- Version Cache: `~/.claude/stack-update-cache.json`
  - Contains: installed BMAD/GSD/Pi versions, latest available versions, last check timestamp
  - Lifetime: 7 days (triggers async refresh if older)
  - Managed by: `stack-update-banner.sh` and `weekly-stack-check.sh`

## Authentication & Identity

**Auth Provider:**
- None (authentication is handled by parent runtimes)
- Claude Code: Uses Anthropic API credentials (managed by Claude Code itself)
- OpenCode: Uses OpenAI API credentials (managed by OpenCode)
- Pi: Uses Anthropic API credentials (managed by Pi)

**Configuration:**
- No explicit auth tokens stored by this stack
- Scripts reference environment files (without reading them directly) for secret handling
- Post-write hook checks for hardcoded secrets with pattern matching in `hooks/post-write-check.sh`

## Monitoring & Observability

**Error Tracking:**
- None

**Logs:**
- Session logs: `~/.claude/logs/session-start.log`
- Update check logs: `~/.claude/logs/update-checks.log`
- Post-write check logs: `~/.claude/logs/post-write-check.log`
- All logs written in plain text with timestamps in format: `[YYYY-MM-DD HH:MM:SS]`
- No external log aggregation

**Structured Logging:**
- Version cache serves as structured state: `~/.claude/stack-update-cache.json`
- Contains fields: `last_checked`, `bmad_installed`, `bmad_latest`, `gsd_installed`, `gsd_latest`, `pi_installed`, `pi_latest`, `required_actions_count`, `next_check_recommended`

## CI/CD & Deployment

**Hosting:**
- Not applicable (this is a CLI tool stack, not a hosted application)

**Local Execution:**
- Runs via Claude Code, OpenCode, or Pi runtimes
- Hooks execute automatically at SessionStart and PostToolUse events
- Scripts can be invoked manually or via cron

**CI Pipeline:**
- Weekly cron job installed by `install-runtime-support.sh`
- Cron expression: `0 9 * * 1` (Monday 09:00)
- Command: `bash ~/.claude/scripts/weekly-stack-check.sh >> ~/.claude/logs/update-checks.log 2>&1`
- Purpose: Refresh version cache without network calls on every session start

## Environment Configuration

**Required env vars:**
None. All configuration via:
- `~/.claude/settings.json` (hook registration)
- `.claude/CLAUDE.md` (per-project overrides)
- `OPENCODE_CONFIG_DIR` (optional, defaults to `~/.config/opencode`)

**Secrets location:**
- Secrets are never stored by this stack
- Post-write hook warns if hardcoded secrets detected (patterns: `password=`, `secret=`, `token=`, `apikey=`)
- Guidelines in `hooks/post-write-check.sh`: encourage use of environment variables or secrets managers

**File paths configured:**
- Claude Code: `$HOME/.claude/`
- OpenCode: `$OPENCODE_CONFIG_DIR` or `$HOME/.config/opencode`
- Pi: `$HOME/.pi/`
- Logs directory: `$HOME/.claude/logs/` (created by scripts)

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

**Hook Events (Claude Code only):**
- `SessionStart` - Runs `stack-update-banner.sh` and `session-start.sh` at every session start
  - Shows version update notices (from cache)
  - Shows project state banner (BMAD/GSD presence, active phase)
  - Non-blocking, all async

- `PostToolUse` (Write matcher) - Runs `post-write-check.sh` after every file write
  - Checks for hardcoded secrets, shell script safety, PowerShell patterns, GDScript syntax
  - Outputs warnings/errors to stderr only
  - Never blocks execution

## Integration Points with External Codebases

**BMAD Integration:**
- Agents read BMAD output from `_bmad/` or `.bmad/` (legacy)
- Document paths: `docs/prd*.md`, `docs/architecture*.md`, `docs/stories/`
- Orchestrator extracts project name, epics, tech stack from BMAD docs
- Creates `.planning/config.json` as bridge structure

**GSD Integration:**
- Agents write to `.planning/config.json` and `.planning/STATE.md`
- Reference GSD commands: `/gsd:discuss-phase`, `/gsd:execute-phase`, `/gsd:quick`
- GSD phase tracking updates BMAD story status via orchestrator
- Config fields read by GSD: `project_name`, `description`, `tech_stack`, `phases`, `bmad_source`, `auto_advance`, `nyquist_validation`, `model_overrides`, `project_type`, `granularity`

**Runtime Integration:**
- Claude Code: Agents deployed to `~/.claude/agents/` with YAML frontmatter
- OpenCode: Agents deployed without frontmatter, path varies by version
- Pi: Agents converted to Pi format (Python script strips frontmatter)
- All agents loaded automatically by runtime on startup

---

*Integration audit: 2026-03-11*
