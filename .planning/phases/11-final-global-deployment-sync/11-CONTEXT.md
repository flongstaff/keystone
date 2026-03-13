# Phase 11: Final Global Deployment Sync - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix the Option 3 cross-reference label in wizard.md, redeploy all 3 Keystone skill files to `~/.claude/skills/`, and verify zero diff. No new capabilities — label fix + deployment sync only.

</domain>

<decisions>
## Implementation Decisions

### Option 3 label fix (SC #1)
- `wizard.md` line 321: gsd-only non-uat-passing Option 3 (Validate phase) cross-references "full-stack Option 4" — should say "Option 3"
- Fix in project-local `skills/wizard.md` first, then deploy to global
- One-word change: "Option 4" → "Option 3"

### Sync mechanism (carried from Phase 9)
- `cp -p` of all 3 skill files from project-local `skills/` to `~/.claude/skills/`
- Copy all files regardless of individual diff status — idempotent, ensures completeness
- `cp -p` preserves permissions (wizard-detect.sh executable bit)
- Order: fix label first, then copy all files

### Post-sync verification (carried from Phase 9)
- `diff` between each local and global file — expect zero output (SC #5)
- `test -x ~/.claude/skills/wizard-detect.sh` to confirm executable bit preserved
- Repeatable quick-run command in VERIFICATION.md for future audit use

### Claude's Discretion
- Exact task breakdown and wave structure
- VERIFICATION.md format and additional assertions beyond core checks
- Whether to combine all operations into a single plan or split

</decisions>

<specifics>
## Specific Ideas

Phase 10 changes that need syncing (confirmed via diff):
- `wizard.md`: 6 lines changed — added `"complete"` status handling alongside `"uat-passing"` in both full-stack and gsd-only menu conditionals, simplified question text
- `wizard-backing-agent.md`: 1 line changed — Route C sync note updated to reflect both ladders now check VERIFICATION.md
- `wizard-detect.sh`: ~12 lines added — VERIFICATION.md ladder check above UAT check, with same advance logic (next phase or complete-milestone)

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- Project-local `skills/wizard.md` (~32k, current as of Phase 10): Source of truth for global deployment
- Project-local `skills/wizard-backing-agent.md` (~13k, current as of Phase 10): Source of truth for global deployment
- Project-local `skills/wizard-detect.sh` (~15k, current as of Phase 10): Source of truth for global deployment

### Established Patterns
- Phase 9 deployed via direct `cp -p` — same mechanism reused here
- Global skills directory: flat files at `~/.claude/skills/` level
- Orphaned `wizard-router/` directory already deleted in Phase 9

### Integration Points
- `~/.claude/skills/wizard.md`: Read by Claude Code when `/wizard` is invoked from any project
- `~/.claude/skills/wizard-backing-agent.md`: Invoked via Task() from wizard.md
- `~/.claude/skills/wizard-detect.sh`: Called by wizard.md for state detection

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 11-final-global-deployment-sync*
*Context gathered: 2026-03-13*
