# Hooks and Scripts

How Keystone's automation layer works -- what fires when, what it checks, and how to configure it.

## Hook Lifecycle

Hooks are shell scripts that fire on Claude Code lifecycle events. They're registered in `~/.claude/settings.json` and output warnings to stderr. Keystone's hooks always exit 0 -- they warn but never block.

### Session Start Sequence

Two hooks run in order when a Claude Code session opens:

**1. `stack-update-banner.sh`** reads `~/.claude/stack-update-cache.json`. If BMAD or GSD has a newer version available, or if required agent fixes are pending, it displays a one-line notice. If the cache is older than 7 days, it triggers a background refresh (detached, non-blocking).

**2. `session-start.sh`** scans the current directory for BMAD markers (`_bmad/`, `.bmad/`, `docs/prd*.md`), GSD markers (`.planning/config.json`), and context files (`CLAUDE.md`, `AGENTS.md`). Displays a state banner showing BMAD presence, GSD active phase, and the next recommended command.

Additional notices appear when appropriate:
- Missing `CLAUDE.md` -- warning to create one
- Infrastructure project detected -- dry-run reminder
- No framework present -- suggestion to say `set up this project`

Logs session context to `~/.claude/logs/session-start.log`.

### Post-Write Checks

`post-write-check.sh` runs after every file write via the `PostToolUse` event (matcher: `Write`). The checks depend on file type:

| File type | What it checks |
|-----------|---------------|
| `.sh`, `.bash` | Hardcoded secrets, `set -euo pipefail`, dry-run flag if destructive commands present |
| `.ps1` | Hardcoded secrets, `ErrorActionPreference`/`SupportsShouldProcess`, hardcoded Windows paths |
| `.py`, `.js`, `.ts`, `.json`, `.yaml`, `.yml`, `.env` | Hardcoded secrets |
| `.gd` (GDScript) | Absolute node paths, `yield()` syntax (Godot 3), game logic in UI scripts |

Issues appear as warnings or errors on stderr. The hook never blocks -- it warns and exits 0.

## Scripts

### install-runtime-support.sh

One-command installer. Accepts `--claude`, `--opencode`, `--pi`, or `--all`.

What it does:
1. Installs BMAD via `npx bmad-method install`
2. Installs GSD for each selected runtime
3. Copies agents to `~/.claude/agents/`
4. Deploys hooks to `~/.claude/hooks/` and registers them in `settings.json`
5. Sets up the weekly version check cron job

### restore.sh

Restores agent configs, hooks, and settings from a backup directory. Supports `--dry-run` to preview changes before applying. Accepts `--target claude|pi|opencode|all`.

Since `restore.sh` uses `rsync --delete`, files in the destination that aren't in the backup get removed. Always preview with `--dry-run` first.

### weekly-stack-check.sh

Cron target that fetches current npm versions for BMAD, GSD, and Pi, compares against installed versions, and writes results to `~/.claude/stack-update-cache.json`. Designed to run Monday at 09:00. Does not apply changes.

## settings.json Registration

The installer patches `~/.claude/settings.json` to register hooks. If you manage settings manually, add these entries:

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

## CLAUDE.md Templates

Each project should have a `.claude/CLAUDE.md` describing the project type. The session-start hook reads this for context. Here's a minimal example:

```markdown
# Project: My App

## Type
web

## Stack
Next.js 14, TypeScript, Tailwind CSS

## Key Conventions
- Component files: PascalCase
- API routes: REST, JSON responses
```

See [workflows.md](workflows.md) for full templates by project type (web, infra, game, docs).
