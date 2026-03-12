# Roadmap: Keystone

## Overview

Keystone is a thin orchestration layer that makes BMAD planning and GSD execution feel like one continuous workflow through a single `/wizard` entry point. The build sequence is dependency-driven: the wizard-state.json schema is the interface contract for all three components and must be frozen first. The router skill that writes it comes next. The wizard UI layer reads it. The backing agent processes it. Recovery and polish come last because they are purely additive. Each phase can be tested in isolation before the next begins.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Schema and State Detection** - Freeze wizard-state.json schema and build smart router skill that classifies all four project scenarios
- [x] **Phase 2: Wizard UI Layer** - Build interactive wizard skill with 4-scenario menus, 2-turn max to recommendation, and intent capture (completed 2026-03-12)
- [x] **Phase 3: New Project Routing** - Add complexity-based path recommendation and domain agent suggestions for fresh projects (completed 2026-03-12)
- [x] **Phase 4: Core Backing Agent Routes** - Build backing agent with resume and bridge-to-GSD routes, including traceability assertions (completed 2026-03-12)
- [x] **Phase 4.1: Rewire Backing Agent** - INSERTED — Fix backing agent orphaned by fix commit; restore bridge flow with traceability assertion, update scenario labels, clean tech debt (Gap closure from audit) (completed 2026-03-12)
- [x] **Phase 5: Full Agent Routing** - Add validate-phase, drift-check, and on-demand traceability display routes (completed 2026-03-12)
- [ ] **Phase 6: Recovery, Safety, and Polish** - Add context-reset continuity, IT safety injection, health-monitor prompt, and budget validation
- [ ] **Phase 7: Agent, Skill, Tool and Hook Discovery** - Agent, skill, tool and hook discovery and recommendations
- [ ] **Phase 8: Bridge Path Fix & Infrastructure Cleanup** - Fix orchestrator path mismatch, clean orphaned files, stale labels, and false-negative validation (Gap closure from audit)

## Phase Details

### Phase 1: Schema and State Detection
**Goal**: Users invoking `/wizard` get a correctly classified project state in under one bash block, with the result persisted to wizard-state.json
**Depends on**: Nothing (first phase)
**Requirements**: DETECT-01, DETECT-02, DETECT-03, DETECT-04, DETECT-05, ROUTE-01
**Success Criteria** (what must be TRUE):
  1. Running `/wizard` against a project with no BMAD or GSD files produces scenario A in wizard-state.json
  2. Running `/wizard` against a project with a non-empty `_bmad/docs/` produces scenario C (BMAD-only)
  3. Running `/wizard` against a project with only an empty `_bmad/` directory produces STATE.AMBIGUOUS, not scenario C
  4. Running `/wizard` reads at most 3 files and runs at most 1 bash block before writing wizard-state.json
  5. Running `/wizard` cold against a project with an existing wizard-state.json reads state from disk, not memory
**Plans**: TBD

### Phase 2: Wizard UI Layer
**Goal**: Users reach an actionable, unambiguous recommendation within 2 turns of invoking `/wizard`, with inline explanation available at any branch
**Depends on**: Phase 1
**Requirements**: UI-01, UI-02, UI-03, UI-04, ROUTE-02
**Success Criteria** (what must be TRUE):
  1. A user in scenario A sees a menu appropriate to starting fresh (not GSD resume options)
  2. A user in scenario D (full-stack) sees their exact next GSD command stated literally, e.g., "Run `/gsd:discuss-phase 3`"
  3. A user reaches a concrete recommendation within at most 2 questions from initial `/wizard` invocation
  4. Wizard component overhead consumes less than 10% of context window before delegating to backing agent
  5. A user can type "explain" at any menu prompt and receive context without the wizard restarting
**Plans:** 1/1 plans complete

Plans:
- [ ] 02-01-PLAN.md -- Create interactive wizard skill with 5-scenario menus and rebind /wizard entry point

### Phase 3: New Project Routing
**Goal**: Users starting a fresh project receive a path recommendation (BMAD+GSD vs GSD-only vs quick-task) based on detectable project complexity signals, with relevant domain agents surfaced at the right moment
**Depends on**: Phase 2
**Requirements**: ROUTE-03, ORCH-05
**Success Criteria** (what must be TRUE):
  1. A user with a new project containing a large PRD is recommended the BMAD+GSD path, not GSD-only
  2. A user describing a single-file task is recommended quick-task execution, not full BMAD planning
  3. When a user is at the bridge step for an IT infrastructure project, wizard surfaces the Godot/IT infra domain agent suggestion before proceeding
**Plans:** 1/1 plans complete

Plans:
- [ ] 03-01-PLAN.md -- Add complexity detection, recommendation tags, and domain agent banner

### Phase 4: Core Backing Agent Routes
**Goal**: The backing agent handles the two highest-value intents — resuming GSD work and bridging from completed BMAD planning to GSD — with every BMAD acceptance criterion verified present in GSD phase context files at bridge time
**Depends on**: Phase 2
**Requirements**: ORCH-01, ORCH-02, ORCH-03, TRACE-01, TRACE-02
**Success Criteria** (what must be TRUE):
  1. Selecting "resume" in the wizard causes the backing agent to emit the exact next GSD command (e.g., "Run `/gsd:discuss-phase 3`") without the user having to specify a phase number
  2. Selecting "bridge to GSD" invokes bmad-gsd-orchestrator in a fresh Task() context, not inline
  3. After the bridge completes, every BMAD acceptance criterion from every story appears in at least one GSD phase context file — wizard asserts this and fails loudly if any are missing
  4. The backing agent delegates to existing agents (bmad-gsd-orchestrator, phase-gate-validator) rather than reimplementing their logic
