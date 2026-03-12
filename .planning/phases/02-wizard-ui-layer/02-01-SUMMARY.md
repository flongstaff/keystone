---
phase: 02-wizard-ui-layer
plan: 01
subsystem: ui
tags: [wizard, skill, interactive-menu, AskUserQuestion, scenario-routing]

requires:
  - phase: 01-schema-and-state-detection
    provides: wizard-router.md detection skill and frozen wizard-state.json schema

provides:
  - "skills/wizard.md — interactive wizard skill with 5 scenario blocks and explain mode"
  - "Rebound /wizard entry point to interactive wizard instead of silent router"
  - "Auto-invocation pattern for chosen commands via Skill tool"

affects:
  - phase-03-routing-intelligence
  - phase-04-bridge-and-resume
  - phase-05-traceability

tech-stack:
  added: []
  patterns:
    - "Wizard-router delegation: wizard.md invokes router first, reads wizard-state.json second — no duplicated detection"
    - "0-turn auto-invocation for known scenarios (full-stack, gsd-only): display status box then execute"
    - "1-turn menu for ambiguous scenarios (none, bmad-only, ambiguous): AskUserQuestion then execute"
    - "Explain mode: free side-channel, does not count as interactive turn, re-presents menu without Explain after use"
    - "Context budget discipline: skill reads only router + state file, no @-references, no inline bash"

key-files:
  created:
    - "skills/wizard.md — interactive wizard with YAML frontmatter, 5 scenario blocks, explain mode"
  modified:
    - ".claude/commands/wizard.md — rebound from wizard-router.md to skills/wizard.md"

key-decisions:
  - "wizard.md delegates ALL detection to wizard-router.md — maintains separation between silent router and interactive wizard"
  - "full-stack and gsd-only are 0-turn: status box displayed then auto-invoke immediately, no pre-invocation menu"
  - "Secondary options (check drift, view progress, traceability) deferred to Phase 5 — wizard instructs Claude to respond they are coming in a future update if asked before auto-invoke"
  - "Auto-invocation tries Skill tool first, falls back to reading command file — resilient to tool availability"
  - "Explain mode re-presents menu WITHOUT Explain option to prevent explain loops"

patterns-established:
  - "Skill file structure: YAML frontmatter (name, description, model, tools, maxTurns) + numbered instruction sequence"
  - "AskUserQuestion is used for all interactive menus — no inline text prompts"
  - "Scenario branching in plain prose conditional blocks — Claude reads JSON and matches scenario label"

requirements-completed: [UI-01, UI-02, UI-03, UI-04, ROUTE-02]

duration: 2min
completed: 2026-03-12
---

# Phase 2 Plan 01: Wizard UI Layer Summary

**Interactive wizard skill with 5 scenario-conditional menus, explain mode, and auto-invocation via Skill tool — built on top of wizard-router.md detection without duplicating any logic**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-12T13:12:51Z
- **Completed:** 2026-03-12T13:14:46Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Created `skills/wizard.md` — complete skill with YAML frontmatter (AskUserQuestion, Skill tools, maxTurns: 15) and 5 scenario blocks
- Rebound `/wizard` entry point from silent `wizard-router.md` to interactive `wizard.md`
- Established 0-turn flow for full-stack/gsd-only (auto-invoke immediately) and 1-turn flow for none/bmad-only/ambiguous (menu then invoke)
- Explain mode implemented as a free side-channel on every menu, preventing explain loops by re-presenting without Explain option

## Task Commits

1. **Task 1: Create skills/wizard.md interactive wizard skill** - `218b698` (feat)
2. **Task 2: Rebind /wizard entry point to skills/wizard.md** - `ef18b06` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `/Users/flong/Developer/claude-code-stack/skills/wizard.md` — New interactive wizard skill file with YAML frontmatter, 5 scenario blocks, explain mode, and auto-invocation pattern
- `/Users/flong/Developer/claude-code-stack/.claude/commands/wizard.md` — Updated to reference `skills/wizard.md` instead of `wizard-router.md`; removed "Do not ask questions" constraint

## Decisions Made

- wizard.md delegates detection entirely to wizard-router.md — clean separation between the silent detection layer (Phase 1) and the interactive UI layer (Phase 2)
- Secondary options (drift check, progress view, traceability) deferred to Phase 5 per the plan — wizard instructs Claude to acknowledge them as "coming in a future update" if user asks post-auto-invoke
- Auto-invocation uses Skill tool with fallback to reading command file — resilient pattern that works regardless of tool availability in the session

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `/wizard` entry point now triggers interactive UI, not silent detection
- Wizard-router.md is untouched — Phase 1 detection logic preserved
- Phase 3 (routing intelligence) can extend the `none` scenario menu and the complexity-based path recommendation
- Phase 4 (bridge and resume) can plug into the `bmad-only` Bridge option and `ambiguous` cleanup flow
- Phase 5 (traceability/drift) can implement the secondary options that wizard currently defers

---
*Phase: 02-wizard-ui-layer*
*Completed: 2026-03-12*
