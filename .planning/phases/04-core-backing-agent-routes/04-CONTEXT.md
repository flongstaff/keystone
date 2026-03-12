# Phase 4: Core Backing Agent Routes - Context

**Gathered:** 2026-03-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the backing agent that handles the two highest-value wizard intents — resuming GSD work and bridging from completed BMAD planning to GSD — with traceability assertions that verify every BMAD acceptance criterion appears in GSD phase context files at bridge time. The backing agent delegates to existing agents (bmad-gsd-orchestrator, phase-gate-validator) rather than reimplementing their logic.

</domain>

<decisions>
## Implementation Decisions

### Bridge trigger behavior
- Bridge eligibility follows BMAD conventions: PRD exists + architecture exists + all stories approved (BMAD's "Definition of Done" pattern via PO approval)
- When stories aren't fully approved, wizard follows BMAD's natural flow — suggests continuing planning rather than bridging
- Bridge option visibility follows BMAD readiness signals: show bridge when approved, suggest continuing when not

### Traceability assertion format
- Strict assertion + interactive resolution: assert 100% BMAD acceptance criteria coverage in GSD phase context files (BMAD's completeness principle), but when gaps are found, present each missing criterion and ask user to map it to a phase or explicitly defer (GSD's "human decides scope" principle)
- Never silently drop a criterion — every one must be either mapped or explicitly deferred by the user

### Resume route behavior
- Show brief context (phase name, last activity, what's next) before auto-invoking — helps reorient after a break. Claude picks what to show based on scenario
- Full lifecycle coverage: handle both BMAD resume (suggest appropriate BMAD command based on doc state) and GSD resume (emit next GSD command)

### Backing agent file structure
- Global deployment to ~/.claude/skills/ so it works in any project — consistent with wizard-detect.sh deployment pattern
- Project-local is source of truth, deployed globally

### Claude's Discretion
- Whether to auto-trigger bridge or prompt first when BMAD is fully complete
- What to show after bridge completes (stop and show result vs auto-continue to phase 1)
- Traceability: extraction approach (grep bullets vs full section), matching method (story origin vs keyword), assertion timing (bridge-only vs periodic)
- Resume: context source (wizard-state.json + STATE.md vs dedicated resume files), BMAD command inference (track last command vs infer from doc state)
- File location (agents/bridge/ vs skills/ vs agents/entry/)
- Invocation method (Agent/Task tool vs Skill tool — based on operation weight)
- Single file with conditional routes vs separate files per route

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `agents/bridge/bmad-gsd-orchestrator.md`: Existing bridge agent with Operation A (BMAD→GSD) and Operation B (GSD→BMAD status sync). 30 maxTurns, uses Read/Write/Edit/Bash/Glob
- `agents/bridge/phase-gate-validator.md`: Formal quality gate with 5 gate checks (acceptance criteria, git hygiene, drift, dependencies, readiness). 20 maxTurns
- `agents/bridge/context-health-monitor.md`: Detects architectural drift between planned and built
- `skills/wizard-detect.sh`: Shared detection script with full state detection + complexity signals — already globally deployed
- `skills/wizard.md`: Interactive wizard with scenario branching — the UI layer that will invoke the backing agent
- `~/.claude/commands/wizard.md`: Global entry point — already updated to run detection + present menu

### Established Patterns
- Agent files use YAML frontmatter (name, description, model, tools, maxTurns)
- bmad-gsd-orchestrator uses conditional operation blocks (Operation A / Operation B) for multiple routes in one file
- Detection in bash (wizard-detect.sh), UI in wizard.md, heavy work delegated to agents — three-layer separation
- Global deployment: project-local source → copy to ~/.claude/skills/ (wizard-detect.sh pattern)
- GSD's STATE.md tracks `stopped_at` and `last_activity` — available for resume context

### Integration Points
- wizard.md (UI) → backing agent (work) → existing agents (bmad-gsd-orchestrator, phase-gate-validator)
- wizard-state.json provides scenario, phase status, BMAD completeness — backing agent reads this
- STATE.md provides session continuity info (stopped_at, last_activity) — backing agent reads for resume context
- BMAD story files contain acceptance criteria under `## Acceptance Criteria` heading
- GSD phase context files (CONTEXT.md) are the target for traceability assertions

</code_context>

<specifics>
## Specific Ideas

- Traceability should follow the spirit of both frameworks: BMAD's "nothing ships without coverage" + GSD's "human decides scope" — strict but not blocking when the human makes an informed decision
- Resume should feel natural — like picking up where you left off, not running a diagnostic
- The backing agent wraps existing agents (Phase 1-2 principle) — it coordinates, not reimplements

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-core-backing-agent-routes*
*Context gathered: 2026-03-12*
