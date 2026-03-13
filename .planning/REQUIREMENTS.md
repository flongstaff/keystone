# Requirements: Keystone

**Defined:** 2026-03-11
**Core Value:** At any point in a project, one command (`/wizard`) tells the user exactly where they are and does the next right thing.

## v1.0 Requirements (Complete)

All 23 v1.0 requirements shipped across 11 phases. See v1.0 milestone archive for details.

### State Detection

- [x] **DETECT-01**: Wizard detects 4 project states on invocation: neither framework, BMAD-only, GSD-only, full-stack (both)
- [x] **DETECT-02**: Wizard cross-validates state markers (directory AND content checks — empty `_bmad/` is not "BMAD present")
- [x] **DETECT-03**: Wizard handles STATE.AMBIGUOUS when markers contradict (e.g., `_bmad/` exists but no PRD/architecture docs)
- [x] **DETECT-04**: Wizard computes the exact next command from `.planning/` file state (STATE.md, plans, UAT files)
- [x] **DETECT-05**: Wizard reads state cold from disk on every invocation — no in-memory state dependency

### Entry & Routing

- [x] **ROUTE-01**: User can invoke wizard via single `/wizard` command
- [x] **ROUTE-02**: Wizard outputs unambiguous next command (e.g., "Run `/gsd:discuss-phase 3`" not "you could discuss the next phase")
- [x] **ROUTE-03**: Wizard recommends BMAD+GSD vs GSD-only vs quick-task based on project complexity signals for new projects

### Wizard UI

- [x] **UI-01**: Wizard presents scenario-appropriate menu based on detected state (4 distinct paths)
- [x] **UI-02**: User reaches an actionable recommendation within 2 turns of invoking `/wizard`
- [x] **UI-03**: Wizard overhead consumes less than 10% of context window before delegating to real work
- [x] **UI-04**: User can request inline explanation at any branch point without restarting the wizard flow

### Orchestration

- [x] **ORCH-01**: Backing agent dispatches to existing agents (bmad-gsd-orchestrator, phase-gate-validator, etc.) rather than reimplementing their logic
- [x] **ORCH-02**: Backing agent spawns in a fresh context window via Task() for heavy orchestration work
- [x] **ORCH-03**: Wizard automatically detects when BMAD planning is complete and GSD is uninitialized, and triggers the bridge
- [x] **ORCH-04**: When UAT/phase-gate shows failures, wizard surfaces the failure details and the exact repair command
- [x] **ORCH-05**: Wizard suggests relevant domain agents (Godot, IT infra, open-source, admin docs) at appropriate lifecycle points

### Bridge & Traceability

- [x] **TRACE-01**: BMAD planning output (PRD, architecture, stories) flows into GSD phase context without requiring re-explanation
- [x] **TRACE-02**: Wizard asserts that every BMAD acceptance criterion appears in a GSD phase context file at the bridge step
- [x] **TRACE-03**: User can view requirement traceability status (which BMAD criteria map to which GSD phases and their completion status) on demand

### Recovery & Persistence

- [x] **RECOV-01**: After context reset, wizard detects prior session state from `.planning/wizard-state.json` and presents continuity message
- [x] **RECOV-02**: Wizard auto-detects infrastructure projects and injects safety rules (auto_advance: false, dry-run requirements, rollback documentation)
- [x] **RECOV-03**: After phase execution completes, wizard prompts user to run context-health-monitor before continuing

## v1.1 Requirements

Requirements for Dynamic Toolkit Discovery milestone. Each maps to roadmap phases.

### Discovery

- [x] **DISC-01**: Wizard dynamically scans `~/.claude/agents/` for all installed agents, parsing YAML frontmatter name and description
- [x] **DISC-02**: Wizard dynamically scans MCP servers from `settings.json` mcpServers and `installed_plugins.json`
- [x] **DISC-03**: Wizard dynamically scans `~/.claude/skills/` for all installed skills with SKILL.md metadata
- [x] **DISC-04**: Wizard dynamically scans `~/.claude/hooks/` for all registered hooks
- [x] **DISC-05**: Discovery writes full catalog to `toolkit-registry.json` (machine-specific, gitignored)

### Matching

- [x] **MATCH-01**: Wizard maps discovered tools to workflow stages (research/planning/execution/review) via keyword matching on description fields
- [x] **MATCH-02**: Stage filtering caps injected pointers at 5-8 per spawn to prevent context bloat

### Injection

