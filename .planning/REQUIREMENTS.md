# Requirements: Keystone

**Defined:** 2026-03-11
**Core Value:** At any point in a project, one command (`/wizard`) tells the user exactly where they are and does the next right thing.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### State Detection

- [x] **DETECT-01**: Wizard detects 4 project states on invocation: neither framework, BMAD-only, GSD-only, full-stack (both)
- [x] **DETECT-02**: Wizard cross-validates state markers (directory AND content checks — empty `_bmad/` is not "BMAD present")
- [x] **DETECT-03**: Wizard handles STATE.AMBIGUOUS when markers contradict (e.g., `_bmad/` exists but no PRD/architecture docs)
- [x] **DETECT-04**: Wizard computes the exact next command from `.planning/` file state (STATE.md, plans, UAT files)
- [x] **DETECT-05**: Wizard reads state cold from disk on every invocation — no in-memory state dependency

### Entry & Routing

- [x] **ROUTE-01**: User can invoke wizard via single `/wizard` command
- [x] **ROUTE-02**: Wizard outputs unambiguous next command (e.g., "Run `/gsd:discuss-phase 3`" not "you could discuss the next phase")
- [ ] **ROUTE-03**: Wizard recommends BMAD+GSD vs GSD-only vs quick-task based on project complexity signals for new projects

### Wizard UI

- [x] **UI-01**: Wizard presents scenario-appropriate menu based on detected state (4 distinct paths)
- [x] **UI-02**: User reaches an actionable recommendation within 2 turns of invoking `/wizard`
- [x] **UI-03**: Wizard overhead consumes less than 10% of context window before delegating to real work
- [x] **UI-04**: User can request inline explanation at any branch point without restarting the wizard flow

### Orchestration

- [ ] **ORCH-01**: Backing agent dispatches to existing agents (bmad-gsd-orchestrator, phase-gate-validator, etc.) rather than reimplementing their logic
- [ ] **ORCH-02**: Backing agent spawns in a fresh context window via Task() for heavy orchestration work
- [ ] **ORCH-03**: Wizard automatically detects when BMAD planning is complete and GSD is uninitialized, and triggers the bridge
- [ ] **ORCH-04**: When UAT/phase-gate shows failures, wizard surfaces the failure details and the exact repair command
- [ ] **ORCH-05**: Wizard suggests relevant domain agents (Godot, IT infra, open-source, admin docs) at appropriate lifecycle points

### Bridge & Traceability

- [ ] **TRACE-01**: BMAD planning output (PRD, architecture, stories) flows into GSD phase context without requiring re-explanation
- [ ] **TRACE-02**: Wizard asserts that every BMAD acceptance criterion appears in a GSD phase context file at the bridge step
- [ ] **TRACE-03**: User can view requirement traceability status (which BMAD criteria map to which GSD phases and their completion status) on demand

### Recovery & Persistence

- [ ] **RECOV-01**: After context reset, wizard detects prior session state from `.planning/wizard-state.json` and presents continuity message
- [ ] **RECOV-02**: Wizard auto-detects infrastructure projects and injects safety rules (auto_advance: false, dry-run requirements, rollback documentation)
- [ ] **RECOV-03**: After phase execution completes, wizard prompts user to run context-health-monitor before continuing

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Advanced Routing

- **AROUTE-01**: Wizard remembers user preferences across projects (global defaults for common choices)
- **AROUTE-02**: Wizard supports custom workflow templates beyond the 4 standard scenarios

### Reporting

- **REPORT-01**: Wizard generates project health dashboard on demand (phases, coverage, drift status)
- **REPORT-02**: Wizard tracks and displays time-in-phase metrics

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Replacing BMAD or GSD commands | Wizard wraps existing tools — reimplementation creates maintenance burden and breaks upstream updates |
| Visual/GUI workflow builder | Claude Code is terminal-first — GUI requires separate server, breaks SSH, adds maintenance outside ecosystem |
| Autonomous multi-phase execution | auto_advance: false is a hard constraint — unattended execution creates irreversible changes, especially on infra projects |
| Natural language intent parsing | Non-deterministic routing defeats the wizard's value prop of reliable, testable state detection |
| Cross-project orchestration | Multiplies state complexity by N — one wizard, one project |
| Changelog / history tracking | Belongs in BMAD docs or external tools — wizard reads state, doesn't track it |
| Configuration wizard / onboarding tour | Adds friction before value — state detection handles first-time case naturally |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| DETECT-01 | Phase 1 | Complete |
| DETECT-02 | Phase 1 | Complete |
| DETECT-03 | Phase 1 | Complete |
| DETECT-04 | Phase 1 | Complete |
| DETECT-05 | Phase 1 | Complete |
| ROUTE-01 | Phase 1 | Complete |
| ROUTE-02 | Phase 2 | Complete |
| UI-01 | Phase 2 | Complete |
| UI-02 | Phase 2 | Complete |
| UI-03 | Phase 2 | Complete |
| UI-04 | Phase 2 | Complete |
| ROUTE-03 | Phase 3 | Pending |
| ORCH-05 | Phase 3 | Pending |
| ORCH-01 | Phase 4 | Pending |
| ORCH-02 | Phase 4 | Pending |
| ORCH-03 | Phase 4 | Pending |
| TRACE-01 | Phase 4 | Pending |
| TRACE-02 | Phase 4 | Pending |
| ORCH-04 | Phase 5 | Pending |
| TRACE-03 | Phase 5 | Pending |
| RECOV-01 | Phase 6 | Pending |
| RECOV-02 | Phase 6 | Pending |
| RECOV-03 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 23 total
- Mapped to phases: 23
- Unmapped: 0

---
*Requirements defined: 2026-03-11*
*Last updated: 2026-03-11 after roadmap creation — all 23 requirements mapped*
