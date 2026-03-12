---
phase: 05-full-agent-routing
plan: 02
subsystem: ui
tags: [wizard, routing, skill-invocation, gap-closure]

# Dependency graph
requires:
  - phase: 05-01
    provides: Post-status menus added to wizard.md (full-stack and gsd-only scenarios)
provides:
  - Fixed Continue option that reads next_command from wizard-state.json and invokes the target Skill directly
  - Zero Route A references remain in wizard.md
  - Global deployment at ~/.claude/skills/wizard.md updated to match source
affects: [wizard, wizard-backing-agent, full-agent-routing]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Direct Skill invocation from next_command field: strip leading /, split on space to get skill name and args"

key-files:
  created: []
  modified:
    - skills/wizard.md

key-decisions:
  - "Continue invokes Skill(next_command) directly — no routing through wizard-backing-agent — Route A was deliberately removed in Phase 4.1 and should not be re-routed through the backing agent"

patterns-established:
  - "next_command pattern: strip leading slash, take command name before space as skill_name, pass remainder as Skill prompt"

requirements-completed: [ORCH-04, TRACE-03]

# Metrics
duration: 2min
completed: 2026-03-12
---

# Phase 05 Plan 02: Fix Continue Option (Gap Closure) Summary

**Eliminated infinite loop in wizard Continue option by replacing broken Route A backing-agent invocation with direct next_command Skill dispatch**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-12T22:19:09Z
- **Completed:** 2026-03-12T22:21:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Fixed full-stack Continue option: now reads next_command from wizard-state.json and invokes the Skill directly
- Fixed gsd-only Continue option: same pattern applied
- Eliminated infinite loop (Continue -> backing-agent -> diagnostic fallback -> "run /wizard again")
- Global deployment updated: ~/.claude/skills/wizard.md matches source

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix Continue option to use direct next_command invocation instead of Route A** - `e00dba5` (fix)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `skills/wizard.md` - Fixed two Continue handlers (full-stack line 80, gsd-only line 115) to use direct Skill invocation from next_command

## Decisions Made
- Continue invokes Skill derived from next_command directly, bypassing wizard-backing-agent entirely. Route A was deliberately removed in Phase 4.1 (decision: "Route A removed from backing agent -- detection and resume logic lives in wizard.md inline and wizard-detect.sh"). The Phase 5.1 plan that added menus incorrectly carried forward the old Route A invocation pattern. This fix restores the correct behavior.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- wizard.md Continue option is fully functional for both full-stack and gsd-only scenarios
- The infinite loop gap is closed — users can proceed to their next GSD command from the wizard menu
- Phase 5 full-agent-routing is complete

## Self-Check: PASSED
- `skills/wizard.md` exists and contains 0 Route A references
- `next_command` appears in wizard.md
- "Continue (Recommended)" option preserved
- diff skills/wizard.md ~/.claude/skills/wizard.md shows no differences
- Commit e00dba5 confirmed in git log

---
*Phase: 05-full-agent-routing*
*Completed: 2026-03-12*
