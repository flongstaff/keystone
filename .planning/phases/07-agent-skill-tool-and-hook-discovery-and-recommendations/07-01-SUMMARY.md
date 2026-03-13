---
phase: 07-agent-skill-tool-and-hook-discovery-and-recommendations
plan: 01
subsystem: ui
tags: [wizard, catalog, discovery, skills, agents, hooks]

# Dependency graph
requires:
  - phase: 05-full-agent-routing
    provides: post-status menu loop pattern, secondary option re-present behavior
  - phase: 06-recovery-safety-and-polish
    provides: uat-passing menu variants, token budget headroom measurement
provides:
  - Discover tools option in all 4 post-status menu variants (full-stack uat/non-uat, gsd-only uat/non-uat)
  - Inline catalog of 11 agents, 4 skills, 3 hooks with active-marking logic
  - Domain agent active-marking from project_type field in wizard-state.json
affects:
  - wizard.md consumers -- users who interact with /wizard in full-stack and gsd-only scenarios

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Inline catalog display in wizard.md -- static text rendering with one dynamic token (active marking)
    - Phase 5 loop pattern extended to Discover tools -- re-presents same menu variant after catalog view

key-files:
  created: []
  modified:
    - skills/wizard.md

key-decisions:
  - "Catalog lives inline in wizard.md, not delegated to backing agent -- static text display does not justify Task() round-trip overhead"
  - "Discover tools added as LAST option in each menu variant -- power-user feature placed last to keep Continue Recommended as the primary focus"
  - "project_type already in scope from Step 2 -- no second Read of wizard-state.json needed in catalog handler"

patterns-established:
  - "Inline catalog pattern: static text display with dynamic active-marking token rendered directly by wizard.md, not via Task()"

requirements-completed: []

# Metrics
duration: 3min
completed: 2026-03-13
---

# Phase 7 Plan 01: Discover Tools Discovery Summary

**"Discover tools" option added to all 4 wizard post-status menus, displaying hardcoded catalog of 11 agents, 4 skills, and 3 hooks with domain-agent active-marking from project_type**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-13T00:06:36Z
- **Completed:** 2026-03-13T00:09:20Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Added "Discover tools" as the last option in all 4 post-status menus: full-stack uat-passing (option 5), full-stack non-uat-passing (option 5), gsd-only uat-passing (option 4), gsd-only non-uat-passing (option 4)
- Added inline catalog handler in each menu's "After selection" block with complete 11-agent (entry/bridge/domain/maintenance), 4-skill, 3-hook inventory
- Catalog includes active-marking logic: domain agent matching project_type gets " (active)" appended; null or "web" project_type produces no marking
- After viewing catalog, each handler re-presents the SAME menu variant (Phase 5 loop pattern)
- Deployed updated wizard.md globally to ~/.claude/skills/wizard.md

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Discover tools option and inline catalog to wizard.md** - `d8c2768` (feat)
2. **Task 2: Deploy wizard.md globally and verify** - (deploy operation, no separate commit needed; files already committed in Task 1)

**Plan metadata:** (pending docs commit)

## Files Created/Modified

- `skills/wizard.md` - Added Discover tools option to all 4 post-status menus with inline catalog display and active-marking logic (200 lines inserted)

## Decisions Made

- Catalog is inline in wizard.md, not delegated to backing agent -- the display is a lightweight static text operation with one dynamic token; Task() overhead is unjustified for read-only catalog display
- "Discover tools" placed as the LAST option in each menu variant -- ensures it never draws user attention away from Continue (Recommended)
- project_type from Step 2's already-loaded wizard-state.json is reused directly -- no second file read, consistent with Context Budget Discipline rules

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 7 Plan 01 complete. The Discover tools option is live in all post-status menu variants.
- Running `/wizard` from any project will present the Discover tools option when in full-stack or gsd-only scenarios.
- Phase 7 has only one plan (07-01); phase is complete.

---
*Phase: 07-agent-skill-tool-and-hook-discovery-and-recommendations*
*Completed: 2026-03-13*
