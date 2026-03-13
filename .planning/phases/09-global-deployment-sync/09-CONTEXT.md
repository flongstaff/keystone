# Phase 9: Global Deployment Sync - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Redeploy project-local skill files to `~/.claude/skills/` and delete orphaned `wizard-router/` directory so `/wizard` works correctly from any project context. No new capabilities — deployment sync and orphan cleanup only.

</domain>

<decisions>
## Implementation Decisions

### Sync mechanism
- Direct `cp -p` of all 3 Keystone skill files (wizard.md, wizard-backing-agent.md, wizard-detect.sh) from project-local `skills/` to `~/.claude/skills/`
- Copy all files regardless of diff status — idempotent, ensures completeness
- `cp -p` preserves permissions (wizard-detect.sh executable bit)
- Order: delete orphans first, then copy fresh files (clean slate approach)

### Orphan cleanup
- `rm -rf ~/.claude/skills/wizard-router/` — direct deletion, no temp backup
- Known orphan only — no scan for other stale files
- `rm -rf` is idempotent — no existence check needed before deletion

### Post-sync verification
- `diff` between each local and global file — expect zero output (matches SC #4)
- `test ! -d ~/.claude/skills/wizard-router/` to confirm orphan deletion (SC #3)
- `test -x ~/.claude/skills/wizard-detect.sh` to confirm executable bit preserved
- Repeatable quick-run command in VALIDATION.md for future audit use

### Claude's Discretion
- Exact task breakdown and wave structure
- VALIDATION.md format and additional assertions beyond the core checks
- Whether to combine operations into a single plan or split across multiple

</decisions>

<specifics>
## Specific Ideas

- Phase 8 CONTEXT.md SC #7 claimed `~/.claude/skills/wizard-router/` "already doesn't exist on disk" — but the scout confirmed it **does** exist (contains SKILL.md + wizard-detect.sh). This discrepancy should be noted: likely the audit checked a different path or the directory was recreated by a later operation.

Key diffs found during discussion:
- `wizard.md`: Global has 4 stale wizard-router catalog entries in all 4 post-status menu variants (removed locally in Phase 8 plan 01)
- `wizard-backing-agent.md`: Global Step 4 fallback still references invalid `/bmad-gsd-orchestrator` (fixed locally in Phase 8 plan 01)
- `wizard-detect.sh`: Already in sync — no diff

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- Project-local `skills/wizard.md` (32k, current as of Phase 8): Source of truth for global deployment
- Project-local `skills/wizard-backing-agent.md` (13k, current as of Phase 8): Source of truth for global deployment
- Project-local `skills/wizard-detect.sh` (15k, current as of Phase 8): Already in sync but will be re-copied for completeness

### Established Patterns
- Previous phases deployed via direct cp — no deploy script or automation exists
- Global skills directory structure: flat files at `~/.claude/skills/` level, subdirectories for multi-file skills (wizard-router was one)
- `cp -p` used elsewhere in the project for permission-sensitive files

### Integration Points
- `~/.claude/skills/wizard.md`: Read by Claude Code when `/wizard` is invoked from any project
- `~/.claude/skills/wizard-backing-agent.md`: Invoked via Task() from wizard.md
- `~/.claude/skills/wizard-detect.sh`: Called by wizard.md for state detection
- `~/.claude/skills/wizard-router/`: Currently registered as a skill — orphaned, interferes with clean `/wizard` routing

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 09-global-deployment-sync*
*Context gathered: 2026-03-13*
