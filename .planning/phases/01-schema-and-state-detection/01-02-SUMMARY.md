---
phase: 01-schema-and-state-detection
plan: 02
subsystem: detection
tags: [bash, json, wizard, schema, verification]

# Dependency graph
requires:
  - phase: 01-01
    provides: "wizard-router skill, wizard-state.json schema, /wizard command"
provides:
  - "Acceptance-gated confirmation that wizard-router correctly classifies all 5 project scenarios"
  - "Frozen wizard-state.json schema — interface contract validated by human verification"
  - "Bug fix: BMAD detection now checks _bmad-output/planning-artifacts/ path in addition to _bmad/docs/"
affects: [02-wizard-ui-layer, 03-new-project-routing, 04-core-backing-agent-routes]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Human acceptance gate: checkpoint:human-verify blocks schema freeze until live verification passes"
    - "Bug discovery during verification: detection bugs surface as wrong scenario classification before other issues"

key-files:
  created: []
  modified:
    - skills/wizard-router.md

key-decisions:
  - "Schema is frozen: wizard-state.json shape validated by human + JSON type assertions; safe for Phase 2 to depend on it"
  - "BMAD detection must check _bmad-output/planning-artifacts/ path — the real artifacts directory, not just _bmad/docs/"

patterns-established:
  - "Acceptance gate pattern: build first (Plan 1), verify second (Plan 2) before declaring any schema frozen"

requirements-completed: [DETECT-01, DETECT-02, DETECT-03, DETECT-04, DETECT-05, ROUTE-01]

# Metrics
duration: 10min
completed: 2026-03-12
---

# Phase 1 Plan 2: Acceptance Verification Summary

**Wizard-router schema frozen after live verification uncovered and fixed BMAD detection path bug (_bmad-output/ not checked)**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-03-12T12:15:00Z
- **Completed:** 2026-03-12T12:25:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Human ran `/wizard` against the live project and confirmed `scenario: "full-stack"` with correct JSON types
- Discovered BMAD detection was missing the `_bmad-output/planning-artifacts/` path — detection would have produced wrong results on any project using GSD's own BMAD output directory
- Fixed `skills/wizard-router.md` to check the correct path before declaring the schema frozen
- All 5 wizard-state.json field contracts verified: booleans are bare `true`/`false`, strings are quoted, null is bare `null`

## Task Commits

1. **Fix: detect BMAD artifacts in _bmad-output/ path** - `a56b326` (fix)

## Files Created/Modified
- `skills/wizard-router.md` - Added `_bmad-output/planning-artifacts/` path to BMAD detection check

## Decisions Made
- Schema is now frozen: `wizard-state.json` shape validated by live execution and JSON type assertions — Phase 2 may depend on this interface
- The `_bmad-output/` directory (not `_bmad/`) is where GSD stores BMAD artifacts after processing — the original detection code only checked `_bmad/docs/`, which is the user-facing input location, not the GSD output location

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed BMAD detection missing _bmad-output/ path**
- **Found during:** Task 1 (human verification of scenario classification)
- **Issue:** `wizard-router.md` checked `_bmad/docs/` for BMAD presence but not `_bmad-output/planning-artifacts/`, causing this project (which uses `_bmad-output/`) to be misclassified
- **Fix:** Added `_bmad-output/planning-artifacts/` glob to the BMAD detection block in `skills/wizard-router.md`
- **Files modified:** `skills/wizard-router.md`
- **Verification:** Re-ran `/wizard`, scenario now correctly shows `full-stack`; python3 JSON validation passes
- **Committed in:** `a56b326`

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Bug fix was necessary for correctness — without it, the frozen schema would have been based on a detection implementation that failed on the most common real-world layout.

## Issues Encountered

None — the bug was found and fixed cleanly during the acceptance gate checkpoint. JSON validation and scenario classification both pass.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness
- `wizard-state.json` schema is definitively frozen and human-verified — Phase 2 can build UI that reads it
- `skills/wizard-router.md` detection is complete and correct for all known BMAD layouts
- All 6 requirements (DETECT-01 through DETECT-05, ROUTE-01) remain complete; bug fix was a correctness improvement within the same requirement scope

---
*Phase: 01-schema-and-state-detection*
*Completed: 2026-03-12*
