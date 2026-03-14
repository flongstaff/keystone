---
phase: 14-subagent-injection-confirmation-ux
plan: "02"
subsystem: infra
tags: [gsd, workflow, subagent, capability-injection, wizard-state]

# Dependency graph
requires:
  - phase: 13-state-integration
    provides: wizard-state.json toolkit.by_stage structure populated by wizard-detect.sh
provides:
  - Stage-filtered capability injection in plan-phase.md (researcher, planner, checker, revision planner)
  - Stage-filtered capability injection in execute-phase.md (executor, verifier)
  - Stage-filtered capability injection in research-phase.md (researcher)
affects: [gsd-phase-researcher, gsd-planner, gsd-plan-checker, gsd-executor, gsd-verifier]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Build Capability Block pattern: read wizard-state.json once per workflow, build XML block per stage, append after <files_to_read>"
    - "TOOLKIT_AVAILABLE guard: skip injection gracefully when wizard-state.json absent or empty"

key-files:
  created: []
  modified:
    - ~/.claude/get-shit-done/workflows/plan-phase.md
    - ~/.claude/get-shit-done/workflows/execute-phase.md
    - ~/.claude/get-shit-done/workflows/research-phase.md

key-decisions:
  - "wizard-state.json is the sole data source for capability injection — toolkit-registry.json is never read (PERF-03)"
  - "Capability blocks use <capabilities> XML tag matching existing GSD prompt conventions"
  - "Injection skipped gracefully when wizard-state.json absent, toolkit empty, or stage array empty"
  - "Skill() invocations excluded from injection — they share caller context, no prompt to append to"
  - "gsd-verifier Task() spawn in execute-phase.md confirmed — review-stage injection added"

patterns-established:
  - "Capability injection pattern: build once per workflow in a load_toolkit step, reference by stage at each spawn"
  - "Stage preambles: research='Query these before investigating unknowns:', planning='Reference these during planning if relevant:', execution='Use these during implementation if relevant:', review='Use these for validation and checking:'"

requirements-completed: [INJ-01, INJ-03, INJ-04, PERF-03]

# Metrics
duration: 3min
completed: "2026-03-13"
---

# Phase 14 Plan 02: Subagent Injection Summary

**Stage-filtered `<capabilities>` blocks injected into all three GSD workflow files using wizard-state.json toolkit.by_stage as the sole data source**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-13T19:12:39Z
- **Completed:** 2026-03-13T19:15:15Z
- **Tasks:** 2
- **Files modified:** 3 (global GSD workflow files)

## Accomplishments
- Added Step 1.5 (toolkit capabilities loader) to plan-phase.md with 4 injection points before Task() spawns: gsd-phase-researcher (research stage), gsd-planner (planning stage), gsd-plan-checker (review stage), revision planner (planning stage)
- Added `<step name="load_toolkit">` to execute-phase.md with 2 injection points: gsd-executor (execution stage) and gsd-verifier (review stage — verified spawn exists at line 347)
- Added Step 3.5 to research-phase.md with injection before gsd-phase-researcher spawn and `{capability_block_if_built}` placeholder in the Task() prompt

## Task Commits

Each task modified global GSD installation files outside the keystone git repository.

1. **Task 1: Add capability injection to plan-phase.md** - (global file, not in keystone repo)
2. **Task 2: Add capability injection to execute-phase.md and research-phase.md** - (global files, not in keystone repo)

**Plan metadata:** committed via final documentation commit

## Files Created/Modified
- `~/.claude/get-shit-done/workflows/plan-phase.md` - Added Step 1.5 (toolkit loader + Build Capability Block template) and 4 injection instructions before Task() spawns
- `~/.claude/get-shit-done/workflows/execute-phase.md` - Added `<step name="load_toolkit">` and 2 injection instructions before gsd-executor and gsd-verifier Task() spawns
- `~/.claude/get-shit-done/workflows/research-phase.md` - Added Step 3.5 (toolkit loader) and `{capability_block_if_built}` placeholder in Task() prompt

## Decisions Made
- wizard-state.json is the sole data source — no toolkit-registry.json reads anywhere (satisfies PERF-03)
- Capability block format uses `<capabilities>` XML tag to match existing GSD prompt XML conventions
- TOOLKIT_AVAILABLE guard ensures graceful degradation when no toolkit is configured
- Skill() invocations (e.g., auto-advance `Skill(skill="gsd:execute-phase")`) are explicitly excluded from injection per plan specification — they share the caller's context, no subagent prompt to append to
- gsd-verifier Task() spawn confirmed in execute-phase.md `<step name="verify_phase_goal">` — review-stage injection added there

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None - all three workflow files modified cleanly. The gsd-verifier Task() spawn was confirmed to exist (line 347 in execute-phase.md), so no "no verifier spawn found" note was needed in the summary.

## User Setup Required

None - no external service configuration required. Changes take effect immediately on next GSD workflow invocation where wizard-state.json has toolkit.by_stage data.

## Next Phase Readiness
- All three GSD workflow files now inject stage-filtered capability blocks into subagent prompts
- wizard-state.json (populated by Phase 13 wizard-detect.sh integration) is the data source
- Ready for Phase 14 plan 03 if it exists, or phase completion verification

## Self-Check: PASSED

- SUMMARY.md exists at expected path
- Final commit 0ff5912 confirmed
- All 3 workflow files contain injection points (verified via grep)
- INJ-01, INJ-03, INJ-04, PERF-03 requirements marked complete

---
*Phase: 14-subagent-injection-confirmation-ux*
*Completed: 2026-03-13*
