# Technology Stack

**Analysis Date:** 2026-03-11

## Languages

**Primary:**
- Bash/Shell - All scripts and automation in `scripts/`, `hooks/`, and agent shell commands
- Markdown - Agent definitions and documentation in `agents/` directory
- Python 3 - Utility scripts for agent deployment and settings.json manipulation
- JSON - Configuration format for project state and version caching

**Secondary:**
- JavaScript - Referenced through npm package ecosystem; agents guide use of JavaScript/TypeScript projects
- YAML - Project configuration and CI integration

## Runtime

**Environment:**
- Bash/Zsh shell (required for all scripts and hooks)
- Python 3 (required for agent deployment, Pi conversion, settings.json patching)
- Node.js with npm (required for BMAD and GSD installation and version checking)

**Package Manager:**
- npm (Node Package Manager)
- Cron (scheduling for weekly version checks)

## Frameworks

**Core Frameworks (Installed via npm):**
- BMAD Method (npm: `bmad-method`) - Planning and documentation framework
- GSD (Get Shit Done) (npm: `get-shit-done-cc`) - Phase-based execution framework
- Pi Coding Agent (npm: `@mariozechner/pi-coding-agent`) - Optional runtime support
- Claude Code - Primary AI runtime environment
- OpenCode - Secondary AI runtime (optional)

**Development Patterns:**
- Custom Agent system - 11 markdown-based agents deployed to runtime directories
- Hook system - Bash hooks triggered at SessionStart and PostToolUse events
- Command system - Slash commands for BMAD (/analyst, /architect, /pm, etc.) and GSD (/gsd:*)

## Key Dependencies

**Critical:**
- `bmad-method` - Handles structured planning documents (PRD, architecture, stories). Must be installed via `npx bmad-method install`
- `get-shit-done-cc` - Manages phase-based execution with .planning/ structure. Installed per-runtime (Claude Code, OpenCode, Pi)
- `@mariozechner/pi-coding-agent` - Optional coding agent for Pi runtime support
- `jq` - JSON processor for version cache management in `scripts/weekly-stack-check.sh`
- `@anthropic-ai/claude-code` - Required npm package for Claude Code CLI

**Infrastructure:**
- npm registry access - For fetching version information and package installation
- Crontab - For scheduling weekly version checks (Monday 09:00)
- GitHub API - For fetching changelog data from BMAD and GSD repositories

## Configuration

**Environment:**
- Claude Code settings.json - Stores hook registrations (SessionStart, PostToolUse)
- CLAUDE.md (per-project) - Project-specific conventions, type detection, and stack information
- AGENTS.md (per-project, optional) - Custom agent definitions
- .planning/config.json (created by orchestrator) - GSD project configuration with phase definitions
- .planning/STATE.md (GSD-managed) - Tracks current active phase

**Build/Installation:**
- `install-runtime-support.sh` - Main installer script with arguments for target runtimes (--claude, --opencode, --pi, --all)
- `restore.sh` - Restores agent configurations from backup with --dry-run support
- `weekly-stack-check.sh` - Standalone version check script for cron integration

**Version Caching:**
- `~/.claude/stack-update-cache.json` - Cached version information (BMAD, GSD, Pi) to avoid performance penalty at session start
- `~/.claude/logs/` - Session logs, update checks, post-write checks stored here

## Platform Requirements

**Development:**
- macOS, Linux, or Unix-like system with Bash/Zsh
- Node.js (any LTS version) with npm
- Python 3.6+
- npm access to public registry (npmjs.org)
- jq command-line JSON processor
- cron support (for weekly checks)
- Write access to ~/.claude/ or equivalent runtime config directory

**Production (Claude Code/OpenCode/Pi):**
- Claude Code v2.0+ (primary runtime)
- OpenCode v1.0+ (secondary runtime)
- Pi Coding Agent (optional secondary runtime)
- Network connectivity to GitHub and npm registry for version checks
- Local storage at ~/.claude/ (or $OPENCODE_CONFIG_DIR for OpenCode)

**Optional:**
- PowerShell 5.1+ (for Windows infrastructure scripts written by agents)
- Godot 4.x (for game development projects)
- Docker (for infrastructure automation projects)

---

*Stack analysis: 2026-03-11*
