# Phase 10: Code & Documentation Tech Debt - Research

**Researched:** 2026-03-13
**Domain:** Bash shell scripting, markdown documentation, GSD orchestrator files
**Confidence:** HIGH

## Summary

Phase 10 is a focused correctness fix across four discrete tech debt items identified by the v1.0 milestone audit. No new capabilities are added. All four items involve editing existing files at precisely identified locations. The work divides cleanly into: (1) a logic change to `wizard-detect.sh` and a matching sync note update in `wizard-backing-agent.md`; (2) a path fix in `bmad-gsd-orchestrator.md` Operation B; (3) a config.json template change in `bmad-gsd-orchestrator.md` Operation A Step 3; and (4) a bulk checkbox update across ROADMAP.md.

All decisions are locked in CONTEXT.md. No external library research is required — every change is in project-authored markdown or bash files. The complexity risk is very low for items 2, 3, and 4. Item 1 (ladder alignment) carries slightly higher risk because the bash logic must exactly mirror the advance behavior already used for `uat-passing` in the existing ladder.

**Primary recommendation:** Execute the four fixes as four tasks in a single plan, in order: ladder fix (highest risk first, so it can be reviewed before low-risk cosmetic fixes), Operation B path fix, config.json template fix, and ROADMAP checkbox sweep.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Route C ladder alignment (SC #1)**
- Add VERIFICATION.md check to wizard-detect.sh file-state ladder, placed above UAT check (top-of-ladder = "complete")
- When VERIFICATION.md is detected, use the same next_command advance logic as uat-passing (skip to next phase or complete-milestone)
- Update the sync note in wizard-backing-agent.md Route C Step 3 to reflect that both ladders now check VERIFICATION.md — only document remaining difference ("not started" vs "executing" label)

**Operation B dual-path fix (SC #2)**
- bmad-gsd-orchestrator.md Operation B Step 2 uses dual-path find to locate story files: search both `docs/stories/` and `_bmad-output/stories/`
- Consistent with the dual-path find pattern established in Phase 8 for Operation A
- Write target (bmad-outputs/STATUS.md) stays single-path — reads are dual-path, writes are single-path

**config.json bmad_source paths (SC #3)**
- Operation A writes actual detected file paths into config.json bmad_source, not templated `docs/` paths
- e.g., if PRD was found at `_bmad-output/planning-artifacts/prd.md`, write that exact path
- stories_dir uses the single directory where story files were actually found (not an array, not both directories)

**ROADMAP checkbox cleanup (SC #4)**
- Check ALL plan checkboxes (`- [ ]` → `- [x]`) for all completed phases (1–9), not just audit-flagged ones
- Update all stale plan counts in Phase Details sections where "TBD" or incorrect counts don't match reality
- Ensure progress table and Phase Details sections are consistent

### Claude's Discretion
- Status box display for "complete" vs "uat-passing" phase status
- Phase-to-story file mapping approach in Operation B (phase number vs content match)
- Order of operations for the four fixes
- Whether ROADMAP needs any other consistency fixes beyond checkboxes and plan counts

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

## Standard Stack

No external libraries are used. All edits are to:
- `skills/wizard-detect.sh` — bash script
- `skills/wizard-backing-agent.md` — markdown agent file
- `agents/bridge/bmad-gsd-orchestrator.md` — markdown agent file
- `.planning/ROADMAP.md` — markdown documentation

## Architecture Patterns

### Item 1: wizard-detect.sh Ladder Addition

The existing file-state ladder lives at lines 69–100 of `skills/wizard-detect.sh`. The ladder currently reads:

```
HAS_UAT > HAS_PLAN > HAS_CONTEXT > (else executing)
```

The decision is to add `HAS_VERIFICATION` as the new top condition, above `HAS_UAT`. When VERIFICATION.md is present, the phase is "complete" — same advance logic as `uat-passing`: check if this is the last phase (`PHASE_NUM -ge TOTAL_RAW`), and if so set `GSD_NEXT_CMD="/gsd:complete-milestone"`, otherwise advance to the next phase with `GSD_NEXT_CMD="/gsd:discuss-phase $NEXT_NUM"`. The status string should be `"complete"`.

**Exact pattern to replicate (uat-passing advance logic from lines 80-89):**
```bash
# Check if all phases done
TOTAL_RAW=$(grep -c "^### Phase" .planning/ROADMAP.md 2>/dev/null || echo 0)
if [ "$PHASE_NUM" -ge "$TOTAL_RAW" ] && [ "$TOTAL_RAW" -gt 0 ]; then
    GSD_NEXT_CMD="/gsd:complete-milestone"
    GSD_PHASE_STATUS="complete"
else
    NEXT_NUM=$((PHASE_NUM + 1))
    GSD_NEXT_CMD="/gsd:discuss-phase $NEXT_NUM"
    GSD_PHASE_STATUS="uat-passing"
fi
```

**New VERIFICATION.md check block to insert before the `if [ "$HAS_UAT" -gt 0 ]` block:**
```bash
HAS_VERIFICATION=$(find "$LATEST_PHASE_DIR" -maxdepth 1 -name "*-VERIFICATION.md" 2>/dev/null | head -1 | wc -l | tr -d ' ')

if [ "$HAS_VERIFICATION" -gt 0 ]; then
    # Phase is verified complete — same advance logic as uat-passing
    TOTAL_RAW=$(grep -c "^### Phase" .planning/ROADMAP.md 2>/dev/null || echo 0)
    if [ "$PHASE_NUM" -ge "$TOTAL_RAW" ] && [ "$TOTAL_RAW" -gt 0 ]; then
        GSD_NEXT_CMD="/gsd:complete-milestone"
    else
        NEXT_NUM=$((PHASE_NUM + 1))
        GSD_NEXT_CMD="/gsd:discuss-phase $NEXT_NUM"
    fi
    GSD_PHASE_STATUS="complete"
elif [ "$HAS_UAT" -gt 0 ]; then
    ...existing uat logic...
```

Note: `TOTAL_RAW` is already computed inside the `uat-passing` branch. The VERIFICATION.md branch needs its own local copy of that computation, or the code can be refactored to compute `TOTAL_RAW` once before the entire ladder. Either approach is valid.

### Item 1b: wizard-backing-agent.md Sync Note

Route C Step 3 (lines 243–269 of `skills/wizard-backing-agent.md`) already has `HAS_VERIFICATION` in its ladder and uses `STATUS="complete"`. The sync note at line 271 currently states:

> "Note: This ladder syncs with wizard-detect.sh (same labels: plans-ready, context-ready, uat-failing, uat-passing). Two intentional differences: (1) Route C adds VERIFICATION.md as top-of-ladder 'complete' — detect.sh doesn't check it because it only evaluates the latest in-progress phase; (2) Route C uses 'not started' for empty phase dirs — detect.sh uses 'executing'. If wizard-detect.sh changes its ladder, update this to match."

After the fix, difference (1) is eliminated. The updated note should state that VERIFICATION.md is now checked by both ladders, and only document the remaining difference: (2) "not started" vs "executing" label for empty phase dirs. The note should also remove the instruction to update if detect.sh changes, since they are now aligned on the VERIFICATION.md check.

### Item 2: Operation B Dual-Path Fix

Current Operation B Step 2 (lines 218–224 of `agents/bridge/bmad-gsd-orchestrator.md`):
```
### Steps:
1. Read the phase's UAT file: `.planning/phases/[N]-UAT.md`
2. Read the corresponding BMAD story: `docs/stories/story-[N].md`
3. Update story status from "In Progress" to "Done"
4. Add completion summary to story file
5. Update `bmad-outputs/STATUS.md` table
```

The fix changes Step 2 to use dual-path find. Established dual-path pattern from Phase 8 (Operation A):
```bash
find docs/stories _bmad-output/stories -maxdepth 1 -name "story-*.md" 2>/dev/null
```

The planner has discretion on phase-to-story file mapping (phase number match vs content match). The simple approach: match by phase number `story-{N}.md` using the phase number extracted from the UAT filename.

Write target (`bmad-outputs/STATUS.md`) stays single-path per locked decision.

### Item 3: config.json Template Dynamic Paths

Current config.json template in Operation A Step 3 (lines 88–121 of `agents/bridge/bmad-gsd-orchestrator.md`):
```json
"bmad_source": {
    "prd": "docs/prd-[name].md",
    "architecture": "docs/architecture-[name].md",
    "stories_dir": "docs/stories/"
}
```

The fix: the template description (which is markdown instructions, not executable code) must instruct the agent to write the actual detected paths rather than hardcoded `docs/` prefix. Since Step 1 already does a find that discovers the actual paths, Step 3 should reference "the path found in Step 1" for each field. The template JSON in the markdown changes from hardcoded `docs/` to a placeholder that clarifies the source, e.g.:
```json
"bmad_source": {
    "prd": "[actual path found in Step 1]",
    "architecture": "[actual path found in Step 1]",
    "stories_dir": "[directory where story files were found in Step 1]"
}
```

This is a documentation change to the template text — it changes what the agent will write when it executes Operation A, not the bash commands in Step 1.

### Item 4: ROADMAP Checkbox Sweep

All plan items in Phase Details sections currently have `- [ ]` even though all phases 1–9 are complete. Research confirms this is consistent — all 13 unchecked plan items across phases 1–9 should become `- [x]`.

Additionally:
- Phase 1 `**Plans**: TBD` should be updated to `**Plans:** 2/2 plans complete`
- Phase 7 `**Plans:** 1 plans` should be updated to `**Plans:** 1/1 plans complete`
- Phase 10 `**Plans**: TBD` will stay TBD until this phase is planned
- The progress table row for Phase 10 shows `0/TBD` — this stays accurate until planning completes

Full inventory of unchecked boxes by phase (from grep output):

| Phase | Unchecked Plan Items |
|-------|---------------------|
| 2 | `02-01-PLAN.md` |
| 3 | `03-01-PLAN.md` |
| 4 | `04-01-PLAN.md`, `04-02-PLAN.md` |
| 4.1 | `04.1-01-PLAN.md` |
| 5 | `05-02-PLAN.md` (note: `05-01-PLAN.md` is already `[x]`) |
| 6 | `06-01-PLAN.md`, `06-02-PLAN.md` |
| 7 | `07-01-PLAN.md` |
| 8 | `08-01-PLAN.md`, `08-02-PLAN.md` |
| 9 | `09-01-PLAN.md` |

Note: Phase 1's two plan items are not listed in ROADMAP.md under Phase Details — the Phase 1 section says `**Plans**: TBD`. The actual plan files `01-01-PLAN.md` and `01-02-PLAN.md` exist on disk. The fix should add the plan list and mark them checked, or simply update `TBD` to `2/2 plans complete` (simpler and consistent with CONTEXT.md decision).

Also: the top-level phase list (lines 15–25) shows `- [x]` for phases 1–9 and `- [ ]` for Phase 10. These are already correct — do not change Phase 10's top-level checkbox.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Identifying unchecked boxes | Custom parser | Grep: `grep -n "- \[ \]" .planning/ROADMAP.md` |
| Verifying ladder logic | Re-reading all conditions | Direct diff against the uat-passing block at lines 80-89 |
| Finding story files | New path logic | Exact dual-path find pattern from wizard-detect.sh line 32 |

## Common Pitfalls

### Pitfall 1: TOTAL_RAW Variable Scope in Bash Ladder
**What goes wrong:** The existing `uat-passing` branch computes `TOTAL_RAW` inside the `if [ "$HAS_UAT" -gt 0 ]` block (line 81). If the VERIFICATION.md block is added before it and also needs `TOTAL_RAW`, a naive copy-paste creates duplicate computation.
**How to avoid:** Either move the `TOTAL_RAW` computation to before the entire ladder (once), or duplicate it inside the VERIFICATION.md block. Both work — duplicating is simpler and avoids refactoring scope. The variable name conflict risk is zero since bash does not scope variables inside `if` blocks.

### Pitfall 2: Status Box "complete" vs "uat-passing" Display
**What goes wrong:** The status box already prints `GSD_PHASE_STATUS` to the Scenario line. Adding "complete" as a new status may need consideration for display — but this is in Claude's Discretion per CONTEXT.md.
**How to avoid:** The status box at lines 326–368 of wizard-detect.sh does not specially format `GSD_PHASE_STATUS` — it flows through `GSD_PHASE_STATUS_JSON` into `wizard-state.json`. The status box displays the scenario, not the phase status directly. No change to status box rendering is needed.

### Pitfall 3: Operation B Step 2 Still References Story by Simple Name
**What goes wrong:** The current Step 2 says `docs/stories/story-[N].md` — it's not a bash command, it's an instruction to the agent. The fix must change the instruction to describe dual-path search, not just the path prefix.
**How to avoid:** Rewrite Step 2 as a bash find command (same as Operation A style) rather than a simple file path reference.

### Pitfall 4: config.json Template Change Must Not Break Operation A Step 1
**What goes wrong:** Step 1 already correctly finds files via dual-path find. Step 3 template is a separate markdown instruction. Making Step 3 reference Step 1's found paths is a documentation-only change — no bash logic is changed.
**How to avoid:** Only change the `bmad_source` JSON block in the template; leave Step 1 bash commands untouched.

### Pitfall 5: ROADMAP Phase 5 Has One Already-Checked Item
**What goes wrong:** Line 111 of ROADMAP.md already shows `- [x] 05-01-PLAN.md`. Only `05-02-PLAN.md` at line 112 is unchecked. Blind replace of all `- [ ]` would re-check the already-checked item (no harm, but creates noise).
**How to avoid:** Use line-targeted edits. The grep confirms 13 unchecked plan items — match that count exactly.

### Pitfall 6: Phase 1 Plans Section Is "TBD" — Not Checkbox Style
**What goes wrong:** Phase 1 has `**Plans**: TBD` (no plan list). Simply checking boxes doesn't apply. The fix requires adding the plan entries or changing the count line.
**How to avoid:** Per CONTEXT.md locked decision, update `TBD` or incorrect counts to match reality. For Phase 1: change `**Plans**: TBD` to `**Plans:** 2/2 plans complete` and optionally add the two plan entries as `- [x]`. Check actual filenames on disk: `01-01-PLAN.md` and `01-02-PLAN.md` exist.

## Code Examples

### wizard-detect.sh: Current HAS_UAT check (lines 74-90) — insertion point for VERIFICATION check

```bash
# Source: skills/wizard-detect.sh lines 70-100 (current)
HAS_CONTEXT=$(find "$LATEST_PHASE_DIR" -maxdepth 1 -name "*-CONTEXT.md" 2>/dev/null | head -1 | wc -l | tr -d ' ')
HAS_PLAN=$(find "$LATEST_PHASE_DIR" -maxdepth 1 -name "*-PLAN*.md" 2>/dev/null | head -1 | wc -l | tr -d ' ')
HAS_UAT=$(find "$LATEST_PHASE_DIR" -maxdepth 1 -name "*-UAT.md" 2>/dev/null | head -1 | wc -l | tr -d ' ')

if [ "$HAS_UAT" -gt 0 ]; then
    ...
```

Add `HAS_VERIFICATION` detection using the same find pattern:
```bash
HAS_VERIFICATION=$(find "$LATEST_PHASE_DIR" -maxdepth 1 -name "*-VERIFICATION.md" 2>/dev/null | head -1 | wc -l | tr -d ' ')
```

### Operation B dual-path read pattern (consistent with wizard-detect.sh line 32)

```bash
# Source: skills/wizard-detect.sh line 32 — established dual-path find
BMAD_STORIES_TOTAL=$(find docs/stories _bmad-output/stories -maxdepth 1 -name "story-*.md" 2>/dev/null | wc -l | tr -d ' ')
```

Operation B Step 2 should use the same pattern to locate the specific story file.

## State of the Art

| Old Approach | Current Approach | When Changed |
|--------------|------------------|--------------|
| wizard-detect.sh ladder: UAT is top check | Add VERIFICATION.md as top check | Phase 10 |
| Operation B reads docs/stories/ only | Dual-path: docs/stories/ + _bmad-output/stories/ | Phase 10 |
| config.json template hardcodes docs/ | Template instructs agent to write actual found paths | Phase 10 |
| ROADMAP plan checkboxes unchecked | All completed plan checkboxes checked | Phase 10 |

## Open Questions

1. **Status box "complete" rendering**
   - What we know: The status box does not specifically render `GSD_PHASE_STATUS` as a separate line (it goes into `wizard-state.json` as `phase_status`). The `NEXT_CMD` is what appears in the "Next:" box line.
   - What's unclear: Whether any downstream consumer (wizard.md menus) needs to handle `"complete"` as a distinct phase_status value vs `"uat-passing"`.
   - Recommendation: This is marked Claude's Discretion. Review wizard.md menus for `phase_status == "uat-passing"` checks — if any exist, they may need to also handle "complete". The planner should add this as a verification step.

2. **Phase 1 ROADMAP plan list format**
   - What we know: Phase 1 says `**Plans**: TBD`. Plan files `01-01-PLAN.md` and `01-02-PLAN.md` exist on disk.
   - What's unclear: Whether to add the full plan list with descriptions (matching other phases) or just update the count line.
   - Recommendation: Match the simpler pattern used by Phase 7 (`**Plans:** 1/1 plans complete`) rather than backfilling plan descriptions, to minimize diff noise.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None — all validation is file-inspection and bash execution |
| Config file | none |
| Quick run command | `bash skills/wizard-detect.sh` (inspect output) |
| Full suite command | Manual inspection of all 4 changed files |

### Phase Requirements → Test Map

This phase has no formal requirement IDs. Success criteria map to manual verification:

| SC | Behavior | Test Type | Automated Check |
|----|----------|-----------|-----------------|
| SC #1 | wizard-detect.sh checks VERIFICATION.md above UAT | manual + bash | `grep "HAS_VERIFICATION" skills/wizard-detect.sh` |
| SC #1 | wizard-backing-agent.md sync note updated | manual | `grep -A5 "Two intentional differences" skills/wizard-backing-agent.md` |
| SC #2 | Operation B Step 2 scans both story paths | manual | `grep "_bmad-output/stories" agents/bridge/bmad-gsd-orchestrator.md` |
| SC #3 | config.json template uses dynamic paths | manual | `grep "actual path found" agents/bridge/bmad-gsd-orchestrator.md` |
| SC #4 | All completed plan checkboxes checked | automated | `grep -c "- \[ \]" .planning/ROADMAP.md` (should equal 1 after fix — only Phase 10) |

### Sampling Rate
- **Per task commit:** Run the grep checks above
- **Phase gate:** All 4 grep checks pass + manual review of wizard-detect.sh bash logic

### Wave 0 Gaps

None — no test infrastructure needed for this phase. All verification is grep-based file inspection.

## Sources

### Primary (HIGH confidence)
- Direct file reads: `skills/wizard-detect.sh`, `skills/wizard-backing-agent.md`, `agents/bridge/bmad-gsd-orchestrator.md`, `.planning/ROADMAP.md`
- `.planning/v1.0-MILESTONE-AUDIT.md` — authoritative audit identifying all 4 tech debt items
- `.planning/phases/10-code-and-documentation-tech-debt/10-CONTEXT.md` — locked decisions

### Secondary (MEDIUM confidence)
- `.planning/STATE.md` — accumulated decisions confirming dual-path find pattern established in Phase 8

## Metadata

**Confidence breakdown:**
- Item 1 (ladder fix): HIGH — exact code location and pattern known, advance logic to replicate is in the same file
- Item 2 (Operation B path): HIGH — dual-path pattern is already established in wizard-detect.sh line 32 and Operation A
- Item 3 (config.json template): HIGH — change is documentation-only, no bash logic
- Item 4 (ROADMAP checkboxes): HIGH — deterministic grep confirms exact items to change

**Research date:** 2026-03-13
**Valid until:** No external dependencies — findings are valid indefinitely (project-internal files only)
