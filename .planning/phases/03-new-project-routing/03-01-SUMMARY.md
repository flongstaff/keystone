---
phase: 03-new-project-routing
plan: 01
subsystem: ui
tags: [wizard, routing, complexity-detection, project-type, bash, json-schema]

# Dependency graph
requires:
  - phase: 02-wizard-ui-layer
    provides: wizard.md interactive UI and wizard-router.md silent detection skill
provides:
  - Complexity detection block in wizard-router.md with HAS_PRD, HAS_ARCH, HAS_MULTI_REQS, HAS_LONG_README, CODE_FILE_COUNT, HAS_DEP_MANAGER signals
  - RECOMMENDED_PATH determination logic (bmad-gsd / gsd-only / quick-task)
  - Open-source project type detection via LICENSE, CONTRIBUTING.md, or .github/
  - Extended wizard-state.json schema with complexity_signal and recommended_path fields
  - Conditional (Recommended -- reason) tag on none-scenario menu options in wizard.md
  - Domain agent info banner at bridge moments in bmad-only and full-stack scenarios
affects:
  - 04-bridge-route
  - 05-secondary-options
  - agents/domain/

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Complexity detection uses find+wc idiom already established in BMAD MARKERS section"
    - "Priority-ordered path determination: doc signals win over file count signals"
    - "Domain agent banner is informational text, not AskUserQuestion — non-blocking"
    - "Open-source as fallback type: infra/game/web/docs all take precedence"

key-files:
  created: []
  modified:
    - skills/wizard-router.md
    - skills/wizard.md

key-decisions:
  - "Open-source type detection is a fallback only — placed after all other type checks to preserve priority order"
  - "RECOMMENDED_PATH defaults to gsd-only so unclassifiable projects get a safe default"
  - "Domain agent banner uses box-drawing characters matching existing UI patterns, never AskUserQuestion"
  - "Complexity detection placed between PROJECT TYPE and SCENARIO CLASSIFICATION sections to keep detection logic grouped"

patterns-established:
  - "Pattern 1: Doc signals always override file-count signals for path recommendation"
  - "Pattern 2: Domain agent banner is informational-only at bridge moments — never an interactive turn"
  - "Pattern 3: All 3 path options always visible in none-scenario regardless of recommendation"

requirements-completed: [ROUTE-03, ORCH-05]

# Metrics
duration: 3min
completed: 2026-03-12
---

# Phase 3 Plan 01: New Project Routing Summary

**Complexity-based path recommendation and domain agent surfacing added to wizard via extended wizard-state.json schema (complexity_signal + recommended_path) and conditional UI tags**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-12T13:49:03Z
- **Completed:** 2026-03-12T13:51:57Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- wizard-router.md now detects 6 complexity signals (PRD docs, architecture docs, multi-requirements, long README, dependency manager, code file count) and writes RECOMMENDED_PATH and complexity_signal to wizard-state.json
- wizard-router.md detects open-source project type via LICENSE, CONTRIBUTING.md, or .github/ directory (fallback after infra/game/web/docs)
- wizard.md none-scenario menu now reads recommended_path and applies (Recommended -- reason) tag to exactly one option; all 3 options always visible
- Domain agent info banner added to bmad-only and full-stack scenarios — informational text only, not AskUserQuestion, not an interactive turn

## Task Commits

Each task was committed atomically:

1. **Task 1: Add complexity detection + open-source type + schema extension to wizard-router.md** - `a30a2a9` (feat)
2. **Task 2: Add recommendation tags + domain agent banner to wizard.md** - `8bc57eb` (feat)

**Plan metadata:** TBD (docs: complete plan)

## Files Created/Modified
- `skills/wizard-router.md` - Added COMPLEXITY DETECTION section, open-source type fallback, extended JSON schema with complexity_signal and recommended_path fields
- `skills/wizard.md` - Added conditional recommendation tags to none-scenario menu, added domain agent info banner to bmad-only and full-stack scenarios

## Decisions Made
- Open-source type detection placed as final fallback in PROJECT TYPE section — infra/game/web/docs all take precedence
- RECOMMENDED_PATH defaults to "gsd-only" so projects that don't match any signal get a safe, reasonable default
- Domain agent banner implemented as box-drawing text display matching existing UI patterns; explicitly instructed not to use AskUserQuestion
- Complexity detection block positioned between PROJECT TYPE and SCENARIO CLASSIFICATION to keep detection logic grouped logically

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- wizard-state.json schema is extended and backward-compatible; all new fields are additive
- recommended_path and complexity_signal available for any downstream phase that needs routing context
- Domain agent surfacing established; agents/domain/ agents can be activated by user at bridge moments
- Phase 4 (bridge route) can now read project_type and complexity signals from wizard-state.json

## Self-Check: PASSED

- FOUND: .planning/phases/03-new-project-routing/03-01-SUMMARY.md
- FOUND: skills/wizard-router.md (with complexity_signal, recommended_path, open-source detection)
- FOUND: skills/wizard.md (with Recommended tags, domain agent banner)
- FOUND: commit a30a2a9 (feat: wizard-router.md additions)
- FOUND: commit 8bc57eb (feat: wizard.md additions)

---
*Phase: 03-new-project-routing*
*Completed: 2026-03-12*
