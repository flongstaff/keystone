# Troubleshooting

Common issues and how to fix them.

## The wizard doesn't activate when I say "wizard"

Verify the agent is installed:

```bash
ls ~/.claude/agents/project-setup-wizard.md
```

If missing, re-run the installer:

```bash
bash scripts/install-runtime-support.sh --claude
```

Then restart Claude Code.

## The session-start banner doesn't appear

Check that hooks are registered in `settings.json`:

```bash
cat ~/.claude/settings.json | python3 -m json.tool | grep -A 5 "SessionStart"
```

If missing, re-run the installer or manually add the hook entries. See [hooks-and-scripts.md](hooks-and-scripts.md) for the exact JSON.

## The update banner says "No update cache yet" every session

The cache hasn't been written. Run the weekly check manually:

```bash
bash ~/.claude/scripts/weekly-stack-check.sh
```

Or say `check for updates` to trigger the `stack-update-watcher` agent, which also writes the cache.

## bmad-gsd-orchestrator blocks (PRD or architecture missing)

The orchestrator requires both `docs/prd-[project].md` and `docs/architecture-[project].md`. Run the missing BMAD agents:

```
/prd              # if PRD is missing
/architect        # if architecture is missing
```

Then re-say `initialise GSD from BMAD docs`.

## phase-gate-validator fails Gate 2 (dirty working tree)

Gate 2 requires a clean git working tree. Commit or stash changes before running the validator:

```bash
git status
git add -p
git commit -m "fix: resolve remaining issues from phase N"
```

Then re-run the gate check.

## phase-gate-validator fails Gate 1 (missing UAT evidence)

The UAT file at `.planning/phases/[N]-UAT.md` doesn't cover one or more acceptance criteria. Options:

1. Re-run `/gsd:verify-work N` to regenerate UAT coverage
2. If the criterion was met but not documented, manually add a verification note to the UAT file
3. If the criterion wasn't met, run `/gsd:execute-phase N` again

## post-write-check.sh warns about a false positive

The hook uses heuristics and occasionally flags test fixtures or placeholder values. It's advisory only -- it never blocks. If you're confident the value isn't a real secret, ignore the warning.

The hook already skips obvious non-secrets: `example`, `placeholder`, `changeme`, `your-`, and environment variable references.

## Pi agents installed but not loading

Pi agents live in `~/.pi/agent/` as `.md` files with YAML frontmatter stripped. Verify:

```bash
ls ~/.pi/agent/*.md
```

If files are present but agents aren't available, check the Pi version and its documentation for the correct agent directory path.

## GSD context rot during a long phase

If quality degrades mid-phase (the model loses earlier decisions), switch to `/gsd:quick` for remaining tasks. Each `/gsd:quick` call spawns a fresh context.

After the phase finishes, run `context-health-monitor` to catch drift, then `phase-gate-validator` as usual.

## Weekly cron isn't running

Check the cron entry:

```bash
crontab -l | grep weekly-stack-check
```

If missing, add it:

```bash
(crontab -l 2>/dev/null; echo "0 9 * * 1 /bin/bash $HOME/.claude/scripts/weekly-stack-check.sh >> $HOME/.claude/logs/update-checks.log 2>&1") | crontab -
```

## Hook not firing

Check that the hook script is executable:

```bash
chmod +x ~/.claude/hooks/*.sh
```

Then restart Claude Code.

## Agent not auto-detected

The `description` field in the agent's YAML frontmatter needs to be specific enough for Claude to match it. Add more trigger phrases to the description and restart Claude Code.
