# Phase 16: Global Deployment Sync - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Sync all 4 verified v1.1 skill files from project-local `skills/` to `~/.claude/skills/`, verify cross-project functionality, and confirm machine-specific toolkit data is gitignored. No new capabilities — deployment sync, path verification, and gitignore confirmation only. Milestone closure is a separate step after this phase.

</domain>

<decisions>
## Implementation Decisions

### File set & deployment location
- 4 files deployed to `~/.claude/skills/` flat (same directory):
  1. `toolkit-discovery.sh` (NEW — does not exist globally yet)
  2. `wizard-detect.sh` (v1.1 changes: toolkit discovery call, toolkit JSON write)
  3. `wizard.md` (v1.1 changes: Step 2.5 injection, dynamic catalog display)
  4. `wizard-backing-agent.md` (v1.1 changes: Step 2.5 bridge capability block)
- Sync all 4 files regardless of individual diff size — idempotent, prevents drift
- `cp -p` preserves permissions (executable bit for .sh files)
- No selective sync — copy everything, verify everything

### Path resolution verification
- wizard-detect.sh uses `SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)` to locate toolkit-discovery.sh
- Explicitly verify this resolves correctly from `~/.claude/skills/` context (not just project-local)
- Test: run `wizard-detect.sh` from a non-Keystone directory and confirm toolkit-discovery.sh is found

### Cross-project functional test
- Two-step manual bash test from /tmp (or any non-Keystone directory):
  1. Run `bash ~/.claude/skills/toolkit-discovery.sh` standalone — verify it finds `~/.claude/agents/` and produces valid JSON with correct counts
  2. Run `bash ~/.claude/skills/wizard-detect.sh` — verify `wizard-state.json` contains `toolkit` object with discovery counts matching step 1
- toolkit-registry.json writes to the calling project's `.claude/` directory (alongside wizard-state.json)
- Test cleanup: Claude's discretion

### Post-sync verification (carried from Phase 9/11)
- `diff` between each project-local and global file — expect zero output for all 4 files
- `test -x ~/.claude/skills/wizard-detect.sh` — executable bit preserved
- `test -x ~/.claude/skills/toolkit-discovery.sh` — executable bit preserved (new file)

### Gitignore
- Project-level `.gitignore` is sufficient (already contains `toolkit-registry.json` entry)
- Verify-only — no changes needed. Confirm:
  1. `toolkit-registry.json` appears in `.gitignore`
  2. `toolkit-registry.json` does not appear in `git status` output

### Milestone closure
- NOT included in Phase 16 plan — separate `/gsd:complete-milestone` invocation after verification
- Phase 16 next-steps should note: "After verification passes, run `/gsd:complete-milestone` to close v1.1"
- No v1.1 regression smoke test — each prior phase verified its own features; Phase 16 scope is deployment sync only

### Claude's Discretion
- Exact task breakdown and wave structure
- VERIFICATION.md format and additional assertions beyond core checks
- Test artifact cleanup approach (remove /tmp test files or leave for OS cleanup)
- Whether to combine all operations into a single plan or split

</decisions>

<specifics>
## Specific Ideas

- This is the third deployment sync phase (after Phase 9 and Phase 11) — the pattern is well-established
- toolkit-discovery.sh is the only genuinely new deployment (other 3 files are updates to already-deployed globals)
- Current diffs confirmed during scout:
  - `wizard.md`: Large diff — Step 2.5 injection block (~80 lines), dynamic catalog display
  - `wizard-backing-agent.md`: Medium diff — Step 2.5 bridge capability block (~22 lines)
  - `wizard-detect.sh`: Medium diff — toolkit discovery integration (~24 lines), toolkit JSON in state output
  - `toolkit-discovery.sh`: Entirely new file (not present globally)

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- Project-local `skills/wizard.md`: Source of truth for global deployment (includes all v1.1 changes through Phase 15)
- Project-local `skills/wizard-backing-agent.md`: Source of truth (includes Phase 14 Step 2.5 capability block)
- Project-local `skills/wizard-detect.sh`: Source of truth (includes Phase 13 toolkit discovery integration)
- Project-local `skills/toolkit-discovery.sh`: Source of truth (Phase 12 core scanner)

### Established Patterns
- Phase 9 and 11 deployed via direct `cp -p` — same mechanism reused
- Global skills directory: flat files at `~/.claude/skills/` level
- `cp -p` for permission-sensitive files (wizard-detect.sh executable bit precedent)
- `diff` verification post-deployment (Phase 9/11 pattern)
- Orphaned `wizard-router/` directory already deleted in Phase 9 — no orphans to clean this time

### Integration Points
- `~/.claude/skills/wizard.md`: Read by Claude Code when `/wizard` is invoked from any project
- `~/.claude/skills/wizard-backing-agent.md`: Invoked via Task() from wizard.md
- `~/.claude/skills/wizard-detect.sh`: Called by wizard.md for state detection
- `~/.claude/skills/toolkit-discovery.sh`: Called by wizard-detect.sh for toolkit scanning (SCRIPT_DIR relative path)
- `.gitignore`: Contains `toolkit-registry.json` entry (verify-only)

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 16-global-deployment-sync*
*Context gathered: 2026-03-13*
