---
phase: 15-dynamic-catalog-display
plan: "01"
subsystem: wizard-ui
tags: [wizard, toolkit-registry, catalog, deduplication, dynamic-rendering]

requires:
  - phase: 12-core-discovery-scanner
    provides: toolkit-discovery.sh scanner that produces toolkit-registry.json
  - phase: 13-state-integration
    provides: toolkit.by_stage in wizard-state.json loaded in Step 2
  - phase: 14-subagent-injection-confirmation-ux
    provides: PERF-03 decision to never read toolkit-registry.json from wizard

provides:
  - Shared ## Display Catalog section in skills/wizard.md with 4-step dynamic rendering
  - Single-line redirects from all 4 Option 4 handlers to the shared Display Catalog block
  - Dynamic stage-grouped catalog from toolkit-registry.json with 10-entry cap per type
  - Hardcoded Phase 7 fallback catalog for fresh installs / missing registry
  - PERF-03 exception in Context Budget Discipline for toolkit-discovery.sh and registry reads
affects:
  - skills/wizard.md runtime behavior for all "Discover tools" invocations
  - toolkit-registry.json (read at Display Catalog Step 2)
  - skills/toolkit-discovery.sh (invoked at Display Catalog Step 1)

tech-stack:
  added: []
  patterns:
    - "Shared instruction block pattern: prose redirect ('Go to ## Section') enables deduplication in LLM skill files"
    - "Hardcoded Keystone subsection within dynamic rendering: prevents parity gap from registry omissions"
    - "KEYSTONE_NAMES exclusion set: filters user-installed tools cleanly without manual enumeration"
    - "PERF-03 lazy-load point: designated exception in Context Budget Discipline for heavy data reads"

key-files:
  created: []
  modified:
    - skills/wizard.md

key-decisions:
  - "Keystone tools section is hardcoded within Display Catalog (not registry-sourced) — 4/11 agents and 4/4 skills are absent from toolkit-registry.json due to parity gap"
  - "Dynamic catalog uses no-bold format (- name -- description) while fallback preserves Phase 7 bold format (- **name** -- description)"
  - "10-entry cap per type sub-group in dynamic rendering with '... and N more' overflow line"
  - "toolkit-discovery as 4th skill added to fallback catalog (was missing from Phase 7 original)"

patterns-established:
  - "Prose redirect pattern: replace duplicate inline blocks with 'Go to ## Section, then re-present this SAME [menu] menu'"
  - "Re-present instruction in redirect: each redirect names its specific return menu for Step 4 to key on"

requirements-completed: [CAT-01, CAT-02, CAT-03]

duration: 4min
completed: 2026-03-13
---

# Phase 15 Plan 01: Dynamic Catalog Display Summary

**Single shared ## Display Catalog block replaces 4 duplicate 43-line inline catalog blocks, with dynamic toolkit-registry.json rendering (stage-grouped, 18 hardcoded Keystone tools) and hardcoded Phase 7 fallback**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-13T20:51:59Z
- **Completed:** 2026-03-13T20:55:59Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Consolidated 4 duplicate 43-line Option 4 catalog blocks into single-line redirects pointing to one shared section
- Created ## Display Catalog with 4-step execution: refresh registry (Step 1), dynamic render from toolkit-registry.json (Step 2), hardcoded Phase 7 fallback (Step 3), return to menu (Step 4)
- All 18 Keystone tools appear in both dynamic Keystone subsections and the hardcoded fallback (parity verified)
- Updated Context Budget Discipline with PERF-03 exception; removed the "Never read toolkit-registry.json" prohibition
- toolkit-discovery added as 4th skill in fallback catalog (was missing from Phase 7 original)

## Task Commits

Each task was committed atomically:

1. **Task 1+2: Consolidate catalog and validate parity** - `cb960c4` (feat)

## Files Created/Modified

- `skills/wizard.md` - Replaced 4 inline Option 4 catalog blocks with single-line redirects; added ## Display Catalog shared section (Steps 1-4); updated Context Budget Discipline with PERF-03 exception

## Decisions Made

- Hardcoded Keystone tools in Display Catalog (not registry-sourced) because 4/11 agents and all 4 skills are absent from toolkit-registry.json due to parity gap
- Used prose redirect pattern "Go to ## Display Catalog below, then re-present this SAME [menu-name] menu" to maintain scenario-specific return context
- Dynamic catalog format uses no-bold, no activation commands; fallback preserves Phase 7 bold format
- 10-entry cap per type sub-group prevents context flooding with large toolkits (176 agents)
- toolkit-discovery added to fallback Skills list as 4th entry (added Phase 12, was missing from Phase 7 original)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

The Task 2 validation script used for automated checks had a shell variable expansion issue in the Bash tool environment (word-split of `$NAMES` variable treated all 18 names as a single token). All individual checks were run separately and confirmed passing. The validation script output `Missing=1` was a false positive due to this environment limitation, not an actual missing tool name.

## Self-Check: PASSED

- `skills/wizard.md`: FOUND
- `cb960c4`: FOUND
- `^## Display Catalog$` count: 1
- `Go to ## Display Catalog` count: 4
- All 4 redirects include "re-present": 4
- `#### Entry` count: 1
- PERF-03 present: 1
- "Never read toolkit-registry.json" removed: 0 occurrences

## Next Phase Readiness

- Plan 15-01 complete. Skills/wizard.md now renders a live toolkit from toolkit-registry.json when the registry is present, falling back to the hardcoded Phase 7 catalog when absent.
- Phase 15 has only 1 plan (15-01). Phase 15 is complete.
- Next: Phase 16 (global deployment / gitignore toolkit-registry.json).

---
*Phase: 15-dynamic-catalog-display*
*Completed: 2026-03-13*
