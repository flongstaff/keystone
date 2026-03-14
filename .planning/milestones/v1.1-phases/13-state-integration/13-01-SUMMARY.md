---
phase: 13-state-integration
plan: 01
subsystem: wizard
tags: [bash, shell, json, toolkit-discovery, wizard-state, status-box]

# Dependency graph
requires:
  - phase: 12-core-discovery-scanner
    provides: toolkit-discovery.sh that scans agents/skills/hooks/MCP and emits compact JSON summary to stdout
provides:
  - wizard-state.json contains toolkit field with counts and by_stage arrays after every /wizard invocation
  - Status box shows Tools line with agent/skill/hook/MCP counts (hidden when all zero)
  - Graceful fallback: toolkit: {} when toolkit-discovery.sh is absent
affects: [14-subagent-injection, 15-dynamic-catalog]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Bash subshell capture: TOOLKIT_JSON=$(bash script.sh 2>/dev/null) for stdout capture"
    - "Python3 stdin pipe for JSON parsing: echo var | python3 -c 'import json,sys; d=json.load(sys.stdin)'"
    - "Fallback guard: [ -z \"$VAR\" ] && VAR='{}' for missing script resilience"
    - "Conditional status box line: if [ -n \"$VAR\" ]; then printf pattern; fi"

key-files:
  created: []
  modified:
    - skills/wizard-detect.sh

key-decisions:
  - "Use bash subshell + stdout capture instead of temp file: simpler, no cleanup needed"
  - "TOOLKIT_LINE extraction uses python3 stdin pipe to avoid $TOOLKIT_JSON shell interpolation issues with JSON characters"
  - "Fallback to '{}' (not 'null') when toolkit-discovery.sh is absent so heredoc produces valid JSON"
  - "TOOLKIT_DISCOVERY and TOOLKIT_COUNTS sections inserted before JSON WRITE to share TOOLKIT_JSON variable across both heredoc and status box"

patterns-established:
  - "Two-section integration: capture script output -> use in both JSON write and status display"
  - "Conditional status box line pattern: compute display string, then conditionally printf"

requirements-completed: [PERF-02]

# Metrics
duration: 2min
completed: 2026-03-13
---

# Phase 13 Plan 01: State Integration Summary

**wizard-detect.sh now calls toolkit-discovery.sh on every /wizard invocation, embedding a 653-byte compact toolkit summary in wizard-state.json and displaying 'Tools: N agents, N skills, N hooks' in the status box**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-13T16:08:17Z
- **Completed:** 2026-03-13T16:09:52Z
- **Tasks:** 2 (executed as one atomic change since Task 2 setup was interdependent with Task 1)
- **Files modified:** 1

## Accomplishments
- wizard-detect.sh calls toolkit-discovery.sh via bash subshell capture, embedding compact summary as `toolkit` field in wizard-state.json
- Status box shows conditional "Tools: 176 agents, 28 skills, 24 hooks" line between Phase and Last lines
- Graceful fallback: when toolkit-discovery.sh is absent, wizard-state.json gets `"toolkit": {}` and status box hides Tools line entirely
- All four Phase 13 success criteria verified: toolkit field present, 653 bytes (budget: ~600B), all existing fields preserved, fallback passes

## Task Commits

Each task was committed atomically:

1. **Task 1+2: Integrate toolkit discovery call, JSON write, and status box display** - `080e8c5` (feat)

**Plan metadata:** (to be added in final commit)

## Files Created/Modified
- `skills/wizard-detect.sh` - Added TOOLKIT DISCOVERY section, TOOLKIT COUNTS extraction, toolkit field in JSON heredoc, and conditional Tools line in status box

## Decisions Made
- Merged Task 1 and Task 2 into a single commit since the TOOLKIT_LINE extraction is computed in the same section as the TOOLKIT_JSON capture — the two tasks share variable state and the split was editorial rather than architectural
- Used python3 stdin pipe (`echo "$TOOLKIT_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin)"`) instead of embedding JSON directly in python -c string, preventing shell interpolation issues with JSON special characters

## Deviations from Plan

None - plan executed exactly as written. Both tasks were combined into a single commit since they share the same variable scope and the plan explicitly noted Task 2 setup should be added "after the TOOLKIT_JSON capture."

## Issues Encountered
None - the 692-byte initial measurement was under the 700B limit stated in the plan; compact serialization brings it to 653B for the final check.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- wizard-state.json now contains a `toolkit` object with counts and by_stage arrays, ready for Phase 14 subagent injection to read
- Phase 15 dynamic catalog can extract by_stage arrays directly from wizard-state.json without running its own discovery
- The graceful fallback ensures the wizard pipeline remains robust on pre-Phase 12 installs

---
*Phase: 13-state-integration*
*Completed: 2026-03-13*
