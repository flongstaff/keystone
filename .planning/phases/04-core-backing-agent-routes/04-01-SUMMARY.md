---
phase: 04-core-backing-agent-routes
plan: "01"
subsystem: orchestration
tags: [wizard, backing-agent, resume, bridge, traceability, BMAD, GSD]

# Dependency graph
requires:
  - phase: 01-schema-state-detection
    provides: wizard-state.json schema (scenario, bmad.*, gsd.*, next_command)
  - phase: 02-wizard-ui-layer
    provides: wizard.md UI layer and skill invocation patterns
  - phase: 03-new-project-routing
    provides: project_type detection and recommendation tag pattern
provides:
  - wizard-backing-agent.md with Route A (resume GSD/BMAD) and Route B (bridge + traceability)
  - Coordinator that delegates to bmad-gsd-orchestrator via Task() rather than reimplementing
  - Interactive traceability assertion: every BMAD acceptance criterion is found, mapped, or explicitly deferred
affects:
  - 05-secondary-wizard-intents
  - skills/wizard.md (wired to invoke backing agent in bridge and resume paths)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Conditional operation block: single skill file with Route A / Route B dispatch at the top"
    - "Task() delegation pattern for fresh-context sub-agent invocation (ORCH-02)"
    - "File artifact verification after Task() rather than parsing output text (pitfall 4)"
    - "Collect-all-gaps-first before interactive resolution (anti-anti-pattern)"
    - "awk extraction supporting both H2 and H3 AC headings (pitfall 2)"
    - "DEFERRED-CRITERIA.md tracking file for acknowledged and deferred ACs"

key-files:
  created:
    - skills/wizard-backing-agent.md
  modified: []

key-decisions:
  - "Route B prompts user before bridging — preserves user agency even when BMAD is fully complete"
  - "Route B delegates to bmad-gsd-orchestrator via Task() — never reimplements Operation A logic"
  - "Traceability assertion searches all .planning/ files (cast wide) — AC anywhere counts as covered"
  - "DEFERRED-CRITERIA.md tracks deferred and acknowledged ACs — no criterion is silently dropped"
  - "Bridge does not auto-invoke /gsd:discuss-phase 1 — user decides when to proceed (auto_advance: false)"
  - "Zero-story edge case surfaced explicitly via AskUserQuestion — never vacuously passes"

patterns-established:
  - "Route dispatch: read state first, match conditions, follow labelled route block"
  - "Resume orientation: stopped_at from STATE.md + phase name from ROADMAP.md + next_command from wizard-state.json"
  - "Traceability: collect ALL gaps before presenting any — avoid blocking on first miss"

requirements-completed: [ORCH-01, ORCH-02, ORCH-03, TRACE-01, TRACE-02]

# Metrics
duration: 2min
completed: 2026-03-12
---

# Phase 4 Plan 01: Core Backing Agent Routes Summary

**Wizard backing agent with Route A (resume GSD/BMAD with orientation context) and Route B (BMAD eligibility gate + Task() delegation to bmad-gsd-orchestrator + interactive traceability assertion)**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-12T15:59:04Z
- **Completed:** 2026-03-12T16:01:05Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Created `skills/wizard-backing-agent.md` as the coordinator for the two highest-value wizard intents
- Route A handles both GSD resume (orientation box + auto-invoke next_command) and BMAD resume (gap display + command suggestion) by reading from wizard-state.json and STATE.md
- Route B enforces BMAD eligibility gate, prompts user before bridging, spawns bmad-gsd-orchestrator via Task() for fresh context, verifies via file artifacts, then runs full traceability assertion — every AC is found, mapped to a phase, or explicitly deferred
- All 5 phase requirements (ORCH-01, ORCH-02, ORCH-03, TRACE-01, TRACE-02) satisfied in a single file

## Task Commits

Each task was committed atomically:

1. **Task 1: Create skills/wizard-backing-agent.md with Route A and Route B** - `1f0c7de` (feat)

**Plan metadata:** _(final docs commit follows)_

## Files Created/Modified

- `skills/wizard-backing-agent.md` — Backing agent skill file with YAML frontmatter, route dispatch, Route A (resume), Route B (bridge + traceability), and rules section

## Decisions Made

- **Route B prompts before bridging:** Even when BMAD is fully complete, the backing agent asks "Proceed with bridge?" before invoking Task(). User agency preserved — a fully-complete state may still have stories the user wants to review first.
- **Task() not Skill() for bridge work:** Task() provides a fresh context window per ORCH-02. Skill() inherits the caller's context and is insufficient for heavy bridge work.
- **Cast-wide traceability search:** AC text is searched across all of `.planning/` (not just `context/`). If the string appears anywhere it was deliberately placed — false positives from passing mentions are an acceptable approximation for Phase 4.
- **DEFERRED-CRITERIA.md as tracking file:** Deferred and acknowledged ACs are appended to `.planning/DEFERRED-CRITERIA.md` with story source, criterion text, status, and date — creating an audit trail of every deliberate scope decision.
- **No auto-advance after bridge:** Bridge complete summary shows the next command but does not invoke it — maintains auto_advance: false discipline.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `skills/wizard-backing-agent.md` is ready for integration
- `skills/wizard.md` needs to be updated to invoke the backing agent instead of the direct orchestrator reference in the `bmad-only` bridge option and `full-stack`/`gsd-only` resume paths (addressed in a later plan or Phase 5)
- Global deployment step (`cp skills/wizard-backing-agent.md ~/.claude/skills/`) should be added to the install script

---

*Phase: 04-core-backing-agent-routes*
*Completed: 2026-03-12*
