# Keystone

Agent toolkit that bridges BMAD (planning) and GSD (execution) for Claude Code.

## Structure

- `agents/` — Core agents (entry, bridge, domain, maintenance)
- `agents/optional/` — Niche domain agents not installed by default
- `hooks/` — Shell hooks for session-start, post-write safety, update banner
- `skills/` — Wizard routing, detection, toolkit discovery
- `scripts/` — Install, restore, weekly update check
- `tests/` — Unit and structural tests (bash)
- `docs/` — Architecture, workflows, troubleshooting

## Conventions

- Agents use YAML frontmatter (`description`, `subagent_type`, tools list)
- Hooks must be non-blocking — output to stderr, always `exit 0`
- Hooks include early-exit guards: skip work when no BMAD/GSD markers present
- Install script: core agents by default, `--with-domains` for optional
- All shell scripts use `set -uo pipefail` (not `-e` in hooks — grep returns non-zero on no-match)

## Testing

```bash
bash tests/phase-01-unit.sh     # Unit tests for detection logic
bash tests/phase-03-structural.sh  # Structural validation
```

## Key Design Principle

Keystone must not add context overhead to projects that don't use it. Hooks early-exit when no framework markers are detected. Optional agents are separated from core. The install script is two-stage.
