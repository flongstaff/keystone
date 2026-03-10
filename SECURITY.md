# Security Policy

## Scope

Keystone consists of Markdown agent definitions, shell scripts, and documentation. It doesn't run a server or process user data directly. The main security surface is:

- **Shell scripts** (`hooks/`, `scripts/`, `skills/`, `tests/`) -- these run on your machine
- **The install script** (`scripts/install-runtime-support.sh`) -- copies files to `~/.claude/` and patches `settings.json`

## Reporting a Vulnerability

If you find a security issue (e.g., a script that could leak credentials, an injection vector in a hook, or an unsafe default), please report it privately:

1. **Email:** Open a GitHub Security Advisory at [github.com/flongstaff/keystone/security/advisories](https://github.com/flongstaff/keystone/security/advisories)
2. **Do not** open a public issue for security vulnerabilities

I'll acknowledge reports within 48 hours and aim to ship a fix within 7 days for confirmed issues.

## What the Install Script Does

`install-runtime-support.sh` performs the following actions:

1. Installs BMAD via `npx bmad-method install`
2. Installs GSD via `npx get-shit-done-cc`
3. Copies agent `.md` files to `~/.claude/agents/`
4. Copies hook `.sh` files to `~/.claude/hooks/`
5. Patches `~/.claude/settings.json` to register hooks
6. Optionally sets up a weekly cron job for version checks

It does **not**:
- Run anything with elevated privileges
- Send data to external servers
- Modify files outside `~/.claude/`, `~/.pi/`, or `~/.config/opencode/`

Review the script before running it. You can also install manually by copying the files yourself.

## Best Practices

- The `post-write-check.sh` hook warns about hardcoded secrets but doesn't catch everything. Always review commits before pushing.
- Never commit `.env` files, credentials, or API keys. The `.gitignore` excludes common patterns, but verify.
- If you're using Keystone for infrastructure work, the `it-infra-agent` enforces dry-run flags and secret hygiene, but human review remains essential.