- [x] **INJ-01**: GSD subagent Task() prompts receive stage-filtered capability pointers (name + one-liner format)
- [x] **INJ-02**: BMAD subagent prompts receive stage-filtered capability pointers at appropriate lifecycle points
- [x] **INJ-03**: Injection uses token-efficient format (~40 tokens per pointer, ~200 total per spawn)
- [x] **INJ-04**: Injection targets Task()/Agent() spawns only, never Skill() invocations

### Confirmation

- [x] **CONF-01**: Known-safe tools (Keystone/GSD agents, read-only MCPs) auto-inject without confirmation
- [x] **CONF-02**: Unknown user-installed tools get one batched confirmation per `/wizard` invocation
- [x] **CONF-03**: MCP recommendations use conditional language ("configured — availability may vary")

### Catalog

- [x] **CAT-01**: "Discover tools" reads `toolkit-registry.json` for dynamic display
- [x] **CAT-02**: Catalog displays tools grouped by stage relevance and category
- [x] **CAT-03**: Hardcoded Phase 7 catalog remains as fallback when registry is absent or malformed

### Performance

- [x] **PERF-01**: Discovery uses TTL-gated caching (skip rescan when `toolkit-registry.json` is fresh)
- [x] **PERF-02**: `wizard-state.json` carries compact toolkit summary (~600 bytes) for lightweight startup reads
- [x] **PERF-03**: Full registry loaded only when "Discover tools" is explicitly selected

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Advanced Routing

- **AROUTE-01**: Wizard remembers user preferences across projects (global defaults for common choices)
- **AROUTE-02**: Wizard supports custom workflow templates beyond the 4 standard scenarios

### Reporting

- **REPORT-01**: Wizard generates project health dashboard on demand (phases, coverage, drift status)
- **REPORT-02**: Wizard tracks and displays time-in-phase metrics

### Advanced Discovery

- **ADISC-01**: Semantic capability matching via LLM-based classification over agent bodies
- **ADISC-02**: Per-phase tool recommendation history with persistent cross-session state

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Replacing BMAD or GSD commands | Wizard wraps existing tools — reimplementation creates maintenance burden and breaks upstream updates |
| Visual/GUI workflow builder | Claude Code is terminal-first — GUI requires separate server, breaks SSH, adds maintenance outside ecosystem |
| Autonomous multi-phase execution | auto_advance: false is a hard constraint — unattended execution creates irreversible changes, especially on infra projects |
| Natural language intent parsing | Non-deterministic routing defeats the wizard's value prop of reliable, testable state detection |
| Cross-project orchestration | Multiplies state complexity by N — one wizard, one project |
| Semantic capability matching | LLM-based classification is too expensive and unproven vs keyword matching — defer until keyword matching proves insufficient |
| BMAD internal agent modification | v1.1 injects into BMAD subagent prompts at spawn time, never modifies BMAD framework internals |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

### v1.0 Traceability (Complete)

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
| ROUTE-03 | Phase 3 | Complete |
| ORCH-05 | Phase 3 | Complete |
| ORCH-01 | Phase 4.1 | Complete |
| ORCH-02 | Phase 4.1 | Complete |
| ORCH-03 | Phase 4.1 | Complete |
| TRACE-01 | Phase 4.1 | Complete |
| TRACE-02 | Phase 4.1 | Complete |
| ORCH-04 | Phase 5 | Complete |
| TRACE-03 | Phase 5 | Complete |
| RECOV-01 | Phase 6 | Complete |
| RECOV-02 | Phase 6 | Complete |
| RECOV-03 | Phase 6 | Complete |

### v1.1 Traceability (Pending)

| Requirement | Phase | Status |
|-------------|-------|--------|
| DISC-01 | Phase 12 | Complete |
| DISC-02 | Phase 12 | Complete |
| DISC-03 | Phase 12 | Complete |
| DISC-04 | Phase 12 | Complete |
| DISC-05 | Phase 12 | Complete |
| MATCH-01 | Phase 12 | Complete |
| MATCH-02 | Phase 12 | Complete |
| PERF-01 | Phase 12 | Complete |
| PERF-02 | Phase 13 | Complete |
| INJ-01 | Phase 14 | Complete |
| INJ-02 | Phase 14 | Complete |
| INJ-03 | Phase 14 | Complete |
| INJ-04 | Phase 14 | Complete |
| CONF-01 | Phase 14 | Complete |
| CONF-02 | Phase 14 | Complete |
| CONF-03 | Phase 14 | Complete |
| PERF-03 | Phase 14 | Complete |
| CAT-01 | Phase 15 | Complete |
| CAT-02 | Phase 15 | Complete |
| CAT-03 | Phase 15 | Complete |

**Coverage:**
- v1.1 requirements: 20 total
- Mapped to phases: 20
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-11*
*Last updated: 2026-03-13 after v1.1 roadmap creation*