**Plans:** 2/2 plans complete

Plans:
- [ ] 04-01-PLAN.md -- Create wizard-backing-agent.md with Route A (resume) and Route B (bridge + traceability)
- [ ] 04-02-PLAN.md -- Wire wizard.md to invoke backing agent and deploy globally

### Phase 4.1: Rewire Backing Agent
**Goal**: The backing agent is reachable in all live user flows — bridge path runs traceability assertion, resume path uses coordinator, and all scenario labels match current detection output
**Depends on**: Phase 4
**Requirements**: ORCH-01, ORCH-02, ORCH-03, TRACE-01, TRACE-02
**Gap Closure:** Closes gaps from v1.0 milestone audit — backing agent orphaned by fix commit 357e5af
**Success Criteria** (what must be TRUE):
  1. Selecting "bridge to GSD" in the wizard reaches wizard-backing-agent Route B, which prompts for confirmation, delegates via Task(bmad-gsd-orchestrator), and runs the traceability assertion
  2. The backing agent's Route Dispatch matches on `bmad-ready` and `bmad-incomplete` (not the superseded `bmad-only`)
  3. wizard-backing-agent.md YAML frontmatter includes `Task` in the tools list
  4. The model reliably follows the backing agent instructions without shortcutting (the mechanism that caused the original removal must be addressed)
  5. wizard.md Context Budget Discipline block and YAML description reference current files (wizard-detect.sh, not wizard-router.md)
**Plans:** 1/1 plans complete

Plans:
- [ ] 04.1-01-PLAN.md -- Rewire backing agent: remove Route A, fix scenario labels, add Task tool, rewire wizard.md bridge to Task(), deploy globally

### Phase 5: Full Agent Routing
**Goal**: The backing agent handles phase validation, architectural drift detection, and on-demand traceability status display, completing the full intent routing surface
**Depends on**: Phase 4.1
**Requirements**: ORCH-04, TRACE-03
**Success Criteria** (what must be TRUE):
  1. When UAT or phase-gate checks show failures, wizard surfaces the specific failure details and the exact repair command (e.g., "Run `/gsd:fix-issue plan-02`"), not a generic error message
  2. A user can invoke "show traceability" from the wizard and see which BMAD acceptance criteria map to which GSD phases with their current completion status
  3. Selecting "check drift" invokes context-health-monitor and presents its output without reimplementing its logic
**Plans:** 1/1 plans complete

Plans:
- [ ] 05-01-PLAN.md -- Add post-status menus to wizard + Route C traceability display to backing agent

### Phase 6: Recovery, Safety, and Polish
**Goal**: The wizard survives context resets with continuity messaging, automatically injects safety constraints for infrastructure projects, and is validated against a worst-case large project within the 10% context budget
**Depends on**: Phase 4
**Requirements**: RECOV-01, RECOV-02, RECOV-03
**Success Criteria** (what must be TRUE):
  1. After a context reset, the next `/wizard` invocation reads wizard-state.json and opens with a continuity message showing the user's last position before asking for the next action
  2. When the wizard detects an IT infrastructure project, it automatically sets auto_advance to false and requires dry-run confirmation before any destructive operation — without the user having to configure this
  3. After a phase execution completes, wizard prompts the user to run context-health-monitor before proceeding to the next phase
  4. Running the full router + wizard + backing agent chain against a project with a PRD over 500 lines and 8+ phases consumes less than 20k tokens (10% of a 200k window)
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 4.1 -> 5 -> 6

Note: Phase 3 and Phase 4 both depend on Phase 2 (not on each other). Phase 4.1 is a gap closure phase that fixes Phase 4 regression before Phase 5 adds more routes.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Schema and State Detection | 0/TBD | Not started | - |
| 2. Wizard UI Layer | 1/1 | Complete   | 2026-03-12 |
| 3. New Project Routing | 1/1 | Complete   | 2026-03-12 |
| 4. Core Backing Agent Routes | 2/2 | Complete   | 2026-03-12 |
| 4.1. Rewire Backing Agent | 1/1 | Complete   | 2026-03-12 |
| 5. Full Agent Routing | 1/1 | Complete   | 2026-03-12 |
| 6. Recovery, Safety, and Polish | 0/TBD | Not started | - |

### Phase 7: Agent, Skill, Tool and Hook Discovery
**Goal**: [To be planned]
**Depends on**: Phase 6
**Requirements**: TBD
**Plans**: TBD

### Phase 8: Bridge Path Fix & Infrastructure Cleanup
**Goal**: The orchestrator correctly scans all BMAD output paths, all stale references and orphaned files are removed, and false-negative validation commands are fixed
**Depends on**: Phase 4.1
**Requirements**: None (bug fix + tech debt — protects ORCH-01, TRACE-01 from regression)
**Gap Closure:** Closes integration breaks, flow break, and tech debt from v1.0 milestone audit
**Success Criteria** (what must be TRUE):
  1. `bmad-gsd-orchestrator.md` Operation A scans both `docs/` and `_bmad-output/planning-artifacts/` for BMAD planning documents
  2. `wizard-backing-agent.md` Step 4 fallback message references a valid command (not non-existent `/bmad-gsd-orchestrator`)
  3. Orphaned `skills/wizard-router.md` is deleted
  4. `settings.local.json` inline bash snippets use current scenario labels (not superseded `bmad-only`)
  5. `wizard-detect.sh` line 2 comment no longer references orphaned `wizard-router.md`
  6. Phase 4 `VALIDATION.md` quick-run command produces a valid result (not permanently false-negative)
  7. Duplicate global path `~/.claude/skills/wizard-router/wizard-detect.sh` is removed
**Plans**: TBD
