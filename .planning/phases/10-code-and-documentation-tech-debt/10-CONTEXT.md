# Phase 10: Code & Documentation Tech Debt - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix 4 code-level tech debt items identified by the v1.0 milestone audit: Route C ladder divergence, orchestrator Operation B path hardcoding, config.json template hardcoding, and ROADMAP staleness. No new capabilities — correctness fixes and documentation accuracy only.

</domain>

<decisions>
## Implementation Decisions

### Route C ladder alignment (SC #1)
- Add VERIFICATION.md check to wizard-detect.sh file-state ladder, placed above UAT check (top-of-ladder = "complete")
- When VERIFICATION.md is detected, use the same next_command advance logic as uat-passing (skip to next phase or complete-milestone)
- Update the sync note in wizard-backing-agent.md Route C Step 3 to reflect that both ladders now check VERIFICATION.md — only document remaining difference ("not started" vs "executing" label)

### Operation B dual-path fix (SC #2)
- bmad-gsd-orchestrator.md Operation B Step 2 uses dual-path find to locate story files: search both `docs/stories/` and `_bmad-output/stories/`
- Consistent with the dual-path find pattern established in Phase 8 for Operation A
- Write target (bmad-outputs/STATUS.md) stays single-path — reads are dual-path, writes are single-path

### config.json bmad_source paths (SC #3)
- Operation A writes actual detected file paths into config.json bmad_source, not templated `docs/` paths
- e.g., if PRD was found at `_bmad-output/planning-artifacts/prd.md`, write that exact path
- stories_dir uses the single directory where story files were actually found (not an array, not both directories)

### ROADMAP checkbox cleanup (SC #4)
- Check ALL plan checkboxes (`- [ ]` → `- [x]`) for all completed phases (1–9), not just audit-flagged ones
- Update all stale plan counts in Phase Details sections where "TBD" or incorrect counts don't match reality
- Ensure progress table and Phase Details sections are consistent

### Claude's Discretion
- Status box display for "complete" vs "uat-passing" phase status
- Phase-to-story file mapping approach in Operation B (phase number vs content match)
- Order of operations for the four fixes
- Whether ROADMAP needs any other consistency fixes beyond checkboxes and plan counts

</decisions>

<specifics>
## Specific Ideas

No specific requirements — all items are concretely defined by the v1.0 milestone audit (`v1.0-MILESTONE-AUDIT.md`).

Key audit references:
- Tech debt Phase 05: "Route C file-state ladder adds VERIFICATION.md as 'complete' condition that wizard-detect.sh never checks"
- Tech debt agents-bridge: "Operation B Step 2 reads docs/stories/ hardcoded" and "config.json template hardcodes docs/ in bmad_source paths"
- Tech debt Phase 06: "ROADMAP.md plan checkboxes unchecked despite '2/2 plans complete' in summary table"

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `wizard-detect.sh` lines 69-100: Existing file-state ladder (HAS_UAT > HAS_PLAN > HAS_CONTEXT) — add HAS_VERIFICATION above HAS_UAT
- `wizard-detect.sh` lines 80-89: uat-passing advance logic (check total phases, advance or complete-milestone) — reuse for "complete" status
- `wizard-backing-agent.md` Route C Step 3 lines 243-269: File-state ladder with VERIFICATION.md already present — update sync note only

### Established Patterns
- Dual-path find: `find docs/stories _bmad-output/stories -maxdepth 1 -name "story-*.md" 2>/dev/null` — used in wizard-detect.sh and wizard-backing-agent.md
- Operation A already uses dual-path find for PRD/architecture (fixed in Phase 8) — Operation B should match
- config.json bmad_source is written by Operation A Step 2 — the template lives in the orchestrator markdown

### Integration Points
- `skills/wizard-detect.sh` lines 69-100: File-state ladder to modify (add VERIFICATION.md check)
- `skills/wizard-backing-agent.md` Route C Step 3: Sync note to update
- `agents/bridge/bmad-gsd-orchestrator.md` Operation B Step 2: Story file path to fix
- `agents/bridge/bmad-gsd-orchestrator.md` Operation A Step 2: config.json template to fix
- `.planning/ROADMAP.md`: Checkboxes and plan counts to update

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 10-code-and-documentation-tech-debt*
*Context gathered: 2026-03-13*
