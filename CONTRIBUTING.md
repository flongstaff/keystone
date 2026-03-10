# Contributing to Keystone

Thanks for your interest in contributing. This guide covers the dev setup, how the pieces work, and how to add your own agents or hooks.

## Development Setup

1. Clone the repo:

```bash
git clone https://github.com/flongstaff/keystone
cd keystone
```

2. Install the stack locally:

```bash
bash scripts/install-runtime-support.sh --claude
```

3. Restart Claude Code and verify:

```
set up this project
```

The wizard should detect the project state and show options.

## Project Structure

```
agents/          # Claude Code subagent definitions (.md with YAML frontmatter)
  entry/         # Front-door agents (wizard, advisor)
  bridge/        # BMAD-GSD integration agents
  domain/        # Project-type specialists
  maintenance/   # Stack update monitoring
hooks/           # Shell scripts triggered by Claude Code events
scripts/         # Standalone install/restore/cron scripts
skills/          # Wizard skills and detection logic
tests/           # Shell-based test suites
docs/            # User-facing documentation
```

## How Agents Work

Each agent is a Markdown file with YAML frontmatter. Claude Code reads the `description` field to decide when to activate an agent. The body is the agent's system prompt.

```yaml
---
name: my-agent
description: >
  When this agent activates and what trigger phrases to use.
model: sonnet
tools:
  - Read
  - Write
  - Bash
---

# Agent Name

Your system prompt goes here...
```

**Key rules:**

- The `description` field is what Claude reads to auto-route. Be explicit about trigger phrases.
- Keep agents focused -- one job per agent.
- Use `sonnet` for most agents. Reserve `opus` for complex reasoning tasks.

## How Hooks Work

Hooks are shell scripts registered in `~/.claude/settings.json`. They fire on Claude Code lifecycle events:

- `SessionStart` -- runs when a session opens
- `PostToolUse` -- runs after a specific tool (e.g., Write)

Hooks receive context via stdin as JSON. They output warnings to stderr. A hook should never block execution (always exit 0) unless it's catching something critical.

## How to Add a New Agent

1. Create `agents/<category>/my-agent.md` with the frontmatter and system prompt.
2. Add a row to the agents table in `docs/agents.md`.
3. Test that Claude Code auto-detects it by using one of your trigger phrases.
4. Run the tests: `bash tests/phase-03-structural.sh`

## How to Add a New Hook

1. Create `hooks/my-hook.sh` with `#!/bin/bash` and `set -euo pipefail`.
2. Document the hook in `docs/hooks-and-scripts.md`.
3. Add the registration snippet (for `settings.json`) to the docs.
4. Run shellcheck: `shellcheck hooks/my-hook.sh`

## Commit Conventions

We use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` -- new agent, hook, skill, or feature
- `fix:` -- bug fix
- `docs:` -- documentation only
- `chore:` -- maintenance, CI, tooling
- `refactor:` -- restructuring without behaviour change

Keep commits atomic -- one concern per commit.

## Pull Requests

- Branch from `main`, squash merge back
- PR title follows conventional commit format
- PR description explains **why**, not just what
- Run `shellcheck` and the test suite before opening

## Code of Conduct

This project follows the [Contributor Covenant v2.1](https://www.contributor-covenant.org/version/2/1/code_of_conduct/). Be respectful and constructive.

## Questions?

Open an issue or start a discussion on GitHub.
