---
phase: 14-subagent-injection-confirmation-ux
plan: 01
subsystem: wizard
tags: [wizard, toolkit-injection, trust-classification, capabilities-block, confirmation-ux]

# Dependency graph
requires:
  - phase: 13-state-integration
    provides: wizard-state.json with toolkit.by_stage populated by wizard-detect.sh
provides:
  - wizard.md Step 2.5 trust classification with hardcoded KNOWN_SAFE allowlist
  - Batched confirmation guard (AskUserQuestion) triggered at spawn sites when unknown tools exist
  - Capability block injection at all Agent() and Task() spawn sites in wizard.md
  - Capability block injection before Task(bmad-gsd-orchestrator) in wizard-backing-agent.md
affects: [14-02-subagent-injection-gsd-workflows, wizard-execution, bridge-to-gsd-flow]

# Tech tracking
tech-stack:
  added: []
  patterns:
  - "Stage-filtered capability injection via <capabilities> XML block appended to Agent/Task prompts"
  - "Ephemeral TOOLS_CONFIRMED state variable for per-invocation trust tracking"
  - "KNOWN_SAFE allowlist hardcoded in wizard.md matching Phase 12 stage-tag approach"
  - "Graceful skip: missing/empty toolkit does not break spawn flow"

key-files:
  created: []
  modified:
    - skills/wizard.md
    - skills/wizard-backing-agent.md

key-decisions:
  - "TOOLS_CONFIRMED is ephemeral (local variable only) — never written to wizard-state.json"
  - "Confirmation guard lives inside 'Build Capability Block' helper, not at Step 2.5 — fires at spawn sites only"
  - "Skill() invocations receive no injection (INJ-04) — only Agent() and Task() spawns"
  - "wizard-backing-agent.md Step 2.5 has no confirmation guard — backing agent reads toolkit directly without unknown-tool UX"
  - "Never read toolkit-registry.json from wizard files — only wizard-state.json toolkit.by_stage"

patterns-established:
  - "Build Capability Block pattern: confirmation guard + stage filter + XML formatting — referenced by all spawn points"
  - "capability_block_if_built placeholder in prompt strings documents injection site without runtime magic"

requirements-completed: [INJ-02, INJ-03, INJ-04, CONF-01, CONF-02, CONF-03, PERF-03]

# Metrics
duration: 3min
completed: 2026-03-13
---

# Phase 14 Plan 01: Subagent Injection and Confirmation UX Summary

**Stage-filtered `<capabilities>` injection with batched unknown-tool confirmation added to all wizard Agent() and Task() spawn sites in wizard.md and wizard-backing-agent.md**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-13T19:12:40Z
- **Completed:** 2026-03-13T19:15:51Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Added Step 2.5 to wizard.md with trust classification and hardcoded KNOWN_SAFE allowlist (24 tools)
- Added "Build Capability Block" helper with batched confirmation guard (TOOLS_CONFIRMED state variable)
- Added capability block injection instructions at all 8 Agent/Task spawn sites in wizard.md
- Added Step 2.5 to wizard-backing-agent.md with by_stage.planning injection before bridge Task()
- All 7 verification requirements pass (INJ-02 through PERF-03)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Step 2.5 trust classification and spawn-site confirmation to wizard.md** - `1acc1df` (feat)
2. **Task 2: Add capability injection to wizard-backing-agent.md before bridge Task() spawn** - `c120394` (feat)

**Plan metadata:** (see final commit below)

## Files Created/Modified
- `skills/wizard.md` - Added Step 2.5 (classification), Build Capability Block helper, injection at all Agent/Task spawn sites, Context Budget Discipline update
- `skills/wizard-backing-agent.md` - Added Step 2.5 (bridge capability block), updated Step 3 Task prompt, added never-read-registry rule

## Decisions Made
- The confirmation guard (AskUserQuestion) lives inside the "Build Capability Block" helper, not at Step 2.5. Step 2.5 classifies only. This follows the CONTEXT.md locked timing decision: prompt fires after user selects a spawn-triggering action, before the spawn.
- wizard-backing-agent.md has no confirmation guard because it is already spawned from wizard.md after the user has confirmed. The backing agent reads toolkit directly without a second round of confirmation.
- `{capability_block_if_built}` is used as a placeholder in prompt strings — this makes the injection site explicit in the instruction text without requiring runtime variable resolution.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Plan 01 complete: wizard.md and wizard-backing-agent.md have injection and confirmation UX
- Plan 02 ready: GSD workflow files (plan-phase.md, execute-phase.md, research-phase.md) need same injection pattern without confirmation guard (wizard context is not available in GSD workflows)
- Blocker cleared: INJ-02, CONF-01-03, PERF-03 requirements now satisfied

---
*Phase: 14-subagent-injection-confirmation-ux*
*Completed: 2026-03-13*
